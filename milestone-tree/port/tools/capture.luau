--!nocheck
-- Full views of chosen games, for the client's offline checks:
--   node tools/fix_gen.js && luau tools/capture.luau | node tools/split_fix.js data/fixtures    (./test.sh capture)
-- Each fixture is the patch a client gets when it joins (full = true, every node in set): a Session booted from a fuzz
-- save (data/fz/states.json), a scripted prelude (tools/fix_pre.js), then the listed button presses. Printed as
-- "@@FIX <name>" and one line of JSON (keys sorted; an empty table is {}).
local L = require("../lib")
local Session = L.Session
local deps = L.deps()
local pre = require("../data/fixtures/fix_pre")
local JS0 = L.JSRT(L.TN, L.BEcore)
local states = JS0.G.JSON.parse(L.data("fz", "fz_states"))
local NSTATES = JS0.len(states)

-- -------------------------------------------------------------------------------------------------------- JSON
local function jstr(s: string): string
	return '"' .. string.gsub(s, '[%c"\\]', function(c)
		if c == '"' then return '\\"' end
		if c == "\\" then return "\\\\" end
		if c == "\n" then return "\\n" end
		if c == "\r" then return "\\r" end
		if c == "\t" then return "\\t" end
		return string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

local function encode(v, out)
	local t = type(v)
	if t == "string" then
		table.insert(out, jstr(v))
	elseif t == "number" then
		if v ~= v then table.insert(out, '"NaN"')
		elseif v == math.huge then table.insert(out, "1e999")
		elseif v == -math.huge then table.insert(out, "-1e999")
		elseif v == math.floor(v) and math.abs(v) < 2 ^ 53 then table.insert(out, string.format("%d", v))
		else table.insert(out, string.format("%.17g", v)) end
	elseif t == "boolean" then
		table.insert(out, tostring(v))
	elseif t == "table" then
		local n, count = #v, 0
		for _ in v do count += 1 end
		if n > 0 and count == n then
			table.insert(out, "[")
			for i = 1, n do
				if i > 1 then table.insert(out, ",") end
				encode(v[i], out)
			end
			table.insert(out, "]")
		else
			local keys = {}
			for k in v do table.insert(keys, tostring(k)) end
			table.sort(keys)
			table.insert(out, "{")
			for i, k in keys do
				if i > 1 then table.insert(out, ",") end
				table.insert(out, jstr(k) .. ":")
				local x = v[k]
				if x == nil then x = v[tonumber(k)] end
				encode(x, out)
			end
			table.insert(out, "}")
		end
	else
		table.insert(out, "null")
	end
end

-- ---------------------------------------------------------------------------------------------------- captures
local function boot(save: string?)
	local now = 1.7e12
	local s = Session.new(deps, save, nil, now)
	setfenv(pre, s.ENV)
	pre()
	for _ = 1, 2 do
		now += 50
		s:tick(now)
	end
	return s, now
end

local function capture(name: string, save: string?, prelude: string?, acts: { any }?)
	local s, now = boot(save)
	if prelude then s.ENV[prelude](nil) end
	s:view() -- what is on screen is what may be pressed
	for _, a in acts or {} do
		local ok, err = s:act(a, now)
		if not ok then print("-- " .. name .. ": " .. table.concat(a, " ") .. " was not run (" .. tostring(err) .. ")") end
		s:view()
	end
	now += 50
	s:tick(now)
	s:resetView()
	s.lastPopup = 0 -- the popups still on screen come along
	local out = {}
	encode(s:view(), out)
	print("@@FIX " .. name)
	print(table.concat(out))
end

local S13, S19 = states[13].save, states[19].save
capture("fresh_none", nil, nil, {})
capture("fresh_m", nil, nil, { { "tab", "m" } })
capture("s13_none", S13, "fix_s13", {})
capture("s13_p", S13, "fix_s13", { { "tab", "p" } })
capture("s13_m", S13, "fix_s13", { { "tab", "m" } })
capture("s13_sp_spark", S13, "fix_s13", { { "tab", "sp" }, { "subtab", "sp", "mainTabs", "Spark Milestones" } })
capture("s13_options", S13, "fix_s13", { { "tab", "options-tab" } })
capture("s19mv_none", S19, "fix_mv", {})
capture("s19mv_cp", S19, "fix_mv", { { "tab", "cp" } })
capture("s19mv_ex", S19, "fix_mv", { { "tab", "ex" } })
capture("trapped_none", S19, "fix_trapped", {})

-- layer_<l>: each layer's panel at the first save that shows it (the regular saves, then the Multiverse ones)
local want = { "ach", "m", "mm", "em", "p", "pe", "sp", "pb", "pp", "se", "hp", "ep", "hb", "ap", "mp", "t", "pm", "pep", "cp", "cm", "ex" }
-- (not the saves the web game hangs on: data/fz/fz_skip, written by ./test.sh game)
local skip = {}
for n in string.gmatch(L.data("fz", "fz_skip"), "[^,]+") do skip[tonumber(n)] = true end
local at = {}
for i = 0, NSTATES - 1 do
	local ok, s = false, nil
	if not skip[i] then ok, s = pcall(boot, states[i].save) end
	-- a save the game had to restart (NaN) runs in a new environment without the prelude
	if ok and s.ENV.fix_shown == nil then
		setfenv(pre, s.ENV)
		pre()
	end
	if ok then
		for l in string.gmatch(s.ENV.fix_shown(nil), "[^,]+") do
			if at[l] == nil then at[l] = i end
		end
	end
	local all = true
	for _, l in want do if at[l] == nil then all = false end end
	if all then break end
end
for _, l in want do
	if at[l] ~= nil then
		capture("layer_" .. l, states[at[l]].save, nil, { { "tab", l } })
	else
		print("-- no save shows " .. l)
	end
end
