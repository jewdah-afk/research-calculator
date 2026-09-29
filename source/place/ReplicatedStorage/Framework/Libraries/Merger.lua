local Framework = require(game.ReplicatedStorage.Framework)
local Formulas = Framework:GetSharedModule("Formulas")
local Update_Cubes = Framework:GetEvent("Update_Cubes")

local Mergers = {}
local Merger = {}
Merger.__index = Merger
Merger.__call = function(Table , Key : string)
	return Mergers[Key]
end

function Merger.New(Player : Player)
	local Player_Merger = setmetatable({}, Merger)
	Player_Merger.Player = Player
	Player_Merger.CubeStorage = {}
	
	--[ RECONCILIATION ]--
	function Player_Merger:Reconcile(Level : number)
		if not self.CubeStorage[Level] then
			self.CubeStorage[Level] = {}
		end
	end
	
	--[ RESETTING ]--
	function Player_Merger:Reset()
		self.CubeStorage = {}
	end
	
	--[ SPAWNING ] --
	function Player_Merger:Spawn(Level : number)
		self:Reconcile(Level)
		table.insert(self.CubeStorage[Level], "C") -- "C" is key for Cubes
	end
	
	--[ MERGING ]--
	function Player_Merger:Merge(Starting_Level : number)
		local Min = math.max(self.Player.Stats.Cube_Level.Value - 4, 1)
		local Max = self.Player.Stats.Cube_Level.Value + 5
		for Level =  Min, Max do
			if self.CubeStorage[Level] and #self.CubeStorage[Level] >= 3 then
				table.remove(self.CubeStorage[Level], 1)
				table.remove(self.CubeStorage[Level], 1)
				table.remove(self.CubeStorage[Level], 1)
				
				if #self.CubeStorage[Level] <= 0 then self.CubeStorage[Level] = nil end -- Forget about this table until another cube for it spawns
				
				local New_Level = Level + 1
				self:Spawn(New_Level)
				
				--[ Level Up Highest ]--
				if New_Level > self.Player.Stats.Cube_Level.Value then
					self.Player.Stats.Cube_Level.Value = New_Level
					self.Player.Stats.Highest_Cube.Value = math.max(New_Level, self.Player.Stats.Highest_Cube.Value)
				end
			end
		end
	end
	
	--[ CLIENT REPLICATION ]--
	function Player_Merger:UpdateClient()
		local Highest_Levels = {}
		
		local Highest = math.max(self.Player.Stats.Cube_Level.Value, 5)
		local Pos = 0
		
		local Min = Highest - 4
		local Max = Highest
		
		if Highest >= 6 then
			Max = Highest + 4
			Min = Highest
		end
		
		for Level = Max, Min, -1 do
			Pos += 1
			self:Reconcile(Level)
			Highest_Levels[Pos] = {
				Cube_Level = Level;
				Amount = #self.CubeStorage[Level];
			}
		end
		
		Update_Cubes:FireClient(self.Player, Highest_Levels)
	end
	
	Player_Merger:UpdateClient()
	Mergers[Player_Merger.Player] = Player_Merger
	Player.AncestryChanged:Connect(function()
		Mergers[Player] = nil
		Player_Merger = nil
	end)
	
	return Player_Merger
end

return setmetatable({}, Merger)
