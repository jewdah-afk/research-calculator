--!strict
--[[
	Flags: switches for engine features that exist in the API but are not live for players yet.

	    BETA_GRADIENTS   UIGradient Type Radial / Conical, TileMode and Scale are a Studio-only beta (since
	                     2026-09-02; docs/roblox-knowledge/ui-tech.md): the enums are in the API, so a probe passes,
	                     but published games don't draw them. Off, every radial/conical look uses its fallback, so
	                     Studio shows what players see. Turn on once Roblox ships the feature to live games.
]]
return {
	BETA_GRADIENTS = false,
}
