--!strict
--[[
	Input: the raw-input helpers every part of the client shares (plan 2.7, DESIGN.md 3.4).

	    Input.overUi(abs)        true when a HUD, top-bar, marker, panel or overlay element is on top at abs: the map
	                             then ignores the press (and the wheel, so panels can scroll)
	    Input.kind()             "mouse" | "touch" | "gamepad": the last pointer the player used
	    Input.kindChanged        Signal (kind)
	    Input.pointer()          the mouse's last position (abs space; hover tooltips are placed there)
	    Input.HOVER_DELAY, Input.LONG_PRESS, Input.DOUBLE_CLICK

	What blocks: a visible GuiObject under one of those ScreenGuis that is a button, a text box, a scrolling frame,
	Active, or drawn (background less than 95% transparent); never a Root and never something with Interactable off
	(toasts are click-through that way).

	The hold safety itself lives in Recipes.hold (its gate, Recipes.holdGate, is the map's MapInput:busy()).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Signal = require(Core:WaitForChild("Signal"))
local Layout = require(Core:WaitForChild("Layout"))

local Input = {}

Input.HOVER_DELAY = 0.25
Input.LONG_PRESS = 0.45
Input.DOUBLE_CLICK = 0.3
Input.kindChanged = Signal.new() :: Signal.Signal<string>

-- the ScreenGuis whose elements take input over the map
Input.BLOCKING = { HudGui = true, TopbarGui = true, MarkerGui = true, PanelGui = true, OverlayGui = true } :: { [string]: boolean }

local function blocks(o: GuiObject): boolean
	if not o.Visible or o.Name == "Root" then return false end
	local ok, interactable = pcall(function(): boolean return o.Interactable end)
	if ok and interactable == false then return false end
	if o:IsA("GuiButton") or o:IsA("TextBox") or o:IsA("ScrollingFrame") then return true end
	if o.Active then return true end
	return o.BackgroundTransparency < 0.95
end

function Input.overUi(abs: Vector2): boolean
	local lp = Players.LocalPlayer
	local pg = if lp then lp:FindFirstChildOfClass("PlayerGui") else nil
	if pg == nil then return false end
	local ok, list = pcall(function(): { GuiObject }
		return (pg :: PlayerGui):GetGuiObjectsAtPosition(abs.X, abs.Y)
	end)
	if not ok then return false end
	for _, o in list do
		local gui = o:FindFirstAncestorWhichIsA("ScreenGui")
		if gui and gui.Enabled and Input.BLOCKING[gui.Name] and blocks(o) then return true end
	end
	return false
end

local current = "mouse"
local function setKind(k: string)
	if k ~= current then
		current = k
		Input.kindChanged:Fire(k)
	end
end
function Input.kind(): string
	return current
end

local pointerAt = Vector2.zero
function Input.pointer(): Vector2
	return pointerAt
end

local started = false
function Input.start()
	if started then return end
	started = true
	UserInputService.InputChanged:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.MouseMovement then pointerAt = Layout.inputToAbs(io.Position) end
	end)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then current = "touch" end
	UserInputService.LastInputTypeChanged:Connect(function(t: Enum.UserInputType)
		if t == Enum.UserInputType.Touch then
			setKind("touch")
		elseif t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseWheel
			or t == Enum.UserInputType.Keyboard then
			setKind("mouse")
		elseif string.sub(t.Name, 1, 7) == "Gamepad" then
			setKind("gamepad")
		end
	end)
end

return Input
