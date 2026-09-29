local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")

local RuneFormulas = {}




--[ BASIC RUNE ]-- 
function RuneFormulas.Basic_Energy(Amount : number) -- Basic Rune >> Energy Boost
	local Value = 1
	
	local Boost = 0.005 * Amount
	Value += Boost
	
	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Unique_Energy(Amount : number) -- Unique Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost
	
	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Rare_Flame(Amount : number) -- Rare Rune >> Flame Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost
	
	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Ascendant_Energy(Amount : number) -- Ascendant Rune >> Energy Boost
	local Value = 1

	local Boost = 0.075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Ascendant_Flame(Amount : number) -- Ascendant Rune >> Flame Boost
	local Value = 1

	local Boost = 0.015 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Exotic_Energy(Amount : number) -- Exotic Rune >> Energy Boost
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Exotic_Flame(Amount : number) -- Exotic Rune >> Flame Boost
	local Value = 1

	local Boost = 0.6 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Exotic_Power(Amount : number) -- Exotic Rune >> Power Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Unknown_RealmPoints(Amount : number) -- Unknown Rune >> RealmPoints Boost
	if Amount <= 0 then return 1 end
	
	local Value = 1
	
	Value = 2.5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Wavecaller_Spheres(Amount : number) -- Unknown Rune >> 
	if Amount <= 0 then return 1 end
	
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Unknown_Damage(Amount : number) -- Unknown Rune >> Damage Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Unknown_RuneLuck(Amount : number) -- Unknown Rune >> Rune Luck Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost
	
	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Mystery_RobuxTokenCD(Amount : number) -- Refract Rune >> RuneSpeed Boost
	return math.clamp(0.1 * Amount, 0, 60)
end

function RuneFormulas.Mystery_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end




--[ COLOR RUNE ]--
function RuneFormulas.Tinted_Energy(Amount : number) -- Tinted Rune >> Energy Boost
	local Value = 1

	local Boost = 0.2 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Colorful_Energy(Amount : number) -- Colorful Rune >> Energy Boost
	local Value = 1

	local Boost = 0.4 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Colorful_Flesh(Amount : number) -- Colorful Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Radiance_Energy(Amount : number) -- Radiance Rune >> Energy Boost
	local Value = 1

	local Boost = 0.3 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Radiance_Power(Amount : number) -- Radiance Rune >> Power Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Neon_Energy(Amount : number) -- Neon Rune >> Energy Boost
	local Value = 1

	local Boost = 0.75 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Neon_Damage(Amount : number) -- Neon Rune >> Damage Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Neon_RealmPoints(Amount : number) -- Neon Rune >> RealmPoints Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2.5)
end

function RuneFormulas.Chrome_Energy(Amount : number) -- Chrome Rune >> Energy Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 2 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Chrome_Flame(Amount : number) -- Chrome Rune >> Flame Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Chrome_Orbs(Amount : number) -- Chrome Rune >> Orbs Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Chrome_Prisms(Amount : number) -- Chrome Rune >> Prisms Boost
	local Value = 1

	local Boost = 0.15 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Rainbow_Flame(Amount : number) -- Rainbow Rune >> Power Boost
	local Value = 1

	local Boost = 5.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Rainbow_Damage(Amount : number) -- Rainbow Rune >> Damage Boost
	local Value = 1

	local Boost = 1.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Rainbow_Orbs(Amount : number) -- Rainbow Rune >> Orbs Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 2 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Rainbow_RuneLuck(Amount : number) -- Rainbow Rune >> RuneLuck Boost
	local Value = 1

	local Boost = 0.04 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.2)
end

function RuneFormulas.Vibrance_Energy(Amount : number) -- Vibrance Rune >> Energy Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 24 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Vibrance_Flame(Amount : number) -- Vibrance Rune >> Flame Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 14 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Vibrance_Flesh(Amount : number) -- Vibrance Rune >> Flesh Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 2 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Vibrance_Orbs(Amount : number) -- Vibrance Rune >> Orbs Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 6.5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Vibrance_RuneSpeed(Amount : number) -- Vibrance Rune >> RuneSpeed Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end


