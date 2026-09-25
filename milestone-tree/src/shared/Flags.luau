--!strict
--[[
	Flags: switches for engine features that exist in the API but are not live for players yet, and for our own
	features until their approval gate (docs/MASTER_PLAN.md). Everything defaults OFF, so the shipped game is always
	the tested path.

	    BETA_GRADIENTS   UIGradient Type Radial / Conical, TileMode and Scale are a Studio-only beta (since
	                     2026-09-02; docs/roblox-knowledge/ui-tech.md): the enums are in the API, so a probe passes,
	                     but published games don't draw them. Off, every radial/conical look uses its fallback, so
	                     Studio shows what players see. Turn on once Roblox ships the feature to live games.
	    REALM3D          the 2.5D realm in Workspace (W2) instead of the 2D map; gate G2
	    GLASS            the crystal Glass slab behind open panels (W3.3)
	    LIVE_PROC        live EditableImage / EditableMesh generators (the sky, rift, tree); off, the bakes show
	    WEATHER          weather on resets (W4)
]]
return {
	BETA_GRADIENTS = false,
	REALM3D = false,
	GLASS = false,
	LIVE_PROC = false,
	WEATHER = false,
}
