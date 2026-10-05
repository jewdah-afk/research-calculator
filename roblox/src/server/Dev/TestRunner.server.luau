--!nonstrict
-- Runs the QA suite inside Studio (never in live servers).
-- Turn on: select this script and set its attribute "Run" = true, then press Play.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or not script:GetAttribute("Run") then
	return
end
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tests = game:GetService("ServerStorage"):WaitForChild("Tests")
local S = {}
for _, m in Shared:GetChildren() do
	if m:IsA("ModuleScript") then
		S[m.Name] = require(m)
	end
end
local unit = require(Tests.UnitTests)(S)
print(string.format("[QA] unit: %d passed, %d failed", unit.passed, #unit.failed))
for _, f in unit.failed do
	warn("[QA] FAIL " .. f)
end
local sim = require(Tests.PacingSim)(S, { tiers = 25 })
print(string.format("[QA] pacing: tier %d in %.1fh game time, %s", sim.final.tiers, sim.hours, sim.ok and "PASS" or "FAIL"))
for _, f in sim.fails do
	warn("[QA] " .. f)
end
