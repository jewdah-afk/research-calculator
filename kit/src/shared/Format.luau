--!nonstrict
-- Format — number and time formatting shared by server logs and client UI.

local Format = {}

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}

-- 1234567 -> "1.23M"
function Format.short(value)
	value = tonumber(value) or 0
	local sign = value < 0 and "-" or ""
	value = math.abs(value)

	if value < 1000 then
		return sign .. tostring(math.floor(value + 0.5))
	end

	local index = math.floor(math.log(value, 1000))
	index = math.clamp(index, 1, #SUFFIXES - 1)
	local scaled = value / 1000 ^ index

	local decimals = scaled < 10 and 2 or (scaled < 100 and 1 or 0)
	return string.format("%s%." .. decimals .. "f%s", sign, scaled, SUFFIXES[index + 1])
end

-- 1234567 -> "1,234,567"
function Format.comma(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local formatted = text
	while true do
		local replaced
		formatted, replaced = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return formatted
end

-- 3725 -> "1h 2m"
function Format.duration(seconds)
	seconds = math.max(math.floor(tonumber(seconds) or 0), 0)
	if seconds < 60 then
		return seconds .. "s"
	end
	local minutes = math.floor(seconds / 60)
	if minutes < 60 then
		return minutes .. "m " .. (seconds % 60) .. "s"
	end
	local hours = math.floor(minutes / 60)
	if hours < 24 then
		return hours .. "h " .. (minutes % 60) .. "m"
	end
	return math.floor(hours / 24) .. "d " .. (hours % 24) .. "h"
end

-- 65 -> "1:05" for countdown pills
function Format.clock(seconds)
	seconds = math.max(math.floor(tonumber(seconds) or 0), 0)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

return Format
