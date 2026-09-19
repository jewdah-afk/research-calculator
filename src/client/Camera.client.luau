--!strict
--[[
	Camera.client.luau — top-down locked follow camera.

	The reference is a fixed-zoom 2D game whose camera is simply centred on the
	player, so the only thing to port is the framing rule: the player stays in
	the middle of the screen and the view never rotates. Roblox needs a height,
	a setback and a field of view to express that, and none of the three exist
	in research/vs — they are in Tuning.camera, flagged NOT from research.

	The camera trails the player by an exponential follow (Tuning.camera
	.followRate) rather than snapping, which hides the one-frame lag between
	the server's simulated position and the replicated root part.

	Owns nothing in the simulation: it reads the character's position and
	writes only to the local Camera.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tuning = require("../shared/Tuning")

local CAMERA = Tuning.camera

local player = Players.LocalPlayer

-- Where the camera currently looks. Seeded on the first frame that finds a
-- character so the camera does not sweep in from the origin.
local focusX = 0
local focusZ = 0
local hasFocus = false

local function rootPart(): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function onRenderStep(dt: number)
	-- CurrentCamera is nil for a frame or two around a respawn.
	local camera: Camera? = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	local root = rootPart()
	if root == nil then
		-- No character yet (spawning, or between deaths). Leave the camera
		-- wherever it was; re-seed the focus when one appears.
		hasFocus = false
		return
	end

	local position = root.Position
	if not hasFocus then
		focusX = position.X
		focusZ = position.Z
		hasFocus = true
	else
		-- Exponential approach: close `followRate` of the remaining gap per
		-- second, framerate-independent.
		local alpha = 1 - math.exp(-CAMERA.followRate * dt)
		focusX += (position.X - focusX) * alpha
		focusZ += (position.Z - focusZ) * alpha
	end

	local focus = Vector3.new(focusX, position.Y, focusZ)
	local eye = Vector3.new(focusX, position.Y + CAMERA.height, focusZ + CAMERA.backDistance)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA.fieldOfView
	camera.CFrame = CFrame.lookAt(eye, focus)
end

RunService:BindToRenderStep("SurvivorsLikeCamera", Enum.RenderPriority.Camera.Value, onRenderStep)
