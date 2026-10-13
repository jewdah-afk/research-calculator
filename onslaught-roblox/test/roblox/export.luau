--[[
	Dump what a client would draw (its PlayerGui tree and the Workspace parts + camera) to JSON, so
	test/roblox/render.html can lay it out in a browser for preview screenshots. Not Roblox's renderer:
	GUI layout uses the same rules (UDim2, anchor, list/grid layouts, padding, automatic size), parts are drawn
	from straight above.
]]

local serde = require("@lune/serde")
local fs = require("@lune/fs")

local Export = {}

local function c3(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end
local function ud2(u)
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end
local function enumName(e)
	return if e then e.Name else nil
end

local function guiNode(inst)
	local cls = inst.ClassName
	local n = { class = cls, name = inst.Name, children = {} }
	if inst:IsA("GuiObject") then
		n.size, n.pos = ud2(inst.Size), ud2(inst.Position)
		n.anchor = { inst.AnchorPoint.X, inst.AnchorPoint.Y }
		n.visible = inst.Visible
		n.bg, n.bgT = c3(inst.BackgroundColor3), inst.BackgroundTransparency
		n.z, n.order = inst.ZIndex, inst.LayoutOrder
		n.auto = enumName(inst.AutomaticSize)
		n.clip = inst.ClipsDescendants
		n.rotation = inst.Rotation
		if cls == "TextLabel" or cls == "TextButton" then
			n.text, n.textSize, n.textColor = inst.Text, inst.TextSize, c3(inst.TextColor3)
			n.weight = enumName(inst.FontFace.Weight)
			n.family = inst.FontFace.Family
			n.xAlign, n.yAlign = enumName(inst.TextXAlignment), enumName(inst.TextYAlignment)
			n.wrap, n.rich, n.textT = inst.TextWrapped, inst.RichText, inst.TextTransparency
			n.strokeT = inst.TextStrokeTransparency
		end
	elseif cls == "UIListLayout" then
		n.dir, n.pad = enumName(inst.FillDirection), { inst.Padding.Scale, inst.Padding.Offset }
		n.hAlign, n.vAlign, n.wraps = enumName(inst.HorizontalAlignment), enumName(inst.VerticalAlignment), inst.Wraps
	elseif cls == "UIGridLayout" then
		n.cell, n.cellPad = ud2(inst.CellSize), ud2(inst.CellPadding)
	elseif cls == "UIPadding" then
		n.padding = { inst.PaddingLeft.Offset, inst.PaddingRight.Offset, inst.PaddingTop.Offset, inst.PaddingBottom.Offset }
	elseif cls == "UICorner" then
		n.radius = inst.CornerRadius.Offset
	elseif cls == "UIStroke" then
		n.color, n.thickness, n.t = c3(inst.Color), inst.Thickness, inst.Transparency
	elseif cls == "UIScale" then
		n.scale = inst.Scale
	elseif cls == "UIGradient" then
		local kp = inst.Color.Keypoints
		n.from, n.to = c3(kp[1].Value), c3(kp[#kp].Value)
	end
	for _, c in inst:GetChildren() do
		table.insert(n.children, guiNode(c))
	end
	return n
end

local function parts(root)
	local out = {}
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 0.98 then
			local cf = p.CFrame
			if cf.Position.Y < -1000 then
				continue -- pooled, parked far away
			end
			local rx, uy, lz = cf.RightVector, cf.UpVector, cf.LookVector
			table.insert(out, {
				pos = { cf.Position.X, cf.Position.Y, cf.Position.Z },
				right = { rx.X, rx.Y, rx.Z }, up = { uy.X, uy.Y, uy.Z }, look = { lz.X, lz.Y, lz.Z },
				size = { p.Size.X, p.Size.Y, p.Size.Z }, color = c3(p.Color), t = p.Transparency,
				shape = if p:IsA("Part") then p.Shape.Name else "Block", material = p.Material.Name,
				mesh = p:FindFirstChildOfClass("SpecialMesh") ~= nil,
			})
		end
		if p:IsA("BillboardGui") and p.Parent and p.Parent:IsA("BasePart") then
			local label = p:FindFirstChildOfClass("TextLabel")
			local pos = p.Parent.CFrame.Position
			if label and label.Visible and label.TextTransparency < 0.95 and pos.Y > -1000 then
				table.insert(out, { billboard = true, pos = { pos.X, pos.Y, pos.Z }, text = label.Text, color = c3(label.TextColor3), size = label.TextSize })
			end
		end
		if p:IsA("SurfaceGui") and p.Parent and p.Parent:IsA("BasePart") then
			local cf = p.Parent.CFrame
			local labels = {}
			for _, d in p:GetDescendants() do
				if d:IsA("TextLabel") then
					table.insert(labels, d.Text)
				end
			end
			table.insert(out, { surface = true, pos = { cf.Position.X, cf.Position.Y, cf.Position.Z }, size = { p.Parent.Size.X, p.Parent.Size.Z }, text = labels })
		end
	end
	return out
end

-- player: the runtime's fake player (has .gui = real PlayerGui); m: its machine (for the camera); workspace: real Workspace
function Export.write(path: string, player, m, workspace, title: string)
	local cam = m.camera
	local cf = cam.CFrame
	local data = {
		title = title,
		viewport = { cam.ViewportSize.X, cam.ViewportSize.Y },
		camera = {
			pos = { cf.Position.X, cf.Position.Y, cf.Position.Z },
			right = { cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z },
			up = { cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z },
			look = { cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z },
			fov = cam.FieldOfView,
		},
		gui = guiNode(player.gui),
		parts = parts(workspace),
	}
	fs.writeFile(path, serde.encode("json", data))
end

return Export
