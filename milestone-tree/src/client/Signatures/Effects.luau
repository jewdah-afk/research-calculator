--!strict
--[[
	Effects: Exotic Prestige and Prestiged-Exotic (DESIGN.md 6 rows ep and pep).

	    EFFECT LADDER   the game's "1st effect: …" lines (its <br> lines, as sent) as rungs in milestone-row style: the
	                    ordinal in a pill, the effect text; a line in class 'ef' / 'pef' gets a gold EMPOWERED chip. No
	                    rung is invented: the ladder has exactly the lines the game sends.
	    accent          ep: acid-green header stripes; pep: an amber fusion-core ring around the emblem
	The rest (the Fusioner buyable, the upgrades board) keeps the template (P.skin: Hide owned).
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Motion = require(Core:WaitForChild("Motion"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Sections = require(PanelF:WaitForChild("Sections"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P

local C = Theme.C

local function isLadder(h: string): boolean
	return string.find(h, "1st effect", 1, true) ~= nil
end

local function trim(s: string): string
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end

local function ladder(ph: Frame, id: string, store: any, ctx: any): any
	local claim = {}
	local lastCount = 0
	function claim.update(_: any, st: any)
		local n = st:get(id)
		local h = if type(n) == "table" and type(n.h) == "string" then n.h else ""
		if not isLadder(h) then
			-- another line: a NOTES row
			for _, c in ph:GetChildren() do
				if c.Name ~= "Text" then c:Destroy() end
			end
			ph.Visible = string.find(Common.plain(h), "%S") ~= nil
			ph.Size = UDim2.new(1, 0, 0, 0)
			ph.AutomaticSize = Enum.AutomaticSize.Y
			ph.BackgroundColor3 = C.panel2
			ph.BackgroundTransparency = 0
			Common.corner(ph, 10)
			Common.pad(ph, 10, 14, 10, 16)
			local l = Common.label(ph, "Text", "body", C.text)
			Common.setText(l, Common.html(h, "body", ctx.layer))
			return
		end
		Common.drop(ph, "Text")
		Common.drop(ph, "Pad")
		Common.drop(ph, "Corner")
		ph.Visible = true
		ph.BackgroundTransparency = 1
		ph.Size = UDim2.new(1, 0, 0, 0)
		ph.AutomaticSize = Enum.AutomaticSize.Y
		Common.list(ph, false, 10)
		local compact = Layout.mode == "COMPACT"
		local hue = ctx.hue :: Color3
		local lines = string.split((string.gsub(h, "<br%s*/?>", "\0")), "\0")
		local rungs: { { ord: string, text: string, ef: boolean } } = {}
		for _, part in lines do
			local plain = trim(Common.plain(part))
			if plain == "" then continue end
			local ord, rest = string.match(plain, "^(%d+%a%a)%s+effect:%s*(.*)$")
			table.insert(rungs, { ord = ord or tostring(#rungs + 1), text = rest or plain,
				ef = string.find(part, "class=[\"']p?ef[\"']") ~= nil })
		end
		local empowered = 0
		for _, r in rungs do
			if r.ef then empowered += 1 end
		end
		local chips: { any } = { { text = #rungs .. " effects", color = C.text, bg = C.panel3, bgT = 0 } }
		if empowered > 0 then table.insert(chips, { text = empowered .. " empowered", color = C.ink, bg = C.gold, bgT = 0 }) end
		Sections.header(ph, { name = "Head", order = 0, text = "EFFECT LADDER", hue = hue, chips = chips })
		local used: { [string]: boolean } = { Head = true }
		for i, r in rungs do
			local name = "R" .. i
			used[name] = true
			local c = Common.get(ph, name, "TextLabel") :: TextLabel
			c.LayoutOrder = i
			c.Active = false
			Common.text(c, "body", C.text)
			c.TextWrapped = true
			c.TextXAlignment = Enum.TextXAlignment.Left
			c.TextYAlignment = Enum.TextYAlignment.Center
			c.Size = UDim2.new(1, 0, 0, 0)
			c.AutomaticSize = Enum.AutomaticSize.Y
			c.BackgroundColor3 = if r.ef then Theme.mix(C.panel, C.gold, 0.12) else Theme.mix(C.panel, hue, 0.1)
			c.BackgroundTransparency = 0
			Common.corner(c, 12)
			Common.stroke(c, if r.ef then 1.5 else 1, if r.ef then C.gold else Theme.lift(hue, 0.2), if r.ef then 0.2 else 0.55)
			local padL = if compact then 64 else 76
			Common.pad(c, 11, if r.ef and not compact then 150 else 14, 11, padL)
			Common.setText(c, Common.esc(r.text))
			local pill = Common.get(c, "Pill", "TextLabel") :: TextLabel
			pill.Active = false
			Common.text(pill, "label", C.ink)
			pill.AnchorPoint = Vector2.new(0, 0.5)
			pill.Position = UDim2.new(0, -padL + 12, 0.5, 0)
			pill.Size = UDim2.fromOffset(if compact then 42 else 50, 28)
			pill.TextXAlignment = Enum.TextXAlignment.Center
			pill.TextYAlignment = Enum.TextYAlignment.Center
			pill.BackgroundColor3 = if r.ef then C.gold else Theme.lift(hue, 0.25)
			pill.BackgroundTransparency = 0
			Common.corner(pill, 14)
			Common.setText(pill, r.ord)
			if r.ef and not compact then
				local chip = Common.chip(c, "Empowered", "EMPOWERED", { color = C.ink, bg = C.gold, bgT = 0, h = 26 })
				chip.AnchorPoint = Vector2.new(1, 0.5)
				chip.Position = UDim2.new(1, 140, 0.5, 0)
			else
				Common.drop(c, "Empowered")
			end
			Common.state(c, if r.ef then "owned" else "can")
		end
		for _, c in ph:GetChildren() do
			if c:IsA("GuiObject") and not used[c.Name] then c:Destroy() end
		end
		-- a new rung lights up (never on first sight)
		if #rungs > lastCount and lastCount > 0 then
			local c = ph:FindFirstChild("R" .. #rungs) :: GuiObject?
			if c then Motion.flash(c) end
		end
		lastCount = #rungs
	end
	function claim.destroy(_: any)
		for _, c in ph:GetChildren() do c:Destroy() end
	end
	return claim
end

-- ep: acid-green stripes
local function stripes(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	Kit.stripes(Kit.accent(band, "Ep"), Theme.lift(ctx.hue, 0.25), 0.06, 22)
end

-- pep: the fusion core, an amber ring around the emblem that turns slowly
local function core(sheet: Frame, ctx: any)
	local emblem = sheet:FindFirstChild("Emblem") :: GuiObject?
	if emblem == nil or Layout.mode == "COMPACT" then return end
	local a = Kit.accent(sheet, "Pep")
	local holder = Common.get(a, "Core", "Frame") :: Frame
	holder.Active = false
	holder.BackgroundTransparency = 1
	holder.ZIndex = 5
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(emblem.Position.X.Offset + emblem.Size.X.Offset / 2, emblem.Position.Y.Offset + emblem.Size.Y.Offset / 2)
	holder.Size = UDim2.fromOffset(emblem.Size.X.Offset + 22, emblem.Size.Y.Offset + 22)
	local ring = Recipes.ring(holder, { size = emblem.Size.X.Offset + 22, thick = 4, color = Theme.lift(ctx.hue, 0.2), track = 0.8 })
	ring:set(0.7)
	Motion.loop(holder, function(dt: number)
		if not Motion.reduced() then holder.Rotation = (holder.Rotation + dt * 24) % 360 end
	end)
end

local function sig(layer: string, accent: (Frame, any) -> ()): any
	return {
		layers = { layer },
		skin = P.skin,
		accent = accent,
		claims = ({ { match = { cn = "display-text" }, make = ladder } } :: { any }),
	}
end

return {
	sig("ep", stripes),
	sig("pep", core),
}
