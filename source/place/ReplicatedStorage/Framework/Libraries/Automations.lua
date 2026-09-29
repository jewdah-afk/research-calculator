local Framework = require(game.ReplicatedStorage.Framework)
--[ Services ]--
local Collection_Service = Framework.Services.CollectionService
local Run_Service = Framework.Services.RunService
local MarketPlaceService = game:GetService("MarketplaceService")
--[ Libraries ]--
local EN = Framework:GetLibrary("EternityNum")
local Merger = Framework:GetLibrary("Merger")
local Runes = Framework:GetLibrary("Runes")
local Upgrades = Framework:GetLibrary("Upgrades")
local MultiplierButtons = Framework:GetLibrary("MultiplierButtons")


--[ Modules ]--
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Formulas = Framework:GetSharedModule("Formulas")
local Resets = Framework:GetSharedModule("Resets")
local Mob_Info = Framework:GetSharedModule("Mob_Info")
local RandomElixir = Framework:GetSharedModule("RandomElixir")

local LikeCount = game.ReplicatedStorage.Likes
--[ Events ]--
local Stat_Popup = Framework:GetEvent("Stat_Popup")
local Play_SFX = Framework:GetEvent("Play_SFX")
local Popup = Framework:GetEvent("Popup")
--[ Raycasts ]--
local Layers_Raycast = RaycastParams.new()
Layers_Raycast.FilterType = Enum.RaycastFilterType.Include
Layers_Raycast.FilterDescendantsInstances = {Collection_Service:GetTagged("Layer_Buttons")}

local Runes_Raycast = RaycastParams.new()
Runes_Raycast.FilterType = Enum.RaycastFilterType.Include
Runes_Raycast.FilterDescendantsInstances = {Collection_Service:GetTagged("Runes")}

local Mobs_Raycast = RaycastParams.new()
Mobs_Raycast.FilterType = Enum.RaycastFilterType.Include
Mobs_Raycast.FilterDescendantsInstances = {workspace.Areas["Spawn Island"].Map.Bases.Mob_Zone}

local Prisms_Raycast = RaycastParams.new()
Prisms_Raycast.FilterType = Enum.RaycastFilterType.Include
Prisms_Raycast.FilterDescendantsInstances = {workspace.Layers.TalentTree.PrismButton}

local Talent_Raycast = RaycastParams.new()
Talent_Raycast.FilterType = Enum.RaycastFilterType.Include
Talent_Raycast.FilterDescendantsInstances = {Collection_Service:GetTagged("TalentUpgrade")}

local Upgrade_Raycast = RaycastParams.new()
Upgrade_Raycast.FilterType = Enum.RaycastFilterType.Include
Upgrade_Raycast.FilterDescendantsInstances = {Collection_Service:GetTagged("UpgradeButtons")}

local Multiplier_Button_Raycast = RaycastParams.new()
Multiplier_Button_Raycast.FilterType = Enum.RaycastFilterType.Include
Multiplier_Button_Raycast.FilterDescendantsInstances = {Collection_Service:GetTagged("MultiplierButtons")}


local RTokensRatio = 1


--[ GENERAL FUNCTIONS ]--
function StartCooldown(Player : Player , Layer : string)
	Player:SetAttribute(Layer, tick()) -- Second began cooldown
end

local function getStartName(item)
	return item:match("^[a-zA-Z]+") or ""
end

function CheckCooldown(Player : Player, Layer : string)
	if not Player:GetAttribute(Layer) then StartCooldown(Player, Layer) return true end

	local TimeStart = Player:GetAttribute(Layer)
	
	if TimeStart == nil then return false end
	
	local TimeElapsed = tick() - TimeStart
	local Threshold = Cooldowns[Layer](Player)

	local Cooldown_Finished = TimeElapsed >= Threshold

	if Cooldown_Finished then
		StartCooldown(Player, Layer)
	end

	return Cooldown_Finished 
end


