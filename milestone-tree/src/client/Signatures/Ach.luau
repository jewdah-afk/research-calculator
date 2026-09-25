--!strict
--[[
	Ach: Achievements (DESIGN.md 6 row ach). No CTA.

	    TROPHY SHELF   the count "13 / 18" (Sarpanch 64 gold, the game's own highlighted count) and its effect line,
	                   then 2 shelves of medallions on plank frames: done = gold medallion with its number and a glint
	                   that crosses one of them every 3 s; not yet = slate "?"
	    inspector      a tap (or hover) shows the medallion's name and its goal / reward (the game's tooltip) with a
	                   DONE / NOT YET chip
	The count line leaves the body (the shelf shows it).
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Layout = require(Core:WaitForChild("Layout"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Sections = require(PanelF:WaitForChild("Sections"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local C = Theme.C
local GOLD = Theme.hue("ach")

local function countLine(h: any): boolean
	return type(h) == "string" and string.find(h, "<h2", 1, true) ~= nil and string.find(h, "completed", 1, true) ~= nil
end

local selected: string? = nil -- the inspected achievement id, for the session

local function shelf(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	local glint: any = nil
	ph.Size = UDim2.new(1, 0, 0, 0)
	ph.AutomaticSize = Enum.AutomaticSize.Y
	Common.list(ph, false, 14)
	local draw: (st: any) -> () = nil :: any
	draw = function(st: any)
		store = st or store
		local compact = Layout.mode == "COMPACT"
		local ids = Kit.findAll(st, id, function(n: any): boolean
			return n.t == "ach"
		end, 3)
		local done = 0
		for _, aid in ids do
			if st:get(aid).done then done += 1 end
		end
		-- the game's count and effect line
		local lid = Kit.find(st, "tab", function(n: any): boolean
			return n.cn == "display-text" and countLine(n.h)
		end, 4)
		local line = if lid then st:get(lid).h else nil
		local count = if line then Kit.h2(line)[1] else nil
		count = count or (done .. " / " .. #ids)
		count = string.gsub(count :: string, "%s*/%s*", " / ")
		Sections.header(ph, { name = "Head", order = 0, text = "TROPHY SHELF", hue = GOLD,
			chips = { { text = done .. " / " .. #ids, color = C.ink, bg = GOLD, bgT = 0 } } })
		local top = Common.get(ph, "Count", "Frame") :: Frame
		top.LayoutOrder = 1
		top.Active = false
		top.Size = UDim2.new(1, 0, 0, 0)
		top.AutomaticSize = Enum.AutomaticSize.Y
		Common.list(top, true, 18, { valign = Enum.VerticalAlignment.Center })
		local big = Common.get(top, "Big", "TextLabel") :: TextLabel
		big.LayoutOrder = 1
		big.AutomaticSize = Enum.AutomaticSize.X
		big.Size = UDim2.fromOffset(0, if compact then 44 else 72)
		local sig = tostring(count) .. "|" .. tostring(compact)
		if big:GetAttribute("Sig") ~= sig then
			big:SetAttribute("Sig", sig)
			Recipes.number(big, { text = count :: string, size = if compact then 38 else 64, from = C.white, mid = Theme.lift(GOLD, 0.35), to = GOLD,
				stroke = if compact then 5 else 7, shadow = if compact then 3 else 5, role = "hero" })
		end
		local eff = Common.label(top, "Effect", "body", C.text, { order = 2 })
		eff.Size = UDim2.new(1, if compact then -130 else -220, 0, 0)
		local effText = ""
		if line then
			local rest = string.match(line, "</h2>(.*)$") or ""
			effText = Common.html(rest, "body", ctx.layer)
		end
		Common.setText(eff, effText)
		-- the shelves: 2 planks of up to 9 medallions (wrapping on phones)
		local per = math.max(1, math.ceil(#ids / 2))
		local size = if compact then 48 else 64
		local used: { [string]: boolean } = { Head = true, Count = true, List = true }
		local firstDone: TextButton? = nil
		for s = 1, 2 do
			local name = "Shelf" .. s
			local lo, hi = (s - 1) * per + 1, math.min(#ids, s * per)
			if lo > hi then
				Common.drop(ph, name)
				continue
			end
			used[name] = true
			local plank = Common.get(ph, name, "Frame") :: Frame
			plank.LayoutOrder = 1 + s
			plank.Active = false
			plank.Size = UDim2.new(1, 0, 0, 0)
			plank.AutomaticSize = Enum.AutomaticSize.Y
			plank.BackgroundColor3 = Color3.fromRGB(58, 40, 22)
			plank.BackgroundTransparency = 0.35
			Common.corner(plank, 10)
			Common.pad(plank, 12, 12, 16, 12)
			Common.list(plank, true, if compact then 8 else 14, { wraps = true, align = Enum.HorizontalAlignment.Center })
			local mine: { [string]: boolean } = { List = true, Pad = true, Corner = true }
			for i = lo, hi do
				local aid = ids[i]
				local n = st:get(aid)
				local key = "A" .. tostring(n.id)
				mine[key] = true
				local b = Common.get(plank, key, "TextButton") :: TextButton
				b.LayoutOrder = i
				b.AutoButtonColor = false
				b.Size = UDim2.fromOffset(size, size)
				Common.corner(b, 0.5)
				local isDone = n.done == true
				local sel = selected == tostring(n.id)
				if isDone then
					b.BackgroundColor3 = GOLD
					Common.stroke(b, if sel then 3 else 2, if sel then C.white else Theme.lift(GOLD, 0.5), 0)
					Common.text(b, "badge", C.ink)
					Common.setText(b, tostring(n.num or i))
					if firstDone == nil then firstDone = b end
				else
					b.BackgroundColor3 = C.panel3
					Common.stroke(b, if sel then 3 else 1.5, if sel then GOLD else C.strokeHi, if sel then 0 else 0.3)
					Common.text(b, "label", C.soft)
					Common.setText(b, "?")
				end
				b.BackgroundTransparency = 0
				b.TextXAlignment = Enum.TextXAlignment.Center
				b.TextYAlignment = Enum.TextYAlignment.Center
				Common.state(b, if isDone then "owned" else "locked")
				local aKey = tostring(n.id)
				local function pick()
					if selected ~= aKey then
						selected = aKey
						draw(store)
					end
				end
				Kit.onPress(b, pick)
				if b:GetAttribute("Hover") ~= true then
					b:SetAttribute("Hover", true)
					b.MouseEnter:Connect(pick)
				end
			end
			for _, c in plank:GetChildren() do
				if c:IsA("GuiObject") and not mine[c.Name] then c:Destroy() end
			end
		end
		-- the glint: one done medallion catches the light every 3 s
		if firstDone and glint == nil then
			glint = Recipes.shine(firstDone, { every = 3, dur = 0.8 })
		elseif firstDone == nil and glint then
			glint:stop()
			glint = nil
		end
		-- the inspector strip
		used.Inspect = true
		local strip = Kit.card(ph, "Inspect", { order = 4, gap = 6, pad = 14, fill = Theme.mix(C.panel, GOLD, 0.08), stroke = GOLD, strokeT = 0.5 })
		local pickN: any = nil
		for _, aid in ids do
			local n = st:get(aid)
			if tostring(n.id) == selected then pickN = n end
		end
		local text = Common.label(strip, "Text", "body", C.text, { order = 1 })
		if pickN then
			local state = if pickN.done then Common.caps("Done", C.ownedValue) else Common.caps("Not yet", C.soft)
			Common.setText(text, Common.title(Common.plain(Common.str(pickN.ti) or ""), "card", C.text) .. "   " .. state .. "\n"
				.. Common.html(pickN.tip, "body", ctx.layer))
		else
			Common.setText(text, Common.run(Common.esc("Tap a medallion to see its goal."), "small", C.soft))
		end
		for _, c in ph:GetChildren() do
			if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
		end
	end
	function claim.update(_: any, st: any)
		draw(st)
	end
	function claim.destroy(_: any)
		if glint then
			glint:stop()
			glint = nil
		end
		for _, c in ph:GetChildren() do c:Destroy() end
	end
	return claim
end

-- the count line leaves the body; other lines stay notes
local function note(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	function claim.update(_: any, st: any)
		local n = st:get(id)
		local h = if type(n) == "table" then n.h else nil
		if countLine(h) or not string.find(Common.plain(h), "%S") then
			ph.Visible = false
			ph.Size = UDim2.new()
			ph.AutomaticSize = Enum.AutomaticSize.None
			Common.drop(ph, "Text")
			return
		end
		ph.Visible = true
		ph.Size = UDim2.new(1, 0, 0, 0)
		ph.AutomaticSize = Enum.AutomaticSize.Y
		ph.BackgroundColor3 = C.panel2
		ph.BackgroundTransparency = 0
		Common.corner(ph, 10)
		Common.pad(ph, 10, 14, 10, 16)
		local l = Common.label(ph, "Text", "body", C.text)
		Common.setText(l, Common.html(h, "body", ctx.layer))
	end
	function claim.destroy(_: any)
		Common.drop(ph, "Text")
	end
	return claim
end

-- a gold shrine: a warm glow behind the header
local function accent(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	local a = Kit.accent(band, "Ach")
	a.ClipsDescendants = true
	local blob = Common.blob(a, "Shrine", GOLD, 0.3)
	if blob then
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.new(0.5, 0, 0, 10)
		blob.Size = UDim2.fromOffset(700, 200)
	end
end

return {
	layers = { "ach" },
	accent = accent,
	claims = ({
		{ match = { cn = "achievements" }, make = shelf },
		{ match = { cn = "display-text" }, make = note },
	} :: { any }),
}
