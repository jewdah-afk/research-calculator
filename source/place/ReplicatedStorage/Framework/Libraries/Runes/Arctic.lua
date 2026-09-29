return {
	Name = "Arctic";
	Currency = "Chromium";
	Cost = 1e6;
	RuneLuck = true;
	AscensionOne_Req = true;
	Runes = {
		{Name = "Glint", Chance = 1/3.33e296, RuneLuck  = false, RuneClone = false};
		
		{Name = "Frostbite", Chance = 1/3e103, RuneLuck  = false, RuneClone = false};
		
		{Name = "Mirror", Chance = 1/7.5e60, RuneLuck  = false, RuneClone = false};
		
		{Name = "Blizzard", Chance = 1/1e11, RuneLuck  = false, RuneClone = false};
		 
		{Name = "Subzero", Chance = 1/2.5e14, RuneLuck  = true, RuneClone = true};
		
		{Name = "Frostveil", Chance = 1/5e12, RuneLuck  = true, RuneClone = true};
		
		{Name = "Hailstorm", Chance = 1/2.5e10, RuneLuck  = true, RuneClone = true};
		
		{Name = "Avalanche", Chance = 1/1.5e8, RuneLuck  = true, RuneClone = true};
		
		{Name = "Icy", Chance = 1/2.5e5, RuneLuck  = true, RuneClone = true};
		
		{Name = "Snow", Chance = 0.01, RuneLuck  = true, RuneClone = true};
		
		{Name = "Snowflake", Chance = .99, RuneLuck  = true, RuneClone = true};
	};
	
	HasRequirement = function(Player : Player)
		return Player.Stats.Chromatize.Value >= 7 
	end,
}