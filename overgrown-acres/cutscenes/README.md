# Overgrown Acres: Cutscene System

A third-person cutscene camera that keeps the player and NPCs in frame, with a dialogue box at the bottom of the screen just above the inventory. The first scene included is **Rowan at the Fire** from *The Glasshouse*.

## What you get

**Camera**
- Stays third person and reframes itself every frame, so shots hold even while characters move.
- Shots:
  - **TwoShot**: side-on view that fits both characters.
  - **OverShoulder**: behind one character looking at the other, both in frame.
  - **CloseUp**: in front of one character's face.
  - **Marker**: a fixed camera placed by hand.
- Smooth eased glides between shots, or hard cuts.
- Slight handheld sway, a soft depth-of-field blur, and automatic pull-in when a tree or wall would block the view.
- If someone speaks who isn't on screen, it moves to an over-the-shoulder shot of them.

**Dialogue box**
- Sits above the inventory. The gap is set in `Config.luau` (`BottomOffset`, plus a separate value for phones).
- Speaker nameplate in each character's color, with a small pop when the speaker changes.
- Typewriter text with natural pauses after punctuation. It stays in sync with a voice line when one is attached.
- "Note" style for letters and notes: paper colored, handwritten font.
- Click, tap, E, Space, Enter or gamepad A advances. The first press finishes the line, the second moves on.
- Hold-to-skip button (Tab / gamepad Y / hold on mobile). By default it only appears on repeat viewings.
- Scales for phone, tablet and PC screens.

**Scene handling**
- NPCs are acted by a local stand-in copy. The client can then move and animate them smoothly, and the real NPC comes back afterwards.
- Freezes the player, hides other players and the chat/player list, fades in and out, and always restores everything, even if a step errors or the player dies.

## Files

```
src/
  ReplicatedStorage/Cutscene/          ModuleScript "Cutscene" (init.luau)
    Config.luau                        all the tweakable settings
    CameraDirector.luau                the camera
    DialogueUI.luau                    the dialogue box (built in code)
    Util.luau
    Cutscenes/RowanAtTheFire.luau      the scene itself (just data)
  ServerScriptService/
    CutsceneService.luau               server API: Play(player, id), Finished
    RowanTrigger.server.luau           ProximityPrompt on Rowan that starts it
  StarterPlayerScripts/
    CutsceneClient.client.luau         plays scenes when the server asks
```

## Setup

### With Rojo
Run `rojo serve` in this folder and connect from Studio. The folder layout is already in `default.project.json`.

### By hand in Studio
Create these scripts and paste in the matching file:

| In Studio | Type | File |
|---|---|---|
| `ReplicatedStorage > Cutscene` | ModuleScript | `Cutscene/init.luau` |
| `ReplicatedStorage > Cutscene > Config` | ModuleScript | `Config.luau` |
| `ReplicatedStorage > Cutscene > CameraDirector` | ModuleScript | `CameraDirector.luau` |
| `ReplicatedStorage > Cutscene > DialogueUI` | ModuleScript | `DialogueUI.luau` |
| `ReplicatedStorage > Cutscene > Util` | ModuleScript | `Util.luau` |
| `ReplicatedStorage > Cutscene > Cutscenes` | Folder | |
| `ReplicatedStorage > Cutscene > Cutscenes > RowanAtTheFire` | ModuleScript | `RowanAtTheFire.luau` |
| `ServerScriptService > CutsceneService` | ModuleScript | `CutsceneService.luau` |
| `ServerScriptService > RowanTrigger` | Script | `RowanTrigger.server.luau` |
| `StarterPlayer > StarterPlayerScripts > CutsceneClient` | LocalScript | `CutsceneClient.client.luau` |

