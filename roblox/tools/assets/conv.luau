local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local path = require("@lune/process").args[1]
local insts = roblox.deserializeModel(fs.readFile(path))
fs.writeFile(path, roblox.serializeModel(insts))
print("ok", #insts, insts[1].Name)
