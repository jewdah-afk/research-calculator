local Framework = require(game.ReplicatedStorage.Framework)

local Players = Framework:GetService("Players")
local EN = Framework:GetLibrary("EternityNum")
local DateJoin = Framework:GetLibrary("DateJoin")
local Thumbnail_Lib = Framework:GetLibrary("Thumbnail")
local Time = Framework:GetLibrary("Time")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()
local Stats = Player.Stats

local Gui = Framework.Gui
local Screen = Gui.Profile
local Holder = Screen.Holder.Stats
local PlayerStats = Screen.Holder.Player
local RuneStats = PlayerStats.Stats

local Profile = {}

local Thumbnail = Thumbnail_Lib.New(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
PlayerStats.PlayerIcon.Image = Thumbnail or "rbxassetid://0"
PlayerStats.User.Text = `@{Player.Name}`

--[ Date Join ]--
PlayerStats.JoinDate.Text = string.upper(`Joined {DateJoin(Player.Stats.TimeJoined.Value)}`)

--[ Total Stats ]--
for _, Stat in Holder:GetChildren() do
	if not Stat:IsA("Frame") then continue end
	if Stat.Name == "Playtime" then continue end
	local CorrStat = Stats:FindFirstChild(Stat.Name)
	if CorrStat then

		Stat.Amount.Text = EN.Format(CorrStat.Value)

		CorrStat:GetPropertyChangedSignal("Value"):Connect(function()
			Stat.Amount.Text = EN.Format(CorrStat.Value)
		end)
	end
end

--[ Playtime ]--
local Playtime = Stats.Playtime

function UpdatePlaytime()
	Holder.Playtime.Amount.Text = Time(Playtime.Value, true)
end

UpdatePlaytime()
Playtime:GetPropertyChangedSignal("Value"):Connect(UpdatePlaytime)

function Profile.Update()
	local Rune_Luck = Formulas.Rune_Luck(Player)
	local Rune_Bulk = Formulas.Rune_Bulk(Player, false)
	local Rune_Speed = Formulas.Rune_Speed(Player)

	RuneStats.RuneLuck.Text = `X{EN.Format(Rune_Luck)} RUNE LUCK` 
	RuneStats.RuneBulk.Text = `+{EN.Format(Rune_Bulk - 1)} RUNE BULK`

	local RuneSpeedMulti = 1 / Rune_Speed
	RuneStats.RuneSpeed.Text = `X{EN.Format(RuneSpeedMulti)} RUNE SPEED`

	PlayerStats.RPS.Text = `[{EN.Format(Formulas.RPS(Rune_Bulk, Rune_Speed))} RPS]`
end

return Profile