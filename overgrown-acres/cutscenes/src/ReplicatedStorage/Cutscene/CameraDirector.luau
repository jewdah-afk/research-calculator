-- Third-person cutscene camera. Each shot is recomputed every frame from the
-- characters' positions, so framing holds even while they move.
--
-- Shot kinds:
--   TwoShot      side-on framing that fits both A and B
--   OverShoulder behind From's shoulder, looking at To (both in frame)
--   CloseUp      in front of Subject's face
--   Marker       a fixed CFrame (from a marker part)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local UP = Vector3.yAxis
local BIND_NAME = "CutsceneCamera"

local CameraDirector = {}
CameraDirector.__index = CameraDirector

local function headPosition(model: Model): Vector3
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return model:GetPivot().Position + UP * 1.5
end

local function flatDirection(from: Vector3, to: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function alive(model: Model?): boolean
	return model ~= nil and model.Parent ~= nil
end

function CameraDirector.new()
	return setmetatable({
		shot = nil,
		blend = nil,
		clock = 0,
		running = false,
	}, CameraDirector)
end

function CameraDirector:Start(ignore: { Instance })
	local camera = Workspace.CurrentCamera
	self.camera = camera
	self.saved = {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		FieldOfView = camera.FieldOfView,
	}
	camera.CameraType = Enum.CameraType.Scriptable

	self.current = camera.CFrame
	self.fov = camera.FieldOfView
	self.targetFov = Config.Camera.FieldOfView

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	params.RespectCanCollide = true
	self.rayParams = params

	if Config.Camera.DepthOfField then
		local dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "CutsceneDepthOfField"
		dof.FarIntensity = 0.3
		dof.NearIntensity = 0
		dof.InFocusRadius = 10
		dof.FocusDistance = 12
		dof.Parent = camera
		self.dof = dof
	end

	self.running = true
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:_update(dt)
	end)
end

-- Switches to a new shot. `blendTime` of 0 is a hard cut.
function CameraDirector:SetShot(shot, blendTime: number?)
	self.shot = shot
	if shot.FieldOfView then
		self.targetFov = shot.FieldOfView
	else
		self.targetFov = Config.Camera.FieldOfView
	end

	local duration = blendTime or Config.Camera.BlendTime
	if duration <= 0 then
		local target = self:_target(shot)
		if target then
			self.current = target
			self.lastTarget = target
		end
		self.fov = self.targetFov
		self.blend = nil
	else
		self.blend = { from = self.current, duration = duration, elapsed = 0 }
	end
end

function CameraDirector:Stop()
	if not self.running then
		return
	end
	self.running = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	if self.dof then
		self.dof:Destroy()
		self.dof = nil
	end

	local camera = self.camera
	camera.FieldOfView = self.saved.FieldOfView
	camera.CameraType = Enum.CameraType.Custom
	local player = game:GetService("Players").LocalPlayer
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraSubject = humanoid or self.saved.CameraSubject
end

-- Returns the camera position and the point it looks at for a shot.
function CameraDirector:_frame(shot): (Vector3?, Vector3?)
	local kind = shot.Kind

	if kind == "Marker" then
		local cf: CFrame = shot.CFrame
		return cf.Position, cf.Position + cf.LookVector * 12
	end

	if kind == "OverShoulder" then
		if not (alive(shot.From) and alive(shot.To)) then
			return nil, nil
		end
		local a, b = headPosition(shot.From), headPosition(shot.To)
		local forward = flatDirection(a, b, shot.From:GetPivot().LookVector)
		local right = forward:Cross(UP)
		local side = shot.Side or Config.Camera.ShoulderSide
		local gap = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
		local back = 3.2 + math.min(gap, 24) * 0.12
		local position = a - forward * back + right * side * 2.1 + UP * 0.6
		local focus = a:Lerp(b, 0.7) - UP * 0.25
		return position, focus
	end

	if kind == "TwoShot" then
		if not (alive(shot.A) and alive(shot.B)) then
			return nil, nil
		end
		local a, b = headPosition(shot.A), headPosition(shot.B)
		local forward = flatDirection(a, b, shot.A:GetPivot().LookVector)
		local right = forward:Cross(UP)
		local side = shot.Side or Config.Camera.ShoulderSide
		local mid = a:Lerp(b, 0.5)
		local gap = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude

		-- Pull back far enough that both characters fit horizontally.
		local viewport = self.camera.ViewportSize
		local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
		local tanHalfWidth = math.tan(math.rad(self.targetFov) / 2) * aspect
		local distance = math.max((gap * 0.5 + 2.5) / tanHalfWidth, 7)

		-- Slightly behind A so B's face reads better.
		local direction = (right * side - forward * 0.35).Unit
		local position = mid + direction * distance + UP * 1.2
		local focus = mid - UP * 0.35
		return position, focus
	end

	if kind == "CloseUp" then
		if not alive(shot.Subject) then
			return nil, nil
		end
		local head = headPosition(shot.Subject)
		local look = shot.Subject:GetPivot().LookVector
		local facing = Vector3.new(look.X, 0, look.Z)
		facing = if facing.Magnitude > 0.05 then facing.Unit else Vector3.new(0, 0, -1)
		local right = facing:Cross(UP)
		local side = shot.Side or Config.Camera.ShoulderSide
		local position = head + facing * 4.2 + right * side * 1.3 + UP * 0.2
		return position, head - UP * 0.1
	end

	return nil, nil
end

-- Pulls the camera in front of walls or trees that would block the view.
function CameraDirector:_unblock(position: Vector3, focus: Vector3): Vector3
	local offset = position - focus
	if offset.Magnitude < 0.1 then
		return position
	end
	local hit = Workspace:Raycast(focus, offset, self.rayParams)
	if hit then
		local distance = math.max((hit.Position - focus).Magnitude - 0.6, 1.5)
		return focus + offset.Unit * distance
	end
	return position
end

function CameraDirector:_target(shot): CFrame?
	local position, focus = self:_frame(shot)
	if not (position and focus) then
		return nil
	end
	if shot.Kind ~= "Marker" then
		position = self:_unblock(position, focus)
	end
	self.focus = focus
	return CFrame.lookAt(position, focus)
end

function CameraDirector:_update(dt: number)
	local shot = self.shot
	if not shot then
		return
	end

	local target = self:_target(shot)
	if target then
		self.lastTarget = target
	else
		target = self.lastTarget
	end
	if not target then
		return
	end

	local blend = self.blend
	local cf: CFrame
	if blend then
		blend.elapsed += dt
		local progress = math.clamp(blend.elapsed / blend.duration, 0, 1)
		cf = blend.from:Lerp(target, Util.easeInOut(progress))
		if progress >= 1 then
			self.blend = nil
		end
	else
		cf = self.current:Lerp(target, 1 - math.exp(-Config.Camera.FollowSpeed * dt))
	end
	self.current = cf
	self.fov += (self.targetFov - self.fov) * (1 - math.exp(-4 * dt))

	local sway = CFrame.identity
	local amount = Config.Camera.Sway
	if amount > 0 then
		self.clock += dt
		local t = self.clock
		sway = CFrame.Angles(
			math.rad(math.sin(t * 0.9) * amount * 0.6 + math.sin(t * 2.3) * amount * 0.15),
			math.rad(math.sin(t * 0.7 + 1.3) * amount),
			0
		)
	end

	local camera = self.camera
	camera.CFrame = cf * sway
	camera.FieldOfView = self.fov
	if self.dof and self.focus then
		self.dof.FocusDistance = (self.focus - cf.Position).Magnitude
	end
end

return CameraDirector