function RuneFormulas.Bloom_Spheres(Amount : number) -- Dreamscape Rune >> Spheres Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 1e3 * Amount

	return math.clamp(Value, 1, 1e300)
end



--[ NATURE RUNE ]--
function RuneFormulas.Oak_Energy(Amount : number) -- Oak Rune >> Energy Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 2 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Oak_Power(Amount : number) -- Oak Rune >> Power Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Moss_Flame(Amount : number) -- Moss Rune >> Flame Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 1.5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Moss_Damage(Amount : number) -- Moss Rune >> Damage Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Dew_Energy(Amount : number) -- Dew Rune >> Energy Boost
	local Value = 1

	local Boost = 3 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Dew_Orbs(Amount : number) -- Dew Rune >> Orbs Boost
	local Value = 1

	local Boost = 0.35 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Dew_RealmPoints(Amount : number) -- Dew Rune >> RealmPoints Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Skylight_Flame(Amount : number) -- Skylight Rune >> Flame Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 2.5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Skylight_Power(Amount : number) -- Skylight Rune >> Power Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 1 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Skylight_Prisms(Amount : number) -- Skylight Rune >> Prisms Boost
	local Value = 1

	local Boost = 0.0003 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Nightshade_Orbs(Amount : number) -- Nightshade Rune >> Orbs Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value += (0.1 * Amount)

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Nightshade_RealmPoints(Amount : number) -- Nightshade Rune >> RealmPoints Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Nightshade_Spheres(Amount : number) -- Nightshade Rune >> Spheres Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Nightshade_Flesh(Amount : number) -- Nightshade Rune >> Flesh Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Wavecaller_Power(Amount : number) -- Wavecaller Rune >> Power Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 2 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Wavecaller_Flesh(Amount : number) -- Wavecaller Rune >> Flesh Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value += (0.5 * Amount)

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Wavecaller(Amount : number) -- Wavecaller Rune >> Spheres Boost
	local Value = 1

	local Boost = 0.75 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Thunderstorm_Energy(Amount : number) -- Thunderstorm Rune >> Energy Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 5 * Amount
	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Thunderstorm_Flame(Amount : number) -- Thunderstorm Rune >> Flame Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Thunderstorm_Power(Amount : number) -- Thunderstorm Rune >> Power Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Thunderstorm_Damage(Amount : number) -- Thunderstorm Rune >> Damage Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 2.5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Thunderstorm_Flesh(Amount : number) -- Thunderstorm Rune >> Flesh Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 3.5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Thunderstorm_Orbs(Amount : number) -- Thunderstorm Rune >> Orbs Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 7.5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Earthvein_Energy(Amount : number) -- Earthvein Rune >> Energy Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 25 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Earthvein_Orbs(Amount : number) -- Earthvein Rune >> Orbs Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 5 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Earthvein_RealmPoints(Amount : number) -- Earthvein Rune >> RealmPoints Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 3 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Earthvein_RuneSpeed(Amount : number) -- Skylight Rune >> RuneSpeed Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.15)
end

function RuneFormulas.Emberglow_Flame(Amount : number) -- Emberglow Rune >> Flame Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 1e3 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Emberglow_Flesh(Amount : number) -- Emberglow Rune >> Flesh Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 500 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Emberglow_Orbs(Amount : number) -- Emberglow Rune >> Orbs Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 2.5e3 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Emberglow_RuneBulk(Amount : number) -- Emberglow Rune >> RuneBulk Boost
	local Value = 0

	local Boost = 1 * Amount 
	Value += Boost

	return math.clamp(Value, 0, 5)
end

function RuneFormulas.Dreamscape_Energy(Amount : number) -- Dreamscape Rune >> Energy Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 5e4 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Dreamscape_Damage(Amount : number) -- Dreamscape Rune >> Damage Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 1e3 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Dreamscape_Spheres(Amount : number) -- Dreamscape Rune >> Spheres Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 1e4 * Amount

	return math.clamp(Value, 1, 1e300)
end



