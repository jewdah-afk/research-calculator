local Framework = require(game.ReplicatedStorage.Framework)
local RichText = Framework:GetLibrary("RichText")

local Messages = {}




return Messages


--[ DOCUMENTATION ]--

--[ TAGS ]--
-- :Bold() -- Makes the text bold
-- :Colored(Color3.fromRGB()) -- Colors the text
-- :Uppercase() -- MAKES THE TEXT BIG
-- :SmallCaps() -- Uppercase but tinier
-- :ClearFormat() -- Removes all the color / bold / etc.
-- :StrikeThrough() -- Strikes through the text with ------
-- :Transparency(number) -- Sets the visibility of the text (from 0 to 1)
-- More tags later when v1.0 Framework releases


--[ SIMPLE TEXT TUTORIALS ]--

--[[ SINGLE-COLORED TEXT

local Message = RichText("Test")
Message:Colored(Color3.fromRGB(115, 255, 115))
table.insert(Messages, Message:Return())

]]

--[[ SINGLE-COLORED TEXT w/ BOLD

local Message = RichText("Test")
Message:Colored(Color3.fromRGB(115, 255, 115))
Message:Bold()
table.insert(Messages, Message:Return())

]]

--[[ TEXT w/ Transparency

local Message = RichText("Test")
Message:Transparency(0.5)
table.insert(Messages, Message:Return())

]]