### Things to set up in the map
1. **Rowan's location.** The scripts expect `Workspace.Campsite.NPCs.Rowan`: a character model with a Humanoid and a HumanoidRootPart. If Rowan lives somewhere else, change the path in `RowanAtTheFire.luau` (`Path`) and `RowanTrigger.server.luau`.
2. **Markers (optional, but they make it look much better).** Make a folder `Workspace.CutsceneMarkers` and add small invisible, anchored, non-collidable parts named:
   - `RowanFire_Wide`: the establishing camera. Point its front face at the campfire.
   - `RowanFire_Treeline`: a spot in the treeline for Rowan to stare at.
   - `RowanFire_EmptyTent`: where Rowan walks to (the empty tent spot).
   - `RowanFire_Seed`: a camera looking down at the seed and note.

   Missing markers don't break anything; the scene falls back to character shots.
3. **Story check.** In `RowanTrigger.server.luau`, `isReady` currently checks a `OrchardComplete` attribute, and the `Finished` handler sets `StoryStage`. Swap both for the game's real progress and inventory code. That's also where Theo's seed should be given.
4. **Inventory gap.** Adjust `Config.Dialogue.BottomOffset` until the box sits just above the inventory bar.

### Test it
In Studio, press Play, then in the **server** command bar:
```lua
game.Players:GetPlayers()[1]:SetAttribute("OrchardComplete", true)
```
Walk up to Rowan and use the prompt.

## Adding voice lines
1. Record or generate each line (see the voice script below).
2. Upload the audio in the Creator Dashboard (or send it over and it can be uploaded through Open Cloud).
3. Paste the id into that line's `Voice` field, e.g. `Voice = "rbxassetid://1234567890"`.

The typing speed matches the length of the audio automatically.

## Writing new cutscenes
Copy `RowanAtTheFire.luau` and change the steps. Available steps:

| Step | Fields | What it does |
|---|---|---|
| `Line` | `Actor` or `Speaker`, `Text`, `Voice`, `Style = "Note"`, `Auto`, `Hold`, `Shot`, `Animation` | Shows a line and waits for the player |
| `Shot` | `Shot` (`TwoShot` / `OverShoulder` / `CloseUp` / `Marker`), `A`/`B`, `From`/`To`, `Subject`, `Marker`, `Side`, `Time`, `FieldOfView`, `Fallback`, `Wait` | Moves the camera |
| `Face` | `Actor`, `Target` (actor or marker), `Time`, `Wait` | Turns a character |
| `MoveTo` | `Actor`, `Target`, `Speed`, `Wait` | Walks a character somewhere |
| `Animation` | `Actor`, `Id`, `Looped`, `Wait` | Plays an animation |
| `Wait` | `Time` | Pause (hides the dialogue box) |
| `Fade` | `To` (1 = black, 0 = clear), `Time` | Fades the screen |
| `Sound` | `Id`, `Volume` | Plays a sound effect |
| `HideDialogue` | | Hides the box |
| `Callback` | `Run = function(ctx) ... end` | Anything custom |

`"Player"` always means the local player's character.

## Voice script: Rowan at the Fire

**Rowan:** a forest guide who has spent years around the camp. Quiet, careful, doesn't waste words. Carries some guilt about turning back once. Low to mid voice, never loud in this scene.

| # | Line | Direction |
|---|---|---|
| 1 | "I've seen that trail." | Quiet, almost to themselves. They weren't planning to say it. |
| 2 | "I followed it once." | Slower. A memory they don't enjoy. |
| 3 | "I turned back." | Flat, a little ashamed. Short pause before it. |
| 4 | "If she said not to go alone..." | Decision made. Steady, looking straight at the player. |
| 5 | "...then you're not going alone." | Warm but firm. A promise. |

**Note lines** ("Do not follow them to the Heart alone." and "A single seed rests on a folded note...") are on-screen text only, with no voice.

## Notes
- Written against current Roblox APIs and syntax-checked with the Luau compiler, but not yet run inside Studio. Expect to tune the camera numbers and offsets once it's in the real map.
- Seen-cutscene flags are player attributes. Save them with the rest of the player data to keep them across sessions.