--[ GLOBAL RUNE ]--
function RuneFormulas.Lightmatter_Energy(Amount : number) -- Lightmatter Rune >> Energy Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 20)
end

function RuneFormulas.Lightmatter_Flame(Amount : number) -- Lightmatter Rune >> Flame Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 20)
end

function RuneFormulas.Lightmatter_Power(Amount : number) -- Lightmatter Rune >> Power Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 20)
end

function RuneFormulas.Lightmatter_RealmPoints(Amount : number) -- Lightmatter Rune >> RP Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 20)
end

function RuneFormulas.Lightmatter_Flesh(Amount : number) -- Lightmatter Rune >> Flesh Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 20)
end

function RuneFormulas.Antimatter_RuneBulk(Amount : number) -- Antimatter Rune >> RuneBulk Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 0, 15)
end

function RuneFormulas.Antimatter_RuneLuck(Amount : number) -- Antimatter Rune >> RuneLuck Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Antimatter_TicketChance(Amount : number) -- Antimatter Rune >> Ticket Chance Boost
	local Value = 500 * Amount
	return math.clamp(Value, 0, 2500)
end

function RuneFormulas.Darkmatter_Energy(Amount : number) -- Darkmatter Rune >> Stats Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 12.5)
end

function RuneFormulas.Darkmatter_Flame(Amount : number) -- Darkmatter Rune >> Stats Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 12.5)
end

function RuneFormulas.Darkmatter_Power(Amount : number) -- Darkmatter Rune >> Stats Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 12.5)
end

function RuneFormulas.Darkmatter_RealmPoints(Amount : number) -- Darkmatter Rune >> Stats Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 12.5)
end

function RuneFormulas.Darkmatter_Flesh(Amount : number) -- Darkmatter Rune >> Stats Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 12.5)
end

function RuneFormulas.Darkmatter_Prisms(Amount : number) -- Darkmatter Rune >> Stats Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 12.5)
end

function RuneFormulas.Darkmatter_Orbs(Amount : number) -- Darkmatter Rune >> Stats Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 12.5)
end

function RuneFormulas.Darkmatter_Spheres(Amount : number) -- Darkmatter Rune >> Stats Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 12.5)
end


function RuneFormulas.Darkmatter_Tickets(Amount : number) -- Darkmatter Rune >> Tickets Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end



--[ POLYCHROME RUNE ]--
function RuneFormulas.Glow_Energy(Amount : number) -- Glow Rune >> Energy Boost
	local Value = 1

	local Boost = 5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Glow_RealmPoints(Amount : number) -- Glow Rune >> RealmPoints Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Shimmer_Orbs(Amount : number) -- Shimmer Rune >> Orbs Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Shimmer_Spheres(Amount : number) -- Shimmer Rune >> Orbs Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Shimmer_Prisms(Amount : number) -- Shimmer Rune >> Prisms Boost
	local Value = 1

	local Boost = 0.0002 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Iridium_RealmPoints(Amount : number) -- Iridium Rune >> RealmPoints Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Iridium_Orbs(Amount : number) -- Iridium Rune >> Orbs Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Iridium_Flesh(Amount : number) -- Iridium Rune >> Flesh Boost
	if Amount <= 0 then return 1 end

	local Value = 1

	Value = 1.3 * Amount

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Iridium_RuneLuck(Amount : number) -- Iridium Rune >> RuneLuck Boost
	local Value = 1

	local Boost = 0.0025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.5)	
end

function RuneFormulas.Spectrum_Prisms(Amount : number) -- Spectrum Rune >> Prisms Boost
	local Value = 1

	local Boost = 0.15 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Spectrum_Flesh(Amount : number) -- Spectrum Rune >> Flesh Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Prismatic_Walkspeed(Amount : number) -- Prismatic Rune >> Walkspeed Boost
	local Value = 1

	local Boost = 3 * Amount
	Value += Boost

	return math.clamp(Value, 1, 15)	
end

function RuneFormulas.Prismatic_Tickets(Amount : number) -- Prismatic Rune >> Tickets Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)	
end

