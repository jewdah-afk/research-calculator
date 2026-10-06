--!nonstrict
-- Drives the plaza's upgrade stands for THIS player only (all changes are client-local):
--   hidden  -> invisible, no collision, no prompt
--   teaser  -> black silhouette, sign reads "???", no prompt (you're close: go earn it!)
--   open    -> real colours pop in with a bounce, prompt enabled
-- Walking away from the stand you opened closes its panel.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Unlocks = require(Shared.Unlocks)

local Stands = {}

local SILHOUETTE = Color3.fromRGB(8, 6, 14)
local CLOSE_DISTANCE = 26

local stands = {} -- [id] = { model, parts = {{part, color, material}}, sign, prompt, display, state }
local onOpen, onLeave
local active = nil

local function setState(s, state, animate)
	if s.state == state then
		return
	end
	local was = s.state
	s.state = state
	for _, rec in s.parts do
		local p = rec.part
		p.LocalTransparencyModifier = if state == "hidden" then 1 else 0
		p.CanCollide = state ~= "hidden" and rec.collide
		if state == "teaser" then
			p.Color, p.Material = SILHOUETTE, Enum.Material.SmoothPlastic
		else
			p.Color, p.Material = rec.color, rec.material
		end
	end
	s.sign.Enabled = state ~= "hidden"
	s.label.Text = if state == "teaser" then "???" else s.def.name
	s.label.TextColor3 = if state == "teaser" then Color3.new(1, 1, 1) else s.color
	s.prompt.Enabled = state == "open"
	-- pop-in when it first unlocks (or first teases) while you're playing
	if animate and state ~= "hidden" and was ~= nil then
		local base = s.model:GetPivot()
		local scale = Instance.new("NumberValue")
		scale.Value = 0.2
		scale.Changed:Connect(function(v)
			s.model:PivotTo(base * CFrame.new(0, (1 - v) * -6, 0))
		end)
		local tw = TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
		tw.Completed:Connect(function()
			s.model:PivotTo(base)
			scale:Destroy()
		end)
		tw:Play()
	end
end

function Stands.init(world: Instance, handlers)
	onOpen, onLeave = handlers.onOpen, handlers.onLeave
	for _, m in world:WaitForChild("Stands"):GetChildren() do
		local id = m:GetAttribute("StandId")
		local def = id and Unlocks.byId[id]
		if not def then
			continue
		end
		local s = { model = m, def = def, parts = {}, color = Color3.fromRGB(def.color[1], def.color[2], def.color[3]) }
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(s.parts, { part = d, color = d.Color, material = d.Material, collide = d.CanCollide })
			elseif d:IsA("BillboardGui") then
				s.sign = d
				s.label = d:FindFirstChildOfClass("TextLabel")
			elseif d:IsA("ProximityPrompt") then
				s.prompt = d
			end
		end
		s.display = m:FindFirstChild("Display")
		s.baseDisplay = s.display and s.display.CFrame
		s.prompt.Triggered:Connect(function()
			active = id
			onOpen(id)
		end)
		stands[id] = s
		setState(s, "hidden", false)
	end
	-- gentle bob on open stands' display orbs + auto-close when you walk off
	local t0 = os.clock()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		local t = os.clock() - t0
		for _, s in stands do
			if s.state == "open" and s.display then
				s.display.LocalTransparencyModifier = 0
				local base = s.baseDisplay
				s.display.CFrame = base * CFrame.new(0, math.sin(t * 2 + s.def.index) * 0.6, 0)
			end
		end
		if active then
			local ch = Players.LocalPlayer.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			local s = stands[active]
			if hrp and s and (hrp.Position - s.model:GetPivot().Position).Magnitude > CLOSE_DISTANCE then
				active = nil
				onLeave()
			end
		end
	end)
end

-- call on every state push
function Stands.refresh(data, animate)
	for id, s in stands do
		setState(s, Unlocks.state(data, id), animate)
	end
end

function Stands.state(id)
	return stands[id] and stands[id].state or "hidden"
end

return Stands
