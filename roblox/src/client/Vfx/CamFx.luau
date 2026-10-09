--!nonstrict
-- Vfx/CamFx: camera "feel" layered ON TOP of the game's scripted camera. Main.client.luau builds its camera CFrame
-- every frame (or IslandView.camCF during a cinematic) and passes it through CamFx.apply, so nothing here fights the
-- camera owner: shake = a small translation in the camera plane, push = narrower FOV + the target slid toward the
-- screen centre, flash = a short ColorCorrection pulse. All three cost nothing while idle (apply returns early).
-- Reduced Motion (UserGameSettings / GuiService) turns shake and push off and softens flashes.
local Lighting = game:GetService("Lighting")

local CamFx = {}

local shakes = {} -- { amp (studs), dur, t, seed }
local push = nil -- { target, amount, pull, inT, hold, outT, t }
local flash = nil -- { color, strength, dur, t }
local cc: ColorCorrectionEffect? = nil

local function reducedMotion(): boolean
	local r = false
	pcall(function() r = UserSettings():GetService("UserGameSettings").ReducedMotion end)
	if not r then pcall(function() r = game:GetService("GuiService").ReducedMotionEnabled end) end
	return r
end

-- amp in studs at the subject (our camera sits ~600 studs away with FOV 11: 1 stud is ~8 px at 1080p, default zoom)
function CamFx.shake(amp: number, dur: number?)
	if reducedMotion() then return end
	if #shakes >= 6 then table.remove(shakes, 1) end
	table.insert(shakes, { amp = amp, dur = dur or 0.3, t = 0, seed = math.random() * 100 })
end

-- slow push-in on a world point: FOV narrows by `amount` (0.15 = 15 %) and the point slides `pull` of the way to the
-- screen centre; eases in over inT, holds, eases out over outT. A new push replaces the old one.
function CamFx.push(target: Vector3, amount: number, inT: number, hold: number, outT: number, pull: number?)
	if reducedMotion() then return end
	push = { target = target, amount = amount, pull = pull or 0.55, inT = math.max(0.05, inT), hold = hold, outT = math.max(0.05, outT), t = 0 }
end

function CamFx.release(outT: number?)
	if not push then return end
	local p = push
	local w = CamFx._pushWeight(p)
	-- restart as an ease-out from the current weight
	p.amount *= w; p.pull *= w
	p.inT, p.hold, p.outT, p.t = 0.0001, 0, outT or 0.6, 0.0001
end

function CamFx.flash(color: Color3, strength: number, dur: number?)
	if reducedMotion() then strength *= 0.35 end
	flash = { color = color, strength = strength, dur = dur or 0.4, t = 0 }
end

function CamFx.busy(): boolean
	return #shakes > 0 or push ~= nil or flash ~= nil
end

function CamFx._pushWeight(p): number
	local t = p.t
	if t < p.inT then
		local u = t / p.inT
		return u * u * (3 - 2 * u)
	elseif t < p.inT + p.hold then
		return 1
	end
	local u = math.clamp((t - p.inT - p.hold) / p.outT, 0, 1)
	return 1 - u * u * (3 - 2 * u)
end

local function ensureCC(): ColorCorrectionEffect
	if cc and cc.Parent then return cc end
	local e = Instance.new("ColorCorrectionEffect")
	e.Name = "VfxFlash"
	e.Enabled = false
	e.Parent = Lighting
	cc = e
	return e
end

-- Main.client.luau: cam.CFrame, cam.FieldOfView = Vfx.camera(cf, FOV, dt)
function CamFx.apply(cf: CFrame, fov: number, dt: number): (CFrame, number)
	if #shakes == 0 and not push and not flash then return cf, fov end
	-- flash (ColorCorrection pulse: tint + brightness, stepped decay so it reads as a cel "flash frame")
	if flash then
		flash.t += dt
		local e = ensureCC()
		local u = flash.t / flash.dur
		if u >= 1 then
			e.Enabled = false
			flash = nil
		else
			local k = if u < 0.18 then 1 elseif u < 0.5 then 0.55 else 0.55 * (1 - (u - 0.5) / 0.5)
			local s = flash.strength * k
			e.Enabled = true
			e.TintColor = Color3.new(1, 1, 1):Lerp(flash.color, math.min(1, s * 1.6))
			e.Brightness = s * 0.6
			e.Saturation = s * 0.25
			e.Contrast = 0
		end
	end
	-- push
	if push then
		push.t += dt
		local w = CamFx._pushWeight(push)
		if push.t >= push.inT + push.hold + push.outT then
			push = nil
		else
			fov = fov * (1 - push.amount * w)
			local look = cf.LookVector
			local v = push.target - cf.Position
			local perp = v - look * v:Dot(look)
			cf = cf + perp * (push.pull * w)
		end
	end
	-- shake (smooth noise, decaying; translation only, in the camera plane)
	if #shakes > 0 then
		local off = Vector2.zero
		for i = #shakes, 1, -1 do
			local s = shakes[i]
			s.t += dt
			if s.t >= s.dur then
				table.remove(shakes, i)
			else
				local k = 1 - s.t / s.dur
				local a = s.amp * k * k
				local f = 22
				off += Vector2.new(math.noise(s.seed, s.t * f, 0.5), math.noise(s.seed + 31.7, s.t * f, 0.5)) * a * 1.8
			end
		end
		cf = cf + cf.RightVector * off.X + cf.UpVector * off.Y
	end
	return cf, fov
end

return CamFx