function RuneFormulas.Prismatic_RealmPoints(Amount : number) -- Prismatic Rune >> RealmPoints Boost
	local Value = 1

	local Boost = 250 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Prismatic_RuneBulk(Amount : number) -- Prismatic Rune >> RuneBulk Boost
	local Value = 0

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 0, 10)
end

function RuneFormulas.Refraction_Prisms(Amount : number) -- Refract Rune >> Prisms Boost
	local Value = 1

	local Boost = 10 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Refraction_RuneSpeed(Amount : number) -- Refract Rune >> RuneSpeed Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Refraction_RobuxTokenCD(Amount : number) -- Refract Rune >> RuneSpeed Boost
	return math.clamp(5 * Amount, 0, 60)
end

function RuneFormulas.Refraction_ChestChance(Amount : number) -- Refract Rune >> RuneSpeed Boost
	if Amount < 1 then return 0 end
	return math.clamp(250 * Amount, 0, 3000)
end

function RuneFormulas.Aether_RuneLuck(Amount : number) -- Aether Rune >> RuneLuck Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10)
end

function RuneFormulas.Vexed_Tickets(Amount : number) -- Hailstorm Rune >> Tickets Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end



--[ CRYO RUNE ]--
function RuneFormulas.Mist_Spheres(Amount : number) -- Mist Rune >> Spheres Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Breeze_Droplets(Amount : number) -- Breeze Rune >> Droplets Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Breeze_Water(Amount : number) -- Breeze Rune >> Water Boost
	local Value = 1

	local Boost = 0.0001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Shiver_Water(Amount : number) -- Shiver Rune >> Water Boost
	local Value = 1

	local Boost = 0.075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Shiver_Prisms(Amount : number) -- Shiver Rune >> Prisms Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Shiver_ArcticPoints(Amount : number) -- Shiver Rune >> ArcticPoints Boost
	local Value = 1

	local Boost = 0.02 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Frigid_Droplets(Amount : number) -- Frigid Rune >> Droplets Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Frigid_Ice(Amount : number) -- Frigid Rune >> Ice Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Frigid_ArcticPoints(Amount : number) -- Frigid Rune >> ArcticPoints Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Frigid_RuneLuck(Amount : number) -- Frigid Rune >> RuneLuck Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.15)
end

function RuneFormulas.Icequake_Water(Amount : number) -- Icequake Rune >> Water Boost
	local Value = 1

	local Boost = 5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Icequake_Ice(Amount : number) -- Icequake Rune >> Ice Boost
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Icequake_Prisms(Amount : number) -- Icequake Rune >> Prisms Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Icequake_Spheres(Amount : number) -- Icequake Rune >> Spheres Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Icequake_DropletsCD(Amount : number) -- Icequake Rune >> Droplets CD
	return math.clamp(0.001 * Amount, 0, 0.4)
end


--[ ARCTIC RUNE ]--
function RuneFormulas.Snowflake_Spheres(Amount : number) -- Snowflake Rune >> Spheres Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Snowflake_Droplets(Amount : number) -- Snowflake Rune >> Droplets Boost
	local Value = 1

	local Boost = 0.0001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Snow_Water(Amount : number) -- Snow Rune >> Water Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Snow_Ice(Amount : number) -- Snow Rune >> Ice Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Icy_Spheres(Amount : number) -- Icy Rune >> Spheres Boost
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Icy_Prisms(Amount : number) -- Icy Rune >> Prisms Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost
	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Icy_Chromium(Amount : number) -- Icy Rune >> Chromium Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Avalanche_Water(Amount : number) -- Avalanche Rune >> Water Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Avalanche_Ice(Amount : number) -- Avalanche Rune >> Ice Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Avalanche_ArcticPoints(Amount : number) -- Avalanche Rune >> ArcticPoints Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Avalanche_Icicles(Amount : number) -- Avalanche Rune >> Icicles Boost
	local Value = 1

	local Boost = 0.0001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Hailstorm_Chromium(Amount : number) -- Hailstorm Rune >> Chromium Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Hailstorm_Tickets(Amount : number) -- Hailstorm Rune >> Tickets Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Frostveil_Droplets(Amount : number) -- Frostveil Rune >> Droplets Boost
	local Value = 1

	local Boost = 4 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Frostveil_Prisms(Amount : number) -- Frostveil Rune >> Prisms Boost
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Frostveil_ArcticPoints(Amount : number) -- Frostveil Rune >> ArcticPoints Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Frostveil_Icicles(Amount : number) -- Frostveil Rune >> Icicles Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Subzero_RuneSpeed(Amount : number) -- Subzero Rune >> RuneSpeed Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Subzero_Chromium(Amount : number) -- Subzero Rune >> Chromium Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Subzero_Water(Amount : number) -- Subzero Rune >> Water Boost
	local Value = 1

	local Boost = 6.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Blizzard_RuneBulk(Amount : number) -- Blizzard Rune >> RuneBulk Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.3)
