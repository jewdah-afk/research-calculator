local replicatedStorage = game:GetService("ReplicatedStorage")
local runeStarring_EVENT = replicatedStorage.RemoteEvents.rune_Starring

local Framework = require(replicatedStorage.Framework)
local Popup = Framework:GetEvent("Popup")
local EN = Framework:GetLibrary("EternityNum")

local data = require(script.data)

local messages = {
	MissingAmount = "You are missing some resources!";
	UpgradedStar = "You have reached a new level!!";
	GeneralError = "An Error has Occured";
	Superstar = "Congrats!! You have unlocked SuperStar!!";
	Completed = "You have already unlocked Superstar for this rune"
}

local Runes = {
	Royal = {
		"Destiny", 
		"Odyssey", 
		"Immortality", 
		"Prosperity", 
		"Divinity", 
		"Kingslayer", 
		"Sovereign",
		"Imperial",
		"Monarch", 
		"Throne", 
		"Crown",
		"Royalty",
		"Gilded" 
	};
	Color = {
		"Bloom", 
		"Vibrance",
		"Rainbow",
		"Chrome", 
		"Neon", 
		"Radiance",
		"Colorful",
		"Tinted" 
	};
	Polychrome = {
		"Vexed", 
		"Aether", 
		"Refraction",
		"Prismatic",
		"Spectrum", 
		"Iridium", 
		"Shimmer", 
		"Glow",
	};
	Arctic = {
		"Blizzard", 
		"Subzero", 
		"Frostveil",
		"Hailstorm",
		"Avalanche",
		"Icy", 
		"Snow", 
		"Snowflake",
	};
}


local debounce = {}

local runeStarring = {}

local function takeRunes(player, percentage, runeType)
	for i, rune in player.Runes:GetChildren() do 
		if table.find(Runes[runeType],rune.Name) then 
			rune.Value = rune.Value * percentage
		end 
	end
end

local function checkVibrances(player, compAmount, Rune)
	assert(type(compAmount) == "number", "Comparison Amoumt must be a number")
	if compAmount ~= compAmount then return false, messages.GeneralError end
	
	local rune_DATA = player.Runes
	local Vibrances = rune_DATA.Vibrance
	
	if compAmount > Vibrances.Value then return false, messages.MissingAmount end
	
	local completeMessage
	
	if Rune == "Superstar" then
		completeMessage = messages.Superstar
	else
		completeMessage = messages.UpgradedStar
	end
	
	Vibrances.Value -= compAmount
	return true, completeMessage	
end

local function checkRefractions(player, compAmount, Rune)
	assert(type(compAmount) == "number", "Comparison Amoumt must be a number")
	if compAmount ~= compAmount then return false, messages.GeneralError end

	local rune_DATA = player.Runes
	local Refraction = rune_DATA.Refraction

	if compAmount > Refraction.Value then return false, messages.MissingAmount end

	local completeMessage

	if Rune == "Superstar" then
		completeMessage = messages.Superstar
	else
		completeMessage = messages.UpgradedStar
	end

	Refraction.Value -= compAmount
	return true, completeMessage	
end

local function checkSubzero(player, compAmount, Rune)
	assert(type(compAmount) == "number", "Comparison Amoumt must be a number")
	if compAmount ~= compAmount then return false, messages.GeneralError end

	local rune_DATA = player.Runes
	local Subzero = rune_DATA.Subzero

	if compAmount > Subzero.Value then return false, messages.MissingAmount end

	local completeMessage

	if Rune == "Superstar" then
		completeMessage = messages.Superstar
	else
		completeMessage = messages.UpgradedStar
	end

	Subzero.Value -= compAmount
	return true, completeMessage	
end

local function checkOdyssey(player, compAmount, Rune)
	assert(type(compAmount) == "number", "Comparison Amoumt must be a number")
	if compAmount ~= compAmount then return false, messages.GeneralError end

	local rune_DATA = player.Runes
	local Odyssey = rune_DATA.Odyssey

	if compAmount > Odyssey.Value then return false, messages.MissingAmount end

	local completeMessage

	if Rune == "Superstar" then
		completeMessage = messages.Superstar
	else
		completeMessage = messages.UpgradedStar
	end

	Odyssey.Value -= compAmount
	return true, completeMessage	
end



