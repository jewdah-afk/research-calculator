--[ Variables ]--
local Systems = {
	Runes = require(script.Runes);
	Elixirs = require(script.Elixirs);
	Tickets = require(script.Tickets);
	Donations = require(script.Donations);
	Buttons = require(script.Buttons);
	Codes = require(script.Codes);
	Gamepasses = require(script.Gamepasses);
	RTokens = require(script.RTokens);
	Products = require(script.Products);
	Gifting = require(script.Gifting);
	Stats = require(script.Stats);
	--WaterButtons = require(script.WaterButtonsCilent);
}

--[ Main ]--
local Store = {}

function Store.init()
	Systems.Runes.init()
	Systems.Elixirs.init()
	Systems.Tickets.init()
	Systems.Donations.init()
	Systems.Buttons.init()
	Systems.Codes.init()
	Systems.Gamepasses.init()
	Systems.RTokens.init()
	Systems.Products.init()
	Systems.Gifting.init()
	Systems.Stats.init()
	--Systems.WaterButtons.init()
end

return Store