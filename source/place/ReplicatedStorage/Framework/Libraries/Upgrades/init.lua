local Framework = require(game.ReplicatedStorage.Framework)
--[ Services ]--
local Sound_Service = Framework:GetService("SoundService")
--[ Libraries ]--
local EN = Framework:GetLibrary("EternityNum")
--[ Variables ]--
local Cache = {}


--[ Main ]--
local Upgrades = {}
Upgrades.__index = Upgrades
Upgrades.__call = function(Table, Key)
	local Upgrade = Cache[Key]
	if not Upgrade then
		Upgrade = setmetatable({}, Upgrades)

		local Module = script:FindFirstChild(Key, true)
		if Module then
			Module = require(Module)
			for New_Key , Value in Module do
				Upgrade[New_Key] = Value
			end
		else
			warn(`UPGRADES | WARNING | {Key} HAS NO UPGRADE INFORMATION. BE CAUTIOUS OF ERRORS!`)
		end

		--// Server Only \\--
		function Upgrade:Buy(Level : number, Max : boolean, Player : Player) -- When Max is true, buys available amount	
			local Currency;
			local Environment = Framework.Environment


			if Environment == "Client" then
				if self.MultiBuy then
					for _, priceTable in self.MultiBuy do
						if priceTable.isRune then
							Currency = Player.Runes[priceTable.Currency]
						else 
							Currency = Player.Stats[priceTable.Currency]
						end
						if not self:CanAfford(Level.Value, Currency.Value, Player, priceTable) then return print("Cannot Buy") end
					end
				else 
					Currency = Player.Stats[self.Currency].Value
					if not self:CanAfford(Level.Value, Currency, Player, self) then return print("Cannot Buy") end
				end
				
				Framework.Events.Buy_Upgrade:FireServer(Key, Max)
				Sound_Service.Upgrade:Play()
				return
			end

			if Environment == "Server" then
				
				if self.MultiBuy then
					for _, priceTable in self.MultiBuy do
						if priceTable.isRune then
							Currency = Player.Runes[priceTable.Currency]
						else 
							Currency = Player.Stats[priceTable.Currency]
						end
						if not self:CanAfford(Level.Value, Currency.Value, Player, priceTable) then return end
					end
				else 
					Currency = Player.Stats[self.Currency]
					if not self:CanAfford(Level.Value, Currency.Value, Player, self) then return  end
				end
				
				
				if not Max then
					
					if self.MultiBuy then 
						for _, priceTable in self.MultiBuy do
							if priceTable.isRune then
								Currency = Player.Runes[priceTable.Currency]
							else 
								Currency = Player.Stats[priceTable.Currency]
							end
							if typeof(Currency.Value) == "number" then
								Currency.Value -= EN.toNumber(self:GetCost(Level.Value, Player, priceTable))
							elseif typeof(Currency.Value) == "string" then
								Currency.Value = EN.toString(EN.sub(Currency.Value, self:GetCost(Level.Value, Player, priceTable)))
							end
						end
					else 
						if typeof(Currency.Value) == "number" then
							Currency.Value -= EN.toNumber(self:GetCost(Level.Value, Player, self))
						elseif typeof(Currency.Value) == "string" then
							Currency.Value = EN.toString(EN.sub(Currency.Value, self:GetCost(Level.Value, Player, self)))
						end
					end
		
					if self.CustomEffect then
						self.CustomEffect(Player)
					end
		
					Level.Value += 1
					return
				end

				--// Buy Max \\--
				Currency = Player.Stats[self.Currency]
				local Max = self:ReturnMax(Currency.Value, Level.Value, Player)
				local New_Level = math.clamp(Max.Levels, 0, self:GetLevels(Player))

				if New_Level > Level.Value then
					if typeof(Currency.Value) == "number" then
						Currency.Value -= EN.toNumber(Max.Cost)
					elseif typeof(Currency.Value) == "string" then
						Currency.Value = EN.toString(EN.sub(Currency.Value,Max.Cost))
					end
					Level.Value = New_Level
				end
				
				if self.CustomEffect then
					self.CustomEffect(Player)
				end
				
				return
			end
		end

		Cache[Key] = Upgrade
	end
	
	return Upgrade
end

function Upgrades:ReturnMax(Currency : number, Starting_Level : number, Player : Player)
	if self.Price_Scale == 0 then return math.floor(EN.toNumber(EN.div(Currency, self.Base_Price))) end

	local Total_Cost = 0
	local Max_Levels = Starting_Level or 0
	local Potential = self:GetLevels(Player)

	while true do
		--// Next Level Cost \\--
		local Next_Cost = self:GetCost(Max_Levels, Player, self)
		--// Break if you're too poor \\--
		if EN.me(EN.add(Total_Cost, Next_Cost), Currency) then print("Can't Afford") break end	
		--// Update Total Cost + Levels \\--
		Total_Cost = EN.add(Total_Cost, Next_Cost)
		Max_Levels += 1
		if Max_Levels >= Potential then print("Maxed", Max_Levels, Potential) break end
		if Max_Levels % 100 == 0 then task.wait() end
	end

	return {Levels = Max_Levels, Cost = Total_Cost}
