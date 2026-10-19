--!native
--!optimize 2
-- Upload scheduler: picks which dirty atlas page to send to its EditableImage each frame.
-- The engine shows one EditableImage update per frame, so sending three images in a frame just queues
-- them; choosing deliberately keeps the most visible content fresh.
--
-- Score = visibility weight × (1 + frames since last upload). Weight is the sum of region weights on the
-- page (set them to on-screen pixel area, or 0 for off-screen). A byte cap splits very large dirty rects
-- into row bands across frames so one big repaint can't blow the frame budget.

local Atlas = require("./Atlas")

local Uploader = {}
Uploader.__index = Uploader

type Page = Atlas.Page

export type Uploader = typeof(setmetatable(
	{} :: {
		pages: { Page },
		weights: { [Page]: number },
		maxUploadsPerFrame: number,
		maxBytesPerFrame: number,
		frame: number,
		stage: { [number]: buffer },
		stageCount: number,
		send: (page: Page, x: number, y: number, w: number, h: number, buf: buffer) -> (),
		sentBytes: number,
		sentCount: number,
	},
	Uploader
))

-- `send` performs the real upload. In Roblox:
--   function(page, x, y, w, h, buf) images[page.id]:WritePixelsBuffer(Vector2.new(x, y), Vector2.new(w, h), buf) end
function Uploader.new(send: (Page, number, number, number, number, buffer) -> (), opts: { maxUploadsPerFrame: number?, maxBytesPerFrame: number? }?): Uploader
	local o = opts or {}
	return setmetatable({
		pages = {},
		weights = {},
		maxUploadsPerFrame = o.maxUploadsPerFrame or 1,
		maxBytesPerFrame = o.maxBytesPerFrame or 1024 * 1024, -- 256K pixels
		frame = 0,
		stage = {},
		stageCount = 0,
		send = send,
		sentBytes = 0,
		sentCount = 0,
	}, Uploader)
end

function Uploader.addPage(self: Uploader, page: Page)
	table.insert(self.pages, page)
	self.weights[page] = 1
end

function Uploader.setPageWeight(self: Uploader, page: Page, w: number)
	self.weights[page] = w
end

local function packRect(self: Uploader, page: Page, x: number, y: number, w: number, h: number): buffer
	local S = page.size
	if x == 0 and w == S and y == 0 and h == S then
		return page.rgba
	end
	local need = w * h * 4
	local buf = self.stage[need]
	if buf == nil then
		self.stageCount += 1
		if self.stageCount > 16 then
			table.clear(self.stage) -- dirty rects vary in size; don't keep every size forever
			self.stageCount = 1
		end
		buf = buffer.create(need)
		self.stage[need] = buf
	end
	local b = buf :: buffer
	if x == 0 and w == S then
		buffer.copy(b, 0, page.rgba, y * S * 4, need)
	else
		for row = 0, h - 1 do
			buffer.copy(b, row * w * 4, page.rgba, ((y + row) * S + x) * 4, w * 4)
		end
	end
	return b
end

-- Call once per frame (RenderStepped). Returns how many pages were sent.
function Uploader.step(self: Uploader): number
	self.frame += 1
	local sent = 0
	local budget = self.maxBytesPerFrame
	self.sentBytes, self.sentCount = 0, 0
	while sent < self.maxUploadsPerFrame do
		local best: Page? = nil
		local bestScore = 0
		for _, page in self.pages do
			if Atlas.isDirty(page) then
				local score = (self.weights[page] or 0) * (1 + self.frame - page.lastUpload)
				if score > bestScore then
					best, bestScore = page, score
				end
			end
		end
		if best == nil then
			break
		end
		local page = best :: Page
		local x0, y0 = math.max(0, page.dx0), math.max(0, page.dy0)
		local x1, y1 = math.min(page.size, page.dx1), math.min(page.size, page.dy1)
		local w = x1 - x0
		local rows = math.max(1, math.min(y1 - y0, budget // (w * 4)))
		self.send(page, x0, y0, w, rows, packRect(self, page, x0, y0, w, rows))
		self.sentBytes += w * rows * 4
		budget -= w * rows * 4
		if y0 + rows >= y1 then
			Atlas.clearDirty(page)
			page.lastUpload = self.frame
		else
			page.dy0 = y0 + rows -- rest of the rect goes next frame
		end
		sent += 1
		if budget <= 0 then
			break
		end
	end
	self.sentCount = sent
	return sent
end

return Uploader
