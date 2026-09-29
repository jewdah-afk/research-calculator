local ChatData = {
	
	Group_Roles = {
		["255"] = {Name = "OWNER", Color = Color3.fromRGB(0, 0, 0)};
		["254"] = {Name = "PILOT", Color = Color3.fromRGB(0, 0, 127)};
		["253"] = {Name = "CO-OWNER", Color = Color3.fromRGB(77, 0, 184)};
		["252"] = {Name = "DEVELOPER", Color = Color3.fromRGB(0, 170, 255)};
		["230"] = {Name = "MANAGER", Color = Color3.fromRGB(202, 105, 255)};
		["200"] = {Name = "CONTRIBUTOR", Color = Color3.fromRGB(255, 255, 0)};
		["190"] = {Name = "STAFF", Color = Color3.fromRGB(8, 255, 189)};
		["100"] = {Name = "LEAD TESTER", Color = Color3.fromRGB(72,61,139)};
		["60"] = {Name = "TESTER", Color = Color3.fromRGB(255, 8, 8)};
		["1"] = {Name = "FAN", Color = Color3.fromRGB(85, 255, 0)};
		["0"] = {Name = "GUEST", Color = Color3.fromRGB(255, 255, 255)};
	};
	
	Leaderboard_Tags = {
		["Playtime"] = {Color = Color3.fromRGB(205, 205, 205)};
		["Prisms_F2P"] = {Color = Color3.fromRGB(240, 153, 252)};
		["Prisms_P2W"] = {Color = Color3.fromRGB(240, 153, 252)};
		["RobuxSpent"] = {Color = Color3.fromRGB(0, 255, 0)};
		["TotalEnergy_P2W"] = {Color = Color3.fromRGB(255, 200, 0)};
		["TotalEnergy_F2P"] = {Color = Color3.fromRGB(255, 200, 0)};
		["Runes_Opened_P2W"] = {Color = Color3.fromRGB(170, 85, 255)};
		["Runes_Opened_F2P"] = {Color = Color3.fromRGB(170, 85, 255)};
		["RawRunes"] = {Color = Color3.fromRGB(170, 85, 255)}
	};
	
	Special = {
		["OG"] = Color3.fromRGB(255, 232, 148);
	};
	
	Leaderboard_Conversions = { -- Converts Folder Name to Tag
		["RobuxSpent"] = "Robux";
		["Prisms_F2P"] = "Prisms F2P";
		["Prisms_P2W"] = "Prisms P2W";
		["TotalEnergy_P2W"] = "Energy P2W";
		["TotalEnergy_F2P"] = "Energy F2P";
		["Runes_Opened_P2W"] = "Runes P2W";
		["Runes_Opened_F2P"] = "Runes F2P";
		["RawRunes"] = "Runes Raw";
	};

	Gamepasses = {
		Prime = Color3.fromRGB(170, 85, 255)
	}
	
}

return ChatData