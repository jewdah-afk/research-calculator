--!native
--!optimize 2
-- Canvas snapshots for saves and late joiners.
-- EditableImage content never replicates, so clients rebuild it from an op log; a joiner mid-session needs
-- a snapshot instead of replaying an hour of strokes. Palette-indexed pixels (1 byte) + run-length coding
-- shrink typical painted/simulated canvases 10-100x before compression; Roblox's native zstd
-- (EncodingService:CompressBuffer) then squeezes the runs further.
--
-- Format: "PXS1" | u16 w | u16 h | runs...   run = varint length, u8 value
-- `compress`/`decompress` are optional hooks. In Roblox:
--   compress = function(b) return EncodingService:CompressBuffer(b, Enum.CompressionAlgorithm.Zstd, 9) end
--   decompress = function(b) return EncodingService:DecompressBuffer(b, Enum.CompressionAlgorithm.Zstd) end

local Snapshot = {}

local MAGIC = 0x31535850 -- "PXS1" little-endian

local function writeVarint(out: buffer, o: number, v: number): number
	while v >= 128 do
		buffer.writeu8(out, o, bit32.bor(bit32.band(v, 127), 128))
		v = bit32.rshift(v, 7)
		o += 1
	end
	buffer.writeu8(out, o, v)
	return o + 1
end

function Snapshot.encode(idx: buffer, w: number, h: number, compress: ((buffer) -> buffer)?): buffer
	local n = w * h
	assert(buffer.len(idx) >= n, "Snapshot.encode: buffer smaller than w*h")
	-- Worst case: every run length 1 → 2 bytes per pixel.
	local out = buffer.create(8 + n * 2)
	buffer.writeu32(out, 0, MAGIC)
	buffer.writeu16(out, 4, w)
	buffer.writeu16(out, 6, h)
	local o, i = 8, 0
	while i < n do
		local v = buffer.readu8(idx, i)
		local j = i + 1
		local quad = v * 0x01010101
		while j + 4 <= n and buffer.readu32(idx, j) == quad do
			j += 4
		end
		while j < n and buffer.readu8(idx, j) == v do
			j += 1
		end
		o = writeVarint(out, o, j - i)
		buffer.writeu8(out, o, v)
		o += 1
		i = j
	end
	local packed = buffer.create(o)
	buffer.copy(packed, 0, out, 0, o)
	if compress then
		return compress(packed)
	end
	return packed
end

-- Decodes into `into` if given (must be ≥ w*h bytes), else a new buffer. Returns (pixels, w, h).
function Snapshot.decode(data: buffer, into: buffer?, decompress: ((buffer) -> buffer)?): (buffer, number, number)
	local b = if decompress then decompress(data) else data
	assert(buffer.readu32(b, 0) == MAGIC, "Snapshot.decode: bad magic")
	local w, h = buffer.readu16(b, 4), buffer.readu16(b, 6)
	local n = w * h
	local px = into or buffer.create(n)
	assert(buffer.len(px) >= n, "Snapshot.decode: target too small")
	local o, i, len = 8, 0, buffer.len(b)
	while o < len do
		local run, shift = 0, 0
		repeat
			local byte = buffer.readu8(b, o)
			o += 1
			run = bit32.bor(run, bit32.lshift(bit32.band(byte, 127), shift))
			shift += 7
		until byte < 128
		local v = buffer.readu8(b, o)
		o += 1
		assert(i + run <= n, "Snapshot.decode: run overflows image")
		buffer.fill(px, i, v, run)
		i += run
	end
	assert(i == n, "Snapshot.decode: truncated data")
	return px, w, h
end

-- Split a snapshot into DataStore-sized chunks. Base64 (EncodingService:Base64Encode, needed to store
-- binary safely) grows data by 4/3, so the 2.9 MB default lands each chunk under the 4 MB value limit.
function Snapshot.chunks(data: buffer, chunkBytes: number?): { buffer }
	local size = chunkBytes or 2_900_000
	local out = {}
	local len = buffer.len(data)
	local o = 0
	while o < len do
		local n = math.min(size, len - o)
		local c = buffer.create(n)
		buffer.copy(c, 0, data, o, n)
		table.insert(out, c)
		o += n
	end
	return out
end

return Snapshot
