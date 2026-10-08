--!strict
-- Spec: every Peckwood window's theme + copy, extracted from Figma file SQOJ2gzGt12vFMGGlNRWBE (page UI v2, board 8:7)
-- on 2026-10-07 by reading each frame's layers (header/tab/hero/row/button fills, text, icons).
-- Gradients use the export format "hex[@alpha]:pos ..." (pos 0-100, top to bottom).
-- Icons are the PNG that actually sits in each Figma slot (matched by image bytes), not the stale layer name.
local Spec = {}

local GOLDEN_PROG = "fffbd0:0 f5d06b:50 b28d34:100"

local function L(id, t) t.id = id; Spec[id] = t; return t end

-- ======================================================== reset layers
L("popcorn", { title = "EGGS", figma = "8:122", body = "3b2a20:0 22180f:100", glow = "ffb45a",
	hdr = "ffd27a:0 f7a634:30 e07a1c:72 9e4a0c:100", band = "943f09:0 4f2205:100", tab = "f6b445:0 e0862a:42 b4560f:86 b4560f:100",
	card = "4a3628:0 2e2016:100", tcol = "ffc94a", gcol = "eaff9a:0 4fd85a:100", chev = "4fd85a@35:0 c9ff9a:100",
	buy = "7dff86:0 2bd04a:42 15962f:86 15962f:100", buyGlow = "4dff66",
	tabs = { { icon = "popcorn", label = "Eggs", active = true }, { icon = "plume", label = "Molt", target = "molt" } },
	footer = "Molting resets eggs and these upgrades. Plumes are forever.", h = 692 })
L("molt", { title = "MOLT", figma = "8:250", body = "30244a:0 1a1329:100", glow = "b06cff",
	hdr = "e9c4ff:0 b06cff:30 8a3fe6:72 4f1d9c:100", band = "561fa5:0 2e1158:100", tab = "d79cff:0 a256f5:42 7432d4:86 7432d4:100",
	card = "3d3058:0 261c3a:100", art = "e6c2ff:0 a256f5:50 5d24b0:100", tcol = "cf8cff", gcol = "f3e6ff:0 c79bff:100", chev = "a256f5@35:0 e6c2ff:100",
	buy = "7dff86:0 2bd04a:42 15962f:86 15962f:100", buyGlow = "4dff66",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "plume", label = "Molt", active = true } },
	hero = { icon = "plume", title = "MOLT", sub = "3 plumes  ·  molted 0 times", btn = "Molt for +2 Plumes", btnIcon = "plume" },
	section = "PLUME KEEPSAKES", sectionColor = "e6d6ff", footer = "Molting resets eggs and these upgrades. Plumes are forever." })
L("seeds", { title = "SEEDS", figma = "43:7", body = "1f3a24:0 101d12:100", glow = "8fe04a",
	hdr = "e6ffc4:0 8fe04a:30 4fb52a:72 256a12:100", band = "27640e:0 153507:100", tab = "c8ff8a:0 7ed64a:42 3fa024:86 3fa024:100",
	card = "2f4a32:0 1c2e1e:100", art = "d8ffb8:0 7ed64a:50 2f7a18:100", tcol = "b8f070", gcol = "e8ffd0:0 8fe04a:100", chev = "4fb52a@35:0 c8ff8a:100",
	buy = "7dff86:0 2bd04a:42 15962f:86 15962f:100", buyGlow = "4dff66",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "seed", label = "Seeds", active = true } },
	hero = { icon = "seed", title = "SUNFLOWERS", sub = "1,250 seeds  ·  +3 / s on the platform", btn = "Go to Sunflowers", btnIcon = "seed" },
	section = "SEED UPGRADES", sectionColor = "e0ffd0", footer = "Evolving resets seeds and these upgrades. Plumes are forever." })
