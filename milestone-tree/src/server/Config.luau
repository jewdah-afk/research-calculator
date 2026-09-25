--!strict
-- Server settings for the Milestone Tree NG+ port.
return {
	-- the web page ticks every 50 ms; a session slows down (never below MAX_TICK) when its ticks get expensive, so
	-- that no player's game takes more than about a quarter of a core
	TICK = 0.05,
	MAX_TICK = 0.5,
	TICK_CPU_SHARE = 0.25,

	-- how often the player's screen is refreshed (right after a button press it is refreshed at once)
	VIEW = 0.2,

	-- DataStore
	STORE_NAME = "MilestoneTreeNG_v1",
	AUTOSAVE = 60,        -- seconds between saves while playing
	LOCK_TTL = 180,       -- a session lock older than this is stale (the other server died without saving)

	-- remote limits per player
	ACTIONS_PER_SECOND = 40,
	IMPORT_COOLDOWN = 10,
}