--[ MAIN ]--
return function(Player : Player)
	local Automations = {

		--[ STAT AUTOMATIONS ]--
		{
			Enabled = true;
			Cooldown = 1/60;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				--[ ENERGY GENERATION ]--
				if Player.Settings.Automation.Value and CheckCooldown(Player, "Energy") then
					local Gain = Formulas.Energy(Player, 1)
					local New_Energy = EN.add(Player.Stats.Energy.Value, Gain)
					local New_Total = EN.add(Player.Stats.Total_Energy.Value, Gain)
					Player.Stats.Energy.Value = EN.toString(New_Energy)
					Player.Stats.Total_Energy.Value = EN.toString(New_Total)
				end
				
				--[ FLAME GENERATION ]--
				if Player.Settings.Automation.Value and Player.Upgrades.Prisms_AutoFlame.Value > 0 and CheckCooldown(Player, "Flame") then
					local Gain = Formulas.Flame(Player, 1)
					local New_Flame = EN.add(Player.Stats.Flame.Value, Gain)
					Player.Stats.Flame.Value = EN.toString(New_Flame)
				end


				--[ POWER GENERATION ]--
				if Player.Settings.Automation.Value and Player.Upgrades.Prisms_AutoPower.Value > 0 and CheckCooldown(Player, "AutoPower") then
					local Gain = EN.mul(Formulas.Power(Player, 1), Formulas.AutoPower(Player))
					local New_Power = EN.add(Player.Stats.Power.Value, Gain)
					Player.Stats.Power.Value = EN.toString(New_Power)
				end
				
				--[ REALM POINT GENERATION ]--
				if Player.Settings.Automation.Value and Player.Runes.Refraction.Value > 0 and CheckCooldown(Player, "RealmPoints") then
					local Gain = Formulas.RealmPoints(Player, 1)
					local New_RP = EN.add(Player.Stats["Realm Points"].Value, Gain)
					Player.Stats["Realm Points"].Value = EN.toString(New_RP)
				end


				--[ LEVEL UP ]--
				if Player.Settings.Automation.Value and EN.meeq(Player.Stats.XP.Value, Formulas.Level_Req(Player.Stats.Level.Value)) then
					Player.Stats.Level.Value += 1
				end

				--[ XP GENERATION ]--
				if Player.Settings.Automation.Value and Player.Stats.Tier.Value >= 4 and CheckCooldown(Player, "XP") then
					Player.Stats.XP.Value = EN.toString(EN.add(Player.Stats.XP.Value, Formulas.XP(Player, 0.25)))
				end


				--[ AUTO ATTACK MOBS ]--
				if Player.Settings.Automation.Value and Player.Stats.Tier.Value >= 4 and Player.Upgrades.Prisms_AutoAttack.Value > 0 and CheckCooldown(Player, "AutoAttack") then
					local Player_Mob = Mob_Info[Player.UserId]
					if not Player_Mob then return end
					Player_Mob:TakeDamage()
				end


				--[ ORBS GENERATION ]--
				if Player.Settings.Automation.Value and Player.Stats.Tier.Value >= 7 and CheckCooldown(Player, "Orbs") then
					local Gain = Formulas.Orbs(Player, 1)
					local New_Orbs = EN.add(Player.Stats.Orbs.Value, Gain)
					Player.Stats.Orbs.Value = EN.toString(New_Orbs)
				end


				--[ MERGER ]--
				Player.Stats.Cube_Level.Value = math.max(Player.Stats.Cube_Level.Value, 1 + Player.Upgrades.Orbs_SpawnLevel.Value) 
				if Player.Stats.Tier.Value >= 8 and CheckCooldown(Player, "Cubes") then
					local Player_Merger = Merger(Player)
					if Player_Merger then
						local Level = Formulas.Cube_Level(Player)
						Player_Merger:Spawn(Level)
						Player_Merger:Merge(Level)
						Player_Merger:UpdateClient()
					end
				end


				--[ SPHERES ]--
				if Player.Settings.Automation.Value and Player.Stats.Tier.Value >= 9 and CheckCooldown(Player, "Spheres") then
					local Gain = Formulas.Spheres(Player, 1)
					local New_Spheres = EN.add(Player.Stats.Spheres.Value, Gain)
					Player.Stats.Spheres.Value = EN.toString(New_Spheres)
				end
				
				
				--[ DROPLETS GENERATION ]--
				if Player.Settings.Automation.Value and Player.Stats.AscensionOne.Value and CheckCooldown(Player, "Droplets") then
					local Gain = Formulas.Droplets(Player, 1)
					local New_Droplets = EN.add(Player.Stats.Droplets.Value, Gain)
					Player.Stats.Droplets.Value = EN.toString(New_Droplets)
				end
				
				
				--[ CHROMIUM GENERATION ]--
				if Player.Settings.Automation.Value and Player.Stats.Chromatize.Value >= 1 and CheckCooldown(Player, "Chromium") then
					local Gain = Formulas.Chromium(Player, 1)
					local New_Chromium = EN.add(Player.Stats.Chromium.Value, Gain)
					Player.Stats.Chromium.Value = EN.toString(New_Chromium)
				end
				
				
				--[ WATER GENERATION ]--
				if Player.Settings.Automation.Value and Player.Upgrades.Chromium_Automation2.Value >= 1 and CheckCooldown(Player, "WaterAuto") then
					local Gain = EN.mul(Player.Stats.Water.Value, 0.01)
					local New_Water = EN.add(Player.Stats.Water.Value, Gain)
					Player.Stats.Water.Value = EN.toString(New_Water)
				end
			
			end;
		};
		
		{
			Enabled = true;
			Cooldown = 1/2;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				if Player.Stats.Realm.Value ~= "One" then
					local Multiplier = Player.Stats.Droplets_Multiplier.Value
					if MarketPlaceService:UserOwnsGamePassAsync(Player.UserId, 78793985260781) then
						Multiplier *= 2
					end
					local Gain = Formulas.Droplets(Player , 0.5)
					local new_Energy = EN.add(Player.Stats.Droplets.Value, Gain)
					local total_Energy = EN.mul(new_Energy, Multiplier)
					Player.Stats.Droplets.Value = EN.toString(total_Energy)
				end
			end;
		};

		--[ Auto Upgrades ]--
		{
			Enabled = true;
			Cooldown = 1/30;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				if Player.Upgrades.Prisms_OrbsAutoBuy.Value > 0 then
					Upgrades("Orbs_Orbs"):Buy(Player.Upgrades.Orbs_Orbs, false, Player)
					Upgrades("Orbs_Energy"):Buy(Player.Upgrades.Orbs_Energy, false, Player)
					Upgrades("Orbs_Flame"):Buy(Player.Upgrades.Orbs_Flame, false, Player)
					Upgrades("Orbs_RuneLuck"):Buy(Player.Upgrades.Orbs_RuneLuck, false, Player)
					Upgrades("Orbs_RuneSpeed"):Buy(Player.Upgrades.Orbs_RuneSpeed, false, Player)
					Upgrades("Orbs_SpawnLevel"):Buy(Player.Upgrades.Orbs_SpawnLevel, false, Player)
					Upgrades("Orbs_SpawnTime"):Buy(Player.Upgrades.Orbs_SpawnTime, false, Player)
					Upgrades("Orbs_RuneBulk"):Buy(Player.Upgrades.Orbs_RuneBulk, false, Player)
				end
				
				
				-- Enable power upgrades
				if Player.Upgrades.Freeze2.Value >= 1 then
					Upgrades("Power_Energy"):Buy(Player.Upgrades.Power_Energy, false, Player)
					Upgrades("Power_Flame"):Buy(Player.Upgrades.Power_Flame, false, Player)
					Upgrades("Power_Flesh"):Buy(Player.Upgrades.Power_Flesh, false, Player)
					Upgrades("Power_Orbs"):Buy(Player.Upgrades.Power_Orbs, false, Player)
					Upgrades("Power_Power"):Buy(Player.Upgrades.Power_Power, false, Player)
					Upgrades("Power_Spheres"):Buy(Player.Upgrades.Power_Spheres, false, Player)
					Upgrades("Power_Spheres2"):Buy(Player.Upgrades.Power_Spheres2, false, Player)
					Upgrades("Power_XP"):Buy(Player.Upgrades.Power_XP, false, Player)
				end
				
				if Player.Stats.Chromatize.Value >= 1 then
					Upgrades("RP_DMG"):Buy(Player.Upgrades.RP_DMG, false, Player)
					Upgrades("RP_DMG2"):Buy(Player.Upgrades.RP_DMG2, false, Player)
					Upgrades("RP_Energy"):Buy(Player.Upgrades.RP_Energy, false, Player)
					Upgrades("RP_Energy2"):Buy(Player.Upgrades.RP_Energy2, false, Player)
					Upgrades("RP_Flame"):Buy(Player.Upgrades.RP_Flame, false, Player)
					Upgrades("RP_Orbs"):Buy(Player.Upgrades.RP_Orbs, false, Player)
					Upgrades("RP_Orbs2"):Buy(Player.Upgrades.RP_Orbs2, false, Player)
					Upgrades("RP_Power"):Buy(Player.Upgrades.RP_Power, false, Player)
					Upgrades("RP_Prisms"):Buy(Player.Upgrades.RP_Prisms, false, Player)
					Upgrades("RP_RP"):Buy(Player.Upgrades.RP_RP, false, Player)
					Upgrades("RP_RP2"):Buy(Player.Upgrades.RP_RP2, false, Player)
					Upgrades("RP_Spheres"):Buy(Player.Upgrades.RP_Spheres, false, Player)
					Upgrades("RP_Spheres2"):Buy(Player.Upgrades.RP_Spheres2, false, Player)
					Upgrades("RP_XP"):Buy(Player.Upgrades.RP_XP, false, Player)
				end
			end;
		};
		

		--[ Like Rewards ]--
		{
			Enabled = true;
			Cooldown = 1/8;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)

				local Scale = 35

				if Player.Stats.LikeReward.Value > 5 then
					Scale = 75
				end

				if Player.Stats.LikeReward.Value > 10 then
					Scale = 250
				end

				if LikeCount.Value >= (35 + (Player.Stats.LikeReward.Value * Scale)) then
					Player.Stats.LikeReward.Value += 1
					Popup:FireClient(Player, "Success", "New Like Goal Reached! You have received a random elixir.")
					RandomElixir(Player, 1)
				end
			end;
		};
		
		{
			Enabled = true;
			Cooldown = 1/30;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				if Player:FindFirstChild("leaderstats") then
					Player.leaderstats.Tier.Value = Player.Stats.Tier.Value
					
					--[ Ascension Stuff ]--
					if Player.Stats.AscensionOne.Value then
						Player.leaderstats.Ascension.Value = 1
					else
						Player.leaderstats.Ascension.Value = 0
					end
				end
			end;
		};

		--[ Challenges ]--
		{
			Enabled = true;
			Cooldown = 1/60;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				if Player.Stats.CurrentChallenge.Value == "C1" and Player.Stats.Tier.Value >= 6 then
					print("Challenge 1 Completed.")
					Player.Stats.InChallenge.Value = false
					Player.Stats.CurrentChallenge.Value = ""
					Player.Stats.C1.Value = true
				end

				if Player.Stats.CurrentChallenge.Value == "C2" and Player.Stats.Tier.Value >= 8 then
					print("Challenge 2 Completed.")
					Player.Stats.InChallenge.Value = false
					Player.Stats.CurrentChallenge.Value = ""
					Player.Stats.C2.Value = true
				end

				if Player.Stats.CurrentChallenge.Value == "C3" and EN.meeq(Player.Stats.Energy.Value , "1e393") then
					print("Challenge 3 Completed.")
					Player.Stats.InChallenge.Value = false
					Player.Stats.CurrentChallenge.Value = ""
					Player.Stats.C3.Value = true
				end

				if Player.Stats.CurrentChallenge.Value == "C4" and EN.meeq(Player.Stats.Energy.Value , "1e96") then
					print("Challenge 4 Completed.")
					Player.Stats.InChallenge.Value = false
					Player.Stats.CurrentChallenge.Value = ""
					Player.Stats.C4.Value = true
				end
			end;
		};
	
		{
			Enabled = true;
			Cooldown = 1/30;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				local Char = Player.Character
				if not Char then return end
				local HRP = Char:FindFirstChild("HumanoidRootPart")
				if not HRP then return end

				local Result = workspace:Raycast(HRP.Position, Vector3.new(0,-15,0), Layers_Raycast)
				if Result then
					local Button = Result.Instance.Parent

					--// Perform Layers \\--
					local Layer_Name = Button.Parent.Name
					if Layer_Name == "Tier" then
						if not CheckCooldown(Player, Layer_Name) then return end
						if Player.Stats.Tier.Value >= 10 then 
							if EN.le(Player.Stats.Droplets.Value, Formulas.Tier_Cost(Player.Stats.Tier.Value)) then return end
						else 
							if EN.le(Player.Stats.Energy.Value, Formulas.Tier_Cost(Player.Stats.Tier.Value)) then return end
						end
						
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Player.Stats.Tier.Value += 1

						if Player.Stats.Tier.Value > Player.Stats.Highest_Tier.Value then
							Player.Stats.Highest_Tier.Value = Player.Stats.Tier.Value
						end

						Stat_Popup:FireClient(Player, "Normal", Layer_Name, 1)
						Play_SFX:FireClient(Player, "Tier")
						Resets.Tier(Player)
					end

					if Layer_Name == "Flame" then
						if not CheckCooldown(Player, Layer_Name) then return end
						if Player.Stats.Tier.Value < 1 then return end
						if EN.le(Player.Stats.Energy.Value, Formulas.Flame_Cost(Player)) then return end

						local Gain = Formulas.Flame(Player, 1)
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
						Play_SFX:FireClient(Player, "Flame")
						Player.Stats.Flame.Value = EN.toString(EN.add(Player.Stats.Flame.Value, Gain))
						Player.Stats.Energy.Value = EN.toString(EN.sub(Player.Stats.Energy.Value, Formulas.Flame_Cost(Player)))
					end

					if Layer_Name == "Realm Points" then
						if not CheckCooldown(Player, "RealmPoints") then return end
						if Player.Stats.Tier.Value < 1 then return end
						
						local Gain = Formulas.RealmPoints(Player, 1)
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
						Play_SFX:FireClient(Player, "Realm Points")
						Player.Stats["Realm Points"].Value = EN.toString(EN.add(Player.Stats["Realm Points"].Value, Gain))
					end

					if Layer_Name == "Power" then
						if not CheckCooldown(Player, Layer_Name) then return end
						if Player.Stats.Tier.Value < 2 then return end
						if EN.le(Player.Stats.Flame.Value, Formulas.Power_Cost(Player)) then return end

						local Gain = Formulas.Power(Player, 1)
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
						Play_SFX:FireClient(Player, "Power")
						Player.Stats.Power.Value = EN.toString(EN.add(Player.Stats.Power.Value, Gain))
						Player.Stats.Flame.Value = "0"
						Player.Stats.Energy.Value = "0"
					end
					
					if Layer_Name == "Reflection" then
						if not CheckCooldown(Player, Layer_Name) then return end
						if Player.Stats.Chromify.Value < 3 then return end
						if EN.le(Player.Stats.Light.Value, Formulas.Reflection_Cost(Player)) then return end

						local Gain = Formulas.Reflection(Player, 1)
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
						Play_SFX:FireClient(Player, "Reflection")
						Player.Stats.Reflection.Value = EN.toString(EN.add(Player.Stats.Reflection.Value, Gain))
						Resets.Reflection(Player)
					end
					
					if Layer_Name == "Arctic Points" then
						if Player.Upgrades.Prisms_AP1.Value < 1 then return end 
						
						if not CheckCooldown(Player, "ArcticPoints") then return end
						local Gain = Formulas.ArcticPoints(Player, 1)
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
						Play_SFX:FireClient(Player, "Realm Points")
						Player.Stats.ArcticPoints.Value = EN.toString(EN.add(Player.Stats.ArcticPoints.Value, Gain))
					end
					

					if Layer_Name == "Haze" then
						if Player.Stats.Tier.Value < 13 then return end
	
						local currentTime = tick()
						local lastTime = Player.Stats.HazeStartTime.Value
						local diffrenceTime = currentTime - lastTime
						
						if diffrenceTime > Player.Stats.HazeTotalTime.Value then
							local Gain = Formulas.Haze(Player, 1)
							Framework.Events.Layer_VFX:FireClient(Player, Button)
							Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
							Play_SFX:FireClient(Player, "Realm Points")
							Player.Stats.Haze.Value += Gain
							
							Player.Stats.HazeStartTime.Value = tick()
						end
					end
					
					if Layer_Name == "Hail" then
						if Player.Stats.Tier.Value < 10 then return end

						local currentTime = tick()
						local lastTime = Player.Stats.HailStartTime.Value
						local diffrenceTime = currentTime - lastTime

						if diffrenceTime > Player.Stats.HailTotalTime.Value then
							local Gain = Formulas.Hail(Player, 1)
							Framework.Events.Layer_VFX:FireClient(Player, Button)
							Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
							Play_SFX:FireClient(Player, "Realm Points")
							Player.Stats.Hail.Value += Gain

							Player.Stats.HailStartTime.Value = tick()
						end
					end
					
					if Layer_Name == "Loot" then
						if Player.Stats.Tier.Value < 4 then return end

						local currentTime = tick()
						local lastTime = Player.Stats.LootStartTime.Value
						local diffrenceTime = currentTime - lastTime

						if diffrenceTime > Player.Stats.LootTotalTime.Value then
							local Gain = Formulas.Loot(Player, 1)
							Framework.Events.Layer_VFX:FireClient(Player, Button)
							Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
							Play_SFX:FireClient(Player, "Realm Points")
							Player.Stats.Loot.Value += Gain

							Player.Stats.LootStartTime.Value = tick()
						end
					end
					
					if Layer_Name == "Chroma" then
						if Player.Stats.Chromatize.Value < 1000 and Player.Runes.Vanguard.Value < 1e19 then return end

						local currentTime = tick()
						local lastTime = Player.Stats.ChromaStartTime.Value
						local diffrenceTime = currentTime - lastTime

						if diffrenceTime > Player.Stats.ChromaTotalTime.Value then
							local Gain = Formulas.Chroma(Player, 1)
							Framework.Events.Layer_VFX:FireClient(Player, Button)
							Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
							Play_SFX:FireClient(Player, "Realm Points")
							Player.Stats.Chroma.Value += Gain

							Player.Stats.ChromaStartTime.Value = tick()
						end
					end
					
					if Layer_Name == "Shine" then
						if Player.Upgrades.Chromium_NewStat.Value < 1 then return end

						local currentTime = tick()
						local lastTime = Player.Stats.ShineStartTime.Value
						local diffrenceTime = currentTime - lastTime

						if diffrenceTime > Player.Stats.ShineTotalTime.Value then
							local Gain = Formulas.Shine(Player, 1)
							Framework.Events.Layer_VFX:FireClient(Player, Button)
							Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
							Play_SFX:FireClient(Player, "Realm Points")
							Player.Stats.Shine.Value += Gain

							Player.Stats.ShineStartTime.Value = tick()
						end
					end
					
					if Layer_Name == "Ascended" then
						if Player.Stats.Chromify.Value < 2 then return end

						local currentTime = tick()
						local lastTime = Player.Stats.AscendedStartTime.Value
						local diffrenceTime = currentTime - lastTime

						if diffrenceTime > Player.Stats.AscendedTotalTime.Value then
							local Gain = Formulas.Chroma(Player, 1)
							Framework.Events.Layer_VFX:FireClient(Player, Button)
							Stat_Popup:FireClient(Player, "Normal", "Chroma", Gain)
							Play_SFX:FireClient(Player, "Realm Points")
							Player.Stats.Chroma.Value += Gain

							Player.Stats.AscendedStartTime.Value = tick()
						end
					end
					
					if Layer_Name == "Light" then
						if Player.Stats.Chromify.Value < 1 then return end

						local currentTime = tick()
						local lastTime = Player.Stats.LightStartTime.Value
						local diffrenceTime = currentTime - lastTime

						if diffrenceTime > Player.Stats.LightTotalTime.Value then
							local Gain = Formulas.Light(Player, 1)
							Framework.Events.Layer_VFX:FireClient(Player, Button)
							Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
							Play_SFX:FireClient(Player, "Realm Points")
							Player.Stats.Light.Value += Gain

							Player.Stats.LightStartTime.Value = tick()
						end
					end


					
					if Layer_Name == "Icicles" then
					
						if Player.Stats.Tier.Value < 13 then return end
					
						if not CheckCooldown(Player, "Icicles") then return end
						local IceThreshold = "1e17" -- 100Qn
						local startGain = 0
						if EN.me(Player.Stats.Ice.Value, IceThreshold) then
							local ratio = EN.div(Player.Stats.Ice.Value, IceThreshold)
							startGain = EN.pow(EN.log10(ratio), 5)
						else
							return 	
						end
						
						local Gain = Formulas.Icicles(Player, startGain)
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Stat_Popup:FireClient(Player, "Normal", Layer_Name, Gain)
						Play_SFX:FireClient(Player, "Realm Points")
						Player.Stats.Icicles.Value = EN.toString(EN.add(Player.Stats.Icicles.Value, Gain))
						Player.Stats.Droplets.Value = "0"
						Player.Stats.Water.Value = "0"
						Player.Stats.Ice.Value = "0"
					end

					if Layer_Name == "Chromatizer" then
						if Player.Upgrades.Prisms_Chromatizer.Value < 1 then return end
						
						if not CheckCooldown(Player, Layer_Name) then return end
						if EN.le(Player.Stats.Prisms.Value, Formulas.Chromatize_Cost(Player.Stats.Chromatize.Value)) then return end
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Player.Stats.Chromatize.Value += 1

						Stat_Popup:FireClient(Player, "Normal", Layer_Name, 1)
						Play_SFX:FireClient(Player, "Tier")
						Resets.Chromatize(Player)
					end
					

					if Layer_Name == "Chromifier" then
						if Player.Upgrades.Chromium_Chromifier.Value < 1 then return end

						if not CheckCooldown(Player, Layer_Name) then return end
						if EN.le(Player.Stats.Chroma.Value, Formulas.Chromify_Cost(Player.Stats.Chromify.Value)) then return end
						Framework.Events.Layer_VFX:FireClient(Player, Button)
						Player.Stats.Chromify.Value += 1

						Stat_Popup:FireClient(Player, "Normal", Layer_Name, 1)
						Play_SFX:FireClient(Player, "Tier")
						Resets.Chromify(Player)
					end
				end
			end;
		};

		{
			Enabled = true;
			Cooldown = 1/60;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				local Char = Player.Character
				if not Char then return end
				local HRP = Char:FindFirstChild("HumanoidRootPart")
				if not HRP then return end

				if CheckCooldown(Player, "Runes") then
					local Result = workspace:Raycast(HRP.Position, Vector3.new(0,-10,0), Runes_Raycast)
					if Result then
						local Button = Result.Instance.Parent
						

						--// Get Runes \\--
						local Rune_Name = Button.Parent.Name
						local Rune = Runes(Rune_Name)
						local Stat = Player.Stats[Rune.Currency]
						local Bulk = math.clamp(Formulas.Rune_Afford(Stat.Value, Rune.Cost), 0, Formulas.Rune_Bulk(Player, true, Rune_Name.Name))
						local Luck = Formulas.Rune_Luck(Player, Rune_Name)

						Player:SetAttribute("Rune_Button", Rune_Name)
						
						if Rune:CanAfford(Stat.Value) and (Player.Stats.Tier.Value >= (Rune.Tier_Req or 0)) then
							if Rune.HasRequirement then
								if not Rune.HasRequirement(Player) then return end
							end
							
							if Rune.AscensionOne_Req and not Player.Stats.AscensionOne.Value then return end
							
							if math.random() <= Formulas.Ticket_Chance(Player, Rune_Name) then
								local Gain = Formulas.Tickets(Player)
								Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value,Gain))
								
								Stat_Popup:FireClient(Player, "Normal", "Tickets", Gain)
							end

							Rune:GetResult(Luck, Bulk, Player)
							 local Rune_Result = Rune:GetResult(Luck, Bulk, Player)
							if type(Stat.Value) == "number" then
								Stat.Value = EN.toNumber(EN.sub(Stat.Value, Rune_Result.Cost))
							elseif type(Stat.Value) == "string" then
								Stat.Value = EN.toString(EN.sub(Stat.Value, Rune_Result.Cost))	
							end
							
							Player.Stats[`{Rune_Name}_Opened`].Value += Bulk
							
							Player.Stats.RawRunes_Opened.Value += 1
							Player.Stats.Runes_Opened.Value += Bulk

							if Player.Settings.Particles.Value then
								Framework.Events.Layer_VFX:FireClient(Player, Button)
							end
							
							if Player.Settings.Popups.Value then
							 	Framework.Events.Rune_Reward:FireClient(Player, Rune_Result.Rewards)
							end
						end
					else
						Player:SetAttribute("Rune_Button", nil)
					end
				end

				--// Mobs \\--
				if Player.Stats.Tier.Value < 4 then return end
				if CheckCooldown(Player, "Mobs") then
					local Result = workspace:Raycast(HRP.Position, Vector3.new(0,-15,0), Mobs_Raycast)
					if Result then
						local Button = Result.Instance.Parent

						local Player_Mob = Mob_Info[Player.UserId]
						if not Player_Mob then return end
						Player_Mob:TakeDamage()
					end
				end
			end;
		};

		{
			Enabled = true;
			Cooldown = 1/60;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				local Char = Player.Character
				if not Char then return end
				local HRP = Char:FindFirstChild("HumanoidRootPart")
				if not HRP then return end
				if Player.Stats.Tier.Value < 5 then return end
				
				if Player.Stats.Tier.Value >= 6 then
					local Result = workspace:Raycast(HRP.Position, Vector3.new(0,-15,0), Prisms_Raycast)
					Player:SetAttribute("Prisms_X2", Result ~= nil)
				end
				
				if EN.meeq(Player.Stats.Spheres.Value, 5e20) then
					Player:SetAttribute("Prisms_X2", true)
				end

				if CheckCooldown(Player, "Prisms") then
					Player.Stats.Prisms.Value = EN.toString(EN.add(Player.Stats.Prisms.Value, Formulas.Prisms(Player)))
				end
			end;
		};

		{
			Enabled = true;
			Cooldown = 1/60;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				local Char = Player.Character
				if not Char then return end
				local HRP = Char:FindFirstChild("HumanoidRootPart")
				if not HRP then return end

				local Result = workspace:Raycast(HRP.Position, Vector3.new(0,-15,0), Talent_Raycast)
				if Result and Result.Instance.Name ~= "Connector" then
					local Upgrade_Name = Result.Instance.Parent.Name
					local Upgrade = Upgrades(Upgrade_Name)
					local Level = Player.Upgrades[Upgrade_Name]
					local Currency = Player.Stats[Upgrade.Currency]
					Upgrade:Buy(Level, false, Player)
				end

				local Result = workspace:Raycast(HRP.Position, Vector3.new(0,-15,0), Upgrade_Raycast)
				if Result then
					local Upgrade_Name = Result.Instance.Parent.Name
					local Upgrade = Upgrades(Upgrade_Name)
					local Level = Player.Upgrades[Upgrade_Name]
					local Currency = Player.Stats[Upgrade.Currency]
					Upgrade:Buy(Level, false, Player)
				end
				
				local Result = workspace:Raycast(HRP.Position, Vector3.new(0,-15,0), Multiplier_Button_Raycast)
				if Result then
					local button = Result.Instance.Parent
					
					local name = getStartName(button.Name)
					if CheckCooldown(Player, name .. "Button") then	
						if MultiplierButtons.Buy(Player, button) then
							Framework.Events.Layer_VFX:FireClient(Player, button)
						end
					end
				end
			end;
		};

		--// Priority : 2 | Misc \\--
		{
			Enabled = true;
			Cooldown = 1/8;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				if not Player:GetAttribute("Location_Ready") then return end
				local Char = Player.Character
				if not Char then return end
				local HRP = Char:FindFirstChild("HumanoidRootPart")
				if not HRP then return end
				local Location = `{HRP.Position.X};{HRP.Position.Y};{HRP.Position.Z}`
				Player.Stats.Location.Value = Location
			end;
		};
		
		--[ Auto Premium Checker ]--
		{
			Enabled = true;
			Cooldown = 1;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				Player:SetAttribute("Premium", Player.MembershipType == Enum.MembershipType.Premium)
			end;
		};

		--[ Robux Token Checker ]--
		{
			Enabled = true;
			Cooldown = 1/60; -- in Seconds
			Timer = 0;
			Perform = function(Player: Player)
				if not Player:GetAttribute("RobuxTokens") then
					StartCooldown(Player, "RobuxTokens")
					return
				end

				if CheckCooldown(Player, "RobuxTokens") then
					if Player.Stats.Chromatize.Value >= 850 then
						Player.Stats.RobuxTokens.Value += (2.625 * RTokensRatio)
					else
					 	Player.Stats.RobuxTokens.Value += (1.75 * RTokensRatio)
					end
				end
			end;
		};
		
		--[ Starter Pack Checker ]--
		{
			Enabled = true;
			Cooldown = 1;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				if Player.Stats.Tier.Value >= 4 then Player.Stats.Starter_Pack_Timer.Value = 0 return end
				
				Player.Stats.Starter_Pack_Timer.Value = math.max(Player.Stats.Starter_Pack_Timer.Value - 1, 0)
			end;
		};
		
		--[ Potion Checker ]--
		{
			Enabled = true;
			Cooldown = 1;-- in Seconds
			Timer = 0;
			Perform = function(Player : Player)
				Player.Stats.StatsElixirDuration.Value = math.max(Player.Stats.StatsElixirDuration.Value - 1, 0)
				Player.Stats.RuneLuckElixirDuration.Value = math.max(Player.Stats.RuneLuckElixirDuration.Value - 1, 0)
				Player.Stats.RuneSpeedElixirDuration.Value = math.max(Player.Stats.RuneSpeedElixirDuration.Value - 1, 0)
			end;
		};
	}

	local Loop = nil

	Loop = Run_Service.Heartbeat:Connect(function(delta : number)
		Player.Stats.Playtime.Value += delta

		if Player.Stats.Tier.Value >= 11 then 
			Player.Stats.PlaytimeStreak.Value += delta
			
			local fifteen_minutes = 60 * 15
			local luck_increase = math.min(math.floor(Player.Stats.PlaytimeStreak.Value / fifteen_minutes),100)
			
			local hour = 60 * 60 
			local bulk_increase = math.min(math.floor(Player.Stats.PlaytimeStreak.Value / hour), 10)
			
			Player:SetAttribute("PlaytimeBulkIncrease", bulk_increase)
			Player:SetAttribute("PlaytimeLuckIncrease", luck_increase)
		end
			

		if Player.Stats.Tier.Value >= 12 then
			Player.Stats.TierTwelveTime.Value += delta
		end

		if Player.Stats.Tier.Value >= 13 and Player.Stats.HazeStartTime.Value == -1 then 
			Player.Stats.HazeStartTime.Value = tick() - 24*60*60 -- Start haze time at 0 
		end
		
		if Player.Stats.Tier.Value >= 10 and Player.Stats.HailStartTime.Value == -1 then 
			Player.Stats.HailStartTime.Value = tick() - 24*60*60 -- Start hail time at 0 
		end
		
		if Player.Stats.Tier.Value >= 4 and Player.Stats.LootStartTime.Value == -1 then 
			Player.Stats.LootStartTime.Value = tick() - 10*60 -- Start loot time at 0 
		end
		

		if Player.Stats.Chromify.Value >= 1 and Player.Stats.LightStartTime.Value == -1 then 
			Player.Stats.LightStartTime.Value = tick() - 10*60 -- Start light time at 0 
		end
		

		if Player.Stats.Chromify.Value >= 2 and Player.Stats.AscendedStartTime.Value == -1 then 
			Player.Stats.AscendedStartTime.Value = tick() - 2 -- Start light time at 0 
		end
		
		if Player.Stats.Chromatize.Value >= 1000 and Player.Runes.Vanguard.Value >= 1e18 and Player.Stats.ChromaStartTime.Value == -1 then 
			Player.Stats.ChromaStartTime.Value = tick() - 10 -- Start Chrome time at 0 
		end
		
		if Player.Upgrades.Chromium_NewStat.Value > 0 and Player.Stats.ShineStartTime.Value == -1 then 
			Player.Stats.ShineStartTime.Value = tick() - 30 -- Start Shine time at 0 
		end

		if Player:GetAttribute("Tiering") or Player:GetAttribute("Challenging") or Player:GetAttribute("Ascending") then return end
		if Player:GetAttribute("ShuttingDown") then return end
		if Player:GetAttribute("Resetting") then return end

		for _ , Automation in Automations do
			if not Automation.Enabled then continue end
			Automation.Timer += delta
			if Automation.Timer >= Automation.Cooldown then
				Automation.Timer = 0
				Automation.Perform(Player)
			end
		end
	end)

	Player.AncestryChanged:Connect(function()
		Loop:Disconnect()
		Loop = nil
	end)
end