L("golden", { title = "GOLDEN", figma = "49:10", body = "3b2e1e:0 1e170f:100", glow = "e6bb44",
	hdr = "ffefc4:0 e6bb44:30 bb9324:72 6e440e:100", band = "673f0a:0 372205:100", tab = "ffe08a:0 dcb344:42 a5811f:86 a5811f:100",
	card = "4b3e2e:0 2f261b:100", art = "ffecb8:0 dcb344:50 7e5014:100", tcol = "f5d06b", gcol = "ffeebf:0 dfb02c:100", chev = "daaa28@35:0 ffe18d:100",
	buy = "ffdc7d:0 d7a724:42 9b7610:86 9b7610:100", buyGlow = "ffcf4d",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "golden", label = "Golden", active = true } },
	hero = { icon = "golden", title = "THE DESERT", sub = "240 golden  ·  5% of desert drops are golden", btn = "Go to the Desert", btnIcon = "golden" },
	section = "GOLDEN UPGRADES", sectionColor = "fff2d0", footer = "Molting resets Golden Value and Auric Silo. Golden eggs are kept." })
L("mine", { title = "MINE", figma = "57:7", body = "202a39:0 11151c:100", glow = "2b3a8f",
	hdr = "2b3a8f:0 4fd2ff:50 ffc22e:100", band = "113160:0 091a33:100", tab = "2b3a8f:0 4fd2ff:50 ffc22e:100",
	card = "303a49:0 1d232d:100", art = "2b3a8f@95:0 4fd2ff@95:50 ffc22e@95:100", tcol = "f5d56b", gcol = "fff8d8:0 e2c03a:100", chev = "e2c03a@35:0 fff0a8:100",
	buy = "2b3a8f:0 4fd2ff:100", buyGlow = "53d7ff",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "pickaxe", label = "Mine", active = true } },
	hero = { icon = "crow", title = "THE MINE", sub = "0 brute ore  ·  Area 1  ·  Crow LV 1", btn = "Go to the Mine", btnIcon = "pickaxe" },
	section = "MINE UPGRADES", sectionColor = "d4ddfb", footer = "Evolving resets all four mine upgrades. Brute Ore is kept." })
L("nest", { title = "NEST", figma = "59:7", body = "33201c:0 19100e:100", glow = "8a4b22",
	hdr = "8a4b22:0 5fbf3a:50 f6e7c8:100", band = "571c0d:0 2e0f07:100", tab = "8a4b22:0 5fbf3a:50 f6e7c8:100",
	card = "412e2a:0 281c19:100", art = "8a4b22@95:0 5fbf3a@95:50 f6e7c8@95:100", tcol = "eddda8", gcol = "fdfaf2:0 d2b862:100", chev = "d2b862@35:0 fdfaf2:100",
	buy = "8a4b22:0 5fbf3a:100", buyGlow = "7eff53",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "nest", label = "Nest", active = true } },
	hero = { icon = "nest", title = "THE NEST", sub = "Basic nest  ·  0 / 100K twigs to Sturdy", btn = "Go to the Forest", btnIcon = "twig" },
	section = "TWIG UPGRADES", sectionColor = "fabf9e", footer = "Molt and Evolve keep twigs, nest tiers and these upgrades." })
L("echo", { title = "ECHO", figma = "60:7", body = "281c33:0 140e19:100", glow = "ff5ed8",
	hdr = "ff5ed8:0 a05cff:50 ff8ff0:100", band = "340d57:0 1c072e:100", tab = "ff5ed8:0 a05cff:50 ff8ff0:100",
	card = "362a41:0 211928:100", art = "ff5ed8@95:0 a05cff@95:50 ff8ff0@95:100", tcol = "f5aad2", gcol = "fef0f8:0 df5da2:100", chev = "df5da2@35:0 fef0f8:100",
	buy = "ff5ed8:0 a05cff:100", buyGlow = "ff5dc4",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "echo", label = "Echo", active = true } },
	hero = { icon = "echo", title = "THE ECHO FIELD", sub = "0 echo eggs  ·  25% of pickups echo", btn = "Go to the Echo Field", btnIcon = "mushroom" },
	section = "ECHO UPGRADES", sectionColor = "de9efa", footer = "Molting resets Echo Value and Echo Capacity. Echo eggs are kept." })
