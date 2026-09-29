local random = Random.new()

local Colors = {
	
	--// SYSTEM CHAT \\--
	System = Color3.fromRGB(255, 120, 255);
	Title = Color3.fromRGB(114, 255, 224);
	Version = Color3.fromRGB(120, 75, 255);
	Shutdown = Color3.fromRGB(255, 255, 255);
	Error = Color3.fromRGB(255, 79, 79);
	Success = Color3.fromRGB(101, 255, 114);
	Loading = Color3.fromRGB(115, 115, 115);
	
}

Colors.__index = function(self, index)

	if index == "init" then return end

	if not Colors[index] then
		--warn(string.format("%s NOT FOUND INSIDE OF COLORS, USING RANDOM COLOR", index))
		local randomizedColor = Color3.fromRGB(random:NextInteger(1,255),random:NextInteger(1,255),random:NextInteger(1,255))
		return randomizedColor
	end

	return Colors[index]
end

return setmetatable({},Colors)
