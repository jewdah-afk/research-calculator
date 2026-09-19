--!strict
-- Self-check that runs on Play and prints to Studio's Output window, so a
-- place can be verified without the command bar. Safe to leave in: it only
-- prints. Each line starts with [SurvivorsLike] so it is easy to find.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TAG = "[SurvivorsLike]"

local function check(name: string, fn: () -> string)
	local ok, result = pcall(fn)
	if ok then
		print(TAG, "OK  ", name, "->", result)
	else
		warn(TAG, "FAIL", name, "->", tostring(result))
	end
end

local shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not shared then
	warn(TAG, "FAIL ReplicatedStorage.Shared is missing: the place was not built from the repo")
	return
end

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

print(TAG, "diagnostics finished. If every line above says OK, the place is wired correctly.")