L("parrot", { title = "PARROT", figma = "61:7", body = "341a20:0 1a0e11:100", glow = "e8322e",
	hdr = "e8322e:0 ffcc2e:33 3fbf4a:67 2f7bff:100", band = "5b091c:0 31050f:100", tab = "e8322e:0 ffcc2e:33 3fbf4a:67 2f7bff:100",
	card = "42282e:0 29181c:100", art = "e8322e@95:0 ffcc2e@95:33 3fbf4a@95:67 2f7bff@95:100", tcol = "f6e27b", gcol = "fff8d6:0 e1c538:100", chev = "e1c538@35:0 fff8d6:100",
	buy = "e8322e:0 ffcc2e:100", buyGlow = "53a3ff",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "parrot", label = "Parrot", active = true } },
	hero = { icon = "parrot", title = "THE EXPEDITION", sub = "Parrot LV 1  ·  Floor 1  ·  3 skill points", btn = "Start Expedition", btnIcon = "sword" },
	section = "SKILL POINTS", sectionColor = "ff989f", footer = "Parrot rebirb resets level, XP and skills. Gear and artifacts are kept." })
L("evolve", { title = "EVOLVE", figma = "62:7", body = "192f30:0 0d1818:100", glow = "39c8f0",
	hdr = "39c8f0:0 8a3fd6:50 ff5a8a:100", band = "0a5053:0 052b2c:100", tab = "39c8f0:0 8a3fd6:50 ff5a8a:100",
	card = "263c3d:0 172526:100", art = "39c8f0@95:0 8a3fd6@95:50 ff5a8a@95:100", tcol = "b8eedc", gcol = "f2fdf9:0 70d1b1:100", chev = "70d1b1@35:0 f2fdf9:100",
	buy = "39c8f0:0 8a3fd6:100", buyGlow = "d153ff",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "monster", label = "Evolve", active = true } },
	hero = { icon = "monster", title = "CASTLE MONSTER", sub = "Evolution 3 to 4  ·  0% fed", btn = "Evolve" },
	section = "FEED THE MONSTER", sectionColor = "80e3fc", footer = "Evolving resets non-permanent upgrades, sparrows and feeding progress." })
-- ======================================================== companions
L("sparrow", { title = "SPARROW", figma = "65:8", body = "30201b:0 18100e:100", glow = "8b4a24",
	hdr = "8b4a24:0 ffa62e:50 f2d9b0:100", band = "521c0e:0 2c0f08:100", tab = "8b4a24:0 ffa62e:50 f2d9b0:100",
	card = "3e2d29:0 261b18:100", art = "8b4a24@95:0 ffa62e@95:50 f2d9b0@95:100", tcol = "e4d9c2", gcol = "fbf8f4:0 c0ab81:100", chev = "c0ab81@35:0 fbf8f4:100",
	buy = "8b4a24:0 ffa62e:100", buyGlow = "ffdd53",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "sparrow", label = "Sparrow", active = true } },
	hero = { icon = "sparrow", title = "THE SPARROW", sub = "LV 1  ·  1 sparrow  ·  0 / 40 XP", btn = "Rebirb (needs 16 sparrows)" },
	section = "SPARROW", sectionColor = "f6b893", footer = "Rebirb at 16 sparrows resets to 1. Boosts egg spawns." })
L("seagull", { title = "SEAGULL", figma = "65:181", body = "1d282f:0 0f1417:100", glow = "8aa4c4",
	hdr = "8aa4c4:0 f4f7fb:33 ffcf2e:67 ff8a2e:100", band = "14384c:0 0b1e29:100", tab = "8aa4c4:0 f4f7fb:33 ffcf2e:67 ff8a2e:100",
	card = "2b363c:0 1a2125:100", art = "8aa4c4@95:0 f4f7fb@95:33 ffcf2e@95:67 ff8a2e@95:100", tcol = "e2e0d6", gcol = "f9f8f6:0 b4b09a:100", chev = "b4b09a@35:0 f9f8f6:100",
	buy = "8aa4c4:0 f4f7fb:100", buyGlow = "ffdd53",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "seagull", label = "Seagull", active = true } },
	hero = { icon = "seagull", title = "THE SEAGULL", sub = "LV 1  ·  0 / 100 XP  ·  catch every 10.0s", btn = "Send Out to Fish", btnIcon = "fish" },
	section = "FISHING ORDERS", sectionColor = "9cc2ee", footer = "Migrating starts the gull over at LV 1. Migrations and their unlocks are kept." })
