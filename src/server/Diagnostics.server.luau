--!strict
-- Self-check that runs on Play. Results print to the Output window AND are
-- shown on screen for every player, so a place can be verified with no
-- Studio panels open. Safe to leave in: it only prints and draws a label.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TAG = "[SurvivorsLike]"
local lines: { string } = {}
local allOk = true

local function check(name: string, fn: () -> string)
	local ok, result = pcall(fn)
	if ok then
		print(TAG, "OK  ", name, "->", result)
		table.insert(lines, "OK    " .. name .. "  —  " .. result)
	else
		allOk = false
		warn(TAG, "FAIL", name, "->", tostring(result))
		table.insert(lines, "FAIL  " .. name .. "  —  " .. tostring(result))
	end
end

local shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not shared then
	allOk = false
	table.insert(lines, "FAIL  ReplicatedStorage.Shared is missing: the place was not built from the repo")
else
	check("data modules load", function()
		local weapons = require(shared:WaitForChild("Data"):WaitForChild("Weapons")) :: any
		return string.format(
			"%s baseDamage=%d levels=%d",
			weapons.data.whip.name,
			weapons.data.whip.baseDamage,
			#weapons.data.whip.levels
		)
	end)

	check("string requires resolve", function()
		local probe = require(shared:WaitForChild("RequireProbe")) :: any
		return "probe returned " .. tostring(probe) .. " (expected 10)"
	end)

	check("tuning present", function()
		local tuning = require(shared:WaitForChild("Tuning")) :: any
		return "baseWalkSpeed=" .. tostring(tuning.baseWalkSpeed)
	end)
end

table.insert(lines, "")
table.insert(
	lines,
	if allOk then 'ALL OK — tell Claude "all OK"' else "Something FAILED — screenshot this and send it to Claude"
)
print(TAG, "diagnostics finished.")

local text = table.concat(lines, "\n")

local function show(player: Player)
	local gui = player:WaitForChild("PlayerGui", 10)
	if not gui then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "SurvivorsLikeDiagnostics"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -40, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Position = UDim2.new(0, 20, 0, 60)
	label.BackgroundColor3 = if allOk then Color3.fromRGB(20, 60, 30) else Color3.fromRGB(80, 25, 25)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.Code
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = "SurvivorsLike self-check\n\n" .. text
	label.Parent = screen

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = label

	screen.Parent = gui
end

for _, p in Players:GetPlayers() do
	task.spawn(show, p)
end
Players.PlayerAdded:Connect(show)