end



--[ ULTRA RUNE ]--
function RuneFormulas.Omniscient_Spheres(Amount : number) -- Omniscient Rune >> Spheres Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Omniscient_Droplets(Amount : number) -- Omniscient Rune >> Droplets Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Omniscient_Water(Amount : number) -- Omniscient Rune >> Water Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Omnipotent_Water(Amount : number) -- Omnipotent Rune >> Water Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Omnipotent_Ice(Amount : number) -- Omnipotent Rune >> Ice Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Omnipotent_ArcticPoints(Amount : number) -- Omnipotent Rune >> ArcticPoints Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Almighty_Droplets(Amount : number) -- Almighty Rune >> Droplets Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Almighty_Water(Amount : number) -- Almighty Rune >> Water Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Almighty_ArcticPoints(Amount : number) -- Almighty Rune >> ArcticPoints Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Almighty_Ice(Amount : number) -- Almighty Rune >> ice Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Almighty_Icicles(Amount : number) -- Almighty Rune >> Icicles Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Almighty_RuneSpeed(Amount : number) -- Almighty Rune >> RuneLuck Boost
	local Value = 1

	local Boost = 0.0075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Almighty_Chromium(Amount : number) -- Almighty Rune >> Chromium Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Boundless_RuneBulk(Amount : number) -- Boundless Rune >> RuneBulk Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Boundless_Tickets(Amount : number) -- Boundless Rune >> Tickets Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Boundless_RuneSpeed(Amount : number) -- Boundless Rune >> RuneSpeed Boost
	local Value = 1

	local Boost = 0.075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 15)
end





--[ 5M Beginner ]--
function RuneFormulas.Noob_Energy(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Intermediate_Flame(Amount : number) -- Intermediate Rune >> Flame Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end


function RuneFormulas.Intermediate_Tickets(Amount : number) -- Intermediate Rune >> Tickets Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.2)
end

function RuneFormulas.Experienced_Energy(Amount : number)
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Experienced_Power(Amount : number)
	local Value = 1

	local Boost = 0.3 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Experienced_Damage(Amount : number)
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end


function RuneFormulas.Master_Flame(Amount : number)
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end


function RuneFormulas.Master_Flesh(Amount : number)
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end


function RuneFormulas.Master_RuneLuck(Amount : number)
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.25)
end

function RuneFormulas.Master_Droplets(Amount : number)
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Champion_Energy(Amount : number)
	local Value = 1

	local Boost = 2 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Champion_Orbs(Amount : number)
	local Value = 1

	local Boost = 0.33 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Champion_Prisms(Amount : number)
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Legend_RealmPoints(Amount : number)
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Legend_Flesh(Amount : number)
	local Value = 1

	local Boost = 2 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Legend_Spheres(Amount : number)
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Legend_Tickets(Amount : number)
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.75)
end

function RuneFormulas.Elite_Orbs(Amount : number)
	local Value = 1

	local Boost = 3 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Elite_Prisms(Amount : number)
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Elite_RuneBulk(Amount : number)
	local Value = 0

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 0, 5)
end