L("dave", { title = "DAVE", figma = "65:354", body = "27222d:0 141116:100", glow = "b9a3c9",
	hdr = "b9a3c9:0 f28bb0:50 8e8399:100", band = "312143:0 1a1124:100", tab = "b9a3c9:0 f28bb0:50 8e8399:100",
	card = "35303b:0 201d24:100", art = "b9a3c9@95:0 f28bb0@95:50 8e8399@95:100", tcol = "e2d3e5", gcol = "f9f5fa:0 b494bb:100", chev = "b494bb@35:0 f9f5fa:100",
	buy = "b9a3c9:0 f28bb0:100", buyGlow = "f765a2",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "dove", label = "Dave", active = true } },
	hero = { icon = "dove", title = "DAVE THE DOVE", sub = "LV 1  ·  golden x1.00  ·  desert forager", btn = "Go to the Desert", btnIcon = "golden" },
	section = "TRAINING", sectionColor = "d1b6e1", footer = "Rebirb resets Dave to LV 1. Branch picks are kept, up to 100 each." })
L("redpanda", { title = "RED PANDA", figma = "65:527", body = "2b1a1e:0 160d0f:100", glow = "d4521f",
	hdr = "d4521f:0 f7e3c3:50 4a2418:100", band = "48111e:0 260910:100", tab = "d4521f:0 f7e3c3:50 4a2418:100",
	card = "38272b:0 23171a:100", art = "d4521f@95:0 f7e3c3@95:50 4a2418@95:100", tcol = "e4d9c2", gcol = "fbf8f4:0 c0ab81:100", chev = "c0ab81@35:0 fbf8f4:100",
	buy = "d4521f:0 f7e3c3:100", buyGlow = "ff935d",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "redpanda", label = "Red Panda", active = true } },
	hero = { icon = "redpanda", title = "THE RED PANDA", sub = "Assist mode  ·  0 twigs waiting", btn = "Collect Twigs", btnIcon = "twig" },
	section = "ASSIST", sectionColor = "ec7d84", footer = "Offline time caps at 8 hours." })
-- ======================================================== fishing (shared deep-ocean base)
local OCEAN = { body = "19252e:0 0d1317:100", band = "0c324f:0 061b2a:100", card = "26323b:0 171f25:100", sectionColor = "7aadf8" }
local function fishing(id, t)
	for k, v in OCEAN do t[k] = t[k] or v end
	t.tabs = { { icon = "popcorn", label = "Fishing", target = "rods" }, { icon = t.tabIcon, label = t.tabLabel, active = true } }
	if id == "rods" then t.tabs[1].target = "index" end
	return L(id, t)
end
fishing("rods", { title = "RODS", figma = "70:8", glow = "e53935", hdr = "e53935:0 ffc93a:50 2f6fe0:100", tab = "e53935:0 ffc93a:50 2f6fe0:100",
	art = "e53935@95:0 ffc93a@95:50 2f6fe0@95:100", tcol = "f6da7b", gcol = "fff5d6:0 e1ba38:100", chev = "e1ba38@35:0 fff5d6:100",
	buy = "e53935:0 ffc93a:100", buyGlow = "ff5953", tabIcon = "rod", tabLabel = "Rods",
	hero = { icon = "rod_simple", title = "THE BRIDGE", sub = "Simple Rod  ·  tier 0  ·  1 moneta per catch", btn = "Go Fishing", btnIcon = "fish" },
	section = "RODS", footer = "Crafting spends the fish. Your best rod sets which fish can bite." })
