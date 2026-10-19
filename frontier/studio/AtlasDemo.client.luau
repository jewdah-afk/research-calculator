-- Atlas demo: 48 animated tiles on screen from ONE EditableImage, all refreshing every frame.
-- With one EditableImage per tile, the engine's one-image-update-per-frame rule would refresh each tile
-- only every 48th frame. Needs Atlas and Uploader as ModuleScripts in ReplicatedStorage.Frontier.

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Frontier = game:GetService("ReplicatedStorage"):WaitForChild("Frontier")
local Atlas = require(Frontier:WaitForChild("Atlas"))
local Uploader = require(Frontier:WaitForChild("Uploader"))

local PAGE, TILE, COUNT = 512, 48, 48
local img = AssetService:CreateEditableImage({ Size = Vector2.new(PAGE, PAGE) })
assert(img, "editable budget exhausted")
local page = Atlas.newPage(1, PAGE, 1)
local up = Uploader.new(function(_, x, y, w, h, buf)
	img:WritePixelsBuffer(Vector2.new(x, y), Vector2.new(w, h), buf)
end, { maxBytesPerFrame = PAGE * PAGE * 4 })
up:addPage(page)

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(96, 96)
grid.Parent = gui

local regions = {}
for i = 1, COUNT do
	local r = Atlas.alloc(page, TILE, TILE) :: Atlas.Region
	regions[i] = r
	local x, y, w, h = Atlas.imageRect(r)
	local label = Instance.new("ImageLabel")
	label.ImageContent = Content.fromObject(img)
	label.ImageRectOffset = Vector2.new(x, y)
	label.ImageRectSize = Vector2.new(w, h)
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.BackgroundTransparency = 1
	label.Parent = gui
end

local tile = buffer.create(TILE * TILE * 4)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i, r in regions do
		-- A different animated plasma per tile.
		for y = 0, TILE - 1 do
			for x = 0, TILE - 1 do
				local v = math.sin(x * 0.2 + t * 3 + i) + math.sin(y * 0.17 - t * 2 + i * 0.5)
				local c = math.floor((v + 2) * 63)
				buffer.writeu32(tile, (y * TILE + x) * 4, bit32.bor(c, bit32.lshift(255 - c, 8), bit32.lshift((i * 37) % 256, 16), 0xFF000000))
			end
		end
		Atlas.write(r, tile)
	end
	up:step()
end)