function RuneFormulas.Superstar_Energy(Amount : number)
	local Value = 1

	local Boost  = 1e6 ^ Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end




--[ 5M Beginner ]--
function RuneFormulas.Gilded_Energy(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Gilded_Droplets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Gilded_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.25)
end

function RuneFormulas.Royalty_Flame(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 2 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Royalty_RuneLuck(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.25)
end

function RuneFormulas.Crown_Energy(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Crown_Prisms(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Crown_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Throne_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.5)
end

function RuneFormulas.Throne_ArcticPoints(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Monarch_Droplets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.33 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Monarch_Energy(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 2 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Monarch_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.75)
end

function RuneFormulas.Imperial_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e21)

end

function RuneFormulas.Imperial_Chromium(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Imperial_Orbs(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.1 ^ Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Sovereign_TicketChance(Amount : number) -- Antimatter Rune >> Ticket Chance Boost
	local Value = 250 * Amount
	return math.clamp(Value, 0, 5000)
end

function RuneFormulas.Sovereign_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5000)
end

function RuneFormulas.Kingslayer_RuneLuck(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100)
end

function RuneFormulas.Kingslayer_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100)
end

function RuneFormulas.Kingslayer_Orbs(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 25000 ^ Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end


function RuneFormulas.Thorn_RuneSpeed(Amount : number) -- Thorns Rune >> RuneSpeed Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2.5e4)
end

function RuneFormulas.Thorn_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e10)
end

function RuneFormulas.Divinity_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 2 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100000)
end

function RuneFormulas.Divinity_RuneLuck(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10)
end

function RuneFormulas.Prosperity_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100000)
end

function RuneFormulas.Prosperity_ChestChance(Amount : number) -- Refract Rune >> RuneSpeed Boost
	if Amount < 1 then return 0 end
	return math.clamp(1 * Amount, 0, 6000)
end


function RuneFormulas.Abyssium_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10000)
end

function RuneFormulas.Abyssium_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100)
end


function RuneFormulas.Oscillon_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.3)
end

function RuneFormulas.Oscillon_RuneLuck(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.02 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1000000)
end

function RuneFormulas.HyperFinality_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.00025 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e12)
end

function RuneFormulas.Garmin_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0001 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e51)
end

function RuneFormulas.Etherborn_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 25)
end

function RuneFormulas.Etherborn_RobuxTokenCD(Amount : number) -- Refract Rune >> RuneSpeed Boost
	return math.clamp(30 * Amount, 0, 60)
end

function RuneFormulas.Gleam_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1000)
end

function RuneFormulas.Gleam_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10000)
end

function RuneFormulas.Shyft_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 10 * Amount
	Value += Boost

	return math.clamp(Value, 1, 500000)
end

function RuneFormulas.Shyft_Walkspeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 30)
end

function RuneFormulas.Overlord_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 24 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e8)
end

function RuneFormulas.Overlord_Energy(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.01 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Mirror_RuneSpeed1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 50000)
end

function RuneFormulas.Mirror_RuneSpeed2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 500000)
end


function RuneFormulas.Oblivion_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 50000)
end

function RuneFormulas.Immortality_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0005 ^ Amount
	Value += Boost

	return math.clamp(Value, 1, 1e9)
end

function RuneFormulas.Vanta_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.000015 ^ Amount
	Value += Boost

	return math.clamp(Value, 1, 3e6)
end

function RuneFormulas.Vanta_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Vanta_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.000000000000007 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e39)
end


function RuneFormulas.Frostbite_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100000)
end

function RuneFormulas.Odyssey_RuneBulk1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.000001 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 10000)
end

function RuneFormulas.Odyssey_RuneBulk2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.000065 * Amount
	Value += Boost

	return math.clamp(Value, 1, 50)
end

function RuneFormulas.Odyssey_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0015 * Amount
	Value += Boost

	return math.clamp(Value, 1, 50)
end

function RuneFormulas.Destiny_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10000)
end

function RuneFormulas.Destiny_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0015 * Amount
	Value += Boost

	return math.clamp(Value, 1, 250)
