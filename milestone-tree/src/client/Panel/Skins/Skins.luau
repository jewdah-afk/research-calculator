--!strict
--[[
	Skins: the dispatcher Render's skin hook calls for every node of the panel's tab tree (plan 2.5).

	    Skins.apply(rec, n, ctx) -> boolean   true when a skin drew the node (Render then skips the old page look)

	Order: the layer's signature skin first (true = handled), then the card skins by kind, then Generic. Every skin is
	idempotent and writes the State attribute on cards (can / owned / notyet / locked).
]]

local Generic = require(script.Parent:WaitForChild("Generic"))
local Upgrade = require(script.Parent:WaitForChild("Upgrade"))
local Buyable = require(script.Parent:WaitForChild("Buyable"))
local Milestone = require(script.Parent:WaitForChild("Milestone"))
local Challenge = require(script.Parent:WaitForChild("Challenge"))
local Achievement = require(script.Parent:WaitForChild("Achievement"))
local GridTile = require(script.Parent:WaitForChild("GridTile"))
local Clickable = require(script.Parent:WaitForChild("Clickable"))
local Perk = require(script.Parent:WaitForChild("Perk"))
local Opt = require(script.Parent:WaitForChild("Opt"))

local Skins = {}

local BY_KIND: { [string]: (rec: any, n: any, ctx: any) -> boolean } = {
	["btn:upg"] = Upgrade.skin,
	["btn:buy"] = Buyable.skin,
	["btn:grid"] = GridTile.skin,
	["btn:click"] = Clickable.skin,
	["btn:perk"] = Perk.skin,
	["btn:opt"] = Opt.skin,
	["btn:chalbtn"] = Challenge.button,
	ms = Milestone.skin,
	chal = Challenge.skin,
	ach = Achievement.skin,
}

function Skins.apply(rec: any, n: any, ctx: any): boolean
	if ctx == nil then return false end
	local sig = ctx.signature
	if sig and sig.skin then
		local ok, handled = pcall(sig.skin, rec, n, ctx)
		if ok and handled then return true end
		if not ok then warn("[MilestoneTree] signature skin failed on " .. tostring(rec.id) .. ": " .. tostring(handled)) end
	end
	local f = BY_KIND[rec.kind]
	if f and f(rec, n, ctx) then return true end
	return Generic.skin(rec, n, ctx)
end

return Skins
