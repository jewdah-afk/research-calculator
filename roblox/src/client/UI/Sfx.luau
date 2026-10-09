--!nonstrict
-- Sfx: the one place UI sounds are triggered from. Every key press calls Sfx.press() (owner: "buttery keycap on
-- every press"). Today it plays Kit.sfx's keyboard slice; when the synthesized keycap kit (roblox/assets/sfx/*.ogg)
-- is uploaded, put the ids in Kit.luau KIT_IDS and every caller picks them up with no other change.
local Kit = require(script.Parent.Kit)

local Sfx = {}

function Sfx.press() Kit.sfx("click") end      -- key down: the buttery keycap
function Sfx.release() end                      -- key up: softer tick (hook; no asset yet)
function Sfx.hover() Kit.sfx("hover") end
function Sfx.tab() Kit.sfx("click") end
function Sfx.open() Kit.sfx("open") end
function Sfx.close() Kit.sfx("close") end
function Sfx.buy() Kit.sfx("thock") end
function Sfx.deny() Kit.sfx("nope") end

return Sfx