end

function RuneFormulas.Squid_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0015 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 200)
end

function RuneFormulas.Squid_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e12)
end

function RuneFormulas.Array_RuneBulk1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 3500 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2.5e10)
end

function RuneFormulas.Array_RuneBulk2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 25)
end

function RuneFormulas.Array_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 7.5)
end

function RuneFormulas.Cyclone_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1000)
end

function RuneFormulas.Cyclone_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00000075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.2)
end


function RuneFormulas.Primordial_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.3 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10000)
end

function RuneFormulas.Primordial_ChestChance(Amount : number) -- Refract Rune >> RuneSpeed Boost
	if Amount < 1 then return 0 end
	return math.clamp(100 * Amount, 0, 500)
end


function RuneFormulas.Stray_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0002 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 75000)
end

function RuneFormulas.Stray_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.00002 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e32)
end

function RuneFormulas.Triarch_RuneSpeed1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 75)
end

function RuneFormulas.Triarch_RuneSpeed2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 500)
end


function RuneFormulas.Triarch_RuneSpeed3(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00000075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 50000)
end

function RuneFormulas.Disarray_RuneBulk1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 1.0000075 ^ Amount
	Value += Boost

	return math.clamp(Value, 1, 1e12)
end

function RuneFormulas.Disarray_RuneBulk2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0033 * Amount
	Value += Boost

	return math.clamp(Value, 1, 250)
end

function RuneFormulas.Bolt_RuneBulk1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100)
end

function RuneFormulas.Bolt_RuneBulk2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0000005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 250)
end

function RuneFormulas.Zephyr_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Zephyr_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.000000000000001 ^ (Amount/15) ^ (Amount/37.5)
	Value *= Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Dust_Energy(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Dust_Prisms(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Bone_Orbs(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Bone_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.1)
end

function RuneFormulas.Glyph_Droplets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 7.5)
end

function RuneFormulas.Glyph_ArcticPoints(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Glyph_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.33)
end

function RuneFormulas.Sigil_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.015 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2.5)
end

function RuneFormulas.Sigil_RuneLuck(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Ankh_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10)
end

function RuneFormulas.Ankh_ChestChance(Amount : number) -- Refract Rune >> RuneSpeed Boost
	if Amount < 1 then return 0 end
	return math.clamp(50 * Amount, 0, 250)
end

function RuneFormulas.Ankh_TicketChance(Amount : number) -- Antimatter Rune >> Ticket Chance Boost
	local Value = 150 * Amount
	return math.clamp(Value, 0, 1500)
end


function RuneFormulas.Omen_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10)
end

function RuneFormulas.Omen_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Whirl_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 25)
end

function RuneFormulas.Whirl_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1000)
end

function RuneFormulas.Riptide_RuneSpeed1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Riptide_RuneSpeed2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 500)
end

function RuneFormulas.Riptide_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0001 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e34)
end

function RuneFormulas.CosmicDust_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 15)
end

function RuneFormulas.CosmicDust_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.000025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 25)
end

function RuneFormulas.Star_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.000065 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1500)
end

function RuneFormulas.Star_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0001 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Apex_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0005 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1000)
end

function RuneFormulas.Apex_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.00000033 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 25000)
end

function RuneFormulas.Buff_Tickets1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.002 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 5e4)
end


function RuneFormulas.Buff_Tickets2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0004 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e6)
end



function RuneFormulas.Constellation_RuneBulk1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 25)
end

function RuneFormulas.Constellation_RuneBulk2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 25)
end

function RuneFormulas.Torrent_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.000005 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 10000)
end

function RuneFormulas.Sorcerer_RuneSpeed1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100)
end

function RuneFormulas.Sorcerer_RuneSpeed2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1000)
end

function RuneFormulas.Sorcerer_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.00005 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 5e10)
end

function RuneFormulas.Planet_RuneBulk1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 7.5e4 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2.5e13)
end

function RuneFormulas.Planet_RuneBulk2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.000002 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.035)
end

