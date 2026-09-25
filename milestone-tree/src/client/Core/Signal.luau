--!strict
--[[
	Signal: a small synchronous event. Connect / Once / Fire / DisconnectAll. Handlers run in connection order on the
	firing thread (the map's camera listeners rely on that: plan 2.3), over a snapshot, so a handler may connect or
	disconnect others. Pure Luau (no Roblox services).
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	type Slot = { fn: (T...) -> (), conn: Connection }
	local slots: { Slot } = {}
	local self = {} :: Signal<T...>

	local function remove(conn: Connection)
		for i, s in slots do
			if s.conn == conn then
				table.remove(slots, i)
				break
			end
		end
	end
	local function add(fn: (T...) -> ()): Connection
		local conn = {} :: Connection
		conn.Connected = true
		function conn.Disconnect(c: Connection)
			if c.Connected then
				c.Connected = false
				remove(c)
			end
		end
		table.insert(slots, { fn = fn, conn = conn })
		return conn
	end

	function self.Connect(_: Signal<T...>, fn: (T...) -> ()): Connection
		return add(fn)
	end
	function self.Once(_: Signal<T...>, fn: (T...) -> ()): Connection
		local conn: Connection
		conn = add(function(...: T...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end
	function self.Fire(_: Signal<T...>, ...: T...)
		for _, s in table.clone(slots) do
			if s.conn.Connected then s.fn(...) end
		end
	end
	function self.DisconnectAll(_: Signal<T...>)
		for _, s in slots do s.conn.Connected = false end
		table.clear(slots)
	end
	return self
end

return Signal
