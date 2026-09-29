local Framework = require(game.ReplicatedStorage.Framework)
local Months = Framework:GetSharedModule("Months")
local Days = Framework:GetSharedModule("Days")

return function(Time : number)
	local TimeJoined = os.date("*t", Time)
	local Year = TimeJoined.year
	local Month = Months[TimeJoined.month]
	local Day = TimeJoined.day
	local DayOfWeek = Days[TimeJoined.wday]
	local Hour = TimeJoined.hour
	local Minute = TimeJoined.min
	local Seconds = TimeJoined.sec
	
	return `{Month} {Day} {Year}`
end