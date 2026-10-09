--!nonstrict
-- LightingPresets: the world's look as data (spec: BUILD_BIBLE section 3). One preset = static Lighting properties,
-- post effects, atmosphere, terrain grass + wind, and the day-cycle keyframes IslandView interpolates.
--   "golden" = stylized realism (owner pick 2026-10-09: "holy shit, this is Roblox"): PBR light back on, soft
--              shadows, warm sun / cool fill, haze for depth, swaying terrain grass driven by the shared gusts.
--   "toy"    = the previous cel / toy look, kept 1:1 so it can be switched back in one line.
-- Switch: LightingPresets.ACTIVE. Studio QA: PlayerGui:SetAttribute("PeckwoodLook", "toy" | "golden") live.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local P = {}
P.ACTIVE = "golden"

-- KF rows: hour, brightness, outdoorAmbient, ambient, colorShiftTop, fog, tint, exposure, atmosphere colour, decay
P.toy = {
	lighting = { EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0, ShadowSoftness = 0.12, GeographicLatitude = 38 },
	cc = { Saturation = 0.36, Contrast = 0.2, Brightness = 0.03 },
	bloom = { Intensity = 0.3, Size = 28, Threshold = 1.6 },
	sunrays = { Intensity = 0.05, Spread = 0.6 },
	atmo = { Density = 0.2, Offset = 0.08, Glare = 0.2, Haze = 0.35 },
	dof = nil,
	grass = nil,                                   -- Terrain.Decoration off (flat cel ground)
	wind = nil,
	KF = {
		{ 0, 2.3, "9aa8d8", "6a76a8", "8a98c8", "3a4a86", "e2e8ff", 0.55, "3a4a80", "22305a" },
		{ 4.5, 2.3, "9aa8d8", "6a76a8", "8a98c8", "3a4a86", "e2e8ff", 0.55, "3a4a80", "22305a" },
		{ 5.6, 1.6, "8a7aa0", "3d3a55", "ffb38a", "e0a080", "ffe0d0", 0, "ffc8a8", "c890a8" },
		{ 7, 2.1, "8494b4", "485068", "ffe2bf", "d8e2ee", "fff1e0", -0.12, "d2e6fa", "a8cbef" },
		{ 11, 2.4, "8a9cba", "4c546c", "fff8ec", "c8dcf0", "fffaf2", -0.18, "cfe4fa", "9cc4ee" },
		{ 15, 2.35, "8898b6", "4c546c", "fff0d8", "cfe2f2", "fff6ea", -0.16, "d2e6fa", "a8cbef" },
		{ 17.5, 2.6, "8a86aa", "35324c", "ffb46b", "f0c49a", "ffe0c0", -0.06, "ffd6b8", "f0a89a" },
		{ 18.7, 2.2, "9a8ab0", "4a4466", "ff9a6c", "d89088", "ffe0d0", 0.08, "f0a898", "9a6a98" },
		{ 20, 2.3, "9aa8d8", "6a76a8", "8a98c8", "3c4c88", "e2e8ff", 0.55, "3c4c82", "24325c" },
		{ 24, 2.3, "9aa8d8", "6a76a8", "8a98c8", "3a4a86", "e2e8ff", 0.55, "3a4a80", "22305a" },
	},
}

