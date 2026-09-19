--!strict
-- Sim/EnemyStats. Oracle: research/vs/enemies_waves.md §2 L277-299 (statlines,
-- raw x10 display scale per docs/DATA_CONVENTIONS.md), §3 L314-320 (HP_x_Level
-- by player level; own `level` field unknown, OQ-03; Curse raises health and
-- speed), L226 (stage mod enemySpeed 1.1), core_loop.md L16-17 (Reaper).
local T = require("./_harness")
local F = require("./_fixtures")
local EnemyStats = require("../src/shared/Sim/EnemyStats")
local Tuning = require("../src/shared/Tuning")
local EnemiesWaves = require("../src/shared/Data/EnemiesWaves")

local ALL_IDS = {
	"BAT1",
	"BAT2",
	"BAT3",
	"BAT4",
	"BAT5",
	"ZOMBIE",
	"SKELETON",
	"GHOST",
	"MUDMAN1",
	"MUDMAN2",
	"WEREWOLF",
	"XLBAT",
	"XLMANTIS",
	"XLMUMMY",
	"FLOWER",
	"XLFLOWER",
	"BOSS_XLMANTIS",
	"BOSS_WEREWOLF",
	"BOSS_XLMUMMY",
	"BOSS_XLFLOWER",
	"BOSS_XLDEATH",
}
-- enemies_waves.md L282-283, L293, L295-299: the HP_x_Level entries.
local HP_X_LEVEL = {
	"BAT4",
	"BAT5",
	"FLOWER",
	"BOSS_XLMANTIS",
	"BOSS_WEREWOLF",
	"BOSS_XLMUMMY",
	"BOSS_XLFLOWER",
	"BOSS_XLDEATH",
}
local STAGE_SPEED = EnemiesWaves.data.madForest.stageModifiers.enemySpeed

T.test("ES-01 enemies_waves.md L284: ZOMBIE at display scale: 10 hp, 10 power, kb 0.8, xp 1, not boss", function()
	local z = EnemyStats.scaled("ZOMBIE", 0, 1, 1)
	T.eq(z.health, 10, "health (raw 1 x 10)")
	T.eq(z.power, 10, "power")
	T.eq(z.knockbackTaken, 0.8, "knockbackTaken")
	T.eq(z.xp, 1, "xp")
	T.eq(z.isBoss, false, "isBoss")
end)

T.test("ES-01 enemies_waves.md L286/L288/L290/L296: GHOST, MUDMAN2, XLBAT, BOSS_WEREWOLF", function()
	local g = EnemyStats.scaled("GHOST", 0, 1, 1)
	T.eq(g.knockbackTaken, 0, "ghost immune")
	T.eq(g.xp, 1.5, "ghost xp")
	T.eq(g.health, 10, "ghost health")
	local m = EnemyStats.scaled("MUDMAN2", 0, 1, 1)
	T.eq(m.health, 150, "mudman2 health")
	T.eq(m.xp, 2.5, "mudman2 xp")
	T.eq(m.knockbackTaken, 0.3, "mudman2 kb")
	local x = EnemyStats.scaled("XLBAT", 0, 1, 1)
	T.eq(x.health, 270, "xlbat health")
	T.eq(x.knockbackTaken, 0.1, "xlbat kb")
	local w = EnemyStats.scaled("BOSS_WEREWOLF", 0, 1, 1)
	T.eq(w.isBoss, true, "boss")
	T.eq(w.xp, 30, "xp")
	T.eq(w.health, 200, "health")
	T.eq(w.power, 20, "power")
end)

T.test("ES-01 enemies_waves.md L299 + core_loop.md L16-17: the Reaper 655350 hp, 65535 power, kb -0.5, xp 0", function()
	local r = EnemyStats.scaled("BOSS_XLDEATH", 0, 1, 1)
	T.eq(r.health, 655350, "health")
	T.eq(r.power, 65535, "power")
	T.eq(r.knockbackTaken, -0.5, "knockbackTaken")
	T.eq(r.xp, 0, "xp")
	T.eq(r.isBoss, true, "isBoss")
end)

T.test("ES-01 enemies_waves.md L277-299: every field equals the Data record at level 1, curse 1", function()
	for _, id in ALL_IDS do
		local rec = F.findEnemy(id)
		local s = EnemyStats.scaled(id, 0, 1, 1)
		T.eq(s.health, rec.health, id .. " health")
		T.eq(s.health, rec.rawHealth * EnemiesWaves.displayScale, id .. " display scale")
		T.eq(s.power, rec.power, id .. " power")
		T.eq(s.knockbackTaken, rec.knockbackTaken, id .. " knockbackTaken")
		T.eq(s.xp, rec.xpDropped, id .. " xp")
		T.eq(s.isBoss, rec.isBoss, id .. " isBoss")
	end
end)

T.test("ES-01 unknown ids error", function()
	T.throws(function()
		EnemyStats.scaled("DRAGON", 0, 1, 1)
	end, "DRAGON")
	T.throws(function()
		EnemyStats.scaled("", 0, 1, 1)
	end, "empty id")
end)

