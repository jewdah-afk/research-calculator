--!strict
-- Server settings for the Milestone Tree NG+ port.
return {
	-- the web page ticks every 50 ms; a session slows down (never below MAX_TICK) when its ticks get expensive, so
	-- that no player's game takes more than about a quarter of a core
	TICK = 0.05,
	MAX_TICK = 0.5,
	TICK_CPU_SHARE = 0.25,
	-- a full server shares its cores: each game's tick share is at most SERVER_CPU / players (so 50 late-game players
	-- slow their own ticks down, they do not slow the server's heartbeat for everyone); never under MIN_CPU_SHARE
	SERVER_CPU = 3,
	MIN_CPU_SHARE = 0.03,

	-- how often the player's screen is refreshed (right after a button press it is refreshed at once): 10 times a
	-- second, backing off towards MAX_VIEW when building the screen gets expensive (VIEW_CPU_SHARE of a core); an
	-- unchanged screen still gets a patch every KEEPALIVE seconds, so the client can tell a quiet game from a lost
	-- connection
	VIEW = 0.1,
	MAX_VIEW = 0.25,
	VIEW_CPU_SHARE = 0.06,
	KEEPALIVE = 2,

	-- DataStore
	STORE_NAME = "MilestoneTreeNG_v1",
	AUTOSAVE = 60,        -- seconds between saves while playing
	LOCK_TTL = 180,       -- a session lock older than this is stale (the other server died without saving)

	-- remote limits per player: button presses (a token bucket), whole-screen resyncs, leaderboard pages. A player
	-- who keeps flooding past the limits (FLOOD_DROPS dropped requests within FLOOD_WINDOW seconds) is kicked
	ACTIONS_PER_SECOND = 40,
	RESYNC_EVERY = 1,
	BOARD_EVERY = 0.5,
	FLOOD_DROPS = 400,
	FLOOD_WINDOW = 10,

	-- leaderboards (server/Leaderboards, shared/Boards): each player's stats are sent at most every LB_EVERY seconds
	-- and when they leave, and only the boards whose value went up; a board page is the top LB_TOP, cached LB_CACHE
	-- seconds. LB_BANNED: user ids kept off every board (cheaters, test accounts)
	LB_EVERY = 300,
	LB_TOP = 50,
	LB_CACHE = 60,
	LB_BANNED = {} :: { number },

	-- device options (the Prefs remote): at most one change applied per PREFS_INTERVAL, saved PREFS_SAVE_DELAY
	-- seconds after the last change
	PREFS_INTERVAL = 1,
	PREFS_SAVE_DELAY = 5,
}
