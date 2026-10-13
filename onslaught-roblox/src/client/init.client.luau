--[[
	Onslaught client entry: one ScreenGui, the lobby or a match, and the server connection.
	The server is authoritative. This script only renders snapshots and sends commands.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net).init()
local Snapshot = require(ReplicatedStorage.Shared.Snapshot)
local GAME = require(ReplicatedStorage.Shared.Onslaught.Data)
local X = require(ReplicatedStorage.Shared.Onslaught.Expansion)
local Ui = require(script.Ui)
local Board = require(script.Board)
local MatchUI = require(script.MatchUI)
local LobbyUI = require(script.LobbyUI)

local player = Players.LocalPlayer
local pid = tostring(player.UserId)
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

local gui = Instance.new("ScreenGui")
gui.Name = "Onslaught"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local scale = Instance.new("UIScale")
scale.Parent = gui

local profile = nil
local role = "lobby"
local lobby = nil
local match = nil -- { info, D, board, ui, summary }
local backdrop = nil -- a board behind the lobby

-- ================================================================ helpers
local function request(op: string, ...)
	local ok, res = pcall(function(...)
		return Net.get("Request"):InvokeServer(op, ...)
	end, ...)
	return if ok then res else { ok = false, msg = "Connection problem." }
end
local function send(op: string, ...)
	Net.get("Action"):FireServer(op, ...)
end

local toastF = Ui.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(460, 160), ZIndex = 50, Parent = gui })
Ui.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom).Parent = toastF
local function toast(msg: string, color: Color3?)
	if match and match.ui then
		match.ui:toast(msg, color)
		return
	end
	local f = Ui.new("Frame", { BackgroundColor3 = Ui.C.panel2, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 50, Parent = toastF })
	Ui.corner(8).Parent = f
	Ui.stroke(color or Ui.C.line).Parent = f
	Ui.pad(12, 0).Parent = f
	Ui.text(msg, 13, Ui.C.ink, Ui.BOLD, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 51, Parent = f })
	task.delay(3.2, function()
		f:Destroy()
	end)
end

local function fitScale()
	local vp = Workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.62, 1.15)
end
fitScale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)

-- ================================================================ lobby
local function showLobby()
	if match then
		match.ui:destroy()
		match.board:destroy()
		match = nil
	end
	if not backdrop then
		backdrop = Board.new(GAME.maps.map1)
	end
	if not lobby then
		lobby = LobbyUI.new({
			gui = gui, request = request, userId = player.UserId, toast = toast,
			profile = function()
				return profile
			end,
		})
	end
	lobby:setVisible(true)
	lobby:render()
end

-- ================================================================ match
local function skinOf(info)
	local by = {}
	for _, r in info.roster or {} do
		by[r.pid] = r.skin or "default"
	end
	return function(owner)
		return by[owner] or "default"
	end
end

local function startMatch(info)
	if match and match.info.seed == info.seed and match.info.map == info.map then
		match.info.roster, match.info.host = info.roster, info.host -- same run: someone joined or left
		match.ui.ctx.info = match.info
		return
	end
	if match then
		match.ui:destroy()
		match.board:destroy()
	end
	if lobby then
		lobby:setVisible(false)
	end
	if backdrop then
		backdrop:destroy()
		backdrop = nil
	end
	local D = if info.plus then X.data(GAME, info.hostLoadout) else GAME
	local board = Board.new(D.maps[info.map])
	match = { info = info, D = D, board = board }
	match.ui = MatchUI.new({
		gui = gui, board = board, D = D, info = info, pid = pid, send = send, request = request,
		profile = function()
			return profile
		end,
		onLeave = function()
			request("quitMatch")
		end,
	})
	match.skinOf = skinOf(info)
end

-- ================================================================ events
Net.get("Event").OnClientEvent:Connect(function(kind: string, payload)
	if kind == "hello" then
		role, profile = payload.role, payload.profile
		if role == "lobby" then
			showLobby()
		else
			toast("Waiting for your party…")
		end
	elseif kind == "profile" then
		profile = payload
		if lobby and not match then
			lobby:render()
		end
	elseif kind == "parties" then
		if lobby then
			lobby:setParties(payload)
		end
	elseif kind == "matchInfo" then
		startMatch(payload)
	elseif kind == "turrets" then
		if match then
			match.ui:setTurrets(payload)
			match.board:setTurrets(payload, function(k, stat)
				return MatchUI.upMax(match.D, k, stat)
			end, match.skinOf)
		end
	elseif kind == "queue" then
		if match then
			match.ui.queues = match.ui.queues or {}
			match.ui.queues[payload.id] = payload.list
		end
	elseif kind == "toast" then
		toast(payload.text, if payload.bad then Ui.C.bad else nil)
	elseif kind == "actionFailed" then
		toast(payload.msg, Ui.C.bad)
	elseif kind == "rewards" then
		if match then
			match.summary = payload
		end
	elseif kind == "matchEnded" then
		if match then
			local m = match
			task.delay(0.6, function() -- let the rewards arrive first
				if match == m then
					m.ui:showEnd(payload, m.summary)
				end
			end)
		end
	elseif kind == "toLobby" then
		showLobby()
	end
end)

Net.get("State").OnClientEvent:Connect(function(buf: buffer, header)
	if not match then
		return
	end
	local snap = Snapshot.decode(buf)
	match.board:pushSnapshot(snap)
	local m = match
	task.delay(0.1, function() -- effects play in step with the interpolated picture
		if match == m then
			m.board:playFx(snap.fx)
		end
	end)
	match.ui:onFx(snap.fx)
	match.ui:setDyn(snap.turrets)
	match.ui:setHeader(header)
end)

local lastVp = Vector2.zero
RunService.RenderStepped:Connect(function(dt)
	local vp = Workspace.CurrentCamera.ViewportSize
	if match then
		if vp ~= lastVp or match.fitted ~= true then
			lastVp = vp
			match.fitted = true
			local ins = match.ui:insets()
			local s = scale.Scale
			match.board:fitCamera({ ins[1] * s, ins[2] * s, ins[3] * s, ins[4] * s })
		end
		match.board:render(dt)
		match.ui:update(dt)
	elseif backdrop then
		if vp ~= lastVp or not backdrop.fitted then
			lastVp = vp
			backdrop.fitted = true
			backdrop:fitCamera({ 0, 0, 0, 0 })
		end
		backdrop:render(dt)
	end
end)