fishing("baits", { title = "BAIT", figma = "70:181", glow = "ff7fa8", hdr = "ff7fa8:0 3a6fe0:50 c9d2dc:100", tab = "ff7fa8:0 3a6fe0:50 c9d2dc:100",
	art = "ff7fa8@95:0 3a6fe0@95:50 c9d2dc@95:100", tcol = "e6dbc0", gcol = "fbf9f4:0 c4af7e:100", chev = "c4af7e@35:0 fbf9f4:100",
	buy = "ff7fa8:0 3a6fe0:100", buyGlow = "fb619a", tabIcon = "bait", tabLabel = "Baits",
	hero = { icon = "bait", title = "BAIT SHOP", sub = "0 moneta  ·  bait picks the fish type", btn = "Open Tackle Box", btnIcon = "bait" },
	section = "BAITS", footer = "Bait is consumable. It only narrows the pool if that type can bite." })
fishing("index", { title = "INDEX", figma = "70:354", glow = "ff7a1f", hdr = "ff7a1f:0 ffffff:50 2f5fd6:100", tab = "ff7a1f:0 ffffff:50 2f5fd6:100",
	art = "ff7a1f@95:0 ffffff@95:50 2f5fd6@95:100", tcol = "e2e0d6", gcol = "f9f8f6:0 b4b09a:100", chev = "b4b09a@35:0 f9f8f6:100",
	buy = "ff7a1f:0 ffffff:100", buyGlow = "ffa35d", tabIcon = "index", tabLabel = "Fish Index",
	hero = { icon = "fish", title = "FISH INDEX", sub = "0 / 426 discovered", btn = "Open Full Index", btnIcon = "index" },
	section = "RECENT CATCHES", footer = "A heavier personal best raises that fish's sell value." })
fishing("aquarium", { title = "AQUARIUM", figma = "70:527", glow = "38a8ff", hdr = "38a8ff:0 46c24a:50 ffc93a:100", tab = "38a8ff:0 46c24a:50 ffc93a:100",
	art = "38a8ff@95:0 46c24a@95:50 ffc93a@95:100", tcol = "f7c28c", gcol = "fff5ec:0 e39344:100", chev = "e39344@35:0 fff5ec:100",
	buy = "38a8ff:0 46c24a:100", buyGlow = "5cf661", tabIcon = "aquarium", tabLabel = "Aquarium",
	hero = { icon = "tank_5", title = "AQUARIUM", sub = "0 / 2 tanks filled  ·  tank fish boost you", btn = "Visit Aquarium", btnIcon = "aquarium" },
	section = "TANKS", footer = "Tank effects stack with your equipped fish, bait, lure and hook." })
-- ======================================================== meta
L("quests", { title = "QUESTS", figma = "75:8", body = "2b1e1a:0 160f0d:100", glow = "d8332f",
	hdr = "d8332f:0 ffbf3a:50 f2d39a:100", band = "481e11:0 261009:100", tab = "d8332f:0 ffbf3a:50 f2d39a:100",
	card = "382b27:0 231a17:100", art = "d8332f@95:0 ffbf3a@95:50 f2d39a@95:100", tcol = "e6d9b9", gcol = "fcf9f3:0 c5ae77:100", chev = "c5ae77@35:0 fcf9f3:100",
	buy = "d8332f:0 ffbf3a:100", buyGlow = "ff535f",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "quest_scroll", label = "Quests", active = true } },
	hero = { icon = "quest_merchant", title = "QUEST MERCHANT", sub = "3 dailies  ·  new in 23h 59m  ·  0 / 19 main", btn = "Main Quests", btnIcon = "quest_scroll" },
	section = "DAILY QUESTS", sectionColor = "eca97d", footer = "Dailies refresh every 24h: one floor, one hunt and one boss quest." })
L("sacrifice", { title = "SACRIFICE", figma = "75:181", body = "1e1a26:0 0f0d13:100", glow = "ff7a1f",
	hdr = "ff7a1f:0 8a3fd6:50 ffc93a:100", band = "21163b:0 120c20:100", tab = "ff7a1f:0 8a3fd6:50 ffc93a:100",
	card = "292631:0 19171e:100", art = "ff7a1f@95:0 8a3fd6@95:50 ffc93a@95:100", tcol = "f7dc85", gcol = "fff8e0:0 e8b83a:100", chev = "e8b83a@35:0 fff8e0:100",
	buy = "ff7a1f:0 8a3fd6:100", buyGlow = "ff9e5d",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "altar", label = "Sacrifice", active = true } },
	hero = { icon = "altar", title = "THE ALTAR", sub = "0 sacrificed  ·  tier I at 450", btn = "Sacrifice", btnIcon = "aura" },
	section = "MILESTONES", sectionColor = "a376d7", footer = "Milestones are permanent. Each tier needs the total sacrificed so far." })
