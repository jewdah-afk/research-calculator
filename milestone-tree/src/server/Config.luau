--!strict
-- Server settings for the Milestone Tree NG+ port.
return {
	-- the web page ticks every 50 ms; a session slows down (never below MAX_TICK) when its ticks get expensive, so
	-- that no player's game takes more than about a quarter of a core
	TICK = 0.05,
	MAX_TICK = 0.5,
	TICK_CPU_SHARE = 0.25,

	-- how often the player's screen is refreshed (right after a button press it is refreshed at once); an unchanged
	-- screen still gets a patch every KEEPALIVE seconds, so the client can tell a quiet game from a lost connection
	VIEW = 0.2,
	KEEPALIVE = 2,

	-- DataStore
	STORE_NAME = "MilestoneTreeNG_v1",
	AUTOSAVE = 60,        -- seconds between saves while playing
	LOCK_TTL = 180,       -- a session lock older than this is stale (the other server died without saving)

	-- remote limits per player
	ACTIONS_PER_SECOND = 40,
	IMPORT_COOLDOWN = 10, -- seconds; also the ImportCooldown attribute on the remotes folder, for the client's ring

	-- device options (the Prefs remote): at most one change applied per PREFS_INTERVAL, saved PREFS_SAVE_DELAY
	-- seconds after the last change
	PREFS_INTERVAL = 1,
	PREFS_SAVE_DELAY = 5,
}
