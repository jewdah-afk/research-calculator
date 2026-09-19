--!strict
--[[
	shared/Net.luau -- every RemoteEvent the run uses, and the shape of what
	travels over it.

	One module, required by both sides. The server calls Net.server() once at
	startup, which CREATES the folder and every RemoteEvent under it; clients
	call Net.client(), which WAITS for them. Neither side ever names a remote
	with a bare string anywhere else, so a typo is a type error rather than a
	silently dead event.

	Payloads are plain tables of numbers, strings and booleans -- no
	Instances, no metatables -- so they cross the wire unchanged and can be
	built without allocation pressure on the server.

	Traffic, by design:
	  * Hud          server -> client, ~5 Hz (Tuning.hudPushInterval).
	  * LevelUpOffer server -> client, once per pending level-up. The run is
	                 paused when this fires and stays paused until the reply.
	  * ChooseOption client -> server, the reply. The server validates it
	                 against the offer it actually sent; anything else is
	                 dropped, so a crafted reply cannot grant an item.
	  * RunState     server -> client, pause/resume and end of run.
	  * Visual       server -> client, fire-and-forget cosmetics
	                 (Types.VisualSpec). Carries no gameplay state: dropping
	                 one costs a sparkle, never a hit.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require. HudState below restates
	Types.HudState structurally; Luau's structural typing makes the two
	interchangeable. Keep it byte-for-byte in step with Types.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Mirrors Types.HudState.
export type HudState = {
	time: number,
	level: number,
	xp: number,
	xpToNext: number,
	health: number,
	maxHealth: number,
	kills: number,
	gold: number,
	weapons: { { id: string, level: number } },
	passives: { { id: string, level: number } },
	paused: boolean,
}

-- Mirrors Types.LevelUpOption / Types.LevelUpOffer, plus the offerId the
-- client must echo back so a stale or forged reply cannot be applied.
export type LevelUpOption = {
	kind: string, -- Types.OptionKind: "weapon" | "passive"
	itemId: string,
	toLevel: number,
	isNew: boolean,
}

export type LevelUpOfferPayload = {
	offerId: number,
	options: { LevelUpOption },
	rerollsLeft: number,
	skipsLeft: number,
	banishesLeft: number,
}

-- The client's reply. `action` is what the player pressed; `index` is the
-- 1-based option for "choose" and "banish", and is ignored otherwise.
export type ChooseOptionPayload = {
	offerId: number,
	action: string, -- "choose" | "reroll" | "skip" | "banish"
	index: number,
}

-- Pause/resume and end of run.
export type RunStatePayload = {
	paused: boolean,
	finished: boolean,
	time: number,
	reason: string, -- "levelup" | "running" | "dead" | "survived"
}

-- Mirrors Types.VisualSpec.
export type VisualPayload = {
	kind: string,
	x: number,
	z: number,
	radius: number?,
	angle: number?,
	duration: number?,
	weaponId: string?,
}

export type Net = {
	folder: Folder,
	hud: RemoteEvent,
	levelUpOffer: RemoteEvent,
	chooseOption: RemoteEvent,
	runState: RemoteEvent,
	visual: RemoteEvent,
}

local FOLDER_NAME = "Net"

-- The remotes, in creation order. Field name -> Instance name; the two are
-- deliberately different so a rename on one side is a type error.
local REMOTES: { { field: string, name: string } } = {
	{ field = "hud", name = "Hud" },
	{ field = "levelUpOffer", name = "LevelUpOffer" },
	{ field = "chooseOption", name = "ChooseOption" },
	{ field = "runState", name = "RunState" },
	{ field = "visual", name = "Visual" },
}

local Net = {}

-- Every remote's Instance name, for diagnostics and tests.
Net.names = table.freeze({ "Hud", "LevelUpOffer", "ChooseOption", "RunState", "Visual" })

local cached: Net? = nil

local function assemble(folder: Folder, remotes: { [string]: RemoteEvent }): Net
	return {
		folder = folder,
		hud = remotes.hud,
		levelUpOffer = remotes.levelUpOffer,
		chooseOption = remotes.chooseOption,
		runState = remotes.runState,
		visual = remotes.visual,
	}
end

-- Server side: creates the folder and every remote if they are not already
-- there, and returns them. Idempotent, so a second call (or a server script
-- that restarts) reuses what exists rather than duplicating it.
function Net.server(): Net
	if cached ~= nil then
		return cached
	end
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local folder: Folder
	if existing ~= nil and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	local remotes: { [string]: RemoteEvent } = {}
	for _, spec in REMOTES do
		local child = folder:FindFirstChild(spec.name)
		local remote: RemoteEvent
		if child ~= nil and child:IsA("RemoteEvent") then
			remote = child
		else
			remote = Instance.new("RemoteEvent")
			remote.Name = spec.name
			remote.Parent = folder
		end
		remotes[spec.field] = remote
	end
	local net = assemble(folder, remotes)
	cached = net
	return net
end

-- Client side: waits for what the server made. Yields, so it is never called
-- from anything on the simulation path.
function Net.client(): Net
	if cached ~= nil then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	local remotes: { [string]: RemoteEvent } = {}
	for _, spec in REMOTES do
		remotes[spec.field] = folder:WaitForChild(spec.name) :: RemoteEvent
	end
	local net = assemble(folder, remotes)
	cached = net
	return net
end

return Net
