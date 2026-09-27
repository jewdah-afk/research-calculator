-- Settings for the cutscene system. Tweak these to match the game's UI and feel.

local Config = {}

Config.Dialogue = {
	-- Pixels between the bottom of the screen and the bottom of the dialogue box.
	-- Set this so the box sits just above the inventory bar.
	BottomOffset = 110,
	-- Same, for phones and tablets (their inventory bar is usually taller).
	BottomOffsetTouch = 130,

	MaxWidth = 760,
	WidthScale = 0.9,
	MinHeight = 104,

	-- Typewriter speed and the extra pause after punctuation (seconds).
	CharactersPerSecond = 48,
	PunctuationPause = {
		["."] = 0.28,
		["!"] = 0.28,
		["?"] = 0.28,
		["…"] = 0.4,
		[","] = 0.12,
		[";"] = 0.16,
		[":"] = 0.16,
	},

	-- Optional "blip" while text types, for lines that have no voice acting.
	-- Example: "rbxassetid://1234567890". Leave empty for silence.
	BlipSoundId = "",
	BlipVolume = 0.2,
	BlipEvery = 2,

	PanelColor = Color3.fromRGB(16, 20, 17),
	PanelTransparency = 0.08,
	StrokeColor = Color3.fromRGB(122, 150, 108),
	TextColor = Color3.fromRGB(236, 238, 230),
	PlayerColor = Color3.fromRGB(92, 128, 170),
	DefaultSpeakerColor = Color3.fromRGB(90, 104, 88),

	-- "Note" style lines (letters, notes, signs) look like old paper.
	NoteColor = Color3.fromRGB(233, 221, 190),
	NoteTextColor = Color3.fromRGB(58, 44, 30),
	NoteFont = Enum.Font.Kalam,

	Font = Enum.Font.Gotham,
	BoldFont = Enum.Font.GothamBold,
	TextSize = 21,
	NameSize = 18,
}

Config.Camera = {
	FieldOfView = 55,
	-- Default seconds to glide between shots. 0 = hard cut.
	BlendTime = 0.9,
	-- How tightly the camera follows characters that move during a shot.
	FollowSpeed = 5,
	-- Gentle handheld drift in degrees. 0 turns it off.
	Sway = 0.35,
	-- Soft background blur that keeps focus on the characters.
	DepthOfField = true,
	-- 1 = over the right shoulder, -1 = over the left shoulder.
	ShoulderSide = 1,
	-- When a line is spoken by someone who isn't in the current shot,
	-- automatically move to an over-the-shoulder shot of them.
	AutoShotOnLine = true,
}

Config.Input = {
	AdvanceKeys = { Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA },
	SkipKeys = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonY },
	SkipHoldTime = 1.2,
	-- Let players skip a cutscene they haven't seen before.
	AllowSkipOnFirstView = false,
}

Config.Hide = {
	CoreGui = {
		Enum.CoreGuiType.PlayerList,
		Enum.CoreGuiType.Chat,
		Enum.CoreGuiType.EmotesMenu,
		Enum.CoreGuiType.Health,
	},
	-- Names of the game's own ScreenGuis to hide during cutscenes.
	-- Leave the inventory out so it stays visible under the dialogue box.
	ScreenGuis = {},
	-- Hide other players' characters locally so they don't wander into shots.
	OtherPlayers = true,
}

Config.Actors = {
	-- Default animations for NPC stand-ins (R15). Swap these if the NPCs are R6
	-- or use custom animations. Set to "" to disable.
	IdleAnimation = "rbxassetid://507766388",
	WalkAnimation = "rbxassetid://507777826",
	-- Walk speed for NPCs during cutscenes. Slower reads as calmer.
	WalkSpeed = 9,
}

-- Folder in Workspace holding marker parts (camera positions, walk targets).
Config.MarkersFolder = "CutsceneMarkers"

return Config
