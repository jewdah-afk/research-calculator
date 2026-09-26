--!strict
--[[
	Products: the game passes and developer products, one table for the server (ownership, receipts, perks) and the
	client (the Shop). The ids (and the icon image ids) are filled by port/tools/products.js once they exist on Roblox
	(Open Cloud), or by hand from the Creator Dashboard (Monetization > Passes / Developer Products). An item without
	an id shows as "Coming soon" and cannot be bought.

	Passes (one-time):
	    speed      2x Speed      the whole game runs twice as fast (the game's own devSpeed: every second counts as 2)
	    supporter  Supporter     a gold SUPPORTER tag on the points bar and a gold rim; a thank-you
	Products (consumable):
	    warp1 / warp8 / warp24   Time Warp: 1, 8 or 24 hours of progress at once (fed through the next ticks the way
	                             the game catches up offline time)
]]

export type Pass = { key: string, id: number?, name: string, price: number, blurb: string, icon: number?, speed: number? }
export type Product = { key: string, id: number?, name: string, price: number, blurb: string, icon: number?, warp: number? }

local Products = {}

Products.passes = {
	{ key = "speed", id = 1998278588, icon = 124365077861444, name = "2x Speed", price = 399, speed = 2,
		blurb = "The whole game runs twice as fast, forever. Offline time and Time Warps count double too." },
	{ key = "supporter", id = 1998128578, icon = 99548373984898, name = "Supporter", price = 99,
		blurb = "A gold SUPPORTER tag on your points bar and a gold rim. Thank you for supporting the game!" },
} :: { Pass }

Products.products = {
	{ key = "warp1", id = 3714803203, icon = 134852138466837, name = "Time Warp · 1 hour", price = 29, warp = 3600,
		blurb = "1 hour of progress, right now." },
	{ key = "warp8", id = 3714803208, icon = 110877194725457, name = "Time Warp · 8 hours", price = 149, warp = 8 * 3600,
		blurb = "8 hours of progress, right now." },
	{ key = "warp24", id = 3714803211, icon = 118614298139912, name = "Time Warp · 24 hours", price = 349, warp = 24 * 3600,
		blurb = "A whole day of progress, right now." },
} :: { Product }

function Products.pass(key: string): Pass?
	for _, p in Products.passes do
		if p.key == key then return p end
	end
	return nil
end
function Products.passById(id: number): Pass?
	for _, p in Products.passes do
		if p.id == id then return p end
	end
	return nil
end
function Products.productById(id: number): Product?
	for _, p in Products.products do
		if p.id == id then return p end
	end
	return nil
end

return Products
