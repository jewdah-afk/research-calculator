# Release checklist: The Milestone Tree

Work top to bottom and tick each box. If something looks wrong, stop, copy the red lines from **View › Output** and
send them over. Menu names on the Creator Dashboard (create.roblox.com) move around; look for the **bold** words.

| | |
|---|---|
| Experience | **The Milestone Tree**, universe id `10767974455`, owner user `5167569069` |
| Start place | id `76183483380423` (the only place) |
| Passes | 2x Speed R$399 (`1998278588`), Supporter R$99 (`1998128578`) |
| Products | Time Warp 1h R$29 (`3714803203`), 8h R$149 (`3714803208`), 24h R$349 (`3714803211`) |
| Save data | DataStore `MilestoneTreeNG_v1`: keys `player_<userId>`, `client_<userId>`, `receipt_<purchaseId>` |

## 1. Get the latest code into Studio

- [ ] 1. `sync.bat` is running (in `Documents\research-calculator\milestone-tree`). Its window shows
      `Already up to date.` or a list of changed files, never `fatal:` or `Not possible to fast-forward`.
- [ ] 2. Check the version: in a Command Prompt in `Documents\research-calculator`, run `git log -1 --oneline`. It
      should match the latest commit Claude reported.
- [ ] 3. In Studio, open **the published place**: the start page › **My Experiences** › The Milestone Tree. (Not
      `build\MilestoneTree.rbxlx` from disk: a file opened from disk cannot save and publishes to the wrong place.)
- [ ] 4. **Plugins › Rojo › Connect**. The Rojo panel shows **Connected** and the project name `MilestoneTree`.
- [ ] 5. **View › Command Bar**, run `print(game.GameId, game.PlaceId)`. It must print
      `10767974455 76183483380423`. `0 0` means a local file: go to step 5.2 first.

## 2. Studio test: a brand-new player (saving OFF)

With API access off, every Play starts a fresh game, which is exactly what a new player sees.

- [ ] 1. **Home › Game Settings › Security › Enable Studio Access to API Services: OFF** › Save. Press **Play**.
- [ ] 2. A dark loading card, then the realm map. Output has `[MilestoneTree] caps ...` and **no red lines**. A red
      **NOT SAVING** chip under the points is expected here.
- [ ] 3. **Tutorial** (8 steps, with a spotlight): points grow › open **M** › first milestone › keep going › open
      **Prestige** › prestige › upgrades (**NEXT**) › the READY tray (**DONE**). **Skip tutorial** is always there;
      **OPTIONS › Tutorial › Replay** starts it again.
- [ ] 4. **Buy upgrades**: click upgrade cards and buyables (hold a buyable: it repeats), and the layer's big
      button. Cards keep their size and look after each purchase. Once the next layer is reached (SP for P, MM for
      SP, ...), **BUY ALL** in the UPGRADES title row buys every affordable upgrade of that layer (dim when none).
- [ ] 5. **Prestige**: a READY layer glows and shows in the READY tray; holding its gem 0.6 s prestiges it.
- [ ] 6. **Shop** (bag icon on the dock). Studio purchases are **free test purchases** (the prompt says so):
      - [ ] 2x Speed: the game visibly runs twice as fast.
      - [ ] Supporter: a gold SUPPORTER tag and a gold rim on the points bar.
      - [ ] Time Warp 1h: about 3 s of fast catch-up (1 hour of progress).
      - Studio test passes are gone after Stop/Play; that is normal.
- [ ] 7. Phone: **Test › Device** (emulator) › a phone in landscape (e.g. iPhone 14). Tap a node: the panel fills the
      screen; the close button brings the map back. Also try a tablet.
- [ ] 8. Anything else in `STUDIO_CHECKLIST.md` (map, panel, TROPHIES, OPTIONS, Multiverse gate). Press **Stop**.

## 3. Studio test: saving (saving ON)

Careful: with this on, Studio reads and writes the **real** live save of your own account.