T.test("ES-02 enemies_waves.md L314-316: HP_x_Level multiplies health by the player level at spawn", function()
	T.eq(EnemyStats.scaled("BAT4", 0, 7, 1).health, 350, "BAT4 50 x 7")
	T.eq(EnemyStats.scaled("FLOWER", 0, 12, 1).health, 360, "FLOWER 30 x 12")
	T.eq(EnemyStats.scaled("BOSS_XLDEATH", 0, 30, 1).health, 19660500, "Reaper 655350 x 30")
	T.eq(EnemyStats.scaled("BOSS_XLMANTIS", 0, 4, 1).health, 600, "BOSS_XLMANTIS 150 x 4")
	for _, id in HP_X_LEVEL do
		local rec = F.findEnemy(id)
		T.eq(EnemyStats.scaled(id, 0, 7, 1).health, rec.health * 7, id .. " x7")
		T.eq(EnemyStats.scalesWithPlayerLevel(id), true, id .. " flagged")
	end
end)

T.test(
	"ES-02 enemies_waves.md L317-318 (OQ-03): non-HP_x_Level enemies ignore player level; own enemyLevel unused",
	function()
		T.eq(EnemyStats.scaled("ZOMBIE", 0, 7, 1).health, 10, "ZOMBIE at level 7")
		T.eq(EnemyStats.scaled("XLBAT", 0, 7, 1).health, 270, "XLBAT (enemyLevel 10, no skill) at level 7")
		T.eq(EnemyStats.scaled("XLMANTIS", 0, 50, 1).health, 500, "XLMANTIS (enemyLevel 10) at level 50")
		for _, id in ALL_IDS do
			if not table.find(HP_X_LEVEL, id) then
				local rec = F.findEnemy(id)
				T.eq(EnemyStats.scaled(id, 0, 25, 1).health, rec.health, id .. " unscaled")
				T.eq(EnemyStats.scalesWithPlayerLevel(id), false, id .. " not flagged")
			end
		end
	end
)

T.test("ES-02 power, xp, knockbackTaken never scale with player level", function()
	for _, id in ALL_IDS do
		local a = EnemyStats.scaled(id, 0, 1, 1)
		local b = EnemyStats.scaled(id, 0, 40, 1)
		T.eq(b.power, a.power, id .. " power")
		T.eq(b.xp, a.xp, id .. " xp")
		T.eq(b.knockbackTaken, a.knockbackTaken, id .. " kb")
		T.eq(b.speed, a.speed, id .. " speed")
	end
end)

T.test("ES-03 enemies_waves.md L320 + passives_evolutions.md L51: Curse multiplies health and speed", function()
	local z = EnemyStats.scaled("ZOMBIE", 0, 1, 1.5)
	T.eq(z.health, 15, "health 10 x 1.5")
	T.eq(z.speed, 100 * Tuning.enemySpeedScale * STAGE_SPEED * 1.5, "speed")
	T.eq(z.power, 10, "power unchanged by curse")
	T.eq(z.xp, 1, "xp unchanged by curse")
	local b = EnemyStats.scaled("BAT4", 0, 7, 1.5)
	T.eq(b.health, 525, "BAT4 50 x 7 x 1.5")
end)

T.test("ES-03 enemies_waves.md L226 + Tuning.enemySpeedScale: speed = Data.speed x scale x stageMod x curse", function()
	T.eq(STAGE_SPEED, 1.1, "stage enemySpeed 1.1")
	T.eq(EnemyStats.scaled("ZOMBIE", 0, 1, 1).speed, 100 * Tuning.enemySpeedScale * STAGE_SPEED, "zombie")
	T.eq(EnemyStats.scaled("GHOST", 0, 1, 1).speed, 200 * Tuning.enemySpeedScale * STAGE_SPEED, "ghost 200")
	T.eq(EnemyStats.scaled("BOSS_XLDEATH", 0, 1, 1).speed, 1200 * Tuning.enemySpeedScale * STAGE_SPEED, "Reaper 1200")
	for _, id in ALL_IDS do
		local rec = F.findEnemy(id)
		T.eq(EnemyStats.scaled(id, 0, 1, 1).speed, rec.speed * Tuning.enemySpeedScale * STAGE_SPEED, id)
	end
end)

T.test("ES-03 the shipped data has no time-based enemy scaling: t=0 equals t=1700 field by field", function()
	for _, id in ALL_IDS do
		local a = EnemyStats.scaled(id, 0, 5, 1)
		local b = EnemyStats.scaled(id, 1700, 5, 1)
		T.eq(b.health, a.health, id .. " health")
		T.eq(b.power, a.power, id .. " power")
		T.eq(b.speed, a.speed, id .. " speed")
		T.eq(b.knockbackTaken, a.knockbackTaken, id .. " kb")
		T.eq(b.xp, a.xp, id .. " xp")
		T.eq(b.isBoss, a.isBoss, id .. " isBoss")
	end
end)

T.test("ES-01 enemies_waves.md L279-299: exactly these 21 identifiers exist", function()
	for _, id in ALL_IDS do
		T.eq(EnemyStats.exists(id), true, id)
	end
	T.eq(EnemyStats.exists("DRAGON"), false, "DRAGON")
	T.eq(#(EnemiesWaves.data.enemies :: { any }), 21, "21 records")
end)

return T.finish()
