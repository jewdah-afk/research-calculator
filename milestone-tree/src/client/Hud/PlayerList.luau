--!strict
--[[
	PlayerList: the players in this server, top right (the Roblox player list is off, see App.engineSettings).

	    Chip    "PLAYERS · N" with a caret; a press (or Tab) opens / closes the list
	    Panel   a Sleek slab: the column heads NAME | POINTS | PLAYTIME, then a row per player sorted by points,
	            highest first (the local player's row lit). Points and playtime are the server's totals, published
	            on each Player every few seconds (Worker: MT_Pts the leaderboard-formatted points, MT_PtsKey their
	            sort key, MT_Played the real seconds played).

	    local list = PlayerList.new(root)
	    list:setOpen(b)   list:isOpen()   list.frame   list:destroy()
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Rich = require(Core:WaitForChild("Rich"))
local Sleek = require(Core:WaitForChild("Sleek"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Boards = require(game:GetService("ReplicatedStorage"):WaitForChild("MilestoneTree"):WaitForChild("Boards"))

export type PlayerList = {
	frame: Frame,
	setOpen: (self: PlayerList, b: boolean) -> (),
	isOpen: (self: PlayerList) -> boolean,
	destroy: (self: PlayerList) -> (),
}

local PlayerList = {}

local CYAN = Color3.fromHex("4fd1ff")
local function nameOf(p: Player): string
	local d = p.DisplayName
	return if type(d) == "string" and d ~= "" then d else p.Name
end
local function esc(t: string): string
	return (string.gsub(string.gsub(string.gsub(t, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end
local W = 460 -- the panel's width (du)
local ROW = 34

function PlayerList.new(root: GuiObject): PlayerList
	local self = {} :: PlayerList
	local conns: { RBXScriptConnection } = {}
	local open = false

	local f = Kit.frame(root, "PlayerList", 30)
	f.AnchorPoint = Vector2.new(1, 0)
	f.Size = UDim2.fromOffset(W, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	self.frame = f
	Kit.list(f, "y", 6, Enum.HorizontalAlignment.Right)

	-- the chip
	local chip = Kit.button(f, "Chip")
	chip.LayoutOrder = 1
	chip.AutoButtonColor = false
	chip.Size = UDim2.fromOffset(0, 32)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundTransparency = 1
	Sleek.plate(chip, { alpha = 0.88, line = 0.86, edge = false })
	Kit.pad(chip, 0, 12, 0, 12)
	local chipRow = Kit.frame(chip, "Row")
	chipRow.AutomaticSize = Enum.AutomaticSize.X
	chipRow.Size = UDim2.fromScale(0, 1)
	Kit.list(chipRow, "x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local chipLabel = Kit.label(chipRow, "Label", "caps", "", Color3.new(1, 1, 1))
	chipLabel.LayoutOrder = 1
	chipLabel.AutomaticSize = Enum.AutomaticSize.X
	chipLabel.Size = UDim2.fromScale(0, 1)
	chipLabel.RichText = true
	local caret = Kit.label(chipRow, "Caret", "caps", "▾", CYAN)
	caret.LayoutOrder = 2
	caret.AutomaticSize = Enum.AutomaticSize.X
	caret.Size = UDim2.fromScale(0, 1)

	-- room under the chip when the capsule's warning chip (SOFTCAP / OVERFLOW) reaches under the panel's corner
	local spacer = Kit.frame(f, "Spacer", 30)
	spacer.LayoutOrder = 2
	spacer.Size = UDim2.fromOffset(1, 0)
	spacer.Visible = false
	local extra = 0

	-- the panel
	local panel = Kit.frame(f, "Panel", 30)
	panel.LayoutOrder = 3
	panel.Size = UDim2.fromOffset(W, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	Sleek.plate(panel, { alpha = 0.92, line = 0.86 })
	Sleek.accent(panel, CYAN, 18, 60, { name = "Accent" })
	Kit.pad(panel, 10, 12, 10, 12)
	Kit.list(panel, "y", 2, Enum.HorizontalAlignment.Left)
	local heads = Kit.frame(panel, "Heads", 31)
	heads.LayoutOrder = 0
	heads.Size = UDim2.new(1, 0, 0, 22)
	local function col(parent: Instance, name: string, role: string, text: string, color: Color3, x: number, w: number,
		align: Enum.TextXAlignment): TextLabel
		local l = Kit.label(parent, name, role, text, color)
		l.Position = UDim2.new(x, 0, 0, 0)
		l.Size = UDim2.new(w, 0, 1, 0)
		l.TextXAlignment = align
		l.TextTruncate = Enum.TextTruncate.AtEnd
		return l
	end
	col(heads, "Name", "caps", Rich.caps("Player"), Theme.C.soft, 0, 0.38, Enum.TextXAlignment.Left)
	col(heads, "Points", "caps", Rich.caps("Points"), Theme.C.soft, 0.38, 0.4, Enum.TextXAlignment.Right)
	col(heads, "Played", "caps", Rich.caps("Playtime"), Theme.C.soft, 0.78, 0.22, Enum.TextXAlignment.Right)

	local me = Players.LocalPlayer
	local function draw()
		local list = Players:GetPlayers()
		chipLabel.Text = Rich.caps("Players") .. '  <font color="#4fd1ff">' .. #list .. "</font>"
		caret.Text = if open then "▴" else "▾"
		panel.Visible = open
		if not open then return end
		table.sort(list, function(a: Player, b: Player): boolean
			local ka, kb = tonumber(a:GetAttribute("MT_PtsKey")) or 0, tonumber(b:GetAttribute("MT_PtsKey")) or 0
			if ka ~= kb then return ka > kb end
			return nameOf(a) < nameOf(b)
		end)
		local keep: { [string]: boolean } = {}
		for i, p in list do
			local name = "Row_" .. p.UserId
			keep[name] = true
			local r = panel:FindFirstChild(name) :: Frame?
			if r == nil then
				local nr = Kit.frame(panel, name, 31)
				nr.Size = UDim2.new(1, 0, 0, ROW)
				nr.BackgroundColor3 = Theme.mix(Theme.C.deep, CYAN, 0.18)
				col(nr, "Name", "card", "", Color3.new(1, 1, 1), 0, 0.38, Enum.TextXAlignment.Left)
				col(nr, "Points", "numberHeavy", "", Theme.C.text, 0.38, 0.4, Enum.TextXAlignment.Right)
				col(nr, "Played", "label", "", Theme.C.soft, 0.78, 0.22, Enum.TextXAlignment.Right)
				r = nr
			end
			local row = r :: Frame
			row.LayoutOrder = i
			row.BackgroundTransparency = if p == me then 0.15 else 1
			local pts = p:GetAttribute("MT_Pts")
			local played = tonumber(p:GetAttribute("MT_Played"))
			local nl = row:FindFirstChild("Name") :: TextLabel
			local pl = row:FindFirstChild("Points") :: TextLabel
			local tl = row:FindFirstChild("Played") :: TextLabel
			local rank = if i <= 3 then ({ "#ffc93c", "#d7e0ea", "#e39a5b" })[i] else nil
			nl.RichText = true
			nl.Text = (if rank then '<font color="' .. rank .. '">' .. i .. "</font>  " else '<font color="#8a94a6">' .. i .. "</font>  ")
				.. esc(nameOf(p))
			pl.Text = if type(pts) == "string" then pts else "…"
			tl.Text = if played then Boards.duration(played) else "…"
		end
		for _, c in panel:GetChildren() do
			if string.sub(c.Name, 1, 4) == "Row_" and not keep[c.Name] then c:Destroy() end
		end
	end

	local function place()
		-- the top right of the top bar row
		f.Position = UDim2.new(1, -12, 0, 6)
	end
	-- while open, its area is a HUD rect (abs space): the toasts stack below it, plates and markers keep clear. Worked
	-- out from the list's own geometry (the chip, the heads, a row per player) so it holds before layout has run
	local function register()
		if not open then
			Layout.setRect("hud.players", nil)
			return
		end
		local s = math.max(Layout.s, 0.01)
		local rp, rs = root.AbsolutePosition, root.AbsoluteSize
		local left = rp.X + rs.X - (12 + W) * s
		-- on desktop the capsule's warning chip (SOFTCAP / OVERFLOW) reaches y 61 du beside the capsule: the panel
		-- always starts below that row (a fixed gap: the chip's width varies and is not laid out before it shows)
		local want = if Layout.mode == "COMPACT" then 0 else 26
		if want ~= extra then
			extra = want
			spacer.Size = UDim2.fromOffset(1, math.max(0, extra - 6))
			spacer.Visible = extra > 0
		end
		local h = 6 + 32 + 6 + extra + 20 + 22 + #Players:GetPlayers() * (ROW + 2)
		Layout.setRect("hud.players", { x = left, y = rp.Y, w = (12 + W) * s, h = h * s })
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(register)
	local rectsConn = Layout.rectsChanged:Connect(function()
		if open then register() end
	end)

	function self.setOpen(_: PlayerList, b: boolean)
		open = b
		draw()
		register()
	end
	function self.isOpen(_: PlayerList): boolean
		return open
	end

	chip.Activated:Connect(function() self:setOpen(not open) end)
	table.insert(conns, UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		if processed then return end
		if io.KeyCode == Enum.KeyCode.Tab then self:setOpen(not open) end
	end))
	local watched: { [Player]: { RBXScriptConnection } } = {}
	table.insert(conns, Players.PlayerAdded:Connect(function() task.defer(register) end))
	table.insert(conns, Players.PlayerRemoving:Connect(function() task.defer(register) end))
	local function watch(p: Player)
		local list = {}
		for _, a in { "MT_Pts", "MT_Played" } do
			table.insert(list, p:GetAttributeChangedSignal(a):Connect(function()
				if open then draw() end
			end))
		end
		watched[p] = list
		draw()
	end
	for _, p in Players:GetPlayers() do watch(p) end
	table.insert(conns, Players.PlayerAdded:Connect(watch))
	table.insert(conns, Players.PlayerRemoving:Connect(function(p: Player)
		local w = watched[p]
		if w then
			for _, c in w do c:Disconnect() end
		end
		watched[p] = nil
		task.defer(draw)
	end))
	local layoutConn = Layout.changed:Connect(place)
	function self.destroy(_: PlayerList)
		for _, c in conns do c:Disconnect() end
		layoutConn:Disconnect()
		rectsConn:Disconnect()
		Layout.setRect("hud.players", nil)
		for _, list in watched do
			for _, c in list do c:Disconnect() end
		end
		f:Destroy()
	end
	place()
	draw()
	return self
end

return PlayerList