- [ ] 1. **Game Settings › Security › Enable Studio Access to API Services: ON** › Save. Press **Play**.
- [ ] 2. No NOT SAVING chip. Output has **no** `saving is off on this server` warning.
- [ ] 3. Play a minute (buy a few things). **SAVING…** then **SAVED** shows under the points (autosave every 60 s).
- [ ] 4. **Stop**, then **Play** again: your progress is back. Change an OPTIONS › THIS DEVICE setting, rejoin: kept.
- [ ] 5. Buy **Time Warp 1h** once more (free test). It applies once; after Stop/Play it does not apply again.

## 4. Game Settings (Studio › Home › Game Settings)

- [ ] 1. **Security**: Enable Studio Access to API Services **ON** (Studio only; the live game always has DataStores).
      **Allow HTTP Requests OFF** (the game makes no web requests). Third-party sales/teleports OFF.
- [ ] 2. **Basic Info**: name `The Milestone Tree`. **Playable Devices**: Computer, Phone, Tablet **on**;
      **Console off**, VR off (see Known risks).
- [ ] 3. **Avatar**: nothing to change (the game spawns no character).
- [ ] 4. **Places**: one place, `76183483380423`. Save.

## 5. Publish to Roblox

- [ ] 1. Rojo is still **Connected** and step 1.2 matches. Press **Stop** if a test is running.
- [ ] 2. **File › Publish to Roblox** (Alt+P). If Studio asks where (local file): **File › Publish to Roblox As…** ›
      **The Milestone Tree** › the start place › **Overwrite**. Never create a new experience.
- [ ] 3. Output says the publish succeeded. On the Dashboard, **Places › start place › Version History** shows a
      new version (note its number: it is your rollback point).

## 6. Creator Dashboard: the store page (Creations › The Milestone Tree)

- [ ] 1. **Configure › Basic Settings**: name `The Milestone Tree`. Description (max 1,000 chars; the first ~160
      are what search shows; **no links**):

      > Grow a tree of milestones, prestige layer after layer and break into the Multiverse. A faithful port of the
      > web incremental The Milestone Tree NG+: huge numbers, automation, challenges and offline progress. Your save
      > follows you, and you can import a save from the web game (OPTIONS › Import).
      >
      > Credits: "The Milestone Tree NG+" by [AUTHOR NAME(S) — confirm how they want to be credited], ported to
      > Roblox with their permission. Built on The Modding Tree by Acamaeda.
- [ ] 2. **Genre**: Simulation › **Incremental Simulator** (or the closest idle/incremental option).
- [ ] 3. **Icon**: `art/marketing/out/icon_512.png`. **Thumbnails**: `thumb_1.jpg` … `thumb_5.jpg` in that order.
      **Video**: `video_preview.mp4` (only 3 video uploads a month: upload once). Full notes:
      `art/marketing/README.md` › *Upload checklist*. All are moderated: wait for **Approved**.
- [ ] 4. **Places › start place › Permissions/Settings**: **Allow Copying OFF** (it would give the game away).

## 7. Dashboard: questionnaires, audience, servers, money

- [ ] 1. **Audience › Maturity & Compliance Questionnaire**: answer honestly (no violence, blood, romance, gambling
      or paid random items; Time Warps are not random). Expect **Minimal**. Required before going public.
- [ ] 2. If the Dashboard also shows an **Experience Questionnaire** or other compliance prompt, finish it too.
- [ ] 3. Owner account: **Settings › Security › 2-Step Verification ON**. Without it (plus ID verification, which is
      done, and Premium or the refundable fee), the game stays 16+ only and out of search/home.
- [ ] 4. **Places › start place › Server Size / max players: 8**. Each player's game uses up to about a quarter of a
      CPU core on the server and players never play together, so small servers are safer.
- [ ] 5. **Monetization › Passes**: both passes **On Sale**, prices R$399 / R$99. **Developer Products**: the three
      Time Warps at R$29 / R$149 / R$349. The in-game Shop shows the prices written in `src/shared/Products.luau`:
      if you change a price on Roblox, tell Claude so the Shop label changes too.
