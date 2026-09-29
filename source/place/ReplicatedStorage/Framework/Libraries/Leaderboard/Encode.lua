local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")

return {
	Total_Energy = function(Value : string)
		return EN.lbencode(Value)
	end,
	
	Prisms = function(Value : string)
		return EN.lbencode(Value)
	end,
	
	Playtime = function(Value : string)
		return math.floor(Value)
	end,
	
	TierTwelveTime = function(Value : string)
		return math.floor(Value)
	end,
	
	Runes_Opened = function(Value : number)
		return math.floor(Value)
	end,
	
	RawRunes_Opened = function(Value : number)
		return math.floor(Value)
	end,
}