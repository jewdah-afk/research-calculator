--!strict
-- Peckwood config. Set GROUP_ID to the Roblox group whose members get AUTO mode.
-- While it is 0, AUTO is granted to everyone in Studio playtests (so it can be tested) and to nobody live.
return {
	GROUP_ID = 0,
	-- user ids that see the dev panel (Regular / Maxed / Next island) in live servers; Studio always sees it
	DEV_USER_IDS = {} :: { number },
	DATASTORE = "Peckwood_v2",
}
