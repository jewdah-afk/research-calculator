--!strict
--[[
	PrefsSchema: the device options, one table for the client (Core/Prefs) and the server (Main: validation and the
	store), so the two can never disagree. They are not part of the game save.

	    motion        SYSTEM | FULL | REDUCED
	    detail        AUTO | HIGH | LOW (the map's texture set)
	    labels        AUTO | ALWAYS | OFF
	    size          90 | 100 | 115 (Interface size, %)
	    weather       OFF | RESETS | AMBIENT (weather on resets; AMBIENT also plays now and then on its own)
	    guide         ON | OFF (hints for significant moments only)
	    notation      SUFFIX | SCIENTIFIC (how numbers read: 1.23M or 1.23e6; the server formats them)
	    tut           0 to 8: the first-run tutorial's next step (8 = done or skipped; Options › Tutorial › Replay sets 0)
	    music, sfx, ambience   0 to 100 in steps of 10
	    seenPrestige  the layers whose first prestige has played its big moment (a list of layer ids)

	A key missing from a stored table takes its default, so saves from before a key existed still load. Unknown keys
	are dropped; a wrong value falls back to the default rather than throwing the whole table away.
]]

local PrefsSchema = {}

local function steps(from: number, to: number, by: number): { number }
	local t = {}
	for v = from, to, by do table.insert(t, v) end
	return t
end

PrefsSchema.CHOICES = {
	motion = { "SYSTEM", "FULL", "REDUCED" },
	detail = { "AUTO", "HIGH", "LOW" },
	labels = { "AUTO", "ALWAYS", "OFF" },
	size = { 90, 100, 115 },
	weather = { "OFF", "RESETS", "AMBIENT" },
	guide = { "ON", "OFF" },
	notation = { "SUFFIX", "SCIENTIFIC" },
	tut = steps(0, 8, 1),
	music = steps(0, 100, 10),
	sfx = steps(0, 100, 10),
	ambience = steps(0, 100, 10),
} :: { [string]: { any } }

PrefsSchema.DEFAULTS = {
	motion = "SYSTEM",
	detail = "AUTO",
	labels = "AUTO",
	size = 100,
	weather = "RESETS",
	guide = "ON",
	notation = "SUFFIX",
	tut = 0,
	music = 60,
	sfx = 70,
	ambience = 60,
} :: { [string]: any }

-- the list keys: at most MAX_SEEN short lowercase layer ids
PrefsSchema.MAX_SEEN = 32

function PrefsSchema.valid(key: string, value: any): boolean
	if key == "seenPrestige" then
		if type(value) ~= "table" then return false end
		local n = 0
		for i, id in value do
			n += 1
			if type(i) ~= "number" or type(id) ~= "string" or #id > 4 or not string.match(id, "^%l+$") then return false end
		end
		return n <= PrefsSchema.MAX_SEEN and n == #value
	end
	local list = PrefsSchema.CHOICES[key]
	return list ~= nil and table.find(list, value) ~= nil
end

-- a full, valid table from anything (a client message or a stored record); nil only when it is not a table
function PrefsSchema.clean(t: any): { [string]: any }?
	if type(t) ~= "table" then return nil end
	local out: { [string]: any } = {}
	for key, default in PrefsSchema.DEFAULTS do
		local v = t[key]
		out[key] = if v ~= nil and PrefsSchema.valid(key, v) then v else default
	end
	local seen = t.seenPrestige
	out.seenPrestige = if seen ~= nil and PrefsSchema.valid("seenPrestige", seen) then table.clone(seen) else {}
	return out
end

function PrefsSchema.defaults(): { [string]: any }
	return PrefsSchema.clean({}) :: { [string]: any }
end

return PrefsSchema
