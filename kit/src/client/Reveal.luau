--!nonstrict
--[[
	Reveal — the hatch moment.

	This is the "clicky" part of the genre and it is worth more than any economy
	tweak: the roll already happened on the server, this is purely about making
	the number feel earned. Rarer pulls get a longer wind-up, a brighter flash
	and camera shake, so players learn to read the animation before the text.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Reveal = {}

local function new(class, props, parent)
	local instance = Instance.new(class)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

function Reveal.mount(screenGui)
	local holder = new("Frame", {
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(340, 150),
		BackgroundColor3 = Color3.fromRGB(18, 20, 26),
		BackgroundTransparency = 1,
		Visible = false,
	}, screenGui)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, holder)
	local stroke = new("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Transparency = 1 }, holder)

	local flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, screenGui)

	local rarity = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
	}, holder)

	local name = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 46),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 34,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
	}, holder)

	local chance = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 96),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(190, 198, 210),
		Text = "",
	}, holder)

	local shaking = false

	local function shake(intensity, duration)
		if shaking or intensity <= 0 then
			return
		end
		shaking = true
		task.spawn(function()
			local camera = workspace.CurrentCamera
			local elapsed = 0
			while elapsed < duration do
				local delta = RunService.RenderStepped:Wait()
				elapsed += delta
				local falloff = 1 - elapsed / duration
				camera.CFrame = camera.CFrame * CFrame.new(
					(math.random() - 0.5) * intensity * falloff,
					(math.random() - 0.5) * intensity * falloff,
					0
				)
			end
			shaking = false
		end)
	end

	function Reveal.play(result)
		holder.Visible = true
		holder.BackgroundTransparency = 0.05
		holder.Size = UDim2.fromOffset(300, 130)
		stroke.Color = result.color or Color3.new(1, 1, 1)
		stroke.Transparency = 0

		rarity.Text = string.upper(result.rarity or "")
		rarity.TextColor3 = result.color or Color3.new(1, 1, 1)
		name.Text = result.pet or "?"
		chance.Text = result.chance or ""

		TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(360, 160),
		}):Play()

		local shakeAmount = result.shake or 0
		if shakeAmount > 0 then
			flash.BackgroundTransparency = 1 - math.min(shakeAmount * 0.35, 0.75)
			TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
			shake(shakeAmount * 0.35, 0.35 + shakeAmount * 0.15)
		end

		task.delay(2.2 + shakeAmount * 0.5, function()
			local fade = TweenService:Create(holder, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			fade:Play()
			fade.Completed:Wait()
			holder.Visible = false
		end)
	end

	return Reveal
end

return Reveal
