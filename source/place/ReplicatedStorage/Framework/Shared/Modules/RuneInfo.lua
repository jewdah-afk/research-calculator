local Runes = game.ReplicatedStorage.Framework.Libraries.Runes

local module = {}

for _ , Category in Runes:GetChildren() do
	Category = require(Category)
	for _ , Info in Category.Runes do
		module[Info.Name] = Info.Chance
	end
end

--print(module)

return module
