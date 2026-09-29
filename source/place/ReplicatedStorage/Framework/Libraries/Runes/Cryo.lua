return {
	Name = "Cryo";
	Currency = "ArcticPoints";
	Cost = 50;
	AscensionOne_Req = true;
	--FreezeReq = 3;
	Runes = {
		{Name = "Soup", Chance = 1/2.5e307, RuneLuck  = false, RuneClone = false};
		{Name = "Mommy", Chance = 1/7.5e304, RuneLuck  = false, RuneClone = false};
		{Name = "Bozo", Chance = 1/1e295, RuneLuck  = false, RuneClone = false};
		{Name = "Buff", Chance = 1/2e222, RuneLuck  = false, RuneClone = false};
		{Name = "Stray", Chance = 1/1e160, RuneLuck  = false, RuneClone = false};
		{Name = "Garmin", Chance = 1/1e42, RuneLuck  = false, RuneClone = false};
		{Name = "Icequake", Chance = 1/7.5e12, RuneLuck  = true, RuneClone = true};
		{Name = "Frigid", Chance = 1/2.5e11, RuneLuck  = true, RuneClone = true};
		{Name = "Shiver", Chance = 1/7.5e7, RuneLuck  = true, RuneClone = true};
		{Name = "Breeze", Chance = 1/500e3, RuneLuck  = true, RuneClone = true};
		{Name = "Mist", Chance = .99, RuneLuck  = true, RuneClone = true};
	};
	
	HasRequirement = function(Player : Player)
		return Player.Upgrades.Freeze3.Value >= 1 
	end,
}