--!nonstrict
-- WindowDefs: every in-game window and which Figma frame(s) it is made of.
--   tabs   = the window's tab bar, in Figma order: { label, variant } or { label, go = "<other window>" }
--            (label = the Figma tab layer name without "tab/" and its state suffix)
--   views  = extra variants switched by a clickable layer inside the window (segments, view switches, state demos)
--   drawer = docked on the right instead of a centred modal (Shop drawer)
--   build  = hand-built window (no squared Figma frame yet), see UI/Screens.luau
-- Variant names are module names in UI/Figma/Layouts (generated from Figma; node ids in the module headers).
return {
	shop = { title = "SHOP", drawer = true, theme = "gold",
		tabs = { { "EGGS", "Shop_Eggs" }, { "MOLT", "Shop_Molt" }, { "SEEDS", "Shop_Seeds" }, { "NEST", go = "nest" }, { "MINE", go = "mine" } },
		views = { ["seg/GOLDEN"] = "Shop_Eggs_Golden", ["seg/EGGS"] = "Shop_Eggs", ["seg/ECHO"] = "Shop_Eggs" } },
	mine = { title = "MINE", tabs = { { "SHOP", "Mine_Shop" }, { "AREAS", "Mine_Areas" }, { "CROW", go = "crow" } } },
	crow = { title = "CROW", tabs = { { "CROW", "Crow" } } },
	treasure = { title = "TREASURE ROOM", tabs = { { "TREASURE ROOM", "Mine_TreasureRoom" } } },
	trees = { title = "SUNFLOWER TREE", tabs = { { "SUNFLOWER", "Tree_Sunflower" }, { "DESERT", "Tree_Desert" }, { "ARCHIVIST", "Tree_Archivist" } } },
	fishing = { title = "FISHING", tabs = { { "COLLECTION", "Fishing_Collection" }, { "EQUIPMENT", "Fishing_Equipment" }, { "FISHDEX", "Fishing_Fishdex" } } },
	aquarium = { title = "AQUARIUM", tabs = { { "BIOMES", "Aquarium_Biomes" }, { "RESONANCE", "Aquarium_Resonance" }, { "TOTAL", "Aquarium_Total" }, { "FISH MARKET", go = "market" } } },
	market = { title = "FISH MARKET", tabs = { { "FISH MARKET", "FishMarket" } }, views = { locked = "FishMarket_Locked" } },
	nest = { title = "NEST", tabs = { { "SHOP", "Nest_Shop" }, { "LAKE", "Nest_Lake" }, { "RIVERSIDE", "Nest_Riverside" }, { "SAWMILL", "Nest_Sawmill" }, { "OWNED", "Nest_Owned" } },
		-- breeding demo: BREED -> incubating -> HATCH -> ready -> FUSE / DISCARD -> back to the lake
		views = { ["btn/breed"] = "Nest_Lake_Incubating", ["btn/hatch (waiting)"] = "Nest_Lake_Ready", ["btn/fuse"] = "Nest_Lake", ["btn/discard"] = "Nest_Lake" } },
	parrot = { title = "PARROT", tabs = { { "OVERVIEW", "Parrot_Overview" }, { "UPGRADE", "Parrot_Upgrade" }, { "EQUIPMENT", "Parrot_Equipment" }, { "INDEX", "Parrot_Index" }, { "REBIRB", "Parrot_Rebirb" } },
		views = { ["view/FORGE"] = "Parrot_Forge", ["view/BAG"] = "Parrot_Equipment", ["view/BAG (active)"] = "Parrot_Equipment" } },
	expedition = { title = "EXPEDITION", tabs = { { "DAY  ·  FLOORS 1-9", "Expedition" }, { "NIGHT  ·  FLOOR 1", "Expedition" } } },
	sacrifice = { title = "SACRIFICE", tabs = { { "SACRIFICE", "Sacrifice" }, { "MYTHIC", "Sacrifice_Mythic" } } },
	objectives = { title = "OBJECTIVES", tabs = { { "QUESTS", "Objectives_Quests" }, { "QUEST INDEX", "Objectives_QuestIndex" }, { "BONUSES", "Objectives_Bonuses" } },
		views = { ["btn/show quests"] = "Objectives_Quests" } },
	sparrow = { title = "SPARROW", tabs = { { "SPARROW", "Sparrow" } } },
	seagull = { title = "SEAGULL", tabs = { { "SEAGULL", "Seagull" } } },
	redpanda = { title = "RED PANDA", tabs = { { "RED PANDA", "RedPanda" } }, views = { naming = "RedPanda_Naming", ["btn/ok"] = "RedPanda" } },
	dave = { title = "DAVE", tabs = { { "DAVE", "Dave" } } },
	evolve = { title = "EVOLVE", tabs = { { "EVOLVE", "Evolve" } } },
	-- no squared Figma frame yet: built in code from FKit (the kit.js recipes), content from the UI v2 / parity screens
	profile = { title = "PROFILE", build = "profile", tabs = { { "PROFILE", go = "profile" }, { "SETTINGS", go = "settings" }, { "LEADERBOARDS", go = "leaderboards" } } },
	settings = { title = "SETTINGS", build = "settings", tabs = { { "PROFILE", go = "profile" }, { "SETTINGS", go = "settings" }, { "LEADERBOARDS", go = "leaderboards" } } },
	teleport = { title = "FAST TRAVEL", build = "teleport" },
	leaderboards = { title = "LEADERBOARDS", build = "leaderboards", tabs = { { "PROFILE", go = "profile" }, { "SETTINGS", go = "settings" }, { "LEADERBOARDS", go = "leaderboards" } } },
	offline = { title = "WELCOME BACK", build = "offline" },
}
