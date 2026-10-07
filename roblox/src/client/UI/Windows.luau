--!nonstrict
-- Windows: builds every Peckwood window from Spec and binds its rows to the server state.
-- Each binder returns row definitions (for the build) and an update(s, d) that fills them every state push.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Defs = require(Shared:WaitForChild("Defs"))
local Nav = require(script.Parent.Parent:WaitForChild("Nav"))
local Spec = require(script.Parent.Spec)
local Window = require(script.Parent.Window)
local Kit = require(script.Parent.Kit)
local EN = Defs.EN
local short = EN.short

local Windows = {}
local fmt = function(n) return short(n) end
local function commas(n)
	n = math.floor(n)
	local s = tostring(n)
	if n < 1e6 then
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end
	return short(n)
end
Windows.commas = commas
-- wallet values: commas below 1M, EternityNum short form above (never inf)
local function amount(v) local n = EN.toNumber(v); if n == n and n < 1e6 then return commas(n) end return short(v) end
Windows.amount = amount
local function fishName(id)
	local n = id:gsub("^fish_", ""):gsub("_", " ")
	return (n:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end
Windows.fishName = fishName

-- ---------------------------------------------------------------- standard upgrade row
local function upgradeRow(id, icon)
	local d = Defs.UP[id]
	return { title = d.name, desc = d.desc, icon = icon or d.icon, buyIcon = Defs.CUR[d.cur].icon, upgrade = id }
end
local function fillUpgrade(r, s, id)
	local d = Defs.UP[id]
	local L = Defs.level(s, id)
	local maxL = Defs.maxLevel(s, id)
	local shown, shownMax = Defs.shownLevel(s, id)
	local isMax = L >= maxL
	local cost = if isMax then 0 else Defs.cost(s, id, L)
	r.set({
		from = d.fx(L), to = if isMax then "MAX" else d.fx(L + 1),
		prog = { if shownMax > 0 then shown / shownMax else 1, "LV " .. shown .. " / " .. shownMax },
		maxed = isMax, cost = fmt(cost), can = not isMax and EN.meeq(s[d.cur], cost),
	})
end

-- ---------------------------------------------------------------- per-window binders
-- rows: list of row defs for Window.build. bind(api, act): wire buttons. update(api, s, d): refresh.
local B = {}

local function shop(ids, icons)
	return {
		rows = (function() local t = {}; for i, id in ids do t[i] = upgradeRow(id, icons and icons[i]) end; return t end)(),
		bind = function(api, act)
			for i, id in ids do
				local r = api.rows[i]
				r.buy.root.Activated:Connect(function() act("buy", id, false, r.buy) end)
				r.all.root.Activated:Connect(function() act("buy", id, true, r.all) end)
			end
		end,
		update = function(api, s) for i, id in ids do fillUpgrade(api.rows[i], s, id) end end,
	}
end

B.popcorn = shop({ "p_value", "p_speed", "p_capacity", "p_move_speed" }, { "golden", "clock", "popcorn", "wing" })
B.molt = shop({ "pr_popcorn_mult", "pr_radius_mult", "pr_respawn_mult" }, { "plume", "magnet", "clock" })
do
	local base = B.molt
	B.molt = { rows = base.rows, bind = function(api, act)
		base.bind(api, act)
		api.hero.btn.root.Activated:Connect(function() act("molt", nil, nil, api.hero.btn) end)
	end, update = function(api, s, d)
		base.update(api, s, d)
		local g = d.plumeGain
		api.hero.sub.Text = amount(s.goldenFeathers) .. " plumes  ·  molted " .. s.rebirbCount .. " times"
		api.hero.btn.setText("Molt for +" .. fmt(g) .. " Plumes")
		api.hero.btn.look(if EN.meeq(g, 1) then "lit" else "grey", Kit.stops(Spec.molt.tab))
	end }
end
B.seeds = shop({ "s_more_popcorn", "s_more_feathers", "s_more_seeds" }, { "popcorn", "plume", "seed" })
do
	local base = B.seeds
	B.seeds = { rows = base.rows, bind = function(api, act)
		base.bind(api, act)
		api.hero.btn.root.Activated:Connect(function() Nav.go("garden") end)
	end, update = function(api, s, d)
		base.update(api, s, d)
		api.hero.sub.Text = amount(s.sunflowerSeeds) .. " seeds  ·  +" .. fmt(d.seedsPerSec) .. " / s on the platform"
	end }
end
B.golden = shop({ "p_golden_popcorn_value", "p_auric_silo", "d_desert_field_notes_plus" }, { "golden", "popcorn", "golden" })
do
	local base = B.golden
	B.golden = { rows = base.rows, bind = function(api, act)
		base.bind(api, act)
		api.hero.btn.root.Activated:Connect(function() Nav.go(if Windows.state and Windows.state.zone == "desert" then "park" else "desert") end)
	end, update = function(api, s, d)
		base.update(api, s, d)
		api.hero.sub.Text = amount(s.goldenPopcorn) .. " golden  ·  " .. math.round(d.goldenChance * 100) .. "% of desert drops are golden"
		api.hero.btn.setText(if s.zone == "desert" then "Back to the Park" else "Go to the Desert")
	end }
end
B.mine = shop({ "m_mining_power", "m_ore_value", "m_charged_strike", "m_rupture" }, { "pickaxe", "ore", "crow", "sword" })
do
	local base = B.mine
	B.mine = { rows = base.rows, bind = base.bind, update = function(api, s, d)
		base.update(api, s, d)
		api.hero.sub.Text = amount(s.bruteOre) .. " brute ore  ·  Area " .. (s.crow.area + 1) .. "  ·  Crow LV " .. s.crow.level
		api.hero.btn.setText("+" .. fmt(d.orePerSec) .. " ore / s")
	end }
end
B.nest = shop({ "n_twig_value", "n_peck_rate", "n_peck_power" }, { "twig", "clock", "wood" })
do
	local base = B.nest
	B.nest = { rows = base.rows, bind = function(api, act)
		base.bind(api, act)
		api.hero.btn.root.Activated:Connect(function()
			if api.goForest then Nav.go("forest") else act("nest", nil, nil, api.hero.btn) end
		end)
	end, update = function(api, s, d)
		base.update(api, s, d)
		local T = Defs.NEST_TIERS
		local cur, nxt = T[s.nest.tier + 1], T[s.nest.tier + 2]
		if nxt then
			api.hero.sub.Text = cur.name .. " nest  ·  " .. fmt(s.twigs) .. " / " .. fmt(cur.next) .. " twigs to " .. nxt.name
			local can = EN.meeq(s.twigs, cur.next) and s.nest.tier + 1 <= Defs.S.nestMaxTier(s.evolutionCount)
			api.hero.btn.setText(if can then "Build the " .. nxt.name .. " Nest" else "Go to the Forest")
			api.goForest = not can
			api.hero.btn.look(if can then "lit" else "grey", Kit.stops(Spec.nest.tab))
		else
			api.hero.sub.Text = cur.name .. " nest  ·  max tier"
		end
	end }
end
B.echo = shop({ "p_echo_value", "e_echo_capacity" }, { "echo", "mushroom" })
do
	local base = B.echo
	B.echo = { rows = base.rows, bind = base.bind, update = function(api, s, d)
		base.update(api, s, d)
		api.hero.sub.Text = amount(s.echoPopcorn) .. " echo popcorn  ·  25% of pickups echo"
	end }
end

B.parrot = {
	rows = {
		{ title = "Health", desc = "+1 base max HP per point.", icon = "heart", buyIcon = "skill", allText = "SPEND ALL" },
		{ title = "Damage", desc = "+1 base damage per point.", icon = "sword", buyIcon = "skill", allText = "SPEND ALL" },
		{ title = "Regen", desc = "+1 base life regen per point.", icon = "shield", buyIcon = "skill", allText = "SPEND ALL" },
	},
	bind = function(api, act)
		for i, st in { "hp", "dmg", "regen" } do
			api.rows[i].buy.root.Activated:Connect(function() act("spend", st, false, api.rows[i].buy) end)
			api.rows[i].all.root.Activated:Connect(function() act("spend", st, true, api.rows[i].all) end)
		end
		api.hero.btn.root.Activated:Connect(function() act("expedition") end)
	end,
	update = function(api, s, d)
		local p = s.parrot
		local sp = math.floor(EN.toNumber(s.skillPoints))
		local vals = { { 100 + p.hp, d.parrot.hp }, { 100 + p.dmg, d.parrot.dmg }, { p.regen, d.parrot.regen } }
		for i, v in vals do
			local suf = if i == 3 then "/s" else ""
			api.rows[i].set({ from = commas(v[1]) .. suf, to = commas(v[1] + 1) .. suf, prog = { math.min(1, sp / 100), commas(sp) .. " points" }, cost = "1", can = sp > 0 })
		end
		api.hero.sub.Text = "Parrot LV " .. p.level .. "  ·  Floor " .. p.floor .. "  ·  " .. commas(sp) .. " skill points"
		api.hero.btn.setText(if p.active then "Return to Camp" else "Start Expedition")
		api.hero.btn.look(if p.active then "grey" else "lit", Kit.stops(Spec.parrot.tab))
	end,
}

B.evolve = {
	rows = {
		{ title = "Popcorn", desc = "Feed popcorn to the monster.", icon = "popcorn", buyIcon = "popcorn", allText = "FEED ALL" },
		{ title = "Twigs", desc = "Feed twigs from the nest.", icon = "twig", buyIcon = "twig", allText = "FEED ALL" },
		{ title = "Moneta", desc = "Feed moneta from fish sales.", icon = "moneta", buyIcon = "moneta", allText = "FEED ALL" },
	},
	bind = function(api, act)
		api.hero.btn.root.Activated:Connect(function() act("evolve", nil, nil, api.hero.btn) end)
		for i in api.rows do
			api.rows[i].buy.root.Activated:Connect(function() act("feed", api.rows[i].res, false, api.rows[i].buy) end)
			api.rows[i].all.root.Activated:Connect(function() act("feed", api.rows[i].res, true, api.rows[i].all) end)
		end
	end,
	update = function(api, s, d)
		local need = Defs.EVO[s.evolutionCount + 1]
		local done = need == nil
		need = need or Defs.EVO[#Defs.EVO] or {}   -- fully evolved: show the last feeding, completed
		local list = {}
		for _, k in { "popcorn", "sunflowerSeeds", "twigs", "moneta" } do if need[k] then table.insert(list, k) end end
		for i, r in api.rows do
			local k = list[i]
			r.row.Visible = k ~= nil
			if k then
				r.res = k
				local fed = if done then need[k] else (s.evo.fed[k] or 0)
				local cur = Defs.CUR[k]
				r.set({ title = cur.name, icon = cur.icon, buyIcon = cur.icon, desc = "Feed " .. cur.name:lower() .. " to the monster.",
					from = fmt(fed), to = fmt(need[k]), prog = { fed / need[k], math.floor(fed / need[k] * 100) .. "%" },
					cost = "FEED", can = fed < need[k] and EN.me(s[k], 0), maxed = done })
			end
		end
		local nextEvo = s.evolutionCount + 1
		api.hero.sub.Text = if Defs.EVO[nextEvo] then "Evolution " .. s.evolutionCount .. " to " .. nextEvo .. "  ·  " .. math.floor(d.evoProgress * 100) .. "% fed" else "Fully evolved"
		if done then api.hero.btn.setText("Fully Evolved"); api.hero.btn.look("gold")
		else api.hero.btn.setText("Evolve"); api.hero.btn.look(if d.evoProgress >= 1 then "lit" else "grey", Kit.stops(Spec.evolve.tab)) end
	end,
}

B.sparrow = {
	rows = {
		{ title = "Feed", desc = "Feeds 25% of seed income.", icon = "seed", buyIcon = "seed", allText = "FEED ALL" },
		{ title = "Resonance", desc = "Drains XP into popcorn mult.", icon = "popcorn", buyIcon = "clock", allText = "STOP" },
		{ title = "Mitosis", desc = "Needs 10K XP. Resets level.", icon = "heart", buyIcon = "wing", allText = "AUTO" },
	},
	bind = function(api, act)
		local r = api.rows
		r[1].buy.root.Activated:Connect(function() act("sparrow", "feed", nil, r[1].buy) end)
		r[1].all.root.Activated:Connect(function() act("sparrow", "feedall", nil, r[1].all) end)
		r[2].buy.root.Activated:Connect(function() act("sparrow", "drain", nil, r[2].buy) end)
		r[2].all.root.Activated:Connect(function() act("sparrow", "stop", nil, r[2].all) end)
		r[3].buy.root.Activated:Connect(function() act("sparrow", "split", nil, r[3].buy) end)
		r[3].all.root.Activated:Connect(function() act("sparrow", "auto", nil, r[3].all) end)
		api.hero.btn.root.Activated:Connect(function() act("sparrow", "rebirb", nil, api.hero.btn) end)
	end,
	update = function(api, s)
		local sp = s.sparrow
		local need = Defs.S.sparrowXpNeeded(sp.level)
		local mreq = Defs.S.mitosisRequirement(sp.count)
		local res = Defs.S.sparrowDrainMultiplier(sp.resonance)
		api.rows[1].set({ from = commas(sp.xp) .. " XP", to = commas(need) .. " XP", prog = { sp.xp / need, "LV " .. sp.level .. "  ·  " .. commas(sp.xp) .. " / " .. commas(need) .. " XP" }, cost = "FEED", can = EN.me(s.sunflowerSeeds, 0) })
		api.rows[2].set({ from = string.format("x%.2f", res), to = string.format("x%.2f", Defs.S.sparrowDrainMultiplier(sp.resonance + need * 2)), prog = { math.min(1, sp.resonance / 1e6), commas(sp.resonance) .. " resonance" }, cost = if sp.draining then "DRAINING" else "DRAIN", can = not sp.draining and sp.level > 1, canAll = sp.draining })
		api.rows[3].set({ from = tostring(sp.count), to = tostring(math.min(16, sp.count * 2)), desc = "Needs " .. fmt(mreq) .. " XP. Resets level.", prog = { math.min(1, sp.mitosisXp / mreq), fmt(sp.mitosisXp) .. " / " .. fmt(mreq) .. " XP" }, cost = "SPLIT", can = sp.count < 16 and sp.mitosisXp >= mreq, canAll = sp.autoMitosis, allText = if sp.autoMitosis then "AUTO ON" else "AUTO" })
		api.hero.sub.Text = "LV " .. sp.level .. "  ·  " .. sp.count .. (if sp.count == 1 then " sparrow" else " sparrows") .. "  ·  " .. commas(sp.xp) .. " / " .. commas(need) .. " XP"
		api.hero.btn.setText(if sp.count >= 16 then "Rebirb the Flock" else "Rebirb (needs 16 sparrows)")
		api.hero.btn.look(if sp.count >= 16 then "lit" else "grey", Kit.stops(Spec.sparrow.tab))
	end,
}

local ROUTES = { "Bridge", "Floor 1", "Floor 2", "Floor 4", "Floor 6" }
local ROUTE_M = { 1, 1.18, 1.22, 1.28, 1.34 }
local DOCS = { { "Balanced", 1, "Even catches." }, { "Hunter", 1.3, "Hunter: slower, rarer fish." }, { "Training", 1.02, "Training: more gull XP." } }
B.seagull = {
	rows = {
		{ title = "Route", desc = "Where the gull fishes.", icon = "index", buyIcon = "index", allText = "INFO" },
		{ title = "Doctrine", desc = "Hunter: slower, rarer fish.", icon = "shield", buyIcon = "shield", allText = "INFO" },
		{ title = "Migration", desc = "Reach LV 50. 1 unlocks Frenzy.", icon = "wing", buyIcon = "wing", allText = "AUTO" },
	},
	bind = function(api, act)
		local r = api.rows
		r[1].buy.root.Activated:Connect(function() act("seagull", "route") end)
		r[2].buy.root.Activated:Connect(function() act("seagull", "doctrine") end)
		r[3].buy.root.Activated:Connect(function() act("seagull", "migrate", nil, r[3].buy) end)
		r[3].all.root.Activated:Connect(function() act("seagull", "auto") end)
		r[1].all.root.Activated:Connect(function() Windows.toast("Routes: Bridge x1.00, Floor 1 x1.18, Floor 2 x1.22, Floor 4 x1.28, Floor 6 x1.34 interval") end)
		r[2].all.root.Activated:Connect(function() Windows.toast("Balanced 1x · Hunter 1.3x interval, rarer · Training 1.45x gull XP") end)
		api.hero.btn.root.Activated:Connect(function() act("seagull", "send") end)
	end,
	update = function(api, s, d)
		local g = s.seagull
		local need = Defs.S.seagullXpNeeded(g.level)
		api.rows[1].set({ from = ROUTES[g.route], to = string.format("x%.2f", ROUTE_M[g.route]), prog = { 1, string.format("Interval x%.2f", ROUTE_M[g.route]) }, cost = "CHANGE", can = true, canAll = true })
		local dd = DOCS[g.doctrine]
		api.rows[2].set({ from = dd[1], to = string.format("x%.2f", dd[2]), desc = dd[3], prog = { 1, "Interval x" .. string.format("%.2f", dd[2]) }, cost = "CHANGE", can = true, canAll = true })
		api.rows[3].set({ from = tostring(g.migrations), to = tostring(g.migrations + 1), prog = { g.level / 50, "LV " .. g.level .. " / 50" }, cost = "MIGRATE", can = g.level >= 50, canAll = g.autoMigrate, allText = if g.autoMigrate then "AUTO ON" else "AUTO" })
		api.hero.sub.Text = "LV " .. g.level .. "  ·  " .. commas(g.xp) .. " / " .. commas(need) .. " XP  ·  catch every " .. string.format("%.1f", d.seagullInterval) .. "s"
		api.hero.btn.setText(if g.out then "Call the Gull Home" else "Send Out to Fish")
	end,
}

B.dave = {
	rows = {
		upgradeRow("dave_training", "seed"),
		{ title = "Rebirb", desc = "Needs LV 100 and 250 golden.", icon = "golden", allText = "BRANCH" },
	},
	bind = function(api, act)
		api.rows[1].buy.root.Activated:Connect(function() act("buy", "dave_training", false, api.rows[1].buy) end)
		api.rows[1].all.root.Activated:Connect(function() act("buy", "dave_training", true, api.rows[1].all) end)
		api.rows[2].buy.root.Activated:Connect(function() act("dave", "rebirb", nil, api.rows[2].buy) end)
		api.rows[2].all.root.Activated:Connect(function() act("dave", "branch") end)
		api.hero.btn.root.Activated:Connect(function() Nav.go("desert") end)
	end,
	update = function(api, s)
		fillUpgrade(api.rows[1], s, "dave_training")
		local dv = s.dave
		local BR = { "Scavenger", "Sweep", "Gilded" }
		api.rows[2].set({ from = BR[dv.branch + 1], to = "+1x", prog = { math.min(1, dv.level / 100), "LV " .. dv.level .. " / 100" }, cost = "REBIRB", can = dv.level >= 100 and dv.golden >= 250, canAll = true })
		api.hero.sub.Text = "LV " .. dv.level .. "  ·  golden x" .. string.format("%.2f", Defs.S.daveGoldenMult(dv.level)) .. "  ·  desert forager"
	end,
}

B.redpanda = {
	rows = { { title = "Assist Mode", desc = "Collects twigs while away.", icon = "clock", buyIcon = "twig", allText = "OFF" } },
	bind = function(api, act)
		api.rows[1].buy.root.Activated:Connect(function() act("panda", "on") end)
		api.rows[1].all.root.Activated:Connect(function() act("panda", "off") end)
		api.hero.btn.root.Activated:Connect(function() act("panda", "collect", nil, api.hero.btn) end)
	end,
	update = function(api, s)
		local p = s.panda
		api.rows[1].set({ from = if p.assist then "55%" else "0%", to = "55%", prog = { if p.assist then 1 else 0, if p.assist then "On  ·  up to 8h" else "0h / 8h" }, cost = "ON", can = not p.assist, canAll = p.assist })
		api.hero.sub.Text = "Assist mode  ·  " .. fmt(p.waiting) .. " twigs waiting"
		api.hero.btn.look(if p.waiting > 0 then "lit" else "grey", Kit.stops(Spec.redpanda.tab))
	end,
}

-- fishing ---------------------------------------------------------------
B.rods = {
	rows = {
		{ title = "Normal Rod", desc = "3 moneta per catch.", icon = "rod_normal", buyIcon = "fish", allText = "INFO" },
		{ title = "Reinforced Rod", desc = "4 moneta per catch.", icon = "rod_reinforced", buyIcon = "fish", allText = "INFO" },
		{ title = "Pro Rod", desc = "5 moneta per catch.", icon = "rod_pro", buyIcon = "fish", allText = "INFO" },
	},
	bind = function(api, act)
		for i, r in api.rows do
			r.buy.root.Activated:Connect(function() act("fish", "craft", r.rod, r.buy) end)
			r.all.root.Activated:Connect(function() if r.info then Windows.toast(r.info) end end)
		end
		api.hero.btn.root.Activated:Connect(function() act("fish", "go") end)
	end,
	update = function(api, s, d)
		local cur = Defs.ROD_BY_ID[s.fish.rod]
		-- nothing left to craft: show the best crafted rods as owned (MAXED) instead of empty cards
		local list = d.rodRows
		if #list == 0 then
			list = {}
			for i = #Defs.RODS, 1, -1 do
				if s.fish.crafted[Defs.RODS[i].id] and #list < #api.rows then table.insert(list, 1, Defs.RODS[i].id) end
			end
		end
		for i, r in api.rows do
			local id = list[i]
			r.row.Visible = id ~= nil
			if id and s.fish.crafted[id] then
				local rod = Defs.ROD_BY_ID[id]
				r.set({ title = fishName(id:gsub("^rod_", "")) .. " Rod", icon = id, desc = rod.monetaPerCatch .. " moneta per catch.",
					from = string.format("x%.2f", rod.speedBonus), to = "OWNED", prog = { 1, "CRAFTED" }, maxed = true })
			elseif id then
				local rod = Defs.ROD_BY_ID[id]
				r.rod = id
				local parts, ok, frac = {}, true, 0
				for _, c in rod.cost do
					local have = Windows.fishHave and Windows.fishHave[c.fishId] or 0
					table.insert(parts, fishName(c.fishId):sub(1, 10) .. " " .. math.min(have, c.count) .. "/" .. c.count)
					if have < c.count then ok = false end
					frac += math.min(1, have / c.count) / #rod.cost
				end
				r.info = "Needs " .. table.concat(parts, ", ")
				r.set({ title = fishName(id:gsub("^rod_", "")) .. " Rod", icon = id, desc = rod.monetaPerCatch .. " moneta per catch.",
					from = string.format("x%.2f", cur.speedBonus), to = string.format("x%.2f", rod.speedBonus),
					prog = { frac, table.concat(parts, " · ") }, cost = "CRAFT", can = ok, canAll = true, buyIcon = rod.cost[1] and rod.cost[1].fishId or "fish" })
			end
		end
		api.hero.icon.Image = Kit.iconId(s.fish.rod)
		api.hero.sub.Text = fishName(s.fish.rod:gsub("^rod_", "")) .. " Rod  ·  tier " .. cur.tier .. "  ·  " .. cur.monetaPerCatch .. " moneta per catch"
		api.hero.btn.setText(if s.fish.active then "Stop Fishing" else "Go Fishing")
	end,
}
B.baits = {
	rows = {
		{ title = "Coastal Chum", icon = "bait_coastal_chum", buyIcon = "moneta", allText = "BUY 10", bait = "bait_coastal_chum" },
		{ title = "Fresh Pellet", icon = "bait_freshwater_pellet", buyIcon = "moneta", allText = "BUY 10", bait = "bait_freshwater_pellet" },
		{ title = "River Grub", icon = "bait_river_grub", buyIcon = "moneta", allText = "BUY 10", bait = "bait_river_grub" },
	},
	bind = function(api, act)
		for i, r in api.rows do
			local id = B.baits.rows[i].bait
			r.buy.root.Activated:Connect(function() act("fish", "bait", id, r.buy) end)
			r.all.root.Activated:Connect(function() act("fish", "bait10", id, r.all) end)
		end
		api.hero.btn.root.Activated:Connect(function() Windows.open("index") end)
	end,
	update = function(api, s)
		for i, r in api.rows do
			local id = B.baits.rows[i].bait
			local b
			for _, x in Defs.BAITS do if x.id == id then b = x end end
			local c = 1
			for _, cc in b.cost or {} do if cc.type == "currency" then c = cc.count end end
			local t = b.effect and b.effect.targetType or "?"
			local need = b.evolutionRequired or 0
			local owned = s.fish.baits[id] or 0
			r.set({ from = "All", to = t:gsub("^%l", string.upper), desc = if need > s.evolutionCount + 1 then "Needs " .. need .. " evolutions." else "Only " .. t .. " fish bite.",
				prog = { math.min(1, owned / 10), "Owned " .. owned .. (if s.fish.bait == id then "  ·  equipped" else "") }, cost = tostring(c), can = EN.meeq(s.moneta, c), canAll = EN.meeq(s.moneta, c * 10) })
		end
		api.hero.sub.Text = amount(s.moneta) .. " moneta  ·  bait picks the fish type"
	end,
}
B.index = {
	rows = {
		{ title = "Silver Fish", icon = "fish_silver", buyIcon = "fish_silver", allText = "SELL" },
		{ title = "Swallowtail", icon = "swallowtail_purple", buyIcon = "swallowtail_purple", allText = "SELL" },
		{ title = "Huchen", icon = "huchen", buyIcon = "huchen", allText = "SELL" },
	},
	bind = function(api, act)
		for i, r in api.rows do
			r.buy.root.Activated:Connect(function() if r.fish then act("fish", "equip", r.fish, r.buy) end end)
			r.all.root.Activated:Connect(function() if r.fish then act("fish", "sell", r.fish, r.all) end end)
		end
		api.hero.btn.root.Activated:Connect(function() Windows.openIndex() end)
	end,
	update = function(api, s, d)
		for i, r in api.rows do
			local c = s.fish.recent[i]
			r.row.Visible = c ~= nil
			if c then
				local f = Defs.FISH_BY_ID[c.id]
				r.fish = c.id
				local best = Windows.fishBest and Windows.fishBest[c.id] or c.kg
				local eff = f.effect and (f.effect.type:gsub("_mult", ""):gsub("_", " ") .. " x" .. f.effect.value) or ""
				r.set({ title = fishName(c.id), icon = c.id, buyIcon = c.id, from = string.format("%.2f kg", c.kg), to = string.format("%.2f kg", best),
					desc = f.rarity:gsub("^%l", string.upper) .. " · " .. eff, prog = { 1, "Sells for " .. commas(d.recentSell[i] or 0) },
					cost = if s.fish.equipped == c.id then "EQUIPPED" else "EQUIP", can = s.fish.equipped ~= c.id, canAll = true })
			end
		end
		api.hero.sub.Text = d.discovered .. " / " .. #Defs.FISH .. " discovered"
	end,
}
B.aquarium = {
	rows = {
		{ title = "Tank 1", desc = "Place a fish to use its effect.", icon = "tank_1", buyIcon = "fish", allText = "AUTO" },
		{ title = "Tank 2", desc = "Place a fish to use its effect.", icon = "tank_2", buyIcon = "fish", allText = "AUTO" },
	},
	bind = function(api, act)
		for i, r in api.rows do
			r.buy.root.Activated:Connect(function() act("fish", "tank", i, r.buy) end)
			r.all.root.Activated:Connect(function() act("fish", "tank", i, r.all) end)
		end
	end,
	update = function(api, s, d)
		local filled = 0
		for i, r in api.rows do
			local unlocked = i <= d.tankCount
			local id = s.fish.tanks[i]
			if id then filled += 1 end
			r.set({ from = if id then fishName(id) else "Empty", to = if id then "Active" else "Fish", buyIcon = id or "fish",
				prog = { if id then 1 else 0, if unlocked then (if id then "In tank" else "Pro lure: x3 for new fish") else "Locked tank" },
				cost = if id then "SWAP" else "PLACE", can = unlocked, canAll = unlocked })
		end
		api.hero.sub.Text = filled .. " / " .. d.tankCount .. " tanks filled  ·  tank fish boost you"
	end,
}

-- meta ---------------------------------------------------------------
B.quests = {
	rows = {
		{ title = "Floor 1 Clear", icon = "quest_floor", buyIcon = "chest", allText = "TRACK" },
		{ title = "Hunt Harpies", icon = "quest_hunt", buyIcon = "chest", allText = "TRACK" },
		{ title = "Floor 1 Boss", icon = "quest_boss", buyIcon = "chest", allText = "TRACK" },
	},
	bind = function(api, act)
		for i, r in api.rows do
			r.buy.root.Activated:Connect(function() act("quest", "claim", i, r.buy) end)
			r.all.root.Activated:Connect(function() Windows.open("parrot") end)
		end
		api.hero.btn.root.Activated:Connect(function() Windows.toast("Main quests: " .. (Windows.state and Windows.state.quests.done or 0) .. " / 19 done") end)
	end,
	update = function(api, s)
		local QB = {}
		for _, q in Defs.QUESTS do if q.id then QB[q.id] = q end end
		for i, r in api.rows do
			local id = s.quests.daily[i]
			local q = id and QB[id]
			r.row.Visible = q ~= nil
			if q then
				local p = math.floor(s.quests.prog[id] or 0)
				local stat = (q.rewardStat or ""):gsub("_mult", ""):gsub("_", " ")
				local done = s.quests.claimed[id]
				r.set({ title = fishName(q.id:gsub("^daily_", "")), desc = "Reward: +" .. math.round((q.rewardValue or 0) * 100) .. "% " .. stat,
					from = "+" .. math.round((s.quests.bonus[q.rewardStat] or 0) * 100) .. "%", to = "+" .. math.round(((s.quests.bonus[q.rewardStat] or 0) + q.rewardValue) * 100) .. "%",
					prog = { p / q.target, p .. " / " .. q.target }, cost = if done then "DONE" else "CLAIM", can = not done and p >= q.target, canAll = true })
			end
		end
		local left = 86400 - (os.time() % 86400)
		api.hero.sub.Text = "3 dailies  ·  new in " .. math.floor(left / 3600) .. "h " .. math.floor(left % 3600 / 60) .. "m  ·  " .. s.quests.done .. " / 19 main"
	end,
}
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII" }
B.sacrifice = {
	rows = {
		{ title = "Tier I", icon = "sacrifice_I", buyIcon = "aura", allText = "INFO" },
		{ title = "Tier II", icon = "sacrifice_II", buyIcon = "aura", allText = "INFO" },
		{ title = "Tier III", icon = "sacrifice_III", buyIcon = "aura", allText = "INFO" },
	},
	bind = function(api, act)
		for _, r in api.rows do
			r.buy.root.Activated:Connect(function() act("sacrifice", nil, nil, r.buy) end)
			r.all.root.Activated:Connect(function() if r.info then Windows.toast(r.info) end end)
		end
		api.hero.btn.root.Activated:Connect(function() act("sacrifice", nil, nil, api.hero.btn) end)
	end,
	update = function(api, s)
		local tot = s.sacrifice.total
		local sp = EN.toNumber(s.skillPoints)
		local start = math.clamp(s.sacrifice.tier, 1, #Defs.SACRIFICE - 2)   -- show the current tier and the next two
		if s.sacrifice.tier == 0 then start = 1 end
		for i, r in api.rows do
			local t = start + i - 1
			local m = Defs.SACRIFICE[t]
			local prev = Defs.SACRIFICE[t - 1]
			local got = tot >= m.cost
			local what = if m.popcornMultiplier > (prev and prev.popcornMultiplier or 1) then "Popcorn and seeds."
				elseif m.skillPointMultiplier > (prev and prev.skillPointMultiplier or 1) then "Skill points from expeditions."
				else "Aura amount and chance."
			r.info = "Tier " .. ROMAN[t] .. ": popcorn x" .. m.popcornMultiplier .. ", seeds x" .. m.seedMultiplier .. ", skill points x" .. m.skillPointMultiplier
			r.set({ title = "Tier " .. ROMAN[t], icon = "sacrifice_" .. ROMAN[t], desc = what,
				from = "x" .. (prev and prev.popcornMultiplier or 1), to = "x" .. m.popcornMultiplier,
				prog = { math.min(1, tot / m.cost), commas(math.min(tot, m.cost)) .. " / " .. fmt(m.cost) }, maxed = got,
				cost = fmt(m.cost), can = not got and tot + sp >= m.cost, canAll = true })
		end
		local nxt = Defs.SACRIFICE[s.sacrifice.tier + 1]
		api.hero.sub.Text = commas(tot) .. " sacrificed  ·  " .. (if nxt then "tier " .. ROMAN[s.sacrifice.tier + 1] .. " at " .. fmt(nxt.cost) else "every tier reached")
		api.hero.btn.look(if sp >= 1 then "lit" else "grey", Kit.stops(Spec.sacrifice.tab))
	end,
}

local STATS = {
	{ "Popcorn", "popcorn", function(s) return fmt(s.popcorn) end }, { "Plumes", "plume", function(s) return fmt(s.goldenFeathers) end },
	{ "Seeds", "seed", function(s) return fmt(s.sunflowerSeeds) end }, { "Golden", "golden", function(s) return fmt(s.goldenPopcorn) end },
	{ "Brute Ore", "ore", function(s) return fmt(s.bruteOre) end }, { "Twigs", "twig", function(s) return fmt(s.twigs) end },
	{ "Echo", "echo", function(s) return fmt(s.echoPopcorn) end }, { "Moneta", "moneta", function(s) return fmt(s.moneta) end },
	{ "Molts", "crown", function(s) return commas(s.rebirbCount) end }, { "Evolutions", "monster", function(s) return tostring(s.evolutionCount) end },
	{ "Crow", "crow", function(s) return "LV " .. s.crow.level end }, { "Parrot", "parrot", function(s) return "LV " .. s.parrot.level end },
	{ "Sparrows", "sparrow", function(s) return tostring(s.sparrow.count) end }, { "Migrations", "seagull", function(s) return tostring(s.seagull.migrations) end },
	{ "Fish caught", "fish", function(s) return commas(s.stats.fishCaught) end }, { "Quests", "quest_scroll", function(s) return tostring(s.stats.questsDone) end },
	{ "Best rod", "rod_simple", function(s) return fishName(s.fish.rod:gsub("^rod_", "")) end }, { "Play time", "clock", function(s) return math.floor(s.stats.playTime / 3600) .. "h" end },
}
B.profile = {
	rows = {
		{ title = "Fish Index", icon = "index", buyIcon = "trophy", allText = "SHARE" },
		{ title = "Highest Floor", icon = "quest_floor", buyIcon = "trophy", allText = "SHARE" },
		{ title = "Sacrifice", icon = "altar", buyIcon = "trophy", allText = "SHARE" },
	},
	bind = function(api, act)
		api.rows[1].buy.root.Activated:Connect(function() Windows.open("index") end)
		api.rows[2].buy.root.Activated:Connect(function() Windows.open("parrot") end)
		api.rows[3].buy.root.Activated:Connect(function() Windows.open("sacrifice") end)
		for _, r in api.rows do r.all.root.Activated:Connect(function() Windows.toast("Records show on the leaderboards.") end) end
		api.hero.btn.root.Activated:Connect(function() Windows.toast("Leaderboards open with the live servers.") end)
		-- ALL STATS drop-down (80:7): 18 chips, two columns, HIDE toggles
		local y = api.extraY
		local dd = Kit.frame(api.body, 16, y, 468, 471, nil, { ZIndex = 2 })   -- card + chips are in the Figma render
		Kit.title(dd, "ALL STATS", 18, Kit.hex("c2ecde"), 2, 0, { Position = UDim2.fromOffset(17, 13), ZIndex = 3 })
		local hide = Kit.new("TextButton", { Text = "HIDE  ▲", FontFace = Kit.TITLE, TextSize = 17, TextColor3 = Kit.hex("5cf2e8"), BackgroundTransparency = 1, Position = UDim2.fromOffset(368, 15), Size = UDim2.fromOffset(84, 22), ZIndex = 3 }, dd)
		Kit.textStroke(hide, 2)
		api.statVals = {}
		local grid = Kit.frame(dd, 17, 47, 435, 408, nil, { ZIndex = 3 })
		-- chips measured on the Figma render: 212 x 29, columns at x 0 / 221, rows every 35 px
		for i, st in STATS do
			local col, rw = (i - 1) % 2, math.floor((i - 1) / 2)
			local chip = Kit.frame(grid, col * 221, rw * 35, 212, 29, nil, { ZIndex = 3 })
			Kit.icon(chip, 6, 3, 23, st[2], { ZIndex = 4 })
			Kit.text(chip, st[1], 13, Kit.hex("bcc3cf"), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(35, 15), ZIndex = 4 })
			local v = Kit.text(chip, "0", 14, Kit.hex("c2ecde"), { AutomaticSize = Enum.AutomaticSize.None, AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromOffset(204, 15), Size = UDim2.fromOffset(100, 20), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
			Kit.textStroke(v, 1.6)
			api.statVals[i] = { set = function(t) v.Text = t end }
		end
		hide.Activated:Connect(function()
			grid.Visible = not grid.Visible
			hide.Text = if grid.Visible then "HIDE  ▲" else "SHOW  ▼"
		end)
	end,
	update = function(api, s, d)
		api.rows[1].set({ from = tostring(d.discovered), to = tostring(#Defs.FISH), desc = "Fish discovered.", prog = { d.discovered / #Defs.FISH, math.floor(d.discovered / #Defs.FISH * 100) .. "%" }, cost = "VIEW", can = true, canAll = true })
		api.rows[2].set({ from = tostring(s.parrot.best), to = "12", desc = "Expedition record.", prog = { s.parrot.best / 12, "Floor " .. s.parrot.best }, cost = "VIEW", can = true, canAll = true })
		api.rows[3].set({ from = if s.sacrifice.tier > 0 then "Tier " .. ROMAN[s.sacrifice.tier] else "None", to = "Tier " .. ROMAN[math.min(18, s.sacrifice.tier + 1)], desc = "Highest altar tier.", prog = { s.sacrifice.tier / 18, s.sacrifice.tier .. " / 18" }, cost = "VIEW", can = true, canAll = true })
		api.hero.sub.Text = commas(s.rebirbCount) .. " Molts  ·  " .. s.evolutionCount .. " Evolutions  ·  floor " .. s.parrot.best
		for i, st in STATS do api.statVals[i].set(st[3](s)) end
	end,
}

-- fishing tab cycles through the four fishing windows

-- ---------------------------------------------------------------- registry
Windows.binders = B
Windows.built = {}
function Windows.build(parent, id, act)
	local spec = table.clone(Spec[id])
	local b = B[id]
	spec.rows = b.rows
	-- tabs = the window's feature group (a lone window keeps one full-width tab naming itself)
	spec.tabs = {}
	for _, m in Spec.GROUP_OF[id].members do
		table.insert(spec.tabs, { id = m, icon = Spec.MENU_ICON[m], label = Spec.TAB_LABEL[m], active = m == id, target = if m ~= id then m else nil })
	end
	local api = Window.build(parent, spec)
	b.bind(api, act)
	for _, t in api.tabs do
		if t.target then t.root.Activated:Connect(function() Windows.open(t.target) end) end
	end
	Windows.built[id] = api
	return api
end
function Windows.update(id, s, d)
	local api = Windows.built[id]
	if api and api.root.Visible then B[id].update(api, s, d) end
end

return Windows
