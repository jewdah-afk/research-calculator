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

-- Every number below comes from Tuning.diagnostics (ARCHITECTURE.md rule 2).
-- If Tuning itself cannot be required the place is broken; that is reported as a
-- failed check and the on-screen label is skipped rather than guessed at.
local tuningOk, Tuning = pcall(function()
	return require("../shared/Tuning") :: any
end)
local ui = if tuningOk then Tuning.diagnostics else nil

-- No Tuning means no timeout constant to wait with, so fall back to a
-- non-yielding lookup rather than inventing a literal here.
local shared = if ui
	then ReplicatedStorage:WaitForChild("Shared", ui.waitTimeout)
	else ReplicatedStorage:FindFirstChild("Shared")
if not shared then
	allOk = false
	table.insert(lines, "FAIL  ReplicatedStorage.Shared is missing: the place was not built from the repo")
else
	check("data modules load", function()
		-- String path, like every other module in src/: this require is itself
		-- part of the check that server -> shared paths resolve in the place.
		local weapons = require("../shared/Data/Weapons") :: any
		-- `levels` is read only by Sim/WeaponLevels (ARCHITECTURE.md rule 4), so
		-- the folded top-level stats stand in for a direct `.levels` probe.
		local weaponLevels = require("../shared/Sim/WeaponLevels") :: any
		local maxLevel = weaponLevels.maxLevel("whip")
		-- Ids only. `Data.*.name` is the reference label and never reaches a
		-- player-facing string (docs/ARCHITECTURE.md rule 7).
		return string.format(
			"whip baseDamage=%d maxLevel=%d maxDamage=%s",
			weapons.data.whip.baseDamage,
			maxLevel,
			tostring(weaponLevels.statsAt("whip", maxLevel).damage)
		)
	end)

	check("string requires resolve", function()
		-- RequireProbe is reached by a server -> shared string require and
		-- itself string-requires ./Data/Weapons, so this fails exactly when
		-- the real path shape fails.
		local probe = require("../shared/RequireProbe") :: any
		return "probe returned " .. tostring(probe) .. " (expected 10)"
	end)

	check("tuning present", function()
		if not tuningOk then
			error(tostring(Tuning), 0)
		end
		return "baseWalkSpeed=" .. tostring(Tuning.baseWalkSpeed)
	end)
end

table.insert(lines, "")
table.insert(
	lines,
	if allOk then 'ALL OK — tell Claude "all OK"' else "Something FAILED — screenshot this and send it to Claude"
)
print(TAG, "diagnostics finished.")

local text = table.concat(lines, "\n")

local function rgb(c: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function show(player: Player)
	if not ui then
		return
	end
	local gui = player:WaitForChild("PlayerGui", ui.waitTimeout)
	if not gui then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "SurvivorsLikeDiagnostics"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, ui.widthInset, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Position = UDim2.new(0, ui.offsetX, 0, ui.offsetY)
	label.BackgroundColor3 = if allOk then rgb(ui.colors.ok) else rgb(ui.colors.fail)
	label.BackgroundTransparency = ui.backgroundTransparency
	label.TextColor3 = rgb(ui.colors.text)
	label.Font = Enum.Font.Code
	label.TextSize = ui.textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = "SurvivorsLike self-check\n\n" .. text
	label.Parent = screen

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, ui.paddingY)
	pad.PaddingBottom = UDim.new(0, ui.paddingY)
	pad.PaddingLeft = UDim.new(0, ui.paddingX)
	pad.PaddingRight = UDim.new(0, ui.paddingX)
	pad.Parent = label

	screen.Parent = gui
end

for _, p in Players:GetPlayers() do
	task.spawn(show, p)
end
Players.PlayerAdded:Connect(show)
