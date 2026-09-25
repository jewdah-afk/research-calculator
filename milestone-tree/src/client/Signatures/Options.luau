--!strict
--[[
	Options (DESIGN.md 6 row Options, 6.1 "Options"). Gear emblem, no hero.

	    YOUR SAVE     the game's "[ Saving ]" line becomes the section title with a "Saved with your game" tag; SAVE is
	                  a tile (the title, the game's one-line sub in a well); Offline Production keeps the toggle row.
	                  Saves live in Roblox (autosave), so there is no export, import or hard reset.
	    DISPLAY       "[ Displays ]" becomes the section title; the cyclers and toggles keep the Opt rows
	    ABOUT         the about node (Skins/Generic)
	    THIS DEVICE   "Not part of the save": Motion, Map detail, Map labels, Interface size as segmented controls,
	                  client-only through Prefs (one press)
	Every game option fires its node's own action; device options never reach the save.
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Prefs = require(Core:WaitForChild("Prefs"))
local PanelF = Client:WaitForChild("Panel")
local Skins = PanelF:WaitForChild("Skins")
local Common = require(Skins:WaitForChild("Common"))
local Generic = require(Skins:WaitForChild("Generic"))
local Sections = require(PanelF:WaitForChild("Sections"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local C = Theme.C

local HEADINGS: { [string]: { title: string, tag: string } } = {
	saving = { title = "YOUR SAVE", tag = "Saved with your game" },
	displays = { title = "DISPLAY", tag = "Saved with your game" },
}
local TILES: { [string]: boolean } = { save = true }

local DEVICE: { { key: string, title: string, sub: string, values: { any }, labels: { string } } } = {
	{ key = "motion", title = "Motion", sub = "Animations and effects", values = { "SYSTEM", "FULL", "REDUCED" },
		labels = { "System", "Full", "Reduced" } },
	{ key = "detail", title = "Map detail", sub = "Lower detail runs lighter", values = { "AUTO", "HIGH", "LOW" },
		labels = { "Auto", "High", "Low" } },
	{ key = "labels", title = "Map labels", sub = "Names under the map nodes", values = { "AUTO", "ALWAYS", "OFF" },
		labels = { "Auto", "Always", "Off" } },
	{ key = "size", title = "Interface size", sub = "Scales every panel and the HUD", values = { 90, 100, 115 },
		labels = { "90%", "100%", "115%" } },
}

-- a section title with its tag chip (sentence case)
local function heading(root: Instance, title: string, tag: string, hue: Color3, order: number?)
	Sections.header(root, { name = "SectionTitle", order = order, text = title, hue = hue,
		chips = { { text = tag, color = C.soft, bg = C.panel2, bgT = 0 } } })
	local h = root:FindFirstChild("SectionTitle")
	-- the tag is a sentence, not a count: small, soft
	local chip = if h then h:FindFirstChild("Chip1") else nil
	if chip and chip:IsA("TextLabel") then Common.text(chip, "small", C.soft) end
end

-- ------------------------------------------------------------------------------------------------------ tiles
local function tile(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local compact = ctx.mode == "COMPACT"
	b.Visible = true
	b.AutoButtonColor = false
	for _, name in { "Gradient", "Glow", "Num", "Limit", "Fill" } do Common.drop(b, name) end
	b.BackgroundColor3 = Theme.mix(C.panel, ctx.hue, 0.3)
	b.BackgroundTransparency = 0
	Common.corner(b, 16)
	Common.stroke(b, 1.5, Theme.lift(ctx.hue, 0.3), 0.1)
	b.Size = UDim2.fromOffset(if compact then math.floor((ctx.contentW - 20) / 3) else 220, if compact then 84 else 104)
	b.AutomaticSize = Enum.AutomaticSize.None
	Common.pad(b, 12, 10, 12, 10)
	Common.text(label, "card", C.text)
	label.Visible = true
	label.ZIndex = 3
	label.Size = UDim2.new(1, 0, 0, 30)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = false
	local stroke = Common.stroke(label, 2, C.black, 0, "Stroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local title = string.upper(Common.plain(Common.str(n.ti) or n.h or ""))
	title = string.gsub(title, " SAVE$", "")
	title = string.gsub(title, " A SAVE$", "")
	Common.setText(label, Common.esc(title))
	local sub = string.match(Common.str(n.h) or "", "<br%s*/?>(.*)$")
	local subText = Common.plain(sub or "")
	subText = string.gsub(string.gsub(subText, "^%s+", ""), "%s+$", "")
	if subText ~= "" and not compact then
		local well = Common.chip(label, "Sub", subText, { color = C.text, bg = C.black, bgT = 0.45, h = 26, role = "small" })
		well.AnchorPoint = Vector2.new(0.5, 0)
		well.Position = UDim2.new(0.5, 0, 1, 12)
		well.TextTruncate = Enum.TextTruncate.AtEnd
		local lim = Common.get(well, "Max", "UISizeConstraint") :: UISizeConstraint
		lim.MaxSize = Vector2.new(200, 26)
	else
		Common.drop(label, "Sub")
	end
	Common.state(b, "can")
	return true
end

-- ------------------------------------------------------------------------------------------------------ this device
local function device(root: Instance, ctx: any)
	local compact = ctx.mode == "COMPACT"
	local card = Kit.card(root, "Device", { order = 99, gap = 12, pad = 16 })
	heading(card, "THIS DEVICE", "Not part of the save", ctx.hue, 0)
	local prefs = Prefs.get() :: any
	for i, d in DEVICE do
		local row = Common.get(card, "Row" .. i, "Frame") :: Frame
		row.LayoutOrder = i
		row.Active = false
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		local t = Common.label(row, "Title", "small", C.soft)
		t.Size = UDim2.new(1, if compact then -250 else -360, 0, 0)
		Common.setText(t, Common.title(d.title, "cardSmall", C.text) .. "\n" .. Common.esc(d.sub))
		local seg = Common.get(row, "Seg", "Frame") :: Frame
		seg.Active = false
		seg.AnchorPoint = Vector2.new(1, 0)
		seg.Position = UDim2.new(1, 0, 0, 0)
		seg.Size = UDim2.fromOffset(if compact then 240 else 340, 38)
		seg.BackgroundColor3 = C.deep
		seg.BackgroundTransparency = 0
		Common.corner(seg, 10)
		Common.list(seg, true, 4, { valign = Enum.VerticalAlignment.Center, align = Enum.HorizontalAlignment.Center })
		for j, v in d.values do
			local on = prefs[d.key] == v
			local b = Kit.button(seg, "O" .. j, Common.esc(d.labels[j]), { fill = if on then Theme.mix(C.panel, ctx.hue, 0.6) else C.panel2,
				ink = if on then C.text else C.soft, h = 32, w = if compact then 76 else 108, order = j, radius = 8 })
			b.FontFace = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold, if on then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
			Common.state(b, if on then "owned" else "can")
			local key, value = d.key, v
			Kit.onPress(b, function()
				Prefs.set(key, value)
				device(root, ctx)
			end)
		end
	end
end

-- ------------------------------------------------------------------------------------------------------ the skin
local function skin(rec: any, n: any, ctx: any): boolean
	-- the game's "[ Saving ]" / "[ Displays ]" lines become section titles
	if n.t == "html" and rec.kind == "html" then
		local plain = Common.plain(n.h)
		local word = string.match(plain, "^%s*%[%s*(%a+)%s*%]%s*$")
		local head = if word then HEADINGS[string.lower(word)] else nil
		if head then
			local root = rec.root :: Frame
			root.Visible = true
			root.BackgroundTransparency = 1
			root.Size = UDim2.new(1, 0, 0, 0)
			root.AutomaticSize = Enum.AutomaticSize.Y
			Common.drop(root, "Pad")
			local text = root:FindFirstChild("Text")
			if text and text:IsA("GuiObject") then text.Visible = false end
			heading(root, head.title, head.tag, ctx.hue)
			return true
		end
		return false
	end
	if rec.kind == "btn:opt" then
		if TILES[n.id or ""] then return tile(rec, n, ctx) end
		return false
	end
	-- the tab root: the device options come last
	if rec.id == "tab" and (n.t == "col" or n.t == "row") then
		Generic.skin(rec, n, ctx)
		device(rec.root, ctx)
		return true
	end
	return false
end

-- the gear emblem's accent: a quiet system-violet glow in the header
local function accent(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	local a = Kit.accent(band, "Options")
	Kit.watermark(a, "⚙", Theme.lift(ctx.hue, 0.3), 0.08)
end

return {
	layers = { "options-tab" },
	skin = skin,
	accent = accent,
}
