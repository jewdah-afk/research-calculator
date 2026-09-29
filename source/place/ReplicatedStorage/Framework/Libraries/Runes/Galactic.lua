return {
	Name = "Galactic";
	Currency = "Tickets";
	Cost = 500;
	AscensionOne_Req = true;
	Runes = {
		{Name = "Paracosm", Chance = 1/4e307, RuneLuck  = false, RuneClone = false};
		
		{Name = "Axium", Chance = 1/1e306, RuneLuck  = false, RuneClone = false};
		
		{Name = "Galaxy", Chance = 1/1.5e304, RuneLuck  = false, RuneClone = false};
		
		{Name = "Rocket", Chance = 1/1.5e260, RuneLuck  = false, RuneClone = false};
		
		{Name = "Planet", Chance = 1/3.33e238, RuneLuck  = false, RuneClone = false};
		
		{Name = "Constellation", Chance = 1/2.5e223, RuneLuck  = false, RuneClone = false};
		
		{Name = "Star", Chance = 1/2.5e208, RuneLuck  = false, RuneClone = false};
		
		{Name = "CosmicDust", Chance = 1/1e207, RuneLuck  = false, RuneClone = false};
	};
	
	HasRequirement = function(Player : Player)
		return Player.Stats.Chromatize.Value >= 750 
	end,
}