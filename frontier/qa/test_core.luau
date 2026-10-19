local Out = require("./Out")
local Atlas = require("../Atlas")
local Uploader = require("../Uploader")
local ImagePool = require("../ImagePool")
local Snapshot = require("../Snapshot")
local IndexedFrame = require("../IndexedFrame")

-- Atlas: packing ---------------------------------------------------------------

local page = Atlas.newPage(1, 1024, 1)
local regions = {}
local seed = 12345
local function rand(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n
end
for _ = 1, 5000 do
	local r = Atlas.alloc(page, 16 + rand(48), 16 + rand(48))
	if r == nil then
		break
	end
	table.insert(regions, r)
end
local area = 0
for _, r in regions do
	area += r.w * r.h
end
Out.check("atlas.packs_many", #regions >= 250, `{#regions} regions`)
Out.check("atlas.occupancy", area / (1024 * 1024) > 0.5, string.format("%.0f%% content", area / 10485.76))

-- No overlaps (including gutters) and all inside the page.
local function overlaps(a, b)
	local g = 1
	return a.x - g < b.x + b.w + g and b.x - g < a.x + a.w + g and a.y - g < b.y + b.h + g and b.y - g < a.y + a.h + g
end
local bad = 0
for i = 1, #regions do
	local a = regions[i]
	if a.x - 1 < 0 or a.y - 1 < 0 or a.x + a.w + 1 > 1024 or a.y + a.h + 1 > 1024 then
		bad += 1
	end
	for j = i + 1, #regions do
		if overlaps(a, regions[j]) then
			bad += 1
		end
	end
end
Out.check("atlas.no_overlap", bad == 0, `{bad} overlaps`)

-- Free and reuse: freeing everything lets the same set pack again.
local liveBefore = page.live
for _, r in regions do
	Atlas.free(r)
end
Out.check("atlas.free_all", page.live == 0, `live {page.live} (was {liveBefore})`)
local again = 0
for _, r in regions do
	if Atlas.alloc(page, r.w, r.h) then
		again += 1
	end
end
Out.check("atlas.reuse_after_free", again == #regions, `{again}/{#regions}`)

-- Churn: random alloc/free must keep working without leaking space.
local churnPage = Atlas.newPage(2, 1024, 1)
local live = {}
local fails = 0
for step = 1, 5000 do
	if #live > 0 and (rand(100) < 45 or #live > 120) then
		local i = rand(#live) + 1
		Atlas.free(live[i])
		live[i] = live[#live]
		live[#live] = nil
	else
		local r = Atlas.alloc(churnPage, 8 + rand(56), 8 + rand(56))
		if r then
			table.insert(live, r)
		else
			fails += 1
		end
	end
end
Out.check("atlas.churn", fails < 50, `{fails} failed allocs over 5000 ops, {#live} live`)

-- Write + gutter: gutter pixels copy edge pixels.
local p2 = Atlas.newPage(3, 64, 2)
local r = Atlas.alloc(p2, 4, 4) :: Atlas.Region
local src = buffer.create(4 * 4 * 4)
for i = 0, 15 do
	buffer.writeu32(src, i * 4, 0xff000000 + i)
end
Atlas.write(r, src)
local function px(x, y)
	return buffer.readu32(p2.rgba, (y * 64 + x) * 4)
end
Out.check("atlas.write_content", px(r.x + 3, r.y + 3) == 0xff00000f)
Out.check("atlas.gutter_left", px(r.x - 2, r.y + 1) == px(r.x, r.y + 1))
Out.check("atlas.gutter_corner", px(r.x - 2, r.y - 2) == px(r.x, r.y))
Out.check("atlas.gutter_bottom_right", px(r.x + 5, r.y + 5) == px(r.x + 3, r.y + 3))
local u0, v0, u1, v1 = Atlas.uvRect(r)
Out.check("atlas.uv_inside", u0 > r.x / 64 and u1 < (r.x + 4) / 64 and v0 > r.y / 64 and v1 < (r.y + 4) / 64)

-- Uploader -----------------------------------------------------------------------

local log = {}
local up = Uploader.new(function(pg, x, y, w, h, buf)
	assert(buffer.len(buf) == w * h * 4, "upload buffer must be exact size")
	table.insert(log, { pg.id, x, y, w, h })
end, { maxUploadsPerFrame = 1, maxBytesPerFrame = 64 * 1024 })

local pages = {}
for i = 1, 3 do
	pages[i] = Atlas.newPage(10 + i, 256, 1)
	up:addPage(pages[i])
end
up:setPageWeight(pages[1], 100) -- big on screen
up:setPageWeight(pages[2], 10)
up:setPageWeight(pages[3], 0) -- off screen: never sent

local regs = {}
for i = 1, 3 do
	regs[i] = Atlas.alloc(pages[i], 32, 32)
end
local tile = buffer.create(32 * 32 * 4)
for i = 1, 3 do
	Atlas.write(regs[i], tile)
end
up:step()
Out.check("uploader.one_per_frame", #log == 1 and log[1][1] == 11, `first upload page {log[1] and log[1][1]}`)
Out.check("uploader.dirty_rect_only", log[1][4] == 34 and log[1][5] == 34, `{log[1][4]}x{log[1][5]}`)
up:step()
Out.check("uploader.next_page", #log == 2 and log[2][1] == 12)
up:step()
Out.check("uploader.skips_invisible", #log == 2)

-- Starvation: a low-weight page still gets sent while a high-weight page stays dirty every frame.
local sentLow = false
for _ = 1, 30 do
	Atlas.write(regs[1], tile)
	Atlas.write(regs[2], tile)
	table.clear(log)
	up:step()
	if log[1] and log[1][1] == 12 then
		sentLow = true
	end
end
Out.check("uploader.no_starvation", sentLow)

-- Byte cap: a full-page repaint is split into bands across frames.
local big = Atlas.newPage(20, 256, 0)
local upBig = Uploader.new(function(pg, x, y, w, h)
	table.insert(log, { pg.id, x, y, w, h })
end, { maxBytesPerFrame = 64 * 1024 })
upBig:addPage(big)
Atlas.markDirty(big, 0, 0, 256, 256)
table.clear(log)
local frames = 0
while Atlas.isDirty(big) and frames < 100 do
	upBig:step()
	frames += 1
end
local rows = 0
for _, e in log do
	rows += e[5]
end
Out.check("uploader.banding", frames == 4 and rows == 256, `{frames} frames, {rows} rows`)

-- ImagePool ------------------------------------------------------------------------

local liveImages, engineBudget = 0, 6 * 256 * 256 * 4 -- the engine's real limit (pretend we don't know it)
local engineUsed = 0
local pool = ImagePool.new(function(w, h)
	if engineUsed + w * h * 4 > engineBudget then
		return nil
	end
	engineUsed += w * h * 4
	liveImages += 1
	return { w = w, h = h }
end, function(img)
	engineUsed -= img.w * img.h * 4
	liveImages -= 1
end, 8 * 256 * 256 * 4) -- our cap is looser than the engine's

local held = {}
for i = 1, 6 do
	held[i] = pool:acquire(256, 256)
end
Out.check("pool.fills", liveImages == 6)
pool:release(held[1])
pool:release(held[2])
local again1 = pool:acquire(256, 256)
Out.check("pool.reuses", again1 == held[2] and pool.stats.reused == 1)
-- A different size needs memory: the idle image gets evicted and creation retried.
local other = pool:acquire(128, 128)
Out.check("pool.evicts_on_engine_nil", other ~= nil and pool.stats.evicted == 1, `evicted {pool.stats.evicted}`)
local tooBig = pool:acquire(1024, 1024)
Out.check("pool.fails_cleanly", tooBig == nil and pool.stats.failed >= 1)

-- Snapshot -----------------------------------------------------------------------------

local W, H = 512, 512
local f = IndexedFrame.new(W, H)
f:fill(0)
for y = 0, H - 1 do
	for x = 0, W - 1 do
		if (x - 256) ^ 2 + (y - 256) ^ 2 < 120 ^ 2 then
			f:set(x, y, 1 + (x // 64 + y // 64) % 4)
		end
	end
end
for k = 1, 2000 do
	f:set(rand(W), rand(H), 9) -- noise so it isn't trivially compressible
end
local snap
Out.time("snapshot.encode_512", 10, function()
	snap = Snapshot.encode(f.idx, W, H)
end)
local back
Out.time("snapshot.decode_512", 10, function()
	back = Snapshot.decode(snap)
end)
Out.check("snapshot.roundtrip", buffer.tostring(back) == buffer.tostring(f.idx))
Out.check("snapshot.ratio", buffer.len(snap) < W * H / 10, `{buffer.len(snap)} bytes from {W * H} pixels ({W * H * 4} RGBA)`)
local worst = buffer.create(64 * 64)
for i = 0, 64 * 64 - 1 do
	buffer.writeu8(worst, i, i % 256)
end
Out.check("snapshot.worst_case", buffer.tostring((Snapshot.decode(Snapshot.encode(worst, 64, 64)))) == buffer.tostring(worst))
local ch = Snapshot.chunks(buffer.create(7_000_000))
Out.check("snapshot.chunks", #ch == 3 and buffer.len(ch[1]) * 4 / 3 < 4_000_000)

-- Timing: atlas write + upload of 64 dirty 64x64 surfaces on one 1024 page.
local tp = Atlas.newPage(30, 1024, 1)
local tregs = {}
for i = 1, 64 do
	tregs[i] = Atlas.alloc(tp, 64, 64)
end
local tsrc = buffer.create(64 * 64 * 4)
local tup = Uploader.new(function() end, { maxBytesPerFrame = 4 * 1024 * 1024 })
tup:addPage(tp)
Out.time("atlas.write64x64x64+pack", 20, function()
	for i = 1, 64 do
		Atlas.write(tregs[i], tsrc)
	end
	tup:step()
end)
Out.done()
