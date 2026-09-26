--!strict
--[[
	Skin: the Substance-painted UI kit on a GuiObject (art/substance, src/shared/UiKit.luau). A slot is a 9-sliced
	texture drawn by a child ImageLabel named "Skin" behind the object's other children; the object's own procedural
	surface (fill, hairline, top edge) is switched off while the skin shows.

	    Skin.apply(f, "cta", { tint = hue, scale = .75 })   -> the ImageLabel, or nil (no kit id / f lays out a list)
	    Skin.clear(f)                                         the procedural look again
	    Skin.ready()                                          the kit is uploaded

	scale is the SliceScale (the corners' size = slice px x scale). A list layout would lay the Skin child out like
	any item, so an object that holds a UIListLayout / UIGridLayout is never skinned (its caller keeps the Sleek
	surface). Everything is idempotent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiKit = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("UiKit"))

local Skin = {}

local WHITE = Color3.new(1, 1, 1)

function Skin.ready(): boolean
	return UiKit.id ~= nil
end

local function strokes(f: GuiObject, on: boolean)
	for _, c in f:GetChildren() do
		if c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then c.Enabled = on end
	end
	local e = f:FindFirstChild("Edge")
	if e and e:IsA("GuiObject") then e.Visible = on end
end

function Skin.clear(f: GuiObject)
	local s = f:FindFirstChild("Skin")
	if s then
		s:Destroy()
		strokes(f, true)
	end
end

export type Opts = { tint: Color3?, scale: number?, alpha: number?, z: number? }
function Skin.apply(f: GuiObject, slot: string, o: Opts?): ImageLabel?
	local id = UiKit.id
	local def = UiKit.slots[slot]
	if id == nil or def == nil or f:FindFirstChildWhichIsA("UIGridStyleLayout") then
		Skin.clear(f)
		return nil
	end
	local opts: Opts = o or ({} :: Opts)
	local im = f:FindFirstChild("Skin") :: ImageLabel?
	if im == nil or not im:IsA("ImageLabel") then
		if im then im:Destroy() end
		local n = Instance.new("ImageLabel")
		n.Name = "Skin"
		n.BackgroundTransparency = 1
		n.BorderSizePixel = 0
		n.Active = false
		n.Size = UDim2.fromScale(1, 1)
		n.Position = UDim2.new()
		n.ScaleType = Enum.ScaleType.Slice
		n.Parent = f
		im = n
	end
	local img = im :: ImageLabel
	-- a (1, 1) child of a padded object covers only the padded area: grow it back over the padding
	local pad = f:FindFirstChildWhichIsA("UIPadding")
	if pad then
		local l, t = pad.PaddingLeft.Offset, pad.PaddingTop.Offset
		img.Position = UDim2.fromOffset(-l, -t)
		img.Size = UDim2.new(1, l + pad.PaddingRight.Offset, 1, t + pad.PaddingBottom.Offset)
	else
		img.Position = UDim2.new()
		img.Size = UDim2.fromScale(1, 1)
	end
	local r, sl = def.rect, def.slice
	img.Image = id
	img.ImageRectOffset = Vector2.new(r[1], r[2])
	img.ImageRectSize = Vector2.new(r[3], r[4])
	img.SliceCenter = Rect.new(sl, sl, r[3] - sl, r[4] - sl)
	img.SliceScale = opts.scale or 0.5
	img.ImageColor3 = if def.tint then (opts.tint or WHITE) else WHITE
	img.ImageTransparency = 1 - (opts.alpha or 1)
	img.ZIndex = opts.z or 0
	f.BackgroundTransparency = 1
	strokes(f, false)
	return img
end

return Skin
