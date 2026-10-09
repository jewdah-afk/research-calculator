--!nonstrict
-- WindowDefs: every in-game window and which Figma frame(s) it is made of.
--   tabs   = the window's tab bar, in Figma order: { label, variant } or { label, go = "<other window>" }
--            (label = the Figma tab layer name without "tab/" and its state suffix)
--   views  = extra variants switched by a clickable layer inside the window (segments, view switches, state demos)
--   drawer = the permanent upgrades SIDEBAR on the right (Shop drawer frames)
--   dock   = where the window sits in the game area, from the Birb captures (playtest/parity/birb_ui):
--            "bl" = bottom-left (Birb companion panels: Fishing, Parrot, Dave ...), "popup" = above the HUD button that
--            opened it (Fast Travel), default = centred in the game area (Aquarium, Objectives, Fish Market ...)
--   title / theme on a tab = that tab's header title and colour (a Figma frame reused for several tabs)
--   build  = hand-built window (no squared Figma frame yet), see UI/Screens.luau
-- Variant names are module names in UI/Figma/Layouts (generated from Figma; node ids in the module headers).
return {
	shop = { title = "SHOP", drawer = true, theme = "gold",
		-- NEST / MINE are sidebar views like Birb's (generated from the SEEDS frame: UI/SidebarViews); their card key
		-- opens the full window
		tabs = { { "EGGS", "Shop_Eggs" }, { "MOLT", "Shop_Molt" }, { "SEEDS", "Shop_Seeds" }, { "NEST", "Shop_Nest" }, { "MINE", "Shop_Mine" } },
		views = { ["seg/GOLDEN"] = "Shop_Eggs_Golden", ["seg/EGGS"] = "Shop_Eggs", ["seg/ECHO"] = "Shop_Eggs" } },
	mine = { title = "MINE", tabs = { { "SHOP", "Mine_Shop" }, { "AREAS", "Mine_Areas" }, { "CROW", go = "crow" } } },
	crow = { dock = "bl", title = "CROW", tabs = { { "CROW", "Crow" } } },
	treasure = { title = "TREASURE ROOM", tabs = { { "TREASURE ROOM", "Mine_TreasureRoom" } } },
	-- one Figma header for all three tabs: the title and header theme follow the tab (parity build names)
	trees = { title = "SUNFLOWER TREE", tabs = { { "SUNFLOWER", "Tree_Sunflower", title = "SUNFLOWER TREE" }, { "DESERT", "Tree_Desert", title = "DESERT TREE", theme = "desert" },
		{ "ARCHIVIST", "Tree_Archivist", title = "ARCHIVIST'S BRANCH", theme = "archivist" } } },
	fishing = { dock = "bl", title = "FISHING", tabs = { { "COLLECTION", "Fishing_Collection" }, { "EQUIPMENT", "Fishing_Equipment" }, { "FISHDEX", "Fishing_Fishdex" } } },
	aquarium = { title = "AQUARIUM", tabs = { { "BIOMES", "Aquarium_Biomes" }, { "RESONANCE", "Aquarium_Resonance" }, { "TOTAL", "Aquarium_Total" }, { "FISH MARKET", go = "market" } } },
	market = { title = "FISH MARKET", tabs = { { "FISH MARKET", "FishMarket" } }, views = { locked = "FishMarket_Locked" } },
	nest = { title = "NEST", tabs = { { "SHOP", "Nest_Shop" }, { "LAKE", "Nest_Lake" }, { "RIVERSIDE", "Nest_Riverside" }, { "SAWMILL", "Nest_Sawmill" }, { "OWNED", "Nest_Owned" } },
		-- breeding demo: BREED -> incubating -> HATCH -> ready -> FUSE / DISCARD -> back to the lake
		views = { ["btn/breed"] = "Nest_Lake_Incubating", ["btn/hatch (waiting)"] = "Nest_Lake_Ready", ["btn/fuse"] = "Nest_Lake", ["btn/discard"] = "Nest_Lake" } },
	parrot = { dock = "bl", title = "PARROT", tabs = { { "OVERVIEW", "Parrot_Overview" }, { "UPGRADE", "Parrot_Upgrade" }, { "EQUIPMENT", "Parrot_Equipment" }, { "INDEX", "Parrot_Index" }, { "REBIRB", "Parrot_Rebirb" } },
		views = { ["view/FORGE"] = "Parrot_Forge", ["view/BAG"] = "Parrot_Equipment", ["view/BAG (active)"] = "Parrot_Equipment" } },
	expedition = { title = "EXPEDITION", tabs = { { "DAY  ·  FLOORS 1-9", "Expedition" }, { "NIGHT  ·  FLOOR 1", "Expedition" } } },
	sacrifice = { title = "SACRIFICE", tabs = { { "SACRIFICE", "Sacrifice" }, { "MYTHIC", "Sacrifice_Mythic" } } },
	objectives = { title = "OBJECTIVES", tabs = { { "QUESTS", "Objectives_Quests" }, { "QUEST INDEX", "Objectives_QuestIndex" }, { "BONUSES", "Objectives_Bonuses" } },
		views = { ["btn/show quests"] = "Objectives_Quests" } },
	sparrow = { dock = "bl", title = "SPARROW", tabs = { { "SPARROW", "Sparrow" } } },
	seagull = { dock = "bl", title = "SEAGULL", tabs = { { "SEAGULL", "Seagull" } } },
	redpanda = { dock = "bl", title = "RED PANDA", tabs = { { "RED PANDA", "RedPanda" } }, views = { naming = "RedPanda_Naming", ["btn/ok"] = "RedPanda" } },
	dave = { dock = "bl", title = "DAVE", tabs = { { "DAVE", "Dave" } } },
	evolve = { title = "EVOLVE", tabs = { { "EVOLVE", "Evolve" } } },
	-- no squared Figma frame yet: built in code from FKit (the kit.js recipes), content from the UI v2 / parity screens
	profile = { title = "PROFILE", build = "profile", tabs = { { "PROFILE", go = "profile" }, { "SETTINGS", go = "settings" }, { "LEADERBOARDS", go = "leaderboards" } } },
	settings = { title = "SETTINGS", build = "settings", tabs = { { "PROFILE", go = "profile" }, { "SETTINGS", go = "settings" }, { "LEADERBOARDS", go = "leaderboards" } } },
	teleport = { dock = "popup", title = "FAST TRAVEL", build = "teleport" },
	leaderboards = { title = "LEADERBOARDS", build = "leaderboards", tabs = { { "PROFILE", go = "profile" }, { "SETTINGS", go = "settings" }, { "LEADERBOARDS", go = "leaderboards" } } },
	offline = { title = "WELCOME BACK", build = "offline" },
	-- dev only (dev bar SOUNDS): audition and pick every UI sound
	sounds = { title = "SOUND BOARD", build = "sounds" },
}
