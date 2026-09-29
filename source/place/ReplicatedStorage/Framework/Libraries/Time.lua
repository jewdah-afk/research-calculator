local Second = 1
local Minute = Second * 60
local Hour = Minute * 60
local Day = Hour * 24
local Month = Day * 30
local Year = Month * 12
local Decade = Year * 10
local Century = Decade * 10
local Millenium = Century * 10
local Epoch = Millenium * 1000
local Era = Epoch * 1e6
local Eon = Era * 1e6

return function(Time : number , returnFullTime : boolean, notSeconds : boolean)
	if type(Time) ~= "number" then return "Invalid Time Input" end

	--[ Conversion ]--
	local eons = math.floor(Time / Eon)
	local eras = math.floor(Time / Era)
	local epochs = math.floor(Time / Epoch)
	local milleniums = math.floor(Time / Millenium)
	local centuries = math.floor(Time / Century)
	local decades = math.floor(Time / Decade)
	local years = math.floor(Time / Year)
	local months = math.floor(Time / Month)
	local days = math.floor(Time / Day)
	local hours = math.floor((Time / Hour) % 24)
	local minutes = math.floor((Time / Minute) % 60)
	local seconds = math.floor(Time % 60)

	if returnFullTime  then
		local text = ""
		if eons > 0 then
			text = string.format("%s%seon ", text, eons)
		end
		if eras > 0 then
			text = string.format("%s%sera ", text, eras)
		end
		if epochs > 0 then
			text = string.format("%s%sepoch ", text, epochs)
		end
		if milleniums > 0 then
			text = string.format("%s%smillen ", text, milleniums)
		end
		if centuries > 0 then
			text = string.format("%s%scent ", text, centuries)
		end
		if decades > 0 then
			text = string.format("%s%sdec ", text, decades)
		end
		if years > 0 then
			text = string.format("%s%sy ", text, years)
		end
		if days > 0 then
			text = string.format("%s%sd ", text, days)
		end
		if hours > 0 then
			text = string.format("%s%sh ", text, hours)
		end
		if minutes > 0 then
			text = string.format("%s%sm ", text, minutes)
		end
		if seconds > 0 and not notSeconds then
			text = string.format("%s%ss", text, seconds)
		end
		return text
	end

	if eons > 0 then
		return string.format("%seon ", eons)
	end
	if eras > 0 then
		return string.format("%sera ", eras)
	end
	if epochs > 0 then
		return string.format("%sepoch ", epochs)
	end
	if milleniums > 0 then
		return string.format("%smillen ", milleniums)
	end
	if centuries > 0 then
		return string.format("%scent ", centuries)
	end
	if decades > 0 then
		return string.format("%sdec ", decades)
	end
	if years > 0 then
		return string.format("%sd", years)
	end
	if days > 0 then
		return string.format("%sd", days)
	end
	if hours > 0 then
		return string.format("%sh", hours)
	end
	if minutes > 0 then
		return string.format("%sm", minutes)
	end
	if seconds >= 0 then
		return string.format("%ss", seconds)
	end
end