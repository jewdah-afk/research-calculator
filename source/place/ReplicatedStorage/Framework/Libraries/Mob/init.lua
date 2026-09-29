local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")

local Mob_Class = {}
Mob_Class.__index = Mob_Class

function Mob_Class.New(Data : {})
	local Mob = setmetatable({}, Mob_Class)
	
	--// Stats \\--
	Mob.Player = Data.Player
	Mob.Flesh = Mob.Player.Stats.Flesh
	Mob.Dead = false
	
	function Mob:Respawn()
		Mob.Dead = true
		
		local RespawnTime = Formulas.Mob_Respawn(self.Player)
		
		Framework.Events.Mob_Respawn:FireClient(self.Player, RespawnTime)
		task.wait(RespawnTime)
		self:SetStats()
		self:SendInfo()
		Mob.Dead = false
	end
	
	function Mob:GiveLoot()
		if not self.Boss then -- Regular Loot
			self.Info.Reward(self.Player, self.Level, self.Type)
			return
		end
	end

	function Mob:SetStats()
		self.Type = 1
		self.Info = require(script[self.Type])
		
		if math.random() <= Formulas.Chest_Chance(self.Player) then
			self.Type = "Chest"
		end
		
		self.Max_Level = math.clamp(self.Player.Stats.Mobs_Level.Value, 1, 1e6)
		self.Level = math.clamp(self.Player.Stats.Mobs_SetLevel.Value, 1, self.Max_Level)
		self.Stage = math.floor(1 / (1 / self.Level))	
		
		local Scale = 2
		local Min_Health
		local Max_Health
		
		if self.Level >= 1e3 then
			Scale = 4
			Min_Health = EN.mul("1e303", EN.pow(Scale, math.max(self.Stage - 1000, 0)))
			Max_Health = EN.mul("2e303", EN.pow(Scale, math.max(self.Stage - 1000, 0)))
		else
			Min_Health = EN.mul(10, EN.pow(Scale, math.max(self.Stage - 1, 0)))
			Max_Health = EN.mul(20, EN.pow(Scale, math.max(self.Stage - 1, 0)))
		end
		
		self.Max_Health = EN.rand(Min_Health, Max_Health)
		
		if self.Type == "Chest" then
			self.Max_Health = EN.mul(self.Max_Health, 3)
		end
		
		self.Health = self.Max_Health
	end
	
	function Mob:TakeDamage()
		if self.Dead then return end
		self.Health = EN.sub(self.Health, Formulas.Damage(self.Player))
		
		if EN.leeq(self.Health, 0) then
			self.Health = 0
			self:GiveLoot()
			
			--// Kill Counter \\--
			if self.Level >= self.Max_Level then
				self.Player.Stats.Mobs_Killed.Value += 1
				
				--[ Auto Level ]--
				if self.Player.Upgrades.Prisms_AutoLevel.Value > 0 and self.Player.Stats.Mobs_Killed.Value >= 15 then
					self.Player.Stats.Mobs_Killed.Value = 0
					self.Player.Stats.Mobs_Level.Value += 1
					self.Player.Stats.Mobs_SetLevel.Value = self.Player.Stats.Mobs_Level.Value
				end
			end
			self.Player.Stats.Mobs_TotalKilled.Value += 1
			
			self:Respawn()
			return
		end
		
		Framework.Events.Mob_Hit:FireClient(self.Player)
		self:UpdateInfo()
	end
	
	function Mob:SendInfo()
		Framework.Events.Mob_Refresh:FireClient(self.Player, self:GetInfo())
	end
	
	function Mob:UpdateInfo()
		Framework.Events.Mob_Update:FireClient(self.Player, self:GetInfo())
	end
	
	function Mob:GetInfo()
		return {
			Type = self.Type;
			Max_Health = self.Max_Health;
			Health = self.Health;
			Level = self.Level;
			Boss = self.Boss;
		}
	end
	
	Mob:SetStats()
	Mob:SendInfo()
	return Mob
end

return Mob_Class
