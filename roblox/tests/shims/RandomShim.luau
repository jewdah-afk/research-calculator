local Random = {}; Random.__index = Random
function Random.new() return setmetatable({}, Random) end
function Random:NextNumber() return math.random() end
return Random
