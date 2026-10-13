--[[
	Theme and a small UI kit. Same palette and hierarchy as the HTML build (onslaught-html/template.html):
	dark panels, one gold accent for money and primary actions, muted labels above big numbers.
]]

local Ui = {}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
Ui.C = {
	bg = hex("#0e1014"), panel = hex("#161920"), panel2 = hex("#1d2129"), line = hex("#2a303c"),
	ink = hex("#eef1f6"), muted = hex("#98a1b0"), dim = hex("#6b7383"),
	gold = hex("#ffcf4a"), good = hex("#6ad46a"), bad = hex("#ff5f57"), info = hex("#6fb6ff"), robux = hex("#77ccff"),
	Blue = hex("#2f6de0"), Green = hex("#36b84a"), Red = hex("#d8352b"), Yellow = hex("#f2c21b"),
	Orange = hex("#f08a24"), Cyan = hex("#29c4d8"), Violet = hex("#9b5de5"), Gold = hex("#e0b23a"),
}
Ui.hex = hex
Ui.FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
Ui.BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
Ui.HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
Ui.MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

-- new("Frame", { props }, { children })
function Ui.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local o = Instance.new(class)
	local parent
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			(o :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = o
	end
	if parent then
		o.Parent = parent
	end
	return o
end
local new = Ui.new

function Ui.corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end
function Ui.stroke(color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", { Color = color or Ui.C.line, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
function Ui.pad(all: number, top: number?)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, top or all), PaddingBottom = UDim.new(0, top or all),
	})
end
function Ui.list(dir: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?)
	return new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left, VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end
function Ui.grid(cell: UDim2, gap: number?)
	return new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(gap or 6, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder })
end

function Ui.panel(props)
	local f = new("Frame", { BackgroundColor3 = Ui.C.panel, BorderSizePixel = 0 })
	Ui.corner(10).Parent = f
	Ui.stroke().Parent = f
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	return f
end

function Ui.text(text: string, size: number?, color: Color3?, font: Font?, props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 14, TextColor3 = color or Ui.C.ink, FontFace = font or Ui.FONT,
		TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.XY, RichText = true,
	})
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end

-- kind: "primary" (gold), "danger", "ghost", nil (default panel button)
function Ui.button(text: string, kind: string?, onClick: (() -> ())?, props)
	local bg = if kind == "primary" then Ui.C.gold elseif kind == "danger" then hex("#3a1d1f") elseif kind == "ghost" then Ui.C.panel else Ui.C.panel2
	local fg = if kind == "primary" then hex("#1b1608") elseif kind == "danger" then Ui.C.bad else Ui.C.ink
	local b = new("TextButton", {
		BackgroundColor3 = bg, Text = text, TextColor3 = fg, FontFace = Ui.BOLD, TextSize = 14, AutoButtonColor = true,
		Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, RichText = true,
	})
	Ui.corner(8).Parent = b
	Ui.pad(12, 0).Parent = b
	if kind ~= "primary" then
		Ui.stroke(if kind == "danger" then hex("#6b2b2e") else Ui.C.line).Parent = b
	end
	if onClick then
		b.Activated:Connect(onClick)
	end
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	return b
end

-- A small uppercase label over a big number (the HUD pattern).
function Ui.stat(label: string, value: string, color: Color3?, width: number?)
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, width or 90, 1, 0) })
	Ui.list(Enum.FillDirection.Vertical, 0, nil, Enum.VerticalAlignment.Center).Parent = f
	Ui.text(string.upper(label), 11, Ui.C.muted, Ui.BOLD, { LayoutOrder = 1 }).Parent = f
	local v = Ui.text(value, 22, color or Ui.C.ink, Ui.HEAVY, { LayoutOrder = 2, Name = "Value" })
	v.Parent = f
	return f, v
end

function Ui.bar(color: Color3, height: number?)
	local back = new("Frame", { BackgroundColor3 = hex("#262b36"), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height or 6) })
	Ui.corner(3).Parent = back
	local fill = new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Name = "Fill", Parent = back })
	Ui.corner(3).Parent = fill
	return back, fill
end

function Ui.scroll(props)
	local s = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = Ui.C.line,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	for k, v in props or {} do
		(s :: any)[k] = v
	end
	return s
end

function Ui.clear(container: Instance)
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- Numbers: 999, 12.3K, 4.5M ... like the HTML fmt(); EternityNum.short for anything past 1e15.
local EN
function Ui.fmt(n: number): string
	if n == math.huge then
		return "∞"
	end
	local a = math.abs(n)
	if a >= 1e15 then
		EN = EN or require(game:GetService("ReplicatedStorage").Shared.Onslaught.EternityNum)
		return EN.short(n, 2)
	end
	for _, s in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		local v, suf = s[1], s[2]
		if a >= v * 10 or (v >= 1e6 and a >= v) then
			local x = n / v
			local str = if a >= v * 100 then string.format("%d", math.floor(x)) else string.format("%.1f", x)
			return (string.gsub(str, "%.0$", "")) .. suf
		end
	end
	return tostring(math.floor(n))
end
function Ui.money(n: number): string
	return "$" .. Ui.fmt(math.floor(n))
end
function Ui.comboName(n: string?): string
	local out = {}
	for w in string.gmatch(n or "", "[^_]+") do
		table.insert(out, if w == "bfg" then "BFG" else string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2))
	end
	return table.concat(out, " ")
end

return Ui