end

function Upgrades:IsMaxed(Level : number, Player : Player) : boolean
	return Level >= self:GetLevels(Player)
end

function Upgrades:GetLevels(Player : Player)
	if not Player then return self.Levels end
	
	local Base_Level = self.Levels
	
	if table.find(self.Cap_Upgrades or {}, "Prisms_Caps") then
		Base_Level += (Player.Upgrades.Prisms_Caps.Value * 100)
	end
	
	if self.Cap_Tier then
		Base_Level += (math.max(Player.Stats.Tier.Value - 6, 0) * 100)
	end
	
	return Base_Level
end

function Upgrades:CanAfford(Level : number, Currency : number, Player : Player, priceTable : table) : boolean
	if self.HasRequirement and not self.HasRequirement(Player) then return false end
	
	Level = math.clamp(Level, 0, self:GetLevels(Player))
	if self:IsMaxed(Level, Player) then return false end

	return EN.meeq(Currency, self:GetCost(Level, Player, priceTable))
end

function Upgrades:GetEffect(Level : number, Player : Player, typeEffect : (string | nil)) : number
	Level = math.clamp(Level, 0, self:GetLevels(Player))
	
	local Base = self.Base_Effect
	local Effect_Scale = self.Effect_Scale
	local Reverse = self.Reverse
	local Exponential = self.Exponential
	local Log = self.Log
	local Effect_Bonus = self.Effect_Bonus
	local Bonus_Needed = self.Bonus_Needed
	
	if(typeEffect and self[typeEffect]) then
		Base =         self[typeEffect].Base_Effect
		Effect_Scale = self[typeEffect].Effect_Scale
		Reverse =      self[typeEffect].Reverse
		Exponential =  self[typeEffect].Exponential
		Log = 		   self[typeEffect].Log
		Effect_Bonus = self[typeEffect].Effect_Bonus
		Bonus_Needed = self[typeEffect].Bonus_Needed
	end
	
	if Level <= 0 then return Base end
	
	local Effect = Effect_Scale * Level

	if Reverse then return Base - Effect end

	if Exponential then
		Effect = EN.pow(Exponential, Level) -- Effect = 
	end

	--// Small Increment Upgrades \\--
	if Effect_Scale <= 1 and not Exponential then
		Effect = EN.add(Base, Effect)
	end

	if Log then
		Effect = EN.log(EN.mul(Effect, Log), Log)
	end

	--// Bonuses \\--
	if Effect_Bonus and Effect_Bonus > 1 then
		local Offset = Effect_Bonus ^ (math.floor(Level / Bonus_Needed))
		Effect = EN.mul(Effect, Offset)
	end
	
	--[ Return As Number ]--
	if typeof(Effect) == "table" and EN.le(Effect, 1e303) then
		return EN.toNumber(Effect)
	end

	return Effect
end

function Upgrades:StayVisible()
	return self.Stay_Visible and true or false
end

function Upgrades:GetCost(Level : number, Player : Player, priceTable : table | nil) : number
	if not priceTable then 
		priceTable = self
	end
	
	local CostTable = { }
	local Cost = nil

		
	if priceTable.MultiBuy then
		for _,price_sub_table in priceTable.MultiBuy do 
			
			Level = math.clamp(Level, 0, self:GetLevels(Player))
			local Cost = EN.mul(price_sub_table.Base_Price, EN.pow(price_sub_table.Price_Scale, Level))

			if price_sub_table.Price_Jump then
				local Offset = EN.pow(price_sub_table.Price_Jump[2], math.floor(Level / price_sub_table.Price_Jump[1]))
				Cost = EN.mul(Cost, Offset)
			end

			if price_sub_table.Price_Jump2 then
				local Offset = EN.pow(price_sub_table.Price_Jump2[2] or 1, math.floor(Level / price_sub_table.Price_Jump2[1]))
				Cost = EN.mul(Cost, Offset)
			end
			
			CostTable[price_sub_table.Currency] = {Cost, price_sub_table.isRune or false}
		end 
		
		return CostTable
	else 
		Level = math.clamp(Level, 0, self:GetLevels(Player))
		Cost = EN.mul(priceTable.Base_Price, EN.pow(priceTable.Price_Scale, Level))

		if priceTable.Price_Jump then
			local Offset = EN.pow(priceTable.Price_Jump[2], math.floor(Level / priceTable.Price_Jump[1]))
			Cost = EN.mul(Cost, Offset)
		end

		if priceTable.Price_Jump2 then
			local Offset = EN.pow(priceTable.Price_Jump2[2] or 1, math.floor(Level / priceTable.Price_Jump2[1]))
			Cost = EN.mul(Cost, Offset)
		end
		
	end
		
	return Cost 
end

return setmetatable({}, Upgrades)