- [ ] 6. **Regional pricing**: optional. If on, the Roblox prompt charges the regional price while the Shop label
      still shows the base price (see Known risks).
- [ ] 7. **Monetization › Private Servers**: optional. The game plays the same there; Free or off is fine.

## 8. Live test while still private (you can play your own private game)

- [ ] 1. On the experience page press **Play** (PC). Loading card, map, sounds, **no NOT SAVING chip**, your Studio save.
- [ ] 2. Press **F9** › **Log** › **Server**: no red lines, no `[MilestoneTree] could not ...` warnings.
- [ ] 3. Optional but recommended: buy **Time Warp 1h** for real (R$29) once, rejoin: it applied once, not twice.
- [ ] 4. On a real phone (Roblox app, same account): play 5 minutes: landscape, taps work, it saves.

## 9. Go public

- [ ] 1. Icon, thumbnails and video show **Approved**; the questionnaire is done; step 8 passed.
- [ ] 2. **Studio › Game Settings › Permissions › Playability: Public** › Save (or the Dashboard's **Make Public**).
- [ ] 3. Open the game page logged out (a private browser window) on PC and phone: icon, thumbnails, description.

## 10. After launch

- [ ] 1. First days: join a live server, **F9 › Log › Server** for red lines. Watch for
      `saving is off`, `could not check receipt`, `could not record receipt`, `a receipt for an unknown product`.
- [ ] 2. **Dashboard › Analytics**: retention, session length, **Monetization** (sales per item), **Performance**
      and the error report. The game logs no custom analytics events, so only Roblox's built-in charts exist.
- [ ] 3. **Hotfix**: Claude pushes a fix › `sync.bat` pulls it within 60 s › Stop/Play test in Studio › **File ›
      Publish to Roblox** › Dashboard: the experience's **⋯ menu › Restart servers for updates** (players are moved
      and saved) or **Shut down all servers** (everyone is kicked; saves still happen on shutdown).
      Running servers keep the old code until then.
- [ ] 4. **Rollback**: **Places › start place › Version History › Restore** the last good version, then restart
      servers as above.
- [ ] 5. **Data**: never rename the DataStore (`STORE_NAME` in `src/server/Config.luau`): every save would vanish.
      There is no backup job; Roblox keeps old versions of a key for about 30 days. Players can copy their own save
      string with OPTIONS › Export (useful for support).
- [ ] 6. **Right to Erasure** messages from Roblox: delete `player_<id>` and `client_<id>` for that user in the
      Dashboard's **Data Stores Manager** within the deadline.

## What's NOT done / known risks

- **Images and video pending moderation** can take hours to days; a rejected one needs a re-upload (video: 3/month).
- **Kids & Select**: until 250 engaged age-checked plays in 60 days (plus 2FA, verification, Premium or fee), the game
  is 16+ only and not in search or home. Expect a slow start; share the link yourself.
- **Console**: the gamepad pans and zooms the map, but map nodes are not gamepad-selectable, so keep Console off
  until it is tested on an Xbox/PlayStation.
- **Shop prices are hard-coded** in `src/shared/Products.luau` (not read from Roblox), so regional pricing or a price
  change on the Dashboard is not reflected in the Shop label. The purchase prompt always shows the real price.
- **Time Warp during a server crash**: a warp is granted only once the player's game can save, and the rest is fed
  before the last save on leaving; a server crash in the ~5 s a warp takes to feed can still lose the unsaved part.
- **Studio with API access uses live data**: Hard Reset in Studio wipes your real save; receipts from Studio tests
  are recorded in the live store.
- **Time Warp edge**: the warp is added over about 3 s and is not saved until finished; leaving in those seconds
  loses the rest of it. There is no admin tool to re-grant a purchase.
- **Web-game differences** (tiny float noise, some web-only screens removed): see `README.md`. Not blockers.
