-- The Glasshouse, opening cutscene. The player brings the orchard note back to
-- camp, and Rowan agrees to go with them.
--
-- Markers (optional parts in Workspace.CutsceneMarkers; the scene still works
-- without them, falling back to character-based shots):
--   RowanFire_Wide      wide establishing camera over the campfire
--   RowanFire_Treeline  a point in the dark treeline Rowan looks toward
--   RowanFire_EmptyTent where Rowan walks to (the old seed tent spot)
--   RowanFire_Seed      camera looking down at the seed and folded note
--
-- Voice: put an uploaded audio id in each line's Voice field
-- (e.g. "rbxassetid://1234567890"). Lines without one use the typewriter only.

local ROWAN = Color3.fromRGB(104, 150, 86)

return {
	Id = "RowanAtTheFire",

	Actors = {
		Rowan = {
			Path = "Workspace.Campsite.NPCs.Rowan",
			DisplayName = "Rowan",
			Color = ROWAN,
		},
	},

	-- Who the camera sits behind when the player speaks. The player is silent
	-- in this scene, but it's here for later cutscenes.
	Focus = "Rowan",

	Steps = {
		-- Shot 1: night, the campfire. Nobody is talking.
		{ Type = "Fade", To = 1, Time = 0.5 },
		{ Type = "Face", Actor = "Player", Target = "Rowan", Time = 0 },
		{
			Type = "Shot",
			Shot = "Marker",
			Marker = "RowanFire_Wide",
			Fallback = { Shot = "TwoShot", A = "Player", B = "Rowan", Side = -1 },
			Time = 0,
			FieldOfView = 50,
		},
		{ Type = "Fade", To = 0, Time = 1.4 },
		{ Type = "Wait", Time = 1.0 },

		-- Shot 2: the note on the crate.
		{ Type = "Shot", Shot = "TwoShot", A = "Player", B = "Rowan", Time = 2.2 },
		{
			Type = "Line",
			Style = "Note",
			Speaker = "The Note",
			Color = Color3.fromRGB(150, 118, 78),
			Text = "Do not follow them to the Heart alone.",
			Shot = false,
		},

		-- Shots 4–6: Rowan picks up the note and reads it twice.
		{ Type = "Face", Actor = "Rowan", Target = "Player", Time = 0.9 },
		{ Type = "Shot", Shot = "OverShoulder", From = "Player", To = "Rowan", Time = 1.4 },
		{ Type = "Wait", Time = 0.9 },
		{ Type = "Line", Actor = "Rowan", Text = "I've seen that trail.", Voice = "" },
		{ Type = "Line", Actor = "Rowan", Text = "I followed it once.", Voice = "" },
		{ Type = "Wait", Time = 0.8 },
		{ Type = "Line", Actor = "Rowan", Text = "I turned back.", Voice = "" },

		-- Shot 7: Rowan looks away, toward the treeline, and doesn't explain.
		{ Type = "Face", Actor = "Rowan", Target = "RowanFire_Treeline", Time = 1.2, Wait = false },
		{ Type = "Shot", Shot = "CloseUp", Subject = "Rowan", Time = 1.8 },
		{ Type = "Wait", Time = 2.0 },

		-- Shot 8: Rowan makes up their mind.
		{ Type = "Face", Actor = "Rowan", Target = "Player", Time = 0.7 },
		{ Type = "Shot", Shot = "TwoShot", A = "Player", B = "Rowan", Time = 1.4 },
		{ Type = "Line", Actor = "Rowan", Text = "If she said not to go alone...", Voice = "" },
		{ Type = "Line", Actor = "Rowan", Text = "...then you're not going alone.", Voice = "" },

		-- Shots 9–10: Rowan walks to the empty tent spot and finds the seed.
		{ Type = "HideDialogue" },
		{ Type = "MoveTo", Actor = "Rowan", Target = "RowanFire_EmptyTent", Wait = false },
		{ Type = "Wait", Time = 2.5 },
		{
			Type = "Shot",
			Shot = "Marker",
			Marker = "RowanFire_Seed",
			Fallback = { Shot = "CloseUp", Subject = "Rowan" },
			Time = 2.0,
		},
		{ Type = "Wait", Time = 1.5 },
		{
			Type = "Line",
			Style = "Note",
			Text = "A single seed rests on a folded note in the flattened grass.",
			Shot = false,
			Auto = true,
			Hold = 3,
		},

		-- Shot 11: cut to black. Control returns next to the empty tent spot.
		{ Type = "Fade", To = 1, Time = 1.0 },
	},
}
