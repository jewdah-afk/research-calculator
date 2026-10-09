--!nonstrict
-- IconAlias: Figma icon name -> uploaded Roblox image id. 427 icon names are used by the Figma windows, 329 of them
-- are not uploaded yet (their PNGs are in birb-icons/final and birb-icons/final/fish; the list is in
-- roblox/tools/figma_export/icons_to_upload.txt). Until they are uploaded each falls back to the closest painted icon
-- of its family, never to a vector. Upload a PNG, add its id to shared/Icons.luau under the same name, done.
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS:WaitForChild("Peckwood"):WaitForChild("Icons"))

local IconAlias = {}

-- exact fallbacks (first match wins)
local EXACT = {
	egg = "popcorn", egg_golden = "golden", egg_shiny = "golden", up_egg_value = "popcorn", up_egg_speed = "clock",
	up_egg_cap = "popcorn", up_egg_mult = "plume", up_golden_value = "golden", up_silo_cap = "golden", up_plume_value = "plume",
	up_seed_value = "seed", up_magnet_value = "magnet", up_basket_value = "popcorn", up_wing_speed = "wing", up_hatch_speed = "clock",
	up_ore_value = "ore", up_mining_power = "pickaxe", up_sword_power = "sword", up_twig_value = "twig", up_twig_power = "twig",
	up_twig_speed = "clock", up_echo_value = "echo", up_echo_cap = "mushroom",
	stat_heart = "heart", skill_hp = "heart", stat_sword = "sword", skill_damage = "sword", skill_regen = "shield",
	item_full_potion = "heart", item_minor_heal_pot = "heart", item_money_bag = "moneta", legendary_key = "crown",
	item_strange_key = "crown", quest_archivist_book = "index", shop_basket = "popcorn", boost = "clock", night_mode = "clock",
	totem = "trophy", relic = "aura", plank = "wood", golem = "monster", anvil = "pickaxe", minecart = "ore", mine_chest = "chest",
	pickaxe_charged = "pickaxe", crow_miner = "crow", crow_rebirb = "crow", crow_training = "crow", parrot_rebirb = "parrot",
	mythic_sacrifice = "altar", goldore = "ore", ui_stripes = "", ui_halftone = "", lock = "",
}
-- prefix families
local FAMILY = {
	{ "^node_mine_", "pickaxe" }, { "^node_desert_", "golden" }, { "^node_archivist_", "echo" }, { "^node_sparrow_", "sparrow" },
	{ "^node_spirit_", "aura" }, { "^node_seagull", "seagull" }, { "^node_", "seed" }, { "^nest_", "nest" }, { "^riv_", "wood" },
	{ "^saw_", "wood" }, { "^dave_", "dove" }, { "^enemy_", "monster" }, { "^item_", "chest" }, { "^gear_beak", "sword" },
	{ "^gear_armor", "shield" }, { "^gear_aura", "aura" }, { "^ore_", "ore" }, { "^badge_", "skill" }, { "^up_", "skill" },
	{ "^sacrifice_", "altar" }, { "^rod_", "rod" }, { "^shiny_bait_", "bait" }, { "^bait_", "bait" }, { "^hook_", "rod" },
	{ "^lure_", "bait" }, { "^tank_", "aquarium" }, { "^quest_", "quest_scroll" }, { "^shop_", "shop" }, { "^seagull", "seagull" },
}
IconAlias.missing = {}

local cache = {}
function IconAlias.id(name: string?): string
	if not name or name == "" then return "" end
	local c = cache[name]
	if c then return c end
	local id = Icons[name]
	if not id then
		local alt = EXACT[name]
		if alt == nil then
			for _, f in FAMILY do
				if string.find(name, f[1]) then alt = f[2]; break end
			end
		end
		-- anything else in the Figma windows is a fish species icon (birb-icons/final/fish)
		if alt == nil then alt = "fish" end
		id = if alt ~= "" then (Icons[alt] or "") else ""
		IconAlias.missing[name] = true
	end
	cache[name] = id
	return id
end

return IconAlias
