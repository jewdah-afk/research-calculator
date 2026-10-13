# Game UI visual hierarchy for TD/strategy HUDs and Roblox lobbies

Note on sourcing: about 12 tool calls. The best primary material on concrete techniques was a Clash Royale UX breakdown (The Rookies) and Roblox's official ScreenInsets docs. I found no official Ninja Kiwi, Ironhide, or Supercell UI talk pages with HUD specifics. I could not open the GDC 2019 Brawl Stars page (404). Anything below that describes BTD6, Kingdom Rush, or TDS behaviour without a citation is under Inferences and labelled as unverified.

## 1. How do the best TD/strategy games rank info on the HUD (size, brightness, placement)?

### Takeaway
They put action controls at the bottom and make them biggest, with the deck and cards in the thumb zone. Persistent status stats (currency, lives, wave) go small in the top corners. Brief alerts take the centre only for a moment. Colour is used as a strict priority code, and Clash Royale's yellow/green/blue/red split is the clearest documented example.

### Cited Findings
- Clash Royale colour-codes priority. Yellow is for the most important buttons (Enter Battle, Use Card, Invite). Green is for secondary actions (Donate, Buy, Upgrade). Blue is the background, and red is for notifications. Primary buttons also get an animated highlight. — [The Rookies: Clash Royale UX breakdown](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)
- When a 2017 Clash Royale update made a free-reward button yellow, it broke the colour meaning, and the change was later reverted. Consistent colour roles matter more than local emphasis. — [The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)
- Clash Royale keeps key functions (deck, menu, donations, chests) in the lower 50% of the screen, and drag/tap input starts from the bottom. The UI rarely goes more than one level deep. Popups are not fullscreen, show the previous screen behind them, and close when you tap the background. — [The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)
- Each unit card has a distinct silhouette, icon and colour theme so it reads at a glance. — [The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)
- Roblox HUD convention: persistent stats (health, currency, level) go in the top corners. Action buttons, cooldowns and tool selectors go bottom-centre and are larger than status elements. Centre screen is for brief alerts only. If more than 5 persistent elements are on screen, cut or hide some. Keep one menu open at a time and put close buttons top-right in every menu. Use 3 colours max (primary, neutral, accent for warnings). — [creation.dev Roblox UI best practices](https://www.creation.dev/blog/roblox-ui-design-best-practices) (community blog, not official)
- HUD content can be split into peripheral information (player or global state, fixed at the screen edges) and contextual information (placed next to the object it relates to). — [UXMatters, Designing with peripheral vision in mind (Mar 2026)](https://www.uxmatters.com/mt/archives/2026/03/designing-with-peripheral-vision-in-mind.php) and related search summary
- Peripheral vision stays active during focused tasks and picks up motion and contrast changes. That is why a pulse or flash at the edge of the screen draws the eye without the player having to look there. — [UXMatters](https://www.uxmatters.com/mt/archives/2026/03/designing-with-peripheral-vision-in-mind.php)
- Hodent's framework runs perception, then attention, then memory, with emotion and motivation feeding attention. Usability means designing for human limits in all three. — [GDC Masterclass: Psychology and Game UX](https://gdconf.com/masterclass/psychology-game-ux); [EGD News #37 (secondary summary)](https://elitegamedevelopers.substack.com/p/egd-news-37-motivations-to-play)

### Inferences
- A suggested Peckwood ranking:
  1. Build palette and the selected-turret panel: bottom, largest, highest saturation.
  2. Send-wave button: the single yellow/primary CTA, bottom-right in the thumb zone. It pulses only when it can be pressed.
  3. Cash: top, large numerals. It is the stat checked most often in a TD because it gates every action.
  4. Lives: top, red/heart icon. It stays quiet until it drops, then flashes.
  5. Wave counter: top-centre, medium size.
  6. Kills, speed and pause: smallest, in the corners.
- Unverified recollection, not sourced: BTD6 keeps cash, lives and round top-left, the tower shop as a right-side column, and play/fast-forward bottom-right. Upgrade paths open as a side panel with three path columns. Kingdom Rush uses a contextual radial ring around the build plot instead of a palette. Someone should check these against gameuidatabase.com screenshots.
- Radial build menus such as Kingdom Rush's put every item at an equal distance from the tap point. Research found them about 20 to 30% faster to navigate, though visual search is slower. That makes them good for a small fixed set (4 options) and poor for big palettes. — [300mind radial menus](https://300mind.studio/blog/radial-menus-in-game-design/)

### Gaps
- I found no official Ninja Kiwi, Ironhide, Supercell or Riot UI talk with numeric HUD sizes. Game UI Database pages were not fetched.
- I have no sourced layouts for Rogue Tower, Mindustry, PvZ, TDS, TTD, Anime Defenders, PS99 or Blox Fruits.

## 2. How are affordability, lock state, upgrade paths and selection shown?

### Takeaway
The documented standard is a red price text when the player can't afford the item. Clash Royale removed it once, players got confused, and it was restored. Readiness shows as a radial fill that completes as the resource accrues. Placement validity uses green and red ghosts. Selection is shown with range circles and outlines.

### Cited Findings
- Clash Royale shows unaffordable items in red text before the player taps. Removing the red caused confusion and it was restored. Cards show a radial progress fill until elixir is enough to play them. The elixir bar glows and animates when full. — [The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)
- Clash Royale shows spell range in team colour, marks deployable areas, and snaps units to a grid so range is easy to judge. — [The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)
- A common TD pattern: the cursor becomes a tower ghost, tinted green on a valid spot and red on an invalid one. — [Construct forum](https://construct.net/en/forum/construct-2/how-do-i-18/tower-defense-ui-65831)
- Another common pattern: tower buttons re-check affordability on every money change, and placement is blocked when gold is below the cost. — [HF tower-defense UIManager](https://huggingface.co/spaces/victor/tower-defense/blob/main/src/ui/UIManager.js); [tldraw TD example](https://tldraw.dev/examples/tower-defense)
- BTD6 upgrade prices differ by difficulty and are patched often (for example, Triple Shot went from $400 to $450). The price display must be data-driven. — [Bloons Wiki v47](https://www.bloonswiki.com/Update_history:Bloons_TD_6/Version_47.0)

### Inferences
- Use more than one cue for each state, so none relies on colour alone:
  - **Affordable:** full-colour card and white price with a dark stroke.
  - **Unaffordable:** desaturate or dim the card to about 50 to 60% and turn the price red, keeping the icon visible so players can plan.
  - **Locked:** grey card, padlock and the unlock requirement replace the price.
  - **Just became affordable:** a quick scale pop (1.0 to 1.08 and back) or a shine sweep. Peripheral vision picks this up.
- **Selection:** a thick bright outline (yellow or white) around the selected card or turret, plus a range circle in the world.
- **Upgrade panel:**
  - Show the current tier pips filled.
  - The next tier is a big button with its price, using the same affordable and unaffordable rules as the cards.
  - Maxed or blocked paths are greyed out and show a lock.
  - The sell button is a separate red/neutral button, kept away from the upgrade button.

### Gaps
- I have no sourced description of BTD6's exact affordability visuals. The search didn't confirm red price text in BTD6.

## 3. What do game-UI writers say about hierarchy, peripheral vision, colour coding and glanceability? Juice?

### Takeaway
The sourced material says to keep colour meanings consistent and few, and to make important changes move or change contrast so peripheral vision catches them. Use short, snappy tweens: about 0.1 s press feedback, 0.2 to 0.3 s menu transitions, and number roll-ups of about 0.5 s.

### Cited Findings
- Animation timing: menu transitions 0.2 to 0.3 s via TweenService, button press feedback about 0.1 s, easing Quad or Back. Currency, health and XP numbers should count up over about 0.5 s rather than jump. — [creation.dev](https://www.creation.dev/blog/roblox-ui-design-best-practices)
- Button press recipe: compress to 0.95 to 0.97 scale on press, overshoot to 1.02 to 1.03 on release, then settle at 1.0. Response should come within 0 to 50 ms. A pop longer than about 0.25 s stops feeling instant. — [skills.sh buttons-ctas (community)](https://www.skills.sh/dylantarre/animation-principles/buttons-ctas); [bugnet button pop easing](https://bugnet.io/blog/how-to-fix-ui-button-pop-easing-feels-stiff)
- Juice means layering channels on one event: SFX, colour flash, squash and stretch, particles and shake. — [itch.io juicy effects](https://itch.io/blog/1059831/making-a-game-feel-juicy-with-simple-effects)
- Clash Royale feedback: units blink brighter when hit, and a red outline pulses when time runs out (with a reddish frame in overtime). An info button that looks the same everywhere replaces clutter. — [The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)
- In game UIs, speed matters more than discoverability, because players can't hunt for controls mid-action. — search summary of [thepromptindex game UI/UX](https://www.thepromptindex.com/skill/1352-game-ui-ux) (weak source)

### Inferences
- **Lives:** shake the lives counter and flash it red when a leak happens.
- **Send-wave button:** idle "breathing" pulse (scale 1.0 to 1.04 over about 1 s) only between waves.
- **Cash:** roll-up over 0.5 s, with a green "+N" floater.
- **Chunky bevelled style:** layer each button as
  1. a dark outline (UIStroke about 2 to 3 px)
  2. the base colour
  3. a lighter top highlight band
  4. a darker bottom "lip"
  5. a soft drop shadow
  On press, shift the face down onto the lip, which pairs well with the 0.95 scale.

### Gaps
- I couldn't fetch Hodent's specific guidance on peripheral vision or colour, Riot UI writing, or Game UI Database commentary.

## 4. Mobile and touch: thumb zones, minimum tap sizes, safe areas, density

### Takeaway
Use touch targets of at least 44 pt (Apple) or 48 dp (Material), and larger for primary actions. Text contrast should be at least 4.5:1 (3:1 for large or bold text), tested against the busiest background. On Roblox, put interactive GUI in CoreUISafeInsets. Keep primary controls in the lower half of the screen.

### Cited Findings
- Minimum touch targets: Apple HIG recommends 44 pt and Material recommends 48 dp. Primary actions should be larger where precision drops. WCAG 2.2 sets 24×24 CSS px as AA (2.5.8) and 44×44 as AAA (2.5.5). — [OpenReplay tap targets](https://blog.openreplay.com/improving-tap-targets-mobile-ux/); [touch target spec](https://specification.website/spec/accessibility/touch-target-size.md)
- Contrast: AA is 4.5:1 for normal text and 3:1 for large text (18 pt+, or 14 pt+ bold). 7:1 is suggested for small text. Translucent panels must be re-tested over the busiest region behind them. — same search results ([tessl apple-hig-expert](https://tessl.io/registry/skills/github/alirezarezvani/claude-skills/apple-hig-expert))
- Roblox ScreenInsets:
  - CoreUISafeInsets avoids notches and Roblox core UI (top bar). Roblox recommends it for interactive or important UI.
  - DeviceSafeInsets avoids notches only.
  - None is only for non-interactive backgrounds.
  - TopbarSafeInsets is dynamic.
  - [Roblox ScreenInsets docs](https://create.roblox.com/docs/en-us/reference/engine/enums/ScreenInsets.md)
- Roblox community guidance:
  - Minimum target 44×44 px. Use UISizeConstraint and an invisible larger hit area behind small icons. — [skills.sh ui-ux](https://skills.sh/taozhuo/game-dev-skills/ui-ux)
  - Prefer Scale over Offset.
  - Hover tooltips need a tap or long-press alternative.
  - The source claims over 70% of Roblox players are on mobile (unverified).
  - The source says 44 px is "about 0.06 scale at 1080p", which looks wrong. 44 px at 1080p is about 0.04.
  - [creation.dev](https://www.creation.dev/blog/roblox-ui-design-best-practices)
- Clash Royale puts its controls in the lower 50% and plays in portrait so it can be used one-handed. — [The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)

### Inferences
- **Landscape Roblox TD on phones:**
  - Put the build palette along the bottom, or at the bottom-right in thumb reach.
  - Put the send-wave and speed buttons bottom-right, sized at least 60 to 70 pt because they are primary.
  - Put stats along the top, inside CoreUISafeInsets.
  - Open the upgrade panel on the side opposite the selected turret so it doesn't cover it.
- **PC:**
  - You can show more cards per row and add hover tooltips and hotkey badges (1 to 9) on cards.
  - On mobile, show fewer cards with larger prices, and switch to tap-for-info.
- Clamp sizes with UISizeConstraint or UITextSizeConstraint so 4K PC screens don't get giant UI and phones don't get tiny text.

### Gaps
- I found no official Roblox minimum tap size, and no published measurements of the safe-area or top-bar sizes on specific devices.
