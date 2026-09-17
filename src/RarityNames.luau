--!strict
--!native
--[[
	RarityNames — deterministic names for rarity indices 1..∞, lapping at 10,000.

	Structure: 10 bands x (10 prefixes x 20 stems x 5 suffixes) = 10 x 1000 = 10,000.
	The (prefix, stem, suffix) decomposition is bijective over 0..999, so names are
	unique by construction — no dedupe pass, no collision table, no storage.

	Store only the INDEX. Never persist a name string: names are presentation and
	must stay re-skinnable without touching saves.
]]

local RarityNames = {}

export type Rarity = {
	index: number,   -- the true rarity number (1-based, unbounded)
	name: string,    -- display name
	band: number,    -- 1..10, drives colour (see RarityColor)
	lap: number,     -- 0 for the first 10,000, then 1, 2, ...
}

local CYCLE = 10000
local PER_BAND = 1000

-- Each band: 10 prefixes, 20 stems, 5 suffixes. Registers climb in grandeur.
local BANDS = {
	{ -- 1: mundane -> notable
		prefix = {"", "Lesser ", "Plain ", "Common ", "Fair ", "Fine ", "Keen ", "Sharp ", "Greater ", "Prime "},
		stem   = {"Ore", "Stone", "Iron", "Copper", "Bronze", "Steel", "Flint", "Clay", "Slate", "Chalk",
		          "Quartz", "Glass", "Timber", "Coal", "Salt", "Rust", "Grit", "Shard", "Scrap", "Husk"},
		suffix = {"", "ite", "an", "ine", "ex"},
	},
	{ -- 2: material / elemental
		prefix = {"", "Molten ", "Frozen ", "Charged ", "Verdant ", "Tidal ", "Gale ", "Ashen ", "Storm ", "Ember "},
		stem   = {"Flame", "Frost", "Spark", "Bloom", "Tide", "Gale", "Ash", "Cinder", "Bolt", "Mire",
		          "Quake", "Surge", "Drift", "Vapor", "Magma", "Sleet", "Thorn", "Dune", "Reef", "Fume"},
		suffix = {"", "ium", "ora", "yx", "arch"},
	},
	{ -- 3: radiant / celestial
		prefix = {"", "Gleaming ", "Lucent ", "Argent ", "Aureate ", "Halcyon ", "Solar ", "Lunar ", "Astral ", "Empyreal "},
		stem   = {"Gleam", "Lumen", "Halo", "Aurora", "Comet", "Nova", "Zenith", "Corona", "Beacon", "Prism",
		          "Radiance", "Starlight", "Meridian", "Vesper", "Dawn", "Twilight", "Glimmer", "Solace", "Aether", "Lustre"},
		suffix = {"", "is", "ael", "ion", "ys"},
	},
	{ -- 4: cosmic
		prefix = {"", "Deep ", "Void ", "Nebular ", "Galactic ", "Quasar ", "Pulsar ", "Singular ", "Infinite ", "Absolute "},
		stem   = {"Nebula", "Quasar", "Pulsar", "Cosmos", "Void", "Expanse", "Horizon", "Orbit", "Eclipse", "Vortex",
		          "Abyss", "Nexus", "Rift", "Sphere", "Helix", "Spiral", "Cluster", "Vacuum", "Ether", "Continuum"},
		suffix = {"", "ar", "os", "ia", "um"},
	},
	{ -- 5: temporal
		prefix = {"", "Fleeting ", "Enduring ", "Ancient ", "Timeless ", "Eternal ", "Perpetual ", "Everlasting ", "Primordial ", "Ageless "},
		stem   = {"Epoch", "Aeon", "Era", "Moment", "Cycle", "Chronicle", "Hourglass", "Echo", "Memory", "Legacy",
		          "Origin", "Terminus", "Interval", "Duration", "Instant", "Forever", "Never", "Always", "Prelude", "Epilogue"},
		suffix = {"", "ica", "ex", "orum", "ath"},
	},
	{ -- 6: dimensional
		prefix = {"", "Folded ", "Layered ", "Parallel ", "Fractured ", "Recursive ", "Boundless ", "Unbounded ", "Hyper", "Meta"},
		stem   = {"Plane", "Fold", "Lattice", "Manifold", "Threshold", "Gateway", "Corridor", "Labyrinth", "Fracture", "Seam",
		          "Boundary", "Interstice", "Dimension", "Topology", "Vertex", "Tessera", "Facet", "Axis", "Domain", "Stratum"},
		suffix = {"", "iad", "arch", "ene", "ux"},
	},
	{ -- 7: conceptual / abstract
		prefix = {"", "Pure ", "Ideal ", "Essential ", "Fundamental ", "Axiomatic ", "Immaculate ", "Sublime ", "Perfect ", "Ineffable "},
		stem   = {"Theorem", "Axiom", "Paradox", "Essence", "Concept", "Notion", "Abstraction", "Principle", "Truth", "Reason",
		          "Logic", "Meaning", "Symbol", "Pattern", "Order", "Chaos", "Balance", "Harmony", "Discord", "Unity"},
		suffix = {"", "ism", "ity", "ance", "osis"},
	},
	{ -- 8: mythic / divine
		prefix = {"", "Hallowed ", "Sacred ", "Blessed ", "Anointed ", "Exalted ", "Seraphic ", "Divine ", "Godly ", "Almighty "},
		stem   = {"Oracle", "Seraph", "Cherub", "Titan", "Colossus", "Pantheon", "Sanctum", "Relic", "Covenant", "Judgment",
		          "Providence", "Ascension", "Revelation", "Genesis", "Apotheosis", "Miracle", "Prophecy", "Dominion", "Sovereign", "Majesty"},
		suffix = {"", "iel", "oth", "ara", "ez"},
	},
	{ -- 9: transcendent
		prefix = {"", "Beyond ", "Ascendant ", "Transcendent ", "Supernal ", "Ultimate ", "Supreme ", "Paramount ", "Omni", "Pan"},
		stem   = {"Apex", "Summit", "Pinnacle", "Culmination", "Overture", "Crescendo", "Paragon", "Epitome", "Quintessence", "Absolute",
		          "Totality", "Omniscience", "Omnipotence", "Ascendance", "Transcendence", "Elevation", "Exaltation", "Sublimity", "Grandeur", "Magnitude"},
		suffix = {"", "arch", "ion", "yss", "um"},
	},
	{ -- 10: beyond language
		prefix = {"", "Un", "Non", "Anti", "Ur", "Proto", "Null", "Zero", "Last ", "First "},
		stem   = {"Nameless", "Wordless", "Unspoken", "Unwritten", "Unknowable", "Unfathomed", "Silence", "Cipher", "Enigma", "Sigil",
		          "Glyph", "Rune", "Emblem", "Signal", "Whisper", "Murmur", "Hush", "Void", "Blank", "Aleph"},
		suffix = {"", "-0", "-X", "-Ω", "-∞"},
	},
}

