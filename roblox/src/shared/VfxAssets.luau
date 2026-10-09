--!strict
-- VfxAssets: uploaded texture ids for the client VFX engine (src/client/Vfx). One entry per PNG in
-- roblox/assets/vfx/ (drawn by roblox/tools/vfx/gen_vfx.py, listed with their use in assets/vfx/manifest.json and
-- HANDOUT.md "VFX"). Upload a PNG as an Image/Decal, paste its id here ("rbxassetid://123" or just "123").
-- id = "" means not uploaded yet: the engine skips every layer that needs it, so nothing errors before upload.
--
-- tint: "tint" textures are greyscale + ink and are coloured per rarity by Color (multiply); "baked" carry colour.
-- layout/mode = ParticleEmitter.FlipbookLayout / FlipbookMode (frames run left to right, top to bottom).
-- beam = a Beam strip: U (width) runs along the beam, V across it, seamless in U.
local L = Enum.ParticleFlipbookLayout
local M = Enum.ParticleFlipbookMode

export type Tex = {
	id: string,
	size: Vector2,
	layout: Enum.ParticleFlipbookLayout?,
	mode: Enum.ParticleFlipbookMode?,
	frames: number?,
	beam: boolean?,
	tint: string,
}

local tex: { [string]: Tex } = {
	-- kept from round 1 (uploaded)
	smoke_puff = { id = "92268408409601", size = Vector2.new(1024, 1024), layout = L.Grid4x4, mode = M.OneShot, frames = 16, tint = "baked" },
	sparkle = { id = "109306538694217", size = Vector2.new(512, 512), layout = L.Grid4x4, mode = M.OneShot, frames = 16, tint = "tint" },
	shell_shards = { id = "140039753673574", size = Vector2.new(512, 512), layout = L.Grid2x2, mode = M.Loop, frames = 4, tint = "tint" },
	confetti = { id = "139503594314619", size = Vector2.new(512, 512), layout = L.Grid4x4, mode = M.Loop, frames = 16, tint = "tint" },
	leaf = { id = "108661409279858", size = Vector2.new(512, 512), layout = L.Grid4x4, mode = M.Loop, frames = 16, tint = "baked" },
	star = { id = "127499349991305", size = Vector2.new(256, 256), tint = "tint" },
	burst_lines = { id = "89698007141854", size = Vector2.new(512, 512), tint = "tint" },
	rune_circle = { id = "127457007197351", size = Vector2.new(1024, 1024), tint = "tint" },
	-- round 2 (QA round 1): new shapes, no ink on additive pieces
	flash_star = { id = "", size = Vector2.new(512, 512), tint = "tint" },
	swirl_arc = { id = "", size = Vector2.new(1024, 1024), layout = L.Grid4x4, mode = M.OneShot, frames = 16, tint = "tint" },
	ink_swirl = { id = "", size = Vector2.new(1024, 1024), layout = L.Grid4x4, mode = M.OneShot, frames = 16, tint = "baked" },
	feather = { id = "", size = Vector2.new(512, 512), layout = L.Grid4x4, mode = M.Loop, frames = 16, tint = "tint" },
	speed_line = { id = "", size = Vector2.new(256, 256), tint = "tint" },
	ring_wave = { id = "", size = Vector2.new(512, 512), tint = "tint" },
	ring_snap = { id = "", size = Vector2.new(256, 256), tint = "tint" },
	glow_step = { id = "", size = Vector2.new(256, 256), tint = "tint" },
	rays_fan = { id = "", size = Vector2.new(1024, 1024), layout = L.Grid4x4, mode = M.OneShot, frames = 16, tint = "tint" },
	beam_core = { id = "", size = Vector2.new(256, 64), beam = true, tint = "tint" },
	-- egg crack decals (Decal.Texture, cumulative stages)
	crack_1 = { id = "", size = Vector2.new(512, 512), tint = "tint" },
	crack_2 = { id = "", size = Vector2.new(512, 512), tint = "tint" },
	crack_3 = { id = "", size = Vector2.new(512, 512), tint = "tint" },
}

local VfxAssets = { tex = tex }

-- "rbxassetid://..." for a texture key, or nil while its id is empty / the key is unknown
function VfxAssets.id(key: string?): string?
	if not key then return nil end
	local t = tex[key]
	if not t or t.id == "" then return nil end
	if string.match(t.id, "^%d+$") then return "rbxassetid://" .. t.id end
	return t.id
end

function VfxAssets.has(key: string?): boolean
	return VfxAssets.id(key) ~= nil
end

-- every uploaded id (for ContentProvider:PreloadAsync)
function VfxAssets.all(): { string }
	local out = {}
	for key in tex do
		local id = VfxAssets.id(key)
		if id then table.insert(out, id) end
	end
	return out
end

return VfxAssets
