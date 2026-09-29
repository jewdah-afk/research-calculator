local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")

return {
	Total_Energy = function(Value : number)
		return EN.toString(EN.lbdecode(Value))
	end,
	
	Prisms = function(Value : number)
		return EN.toString(EN.lbdecode(Value))
	end,
}