-- stylized realism: with EnvironmentDiffuse/Specular back on the sky lights the scene, so ambients drop (shadows
-- get depth instead of a flat lift) and the sun does the work. Warm key, cool fill, golden hour pushed long.
P.golden = {
	lighting = { EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.65, ShadowSoftness = 0.22, GeographicLatitude = 34 },
	cc = { Saturation = 0.14, Contrast = 0.1, Brightness = 0.015 },
	bloom = { Intensity = 0.55, Size = 30, Threshold = 1.2 },
	sunrays = { Intensity = 0.07, Spread = 0.55 },
	atmo = { Density = 0.3, Offset = 0.14, Glare = 0.4, Haze = 1.4 },
	-- no DepthOfField: its FocusDistance caps at 200 studs and the near-ortho game camera sits ~620 studs away, so
	-- the whole frame would blur. Depth comes from Atmosphere haze instead (BUILD_BIBLE 3.4).
	dof = nil,
	grass = { Decoration = true, GrassLength = 0.75 },
	wind = { dir = Vector3.new(0.8, 0, 0.35), base = 5, gust = 12 },   -- GlobalWind: drives terrain grass + WindAffectsDrag particles
	KF = {
		{ 0, 1.2, "3c4a78", "1e2440", "7c8cc8", "1c2850", "dfe6ff", 0.3, "2c3a6e", "141c3a" },
		{ 4.5, 1.2, "3c4a78", "1e2440", "7c8cc8", "1c2850", "dfe6ff", 0.3, "2c3a6e", "141c3a" },
		{ 5.6, 1.6, "7a6a8c", "2e2a40", "ffb07a", "e8a684", "ffe2cc", 0.1, "ffc29c", "b07a94" },
		{ 7, 2.6, "8c96b0", "36384a", "ffd9a8", "d6e0ec", "fff0dc", -0.05, "d8e6f6", "9cbce4" },
		{ 11, 3.0, "96a6c2", "3a3e52", "fff4e2", "c4daf2", "fffaf0", -0.15, "cfe2fa", "8fb8ea" },
		{ 15, 3.0, "94a2be", "3a3e52", "ffead0", "cadff2", "fff4e6", -0.12, "d2e6fa", "9cc0ec" },
		{ 17.5, 3.2, "8e86a6", "33304a", "ffa860", "f2c49a", "ffd9b0", 0, "ffcfaa", "e89a86" },
		{ 18.7, 2.4, "8a7ca4", "3a3456", "ff8a5c", "d08a86", "ffd6c8", 0.1, "e89e92", "8a5a8e" },
		{ 20, 1.3, "3c4a78", "1e2440", "7c8cc8", "1c2850", "dfe6ff", 0.3, "2c3a6e", "141c3a" },
		{ 24, 1.2, "3c4a78", "1e2440", "7c8cc8", "1c2850", "dfe6ff", 0.3, "2c3a6e", "141c3a" },
	},
}

function P.get() return P[P.ACTIVE] or P.toy end

local function setAll(inst, props) if inst and props then for k, v in props do pcall(function() inst[k] = v end) end end end
local function effect(class, name)
	local e = Lighting:FindFirstChildOfClass(class)
	if not e then e = Instance.new(class); e.Name = name; e.Parent = Lighting end
	return e
end

local loop: RBXScriptConnection? = nil
-- apply the active preset. focus() -> the hen's world position; wind(t) -> 0..1 gust signal (IslandView.wind)
function P.apply(focus: (() -> Vector3?)?, wind: ((number) -> number)?)
	local L = P.get()
	setAll(Lighting, L.lighting)
	setAll(Lighting:FindFirstChildOfClass("ColorCorrectionEffect"), L.cc)   -- the project's base grade (Weather / CamFx add their own)
	setAll(effect("BloomEffect", "Bloom"), L.bloom)
	setAll(effect("SunRaysEffect", "SunRays"), L.sunrays)
	setAll(effect("Atmosphere", "Atmosphere"), L.atmo)
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if L.dof then dof = dof or effect("DepthOfFieldEffect", "TiltShift"); setAll(dof, L.dof); dof.Enabled = true
	elseif dof then dof.Enabled = false end
	local terrain = workspace.Terrain
	setAll(terrain, L.grass or { Decoration = false })
	if not L.wind then pcall(function() workspace.GlobalWind = Vector3.zero end) end
	if loop then loop:Disconnect(); loop = nil end
	if not (L.dof or L.wind) then return end
	local acc = 0
	loop = RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end   -- 10 Hz: focus + wind change slowly
		acc = 0
		local cam = workspace.CurrentCamera
		local f = focus and focus()
		if dof and L.dof and f then dof.FocusDistance = (cam.CFrame.Position - f).Magnitude end
		if L.wind then
			local w = if wind then wind(workspace:GetServerTimeNow()) else 0.5
			pcall(function() workspace.GlobalWind = L.wind.dir.Unit * (L.wind.base + L.wind.gust * w) end)
		end
	end)
end

-- live switch for QA (Studio: PlayerGui:SetAttribute("PeckwoodLook", "toy"))
function P.watch(onChange: () -> ())
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	pg:GetAttributeChangedSignal("PeckwoodLook"):Connect(function()
		local v = pg:GetAttribute("PeckwoodLook")
		if typeof(v) == "string" and P[v] then P.ACTIVE = v; onChange() end
	end)
end

return P
