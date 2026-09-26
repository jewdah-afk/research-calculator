--!strict
--[[
	Preload: every image (and the fonts) the client draws, fetched behind the loading screen so the realm, the UI kit
	and the node gems are on the GPU when the screen fades, instead of popping in one by one.

	    local list = Preload.list(view:images())   the map's own tiles first, then the UI kit, the node atlas, the
	                                               sprite atlas, the Shop icons and one label per font face; deduped
	    Preload.run(list, function(done, total) ... end)   yields until every batch is back or the timeout (~20 s)

	ContentProvider:PreloadAsync runs in batches, side by side, each in its own pcall: a batch that errors counts as
	fetched (the image then loads when it shows, as before), and one that never returns cannot hold the game past
	the timeout. The progress counts each asset once, from PreloadAsync's per-asset callback and a batch's return.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent:WaitForChild("Theme"))

local Preload = {}

Preload.BATCH = 8 -- assets per PreloadAsync call
Preload.TIMEOUT = 20 -- seconds before the game goes on without what has not arrived
local POLL = 0.05

export type Options = { batch: number?, timeout: number? }

-- ReplicatedStorage.MilestoneTree.<name>, or nil (a module that fails to load never stops the preload)
local function shared(name: string): any
	local ok, m = pcall(function(): any
		local folder = ReplicatedStorage:WaitForChild("MilestoneTree", 10) :: Instance
		return require(folder:WaitForChild(name, 5) :: ModuleScript) :: any
	end)
	return if ok and type(m) == "table" then m else nil
end

local function isId(v: any): boolean
	return type(v) == "string" and v ~= "" and string.find(v, "^rbx") ~= nil
end

-- the images the client draws beside the map's tiles: the UI kit, the node atlas, the UI sprite atlas and textures of
-- the tier in use, the Shop's pass / product icons
function Preload.images(tier: string?): { string }
	local out: { string } = {}
	local function add(v: any)
		if isId(v) then table.insert(out, v :: string) end
	end
	local uiKit = shared("UiKit")
	if uiKit then add(uiKit.id) end
	local nodeAtlas = shared("NodeAtlas")
	if nodeAtlas then add(nodeAtlas.id) end
	local assets = shared("Assets")
	local t = if tier == "LOW" then "LOW" else "HIGH"
	if assets then
		local sp = assets.sprites
		if type(sp) == "table" and type(sp.atlas) == "table" then add(sp.atlas[t]) end
		local ui = assets.ui
		if type(ui) == "table" then
			if type(ui.atlas) == "table" then add(ui.atlas[t]) end
			if type(ui.textures) == "table" then
				for _, tex in ui.textures do
					if type(tex) == "table" then add(tex.id) end
				end
			end
		end
	end
	local products = shared("Products")
	if products then
		for _, group in { products.passes, products.products } do
			if type(group) == "table" then
				for _, item in group do
					if type(item) == "table" and type(item.icon) == "number" then add("rbxassetid://" .. tostring(item.icon)) end
				end
			end
		end
	end
	return out
end

-- one unparented TextLabel per font face of Theme's type roles: PreloadAsync fetches a label's FontFace
function Preload.fonts(): { Instance }
	local out: { Instance } = {}
	local seen: { [string]: true } = {}
	local names: { string } = {}
	for name in Theme.ROLES do table.insert(names, name) end
	table.sort(names)
	for _, name in names do
		local f = Theme.font(name)
		local k = string.format("%s|%s|%s", tostring(f.Family), tostring(f.Weight), tostring(f.Style))
		if not seen[k] then
			seen[k] = true
			local l = Instance.new("TextLabel")
			l.Name = "Preload_" .. name
			l.FontFace = f
			l.Text = "Aa"
			table.insert(out, l)
		end
	end
	return out
end

-- the whole list, deduped, in order: `first` (the map's tiles, farthest layers first), the other images, the fonts
function Preload.list(first: { string }?, tier: string?): { any }
	local out: { any } = {}
	local seen: { [string]: true } = {}
	local function add(id: string)
		if seen[id] then return end
		seen[id] = true
		table.insert(out, id)
	end
	if first then
		for _, id in first do
			if isId(id) then add(id) end
		end
	end
	for _, id in Preload.images(tier) do add(id) end
	for _, l in Preload.fonts() do table.insert(out, l) end
	return out
end

-- PreloadAsync on `list` in batches (yields); onProgress(done, total) after each asset. Returns done, total and
-- whether it gave up at the timeout.
function Preload.run(list: { any }, onProgress: ((done: number, total: number) -> ())?, opts: Options?): (number, number, boolean)
	local total = #list
	if total == 0 then
		if onProgress then onProgress(0, 0) end
		return 0, 0, false
	end
	local size = math.max(1, (opts and opts.batch) or Preload.BATCH)
	local deadline = os.clock() + ((opts and opts.timeout) or Preload.TIMEOUT)
	local done = 0
	local running = 0
	local over = false
	local function report()
		if onProgress and not over then onProgress(math.min(done, total), total) end
	end
	for i = 1, total, size do
		local batch: { any } = table.move(list, i, math.min(i + size - 1, total), 1, {})
		running += 1
		task.spawn(function()
			local got = 0
			pcall(function()
				ContentProvider:PreloadAsync(batch, function()
					-- an Instance may call back once per content id it holds: never count past the batch
					if got >= #batch then return end
					got += 1
					done += 1
					report()
				end)
			end)
			-- back (or failed): whatever the callback did not count is settled now
			if got < #batch then
				done += #batch - got
				got = #batch
				report()
			end
			running -= 1
		end)
	end
	while running > 0 and os.clock() < deadline do
		task.wait(POLL)
	end
	over = true
	return math.min(done, total), total, running > 0
end

return Preload