--- Resolve a rarity index to its name, band and lap. Pure and allocation-light.
function RarityNames.resolve(index: number): Rarity
	assert(index >= 1, "rarity index is 1-based")
	local zero = index - 1
	local lap = zero // CYCLE
	local idx = zero % CYCLE

	local band = idx // PER_BAND              -- 0..9
	local i = idx % PER_BAND                  -- 0..999
	local p = i // 100                        -- 0..9
	local s = (i % 100) // 5                  -- 0..19
	local x = i % 5                           -- 0..4

	local B = BANDS[band + 1]
	local name = B.prefix[p + 1] .. B.stem[s + 1] .. B.suffix[x + 1]

	return { index = index, name = name, band = band + 1, lap = lap }
end

--- Display string including the lap marker. Lap 0 shows no marker, so normal
--- play never sees the mechanism.
function RarityNames.display(index: number): string
	local r = RarityNames.resolve(index)
	if r.lap == 0 then
		return r.name
	end
	return string.format("%s %s", r.name, string.rep("★", math.min(r.lap, 5)))
end

--- "Luck#100" — the overhead nameplate label. The index leads because it is the
--- real measure of progress; names lap, the number never does.
function RarityNames.luckTag(index: number): string
	return "Luck#" .. tostring(index)
end

return RarityNames
