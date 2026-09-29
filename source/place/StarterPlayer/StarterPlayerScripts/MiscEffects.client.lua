local spawnIsland = workspace.Areas["Spawn Island"]
local basicRuneModel = spawnIsland.Basic.BasicRune
local colorRuneModel = spawnIsland.Color.ColorRune
local natureRuneModel = spawnIsland.Nature.NatureRune

local spin = 1

while true do
	task.wait()
	basicRuneModel:PivotTo(basicRuneModel:GetPivot() * CFrame.Angles(0, math.rad(spin), 0))
	colorRuneModel:PivotTo(colorRuneModel:GetPivot() * CFrame.Angles(0, math.rad(spin), 0))
	natureRuneModel:PivotTo(natureRuneModel:GetPivot() * CFrame.Angles(0, math.rad(spin), 0))
end