function runeStarring.onEvent()
	runeStarring_EVENT.OnServerEvent:Connect(function(player, Rune)
		if debounce[player] then return end
		assert(type(Rune) == "string", "Rune parameter must be a string")
		if data[Rune] == nil then return false, messages.GeneralError end
		debounce[player] = true
		
		if data[Rune].Name == "Color" then --Rune = "Color"
			local Stage_DATA = player.Stats.Color_StarStage
			local Stage
			if tonumber(string.sub(Stage_DATA.Value, #Stage_DATA.Value)) == nil then
				Stage = 4
			else
				Stage = tonumber(string.sub(Stage_DATA.Value, #Stage_DATA.Value))
			end 
			if Stage_DATA.Value == "Completed" then
				Popup:FireClient(player, "Error", messages.Completed)
				task.wait(.05)
				debounce[player] = nil
				return
			end

			local Price = data[Rune].Prices[Stage]
			local reward = data[Rune]["Star"..Stage] or data[Rune]["Superstar"]
			local status, Message = checkVibrances(player, Price, Rune)
			if status == false then
				Popup:FireClient(player, "Error", Message)
			elseif status == true then
				Popup:FireClient(player, "Success", Message)
				Stage_DATA.Value = "Star"..Stage+1
				if Stage >= 4 then
					Stage_DATA.Value = "Completed"
					takeRunes(player, 0, "Color")					
				elseif Stage >= 3 then
					Stage_DATA.Value = "Superstar"
					takeRunes(player, 0.5, "Color")
				end
				runeStarring_EVENT:FireClient(player, Rune, Stage_DATA.Value)
				for i, v in reward do
					if v[2] == "+" then 
						player.Stats[v[3]].Value += v[1]
					elseif v[2] == "*" then
						player.Stats[v[3]].Value *= v[1]
					end
				end
			end

			task.wait(.5)
			debounce[player] = nil

		elseif data[Rune].Name == "Polychrome" then
			local Stage_DATA = player.Stats.Polychrome_StarStage
			local Stage
			if tonumber(string.sub(Stage_DATA.Value, #Stage_DATA.Value)) == nil then
				Stage = 4
			else
				Stage = tonumber(string.sub(Stage_DATA.Value, #Stage_DATA.Value))
			end 
			if Stage_DATA.Value == "Completed" then
				Popup:FireClient(player, "Error", messages.Completed)
				task.wait(.05)
				debounce[player] = nil
				return
			end

			local Price = data[Rune].Prices[Stage]
			local reward = data[Rune]["Star"..Stage] or data[Rune]["Superstar"]
			local status, Message = checkRefractions(player, Price, Rune)

			if status == false then
				Popup:FireClient(player, "Error", Message)
			else
				Popup:FireClient(player, "Success", Message)
				Stage_DATA.Value = "Star"..Stage+1
				if Stage >= 4 then
					Stage_DATA.Value = "Completed"
					takeRunes(player, 0, "Polychrome")					
				elseif Stage >= 3 then
					Stage_DATA.Value = "Superstar"
					takeRunes(player, 0.5, "Polychrome")					
				end
				runeStarring_EVENT:FireClient(player, Rune, Stage_DATA.Value)
				for i, v in reward do
					if v[2] == "+" then 
						player.Stats[v[3]].Value += v[1]
					elseif v[2] == "*" then
						player.Stats[v[3]].Value *= v[1]
					end
				end
			end

			task.wait(.5)
			debounce[player] = nil

		elseif data[Rune].Name == "Arctic" then
			local Stage_DATA = player.Stats.Arctic_StarStage
			local Stage
			if tonumber(string.sub(Stage_DATA.Value, #Stage_DATA.Value)) == nil then
				Stage = 4
			else
				Stage = tonumber(string.sub(Stage_DATA.Value, #Stage_DATA.Value))
			end 
			if Stage_DATA.Value == "Completed" then
				Popup:FireClient(player, "Error", messages.Completed)
				task.wait(.05)
				debounce[player] = nil
				return
			end

			local Price = data[Rune].Prices[Stage]
			local reward = data[Rune]["Star"..Stage] or data[Rune]["Superstar"]
			local status, Message = checkSubzero(player, Price, Rune)

			if status == false then
				Popup:FireClient(player, "Error", Message)
			else
				Popup:FireClient(player, "Success", Message)
				Stage_DATA.Value = "Star"..Stage+1
				if Stage >= 4 then
					Stage_DATA.Value = "Completed"
					takeRunes(player, 0, "Arctic")					
				elseif Stage >= 3 then
					Stage_DATA.Value = "Superstar"
					takeRunes(player, 0.5, "Arctic")					
				end
				runeStarring_EVENT:FireClient(player, Rune, Stage_DATA.Value)
				for i, v in reward do
					if v[2] == "+" then 
						player.Stats[v[3]].Value += v[1]
					elseif v[2] == "*" then
						player.Stats[v[3]].Value *= v[1]
					end
				end
			end
				task.wait(.5)
				debounce[player] = nil
				
		elseif data[Rune].Name == "Royal" then
			local Stage_DATA = player.Stats.Royal_StarStage
			local Stage
			if tonumber(string.sub(Stage_DATA.Value, #Stage_DATA.Value)) == nil then
				Stage = 4
			else
				Stage = tonumber(string.sub(Stage_DATA.Value, #Stage_DATA.Value))
			end 
			if Stage_DATA.Value == "Completed" then
				Popup:FireClient(player, "Error", messages.Completed)
				task.wait(.05)
				debounce[player] = nil
				return
			end

			local Price = data[Rune].Prices[Stage]
			local reward = data[Rune]["Star"..Stage] or data[Rune]["Superstar"]
			local status, Message = checkOdyssey(player, Price, Rune)

			if status == false then
				Popup:FireClient(player, "Error", Message)
			else
				Popup:FireClient(player, "Success", Message)
				Stage_DATA.Value = "Star"..Stage+1
				if Stage >= 4 then
					Stage_DATA.Value = "Completed"
					takeRunes(player, 0, "Royal")					
				elseif Stage >= 3 then
					Stage_DATA.Value = "Superstar"
					takeRunes(player, 0.5, "Royal")					
				end
				runeStarring_EVENT:FireClient(player, Rune, Stage_DATA.Value)
				for i, v in reward do
					if v[2] == "+" then 
						player.Stats[v[3]].Value += v[1]
					elseif v[2] == "*" then
						player.Stats[v[3]].Value *= v[1]
					end
				end
			end
			task.wait(.5)
			debounce[player] = nil
			end
			debounce[player] = nil
		end
	)
end


return runeStarring