L("profile", { title = "PROFILE", figma = "75:354", body = "172925:0 0c1412:100", glow = "ffc23a",
	hdr = "ffc23a:0 e0333a:50 2fc7b8:100", band = "0c4538:0 07251e:100", tab = "ffc23a:0 e0333a:50 2fc7b8:100",
	card = "233430:0 15211e:100", art = "ffc23a@95:0 e0333a@95:50 2fc7b8@95:100", tcol = "c2ecde", gcol = "f0fdf8:0 5cc8a8:100", chev = "5cc8a8@35:0 f0fdf8:100",
	buy = "ffc23a:0 e0333a:100", buyGlow = "ffce5d",
	tabs = { { icon = "popcorn", label = "Eggs", target = "popcorn" }, { icon = "birb", label = "Profile", active = true } },
	hero = { icon = "birb", title = "BIRB", sub = "0 Molts  ·  0 Evolutions  ·  floor 1", btn = "Leaderboards", btnIcon = "leaderboard" },
	section = "RECORDS", sectionColor = "5cf2e8", footer = "Your records show on the leaderboards.", extraH = 471, trim = { 1262, 1338 } })

Spec.GOLDEN_PROG = GOLDEN_PROG
-- Feature groups: windows that belong together share one menu tile and show each other as tabs
-- (Popcorn and its Molt reset, the Garden's seeds/sparrow/evolve, every fishing window, ...). Order = unlock order.
Spec.GROUPS = {
	{ id = "park", name = "PARK", icon = "popcorn", members = { "popcorn", "molt" } },
	{ id = "garden", name = "GARDEN", icon = "seed", members = { "seeds", "sparrow", "evolve" } },
	{ id = "bridge", name = "FISHING", icon = "rod", members = { "rods", "baits", "index", "aquarium", "seagull" } },
	{ id = "forest", name = "FOREST", icon = "nest", members = { "nest", "redpanda" } },
	{ id = "mine", name = "MINE", icon = "crow", members = { "mine" } },
	{ id = "desert", name = "DESERT", icon = "golden", members = { "golden", "dave" } },
	{ id = "expedition", name = "EXPEDITION", icon = "parrot", members = { "parrot", "quests", "sacrifice" } },
	{ id = "echo", name = "ECHO", icon = "echo", members = { "echo" } },
	{ id = "profile", name = "PROFILE", icon = "birb", members = { "profile" } },
}
Spec.GROUP_OF = {}
for _, g in Spec.GROUPS do for _, m in g.members do Spec.GROUP_OF[m] = g end end
Spec.TAB_LABEL = { popcorn = "Eggs", molt = "Molt", seeds = "Seeds", sparrow = "Sparrow", evolve = "Evolve", rods = "Rods", baits = "Bait",
	index = "Index", aquarium = "Aquarium", seagull = "Seagull", nest = "Nest", redpanda = "Panda", mine = "Mine", golden = "Golden", dave = "Dave",
	parrot = "Parrot", quests = "Quests", sacrifice = "Altar", echo = "Echo", profile = "Profile" }
-- HUD menu order (only unlocked windows show)
Spec.MENU = { "popcorn", "molt", "seeds", "sparrow", "evolve", "rods", "seagull", "nest", "redpanda", "mine", "golden", "dave", "parrot", "quests", "sacrifice", "echo", "profile" }
Spec.MENU_ICON = { popcorn = "popcorn", molt = "plume", seeds = "seed", sparrow = "sparrow", evolve = "monster", rods = "rod", seagull = "seagull",
	nest = "nest", redpanda = "redpanda", mine = "crow", golden = "golden", dave = "dove", parrot = "parrot", quests = "quest_scroll",
	sacrifice = "altar", echo = "echo", profile = "birb", baits = "bait", index = "index", aquarium = "aquarium" }

return Spec
