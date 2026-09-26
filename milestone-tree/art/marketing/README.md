# Roblox publish media kit

The icon, thumbnails and video preview for The Milestone Tree NG+ (MASTER_PLAN W8). Everything in `out/` is made by
the scripts in this folder from the real client: `snap_mk.luau` runs the shipped client code on the mock engine
(as `port/tools/snap/snap.luau` does) and the dumps are drawn in headless Chromium by `port/tools/snap/page.js`. The
realm, gems, node plates and panels are therefore the game's own art and layout, not mock-ups.

## Files

| File | Size | What | Made by |
|---|---|---|---|
| `out/icon_512.png` | 512 × 512 | Game icon: the M crystal gem in a glowing conical rift ring on the void. No text. The subject sits inside the central 80 %, so Roblox's rounded corners crop nothing | `icon.js` (1024 master on a 2D canvas) → `icon_post.py` |
| `out/icon_preview.jpg` | | The icon at 512, 150 and 50 px, rounded and square, on the dark and light site themes | `icon_post.py` |
| `out/thumb_1.jpg` | 1920 × 1080 | GROW THE TREE: the lit tree, with the THE MILESTONE TREE logo lockup | `stills.js` → `thumbs.js` |
| `out/thumb_2.jpg` | 1920 × 1080 | PRESTIGE: the Prestige gem up close and the real P panel's hero card | same |
| `out/thumb_3.jpg` | 1920 × 1080 | ENTER THE MULTIVERSE: the rift inside the Prestige Multiverse, its nodes lit | same |
| `out/thumb_4.jpg` | 1920 × 1080 | FIX THE CORRUPTION: the corrupted island (READY nodes) and the real CR panel's CORRUPT card | same |
| `out/thumb_5.jpg` | 1920 × 1080 | EXPLORE: the whole realm at the zoom floor | same |
| `out/video_preview.mp4` | 1920 × 1080 | ~26 s, 30 fps, H.264 High, no audio: the hook pull-back, climbing numbers, the P panel opening, the rift, the realm and an end card (the logo lockup only) | `video.js` → `video_post.py` |

Thumbnail style: Sleek sci-fi (`art/ui/clean/styles.js` Style 1): 1 px hairline frame, corner ticks and registration
marks in one accent colour per thumbnail, tracked-caps micro labels, and the caption in Montserrat 900 italic. Key
content stays in the top 80 % (y < 864). The HUD is hidden on every thumbnail; the node plates stay because the
numbers are the game.

## Regenerate

```sh
cd art/marketing
export PATH=$HOME/bin:$PATH NODE_PATH=$(npm root -g)   # luau and playwright
./build.sh                                             # everything, about 10 minutes

node icon.js && python3 icon_post.py                   # the icon and its preview
node stills.js [tree prestige_bg ...]                  # realm / panel stills -> work/stills/*.png
node thumbs.js [1 2 ...]                               # thumbnails -> out/thumb_N.jpg
node video.js [--force] [--only s3_panel] [--jobs 3]   # clips (cached in work/video/) + assembly
python3 video_post.py                                  # assembly only, from the cached clips
```

Needs: `luau` (in `~/bin`), Node with Playwright Chromium (`/opt/pw-browsers`), Python 3 with Pillow, NumPy and
imageio-ffmpeg. Prerequisites of the snap tool apply (`python3 tools/wrap_scripts.py` and `./test.sh capture` in
`port/` once, and the realm tiles from `node roblox/tile.js` in `art/`). The output is deterministic: seeded
randomness in the icon, a pinned client clock in the clips, single-threaded x264.

### The pieces

- `snap_mk.luau`: a variant of `port/tools/snap/snap.luau` (which stays untouched). It captures the client's
  `MapView` so a still or clip can be framed anywhere in the realm: `cam` is `x,y,z` in world px (3840 × 2560) and map
  zoom (0.405 is the floor at 1080p, 1.25 the ceiling), or `x,y,z>x,y,z` for a smoothstep dolly (zoom in log space).
  Scenes: any fixture (`s13_none`, `s19mv_none`, ...), `panel_<layer>`, and `open_<layer>@<frame>` (the tap happens
  inside a clip). Clips also send view patches every 3 frames so the HUD points and node values climb, and the client
  never shows "Reconnecting".
- `lib/snap.js`: runs `snap_mk.luau`, draws each dump with the snap page, hides screens or plates (`--hide hud`,
  `toasts`, `plates`, `plate_<id>`), saves PNG stills or JPEG clip frames.
- `lib/page.js`: a Playwright page with the game fonts from `art/ui/fonts` and local files, for the compositors.
- `stills.js`: the shot list (scene, camera, hidden pieces) behind the thumbnails.
- `thumbs.js`: the thumbnail layouts (caption, tagline, accent, optional real-panel card crop, logo).
- `video.js`: the segment list (scene, camera move, frames) and the end card; renders segments three at a time.
- `video_post.py`: crossfades (0.5 s), the panel-open dissolve, the end card fade and hold, the H.264 encode.
- `work/`: intermediate files (stills, clip frames, the 1024 icon master). Safe to delete.

### Known limits

- The mock engine has no tweens, so the panel snaps open in one frame; `video_post.py` dissolves over that cut.
- The CR panel's disk grid does not lay out on the mock engine (one tile shows), so thumbnail 4 uses only the panel's
  header and CORRUPT card and takes the corrupted island itself from the realm.
- The Multiverse plate of the `pm` node is redacted by design (block glyphs); it is hidden in the multiverse shots.

## Upload checklist

1. Creator Dashboard (create.roblox.com) → **Creations** → the experience → **Places** → the start place. Its
   settings have the **Icon** and **Thumbnails** sections (the dashboard moves labels now and then; look for those
   two names).
2. **Icon**: upload `out/icon_512.png` (512 × 512 PNG). It is moderated and shows as pending until approved. Check
   it on the game card (~150 px) and in lists (~50 px) against `out/icon_preview.jpg`.
3. **Thumbnails**: upload `thumb_1.jpg` … `thumb_5.jpg` in that order (1 is what a player sees first; drag to
   reorder). Each is 1920 × 1080 and moderated.
4. **Video preview**: in **Thumbnails**, add a video → `out/video_preview.mp4`.
   - Rules: at most 30 s (this one is ~26 s), 16:9 1080p, MP4 H.264; silent is fine.
   - Video previews are moderated and limited to **3 uploads a month**, so upload the final cut only.
   - No voice-over, lyrics or promotional text; a logo overlay is allowed (the end card is the logo lockup).
5. Asset privacy: all uploads belong to the experience's owner (user or group) that publishes the place.
6. After approval, view the experience page logged out, on desktop and on a phone, and check the icon crop and the
   thumbnail captions (the bottom 20 % can be covered by the site's overlay).
