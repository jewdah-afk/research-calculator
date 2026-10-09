--!nonstrict
-- Castle (Birb sR.feedMonster / performEvolutionReset): feeding the monster 10% of each requirement per second while
-- held, and the evolution reset. Written fresh from the playtest (playtest/js/systems.js PT.feedMonster / PT.evolve).
-- State: s.evo = { fed = { popcorn, feathers, seeds, fish, twigs, moneta }, progress = 0..100, talked = bool }.
local function shared(name)
	if script then return require(game:GetService("ReplicatedStorage"):WaitForChild("Peckwood"):WaitForChild("Birb"):WaitForChild(name)) end
	return nil
end
local R = (shared("Rules") or require("../../shared/Birb/Rules")) :: any
local Park = (if script then require(script.Parent.Park) else require("./Park")) :: any
local EN = R.EN

local Castle = {}

-- pct = share of each requirement fed per call (hold = 10% per second, so 10 * dt per step)
function Castle.feed(s, pct: number)
	if (s.evolutionCount or 0) >= 5 then return end
	local n = R.evoReq(s.evolutionCount)
	local fed = s.evo.fed
	local function feed(cur, key, need)
		local f = fed[key] or 0
		if need <= 0 or f >= need then return end
		local have = R.res(s, cur)
		if EN.leeq(have, 0) then return end
		local amt = EN.toNumber(EN.min(need * (pct / 100), EN.min(have, need - f)))
		R.sub(s, cur, amt)
		fed[key] = f + amt
	end
	feed("popcorn", "popcorn", n.popcorn)
	feed("goldenFeathers", "feathers", n.feathers)
	feed("sunflowerSeeds", "seeds", n.seeds)
	if n.fish > 0 and (fed.fish or 0) < n.fish then fed.fish = math.min(n.fish, s.stats.fishCaught or 0) end
	feed("twigs", "twigs", n.twigs)
	feed("monetariaMoneta", "moneta", n.moneta)
	s.evo.progress = math.min(100, R.feedProgress(s))
end

-- Upgrade rows that are not Birb data rows keep their pre-port rule until their phase lands: the nest twig shop and
-- Dave's seed training are kept, the old echo capacity row resets (see roblox/tools/parity/README.md).
local NON_BIRB_RESET = { e_echo_capacity = true }

-- Birb evolvePigeon -> performEvolutionReset -> onEvolutionReset (Phase 1 parts). Returns true on success.
function Castle.evolve(s, rt): boolean
	if not R.canEvolveStage(s) or R.feedProgress(s) < 100 then return false end
	s.evolutionCount = math.min(R.evoCap(s), (s.evolutionCount or 0) + 1)
	s.evo.fed = { popcorn = 0, feathers = 0, seeds = 0, fish = 0, twigs = 0, moneta = 0 }
	s.evo.progress = 0
	-- upgrades: Birb keeps only permanent rows (never mine rows)
	local ups = {}
	for id, L in s.upgrades do
		local def = R.Data.UP_BY_ID[id]
		if def then
			if def.permanent and def.tree ~= "M" and R.orv(L, 0) > 0 then ups[id] = L end
		elseif not NON_BIRB_RESET[id] then
			ups[id] = L
		end
	end
	-- tree nodes: Unlock Evolve, the Desert key, Double Catch, Seagull Synergy and permanent nodes stay
	local sun = {}
	for id, L in s.sunflowerUpgrades do
		local def = R.Data.SUN_BY_ID[id]
		if def and R.orv(L, 0) > 0 and (R.KEEP_SUN[id] or def.permanent) then sun[id] = L end
	end
	local sp = s.sparrow
	if sp.unlocked then
		sp.level = 0; sp.xp = 0
		if s.evolutionCount == 2 then sp.maxLevelReached = 1 end
		sp.count = 1; sp.draining = false; sp.feeding = false; sp.resonanceXP = 0
		if rt then table.clear(rt.sparrows) end
	end
	s.upgrades = ups
	s.sunflowerUpgrades = sun
	for _, k in { "popcorn", "goldenPopcorn", "echoPopcorn", "goldenFeathers", "sunflowerSeeds", "moneta", "twigs" } do s[k] = EN.ZERO end
	if rt then Park.clearField(rt) end
	if s.evolutionCount >= 1 then sp.unlocked = true end
	if rt then   -- Birb sends the bird back to the Park centre (Main teleports the character there)
		rt.map = 0; rt.onPlatform = false; rt.player.x = rt.geom.cx; rt.player.y = rt.geom.cy; rt.evolved = true
	end
	return true
end

return Castle