function RuneFormulas.Onyx_RuneSpeed1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.002 * Amount
	Value += Boost

	return math.clamp(Value, 1, 75)
end

function RuneFormulas.Onyx_RuneSpeed2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0000015 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1e5)
end

function RuneFormulas.Strix_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2.5)
end

function RuneFormulas.Liberty_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10)
end

function RuneFormulas.Liberty_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100)
end

function RuneFormulas.Liberty_Hail(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.25)
end

function RuneFormulas.Rocket_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.000002 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 75000)
end

function RuneFormulas.Rocket_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e21)
end

function RuneFormulas.Vanguard_RuneSpeed1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.001 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 12.5)
end

function RuneFormulas.Vanguard_RuneSpeed2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0000000001 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 700)
end

function RuneFormulas.Vanguard_RuneBulk1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0000225 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 4000)
end

function RuneFormulas.Vanguard_RuneBulk2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.0000000000001 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 15000)
end

function RuneFormulas.Eternal_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.4 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Eternal_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.4 * Amount
	Value += Boost

	return math.clamp(Value, 1, 6)
end

function RuneFormulas.Eternal_AllSecret(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.15 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Raze_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 15)
end

function RuneFormulas.Raze_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00003 * Amount
	Value += Boost

	return math.clamp(Value, 1, 450)
end

function RuneFormulas.Raze_Chrome(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0000025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1000)
end

function RuneFormulas.Bozo_BaseChrome(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 0

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 50)
end

function RuneFormulas.Bozo_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Glint_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.000001 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 500)
end

function RuneFormulas.Glint_Chrome1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 100)
end

function RuneFormulas.Glint_Chrome2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.000001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1000)
end

function RuneFormulas.Nexus_Chrome(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end


function RuneFormulas.Mad_Orbs(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Mad_Spheres(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Rage_Chroma(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.5)
end

function RuneFormulas.Rage_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.25)
end

function RuneFormulas.Rage_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 10)
end

function RuneFormulas.Violence_Chroma(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.2 * Amount
	Value += Boost

	return math.clamp(Value, 1, 7.5)
end

function RuneFormulas.Violence_Light(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Violence_Reflection(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2.5)
end

function RuneFormulas.Vehemence_AllSecret(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.25 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Vehemence_RuneBulk(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Malevolence_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.75 * Amount
	Value += Boost

	return math.clamp(Value, 1, 4)
end

function RuneFormulas.Malevolence_AllSecret(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.5 * Amount
	Value += Boost

	return math.clamp(Value, 1, 5)
end

function RuneFormulas.Malevolence_RobuxTokenCD(Amount : number) -- Refract Rune >> RuneSpeed Boost
	return math.clamp(15 * Amount, 0, 45)
end

function RuneFormulas.Hurricane_Tickets(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.033 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e300)
end

function RuneFormulas.Hurricane_Light(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Galaxy_Light(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Galaxy_Chroma(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 1.02 ^ Amount
	Value *= Boost

	return math.clamp(Value, 1, 1000)
end

function RuneFormulas.Axium_Chroma(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Axium_Light(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Axium_Reflection(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Axium_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Mommy_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.001 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Mommy_Shine(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.01 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Mommy_Reflection(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Hyperion_Chroma1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.0005 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Hyperion_Chroma2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.002 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Hyperion_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00025 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1.5)
end

function RuneFormulas.Soup_RuneSpeed1(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00075 * Amount
	Value += Boost

	return math.clamp(Value, 1, 2)
end

function RuneFormulas.Soup_RuneSpeed2(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00015 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Soup_Shine(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.05 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e6)
end

function RuneFormulas.Paracosm_RuneSpeed(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.00002 * Amount
	Value += Boost

	return math.clamp(Value, 1, 3)
end

function RuneFormulas.Paracosm_Light(Amount : number) -- Noob Rune >> Energy Boost
	local Value = 1

	local Boost = 0.1 * Amount
	Value += Boost

	return math.clamp(Value, 1, 1e9)
end

return RuneFormulas





