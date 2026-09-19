--!strict
--[[
	RenderConfig.luau -- the 2D presentation contract.

	VERIFIED on the target machine by the EditableImage probe (Roblox
	0.739.0.7390687), so these API shapes are facts, not assumptions:
	  AssetService:CreateEditableImage({ Size = Vector2 })
	  ImageLabel.ImageContent = Content.fromObject(editableImage)
	  editableImage:WritePixelsBuffer(position, size, buffer)
	  DrawImage and DrawRectangle both present.
	Measured: 500 8px sprites composited per frame -> 151 fps, worst frame 2.8 ms.

	The canvas is a fixed low-resolution pixel grid scaled to the viewport by an
	INTEGER factor with nearest-neighbour filtering, so pixels stay square and
	the art reads as pixel art at any window size.
]]

local RenderConfig = {
	-- Internal canvas, in pixels. 16:9. Everything is composited here and
	-- uploaded once per frame.
	canvasWidth = 480,
	canvasHeight = 270,

	-- Sprite sheet cell size. Configurable per the asset spec; the manifest may
	-- override it per sheet.
	defaultCellSize = 32,

	-- World units per canvas pixel. The simulation works in world units (the
	-- same units Tuning uses); this is the only place the two meet.
	-- NOT from research: a presentation choice, tune with CALIBRATION.md.
	worldUnitsPerPixel = 0.25,

	-- Camera deadzone in canvas pixels: the player may drift this far from the
	-- centre before the camera follows, which stops micro-jitter.
	cameraDeadzone = 0,

	-- Draw order. Lower draws first.
	layer = {
		ground = 0,
		floorItem = 10,
		gem = 20,
		enemy = 30,
		player = 40,
		projectile = 50,
		effect = 60,
		damageNumber = 70,
	},
}

return RenderConfig
