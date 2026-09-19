--!strict
-- Studio diagnostic: proves string-path requires resolve in this place.
-- Command bar:  print(require(game.ReplicatedStorage.Shared.RequireProbe))
-- Expected:     10   (Whip base damage, reached through a string require)
-- If this errors, run tools/convert_requires.py on a copy of src/ instead.
local Weapons = require("./Data/Weapons")
return Weapons.data.whip.baseDamage
