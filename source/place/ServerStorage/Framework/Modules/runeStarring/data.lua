return {
	["Royal"] = {
		Name = "Royal";
		Star1 = {
			{1.15, "*", "Global_Rune_Bulk"}; 
		},
		Star2 = {
			{1.5, "*", "Global_Rune_Bulk"};
		},
		Star3 = {
			{2, "*", "Global_Rune_Bulk"};
		},
		Superstar = {
			{10, "*", "Global_Rune_Bulk"};
		},
		Prices = {
			250;
			2500;
			5e5;
			1e12;
		}
	},
	["Color"] = {
		Name = "Color";
		Star1 = {
			{1.25, "*", "Color_Rune_Luck"}; 
		},
		Star2 = {
			{1.75, "*", "Color_Rune_Luck"};
		},
		Star3 = {
			{2, "+", "Global_Rune_Bulk"};
			{1.25, "*", "Global_Rune_Luck"};
			{2, "*", "Color_Rune_Luck"};
		},
		Superstar = {
			{3, "*", "Color_Rune_Luck"};
			{1.25, "*", "Color_Rune_Luck"};
			{1.75, "*", "Global_Rune_Luck"};
			{5, "+", "Global_Rune_Bulk"};
		},
		Prices = {
			5e3;
			1.5e4;
			1e5;
			1e6;
		}
	},
	["Polychrome"] = {
		Name = "Polychrome";
		Star1 = {
			{1.25, "*", "Polychrome_Rune_Luck"}; 
		},
		Star2 = {
			{1.75, "*", "Polychrome_Rune_Luck"};
		},
		Star3 = {
			{2, "*", "Polychrome_Rune_Luck"};
			{1.25, "*", "Global_Rune_Luck"};
			{2, "+", "Global_Rune_Bulk"}
		},
		Superstar = {
			{3, "*", "Polychrome_Rune_Luck"};
			{1.25, "*", "Polychrome_Rune_Bulk"};
			{1.75, "*", "Global_Rune_Luck"};
			{5, "+", "Global_Rune_Bulk"}
		},
		Prices = {
			10;
			50;
			150;
			1e3;	
		}
	},
	["Arctic"] = {
		Name = "Arctic",
		Star1 = {
			{1.25, "*", "Arctic_Rune_Luck"};
		},
		Star2 = {
			{1.75, "*", "Arctic_Rune_Luck"};
		},
		Star3 = {
			{2, "*", "Arctic_Rune_Luck"};
			{1.25, "*", "Global_Rune_Luck"};
			{2, "+", "Global_Rune_Bulk"}
		},
		Superstar = {
			{3, "*", "Arctic_Rune_Luck"};
			{1.25, "*", "Arctic_Rune_Bulk"};
			{1.75, "*", "Global_Rune_Luck"};
			{5, "+", "Global_Rune_Bulk"}
		},
		Prices = {
			5,
			15,
			50,
			250,
		}
	}
}