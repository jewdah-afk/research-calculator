--!nonstrict
-- SoundBoard (dev only, opened from the dev bar "SOUNDS"): pick every UI sound by ear. One row per Sfx event with up
-- to three candidates (UI/SfxCandidates): A / B / C play that candidate through the real Sfx path (same category,
-- volume and pitch rules); USE makes it the event's sound live (Sfx.setId) and saves the pick (server dev DataStore
-- key, sent back as the PeckwoodSfxPicks player attribute, so it survives rejoining). COPY TABLE prints the IDS
-- table to the output, ready to commit into Sfx.luau.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Render = require(script.Parent.Figma.Render)
local FKit = require(script.Parent.Figma.FKit)
local Sfx = require(script.Parent.Sfx)
local Candidates = require(script.Parent.SfxCandidates)

local SoundBoard = {}
SoundBoard.refresh = function() end   -- set by build
local PAL = FKit.PAL
local Hud

local function add(parent, n) parent.k = parent.k or {}; table.insert(parent.k, n); return n end

local W, H = 980, 860
local ROW, GAP = 52, 6
function SoundBoard.build(parent, hud)
	Hud = hud
	local L = FKit.layout()
	local win = FKit.WINDOWn(L, "Window / Sound Board", W, H, "crow", "SOUND BOARD")
	add(win, FKit.BODYn(L, "A / B / C / D plays a candidate through the real Sfx path.  USE picks it (live + saved).", 15, { x = 24, y = 88, w = 700, col = "c9d2e3" }))
	add(win, FKit.BTNn(L, "btn/copy table", W - 24 - 190, 80, 190, 44, PAL.blue, "COPY TABLE", { size = 16, d = 5 }))
	local listNode = add(win, FKit.WELLn(L, "events", 16, 136, W - 32, H - 136 - 16, { op = 0.6 }))
	FKit.OUTLINEn(L, win)
	local ui = FKit.build(L, win, parent)
	ui.on("btn/copy table", function()
		local src = Sfx.dump()
		print("[Peckwood] Sfx IDS (paste into UI/Sfx.luau):\n" .. src)
		if Hud then Hud.toast("IDS table printed to the output", "info", "settings") end
	end)
	-- the event rows live in a scrolling list inside the well
	local well = ui.find("events")
	local sf = Render.new("ScrollingFrame", { Name = "rows", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 1, -8), CanvasSize = UDim2.fromOffset(0, #Sfx.ORDER * (ROW + GAP) + 8), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 5 }, well)
	Render.styleScroll(sf, "0a0e14")
	local rowW = listNode.w - 24
	local rowsApi = {}
	for i, ev in Sfx.ORDER do
		local RL = FKit.layout()
		local row = FKit.STEELn(RL, "event/" .. ev, 0, 0, rowW, ROW, { cols = { "29313e", "1b2129" } })
		add(row, FKit.Tn(RL, ev, 17, { name = "event", x = 12, y = 4, w = 245 }))
		add(row, FKit.BODYn(RL, "id 0", 12, { name = "current", x = 12, y = 28, w = 250, col = "8d94a3" }))
		local cands = Candidates[ev] or {}
		for c = 1, 4 do
			local x = 270 + (c - 1) * 160
			local has = cands[c] ~= nil and cands[c] ~= 0
			local letter = string.sub("ABCD", c, c)
			add(row, FKit.BTNn(RL, "btn/play " .. c, x, 6, 64, 40, if has then PAL.violet else PAL.steel, if has then letter else "-", { size = 18, d = 4, glyph = nil }))
			add(row, FKit.BTNn(RL, "btn/use " .. c, x + 70, 6, 76, 40, PAL.steel, "USE", { size = 15, d = 4 }))
		end
		local r = FKit.build(RL, row, sf)
		r.root.Position = UDim2.fromOffset(8, 8 + (i - 1) * (ROW + GAP))
		local api = { ui = r, ev = ev, cands = cands }
		for c = 1, 4 do
			r.on("btn/play " .. c, function()
				local id = cands[c]
				if id and id ~= 0 then Sfx.audition(ev, id) else Sfx.denied() end
			end)
			r.on("btn/use " .. c, function(inst)
				local id = cands[c]
				if not (id and id ~= 0) then Sfx.denied(); return end
				Sfx.setId(ev, id)
				Sfx.toggle(true)
				Sfx.audition(ev, id)
				if Hud then Hud.act("sfxpick", ev, id, inst) end
				SoundBoard.refresh()
			end)
		end
		rowsApi[ev] = api
	end
	-- the chosen candidate's USE key is green; the current id is shown under the event name
	function SoundBoard.refresh()
		for ev, api in rowsApi do
			local cur = Sfx.IDS[ev] or 0
			local cl = api.ui.find("current")
			if cl then Render.setText(cl, if cur ~= 0 then "id " .. cur else "id 0  (keyboard fallback)") end
			for c = 1, 4 do
				local k = api.ui.find("btn/use " .. c)
				local chosen = cur ~= 0 and api.cands[c] == cur
				if k then
					for _, part in { { k:FindFirstChild("face"), nil }, { k:FindFirstChild("lip"), 0.58 } } do
						local f = part[1]
						if f then
							for _, g in f:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
							f.BackgroundColor3 = Color3.new(1, 1, 1); f.BackgroundTransparency = 0
							Render.gradient(f, FKit.vgrad(if chosen then PAL.green else PAL.steel, part[2]), 1)
						end
					end
				end
			end
		end
	end
	SoundBoard.refresh()
	local plr = Players.LocalPlayer
	if plr then plr:GetAttributeChangedSignal("PeckwoodSfxPicks"):Connect(function() task.defer(SoundBoard.refresh) end) end
	ui.update = function() SoundBoard.refresh() end
	local _ = RS
	return ui, W, H
end

return SoundBoard
