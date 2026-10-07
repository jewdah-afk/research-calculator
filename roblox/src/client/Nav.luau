--!strict
-- Nav: "Go to ..." travel. Main.client sets the handler (it owns the bird body); windows call Nav.go(islandId).
local Nav = {}
Nav.handler = nil :: ((string) -> boolean)?
function Nav.go(id: any): boolean
	if typeof(id) ~= "string" or not Nav.handler then return false end
	return (Nav.handler :: (string) -> boolean)(id)
end
return Nav
