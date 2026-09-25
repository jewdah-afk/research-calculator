--!strict
--[[
	Hotkeys: the keyboard (plan 2.7, DESIGN.md 3.4).

	    the game's own hotkeys   a key whose name is in patch.keys is sent as {"key", name} (the only action the
	                             client builds itself, plan 1.11); names follow the web page: "m", "M" (Shift),
	                             "ctrl+e", "ArrowUp", "Enter", " ", "Tab", digits
	    - / =                    one map zoom notch, unless the game uses the key
	    Esc                      closes the top thing: the modal, the peek, the detail sheet, then the panel

	    local hk = Hotkeys.start(o)    o = { active, keys, send, zoom, escape } (functions, see Opts)
	    Hotkeys.keyName(io) -> string?

	Nothing is sent while a TextBox has focus. Except for Esc, input the engine already used is ignored.
]]

local UserInputService = game:GetService("UserInputService")

local Hotkeys = {}

export type Opts = {
	active: () -> boolean, -- false while something else owns the keyboard
	keys: () -> { [string]: true }, -- the game's hotkeys right now (ViewStore.keys)
	send: (name: string) -> (),
	zoom: (dir: number) -> (),
	escape: () -> (),
}
export type Handle = { disconnect: (self: Handle) -> () }

local NAMED: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Up] = "ArrowUp",
	[Enum.KeyCode.Down] = "ArrowDown",
	[Enum.KeyCode.Left] = "ArrowLeft",
	[Enum.KeyCode.Right] = "ArrowRight",
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.Space] = " ",
	[Enum.KeyCode.Tab] = "Tab",
	[Enum.KeyCode.Minus] = "-",
	[Enum.KeyCode.Equals] = "=",
}
local ZOOM: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Minus] = -1,
	[Enum.KeyCode.KeypadMinus] = -1,
	[Enum.KeyCode.Equals] = 1,
	[Enum.KeyCode.KeypadPlus] = 1,
}

local function down(a: Enum.KeyCode, b: Enum.KeyCode): boolean
	return UserInputService:IsKeyDown(a) or UserInputService:IsKeyDown(b)
end

-- the web page's key name for a key press (the old client's rule): letters (upper case with Shift), digits, the
-- named keys above; Ctrl adds "ctrl+"
function Hotkeys.keyName(io: InputObject): string?
	local kc = io.KeyCode
	local name = NAMED[kc]
	if name == nil then
		local v = kc.Value
		if v >= Enum.KeyCode.A.Value and v <= Enum.KeyCode.Z.Value then
			local s = string.char(97 + v - Enum.KeyCode.A.Value)
			if down(Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift) then s = string.upper(s) end
			name = s
		elseif v >= Enum.KeyCode.Zero.Value and v <= Enum.KeyCode.Nine.Value then
			name = tostring(v - Enum.KeyCode.Zero.Value)
		end
	end
	if name == nil then return nil end
	if down(Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl) then return "ctrl+" .. name end
	return name
end

function Hotkeys.start(o: Opts): Handle
	local conn = UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		if io.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if not o.active() then return end
		if UserInputService:GetFocusedTextBox() then return end
		if io.KeyCode == Enum.KeyCode.Escape then
			o.escape()
			return
		end
		if processed then return end
		local name = Hotkeys.keyName(io)
		local keys = o.keys()
		if name and keys[name] then
			o.send(name)
			return
		end
		local dir = ZOOM[io.KeyCode]
		if dir and not down(Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl) then o.zoom(dir) end
	end)
	local handle = {} :: Handle
	function handle.disconnect(_: Handle)
		conn:Disconnect()
	end
	return handle
end

return Hotkeys
