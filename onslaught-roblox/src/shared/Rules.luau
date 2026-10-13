--[[
	Account rules shared by server and client: which modes are open, and what a finished game gives.
	Pure Luau (tested in Lune). The server is the only one that writes profiles; the client uses the same
	functions to show locks and previews.
]]

local RS = if script then game:GetService("ReplicatedStorage") else nil
local X = if RS then require(RS.Shared.Onslaught.Expansion) else require("./Onslaught/Expansion")
local EN = if RS then require(RS.Shared.Onslaught.EternityNum) else require("./Onslaught/EternityNum")

local Rules = {}

Rules.MODES = {
	{ id = "easy", label = "Easy", sub = "Classic difficulty" },
	{ id = "medium", label = "Medium", sub = "The standard game" },
	{ id = "hard", label = "Hard", sub = "Faster, tougher attackers" },
	{ id = "extreme", label = "Extreme", sub = "Unlock: 2,000 kills in one normal game", locked = true },
	{ id = "sandbox", label = "Sandbox", sub = "Unlock: 4,000 kills on Medium", locked = true },
	{ id = "sandbox2", label = "Super Sandbox", sub = "Unlock: 4,000 kills on Hard", locked = true },
	{ id = "challenge", label = "Challenges", sub = "The 14 original presets" },
}
local LOCKED = { extreme = true, sandbox = true, sandbox2 = true }

function Rules.modeOpen(profile, passes, mode: string): boolean
	if not LOCKED[mode] then
		return true
	end
	return (passes and passes.clearance) or (profile.unlocks and profile.unlocks[mode]) or false
end

-- Settings a party leader may start with. Returns true or false, reason.
function Rules.validSettings(GAME, profile, passes, s)
	if type(s) ~= "table" or type(s.map) ~= "string" or not GAME.maps[s.map] or s.map == "tutorial" then
		return false, "Pick a map."
	end
	if s.challengeIndex ~= nil then
		if type(s.challengeIndex) ~= "number" or not GAME.challenges[s.challengeIndex] then
			return false, "Unknown challenge."
		end
		return true
	end
	if type(s.mode) ~= "string" or not GAME.startingCash[s.mode] then
		return false, "Pick a difficulty."
	end
	if not Rules.modeOpen(profile, passes, s.mode) then
		return false, "That mode is still locked."
	end
	return true
end

function Rules.bestKey(s): string
	return (if s.plus then "plus:" else "classic:") .. (if s.challengeIndex then "ch" .. s.challengeIndex else s.mode) .. ":" .. s.map
end

-- Apply a finished game to a profile. `run` = { settings, wave, kills, myKills, myEarned, won, assisted, turretKills,
-- comboCounts, combos, lives, startLives, partyBoost, nowMs }. Returns the summary shown on the end screen.
function Rules.applyGameEnd(profile, passes, run)
	local s = run.settings
	local summary = { xp = 0, intel = 0, levelUps = 0, quests = {}, unlocked = {}, newBest = false }
	profile.games = (profile.games or 0) + 1
	if run.won then
		profile.wins = (profile.wins or 0) + 1
	end
	-- best wave per mode and map
	local key = Rules.bestKey(s)
	if not profile.best[key] or run.wave > profile.best[key] then
		profile.best[key] = run.wave
		summary.newBest = true
	end
	if s.challengeIndex and run.won then
		profile.chal[tostring(s.challengeIndex)] = true
	end
	-- the original's unlocks (GameManager.modeUpdate): Classic normal games only
	if not s.challengeIndex and not s.plus and (s.mode == "easy" or s.mode == "medium" or s.mode == "hard" or s.mode == "extreme") then
		local k = run.kills
		profile.kills.normal = math.max(profile.kills.normal or 0, k)
		if k >= 2000 and not profile.unlocks.extreme then
			profile.unlocks.extreme = true
			table.insert(summary.unlocked, "Extreme")
		end
		if k >= 4000 and s.mode == "medium" and not profile.unlocks.sandbox then
			profile.unlocks.sandbox = true
			table.insert(summary.unlocked, "Sandbox")
		end
		if k >= 4000 and s.mode == "hard" and not profile.unlocks.sandbox2 then
			profile.unlocks.sandbox2 = true
			table.insert(summary.unlocked, "Super Sandbox")
		end
	end
	-- XP and Intel (both modes earn them)
	local challenge = if s.challengeIndex then s.challenge else nil
	local meta = { prestige = profile.prestige, passes = passes or {}, xpBoostUntil = profile.xpBoostUntil }
	local r = X.gameRewards({ waveNum = run.wave, kills = run.kills, mode = s.mode, challenge = challenge, won = run.won }, meta, run.nowMs)
	local intel = r.intel * (if run.partyBoost then 2 else 1)
	summary.xp, summary.intel = r.xp, intel
	profile.intel += intel
	summary.levelUps = X.addXP(profile, r.xp)
	-- lifetime totals (EternityNum: they only grow)
	profile.lifetimeXP = EN.toString(EN.add(EN.fromSave(profile.lifetimeXP or "0"), r.xp))
	profile.lifetimeKills = EN.toString(EN.add(EN.fromSave(profile.lifetimeKills or "0"), run.myKills or 0))
	profile.lifetimeBounty = EN.toString(EN.add(EN.fromSave(profile.lifetimeBounty or "0"), math.floor(run.myEarned or 0)))
	-- daily quests
	local gameView = {
		waveNum = run.wave, kills = run.kills, mode = s.mode, challenge = challenge, won = run.won,
		lives = run.lives, startLives = run.startLives, stats = { combos = run.combos or 0 },
		turrets = run.turretKills or {}, comboCounts = run.comboCounts or {},
	}
	for _, def in X.applyQuests(profile, gameView) do
		table.insert(summary.quests, def.text)
	end
	return summary
end

function Rules.today(nowSeconds: number?): string
	return os.date("!%Y-%m-%d", nowSeconds or os.time()) :: string
end
-- Today's 3 quests (UTC day), rolled the same way as the HTML build.
function Rules.dailyQuestsFor(profile, nowSeconds: number?)
	return X.dailyQuests(profile, Rules.today(nowSeconds))
end
-- Swap one of today's quests for another one not already on the list. Costs a reroll (VIP gets 1 free a day).
function Rules.rerollQuest(profile, passes, index: number, nowSeconds: number?): (boolean, string?)
	local q = Rules.dailyQuestsFor(profile, nowSeconds)
	local it = q.list[index]
	if not it or it.done then
		return false, "Pick an unfinished quest."
	end
	local freeLeft = passes and passes.vip and q.vipReroll ~= q.date
	if not freeLeft and (profile.rerolls or 0) <= 0 then
		return false, "No rerolls left."
	end
	local taken = {}
	for _, o in q.list do
		taken[o.id] = true
	end
	local pool = {}
	for _, def in X.XD.quests do
		if not taken[def.id] then
			table.insert(pool, def.id)
		end
	end
	if #pool == 0 then
		return false, "No other quests today."
	end
	local seed = 0
	for i = 1, #q.date do
		seed = (seed * 31 + string.byte(q.date, i)) % 4294967296
	end
	q.list[index] = { id = pool[(seed + index + (profile.rerolls or 0)) % #pool + 1], progress = 0, done = false }
	if freeLeft then
		q.vipReroll = q.date
	else
		profile.rerolls -= 1
	end
	return true
end

return Rules
