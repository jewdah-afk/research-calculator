# Unconventional Game UI and Visual-Hierarchy Tricks (for a Roblox tower defense HUD)

## Which techniques come from perception science, and how do games use them?

### Takeaway
Pre-attentive features (hue, intensity, size, orientation, motion, flicker) let one element "pop out" in under about 250 ms, whatever the number of distractors. A HUD should spend each feature on exactly one meaning. Peripheral vision catches motion but misses static detail, and heavy central attention causes inattentional blindness. Edge-of-screen HUD elements therefore need motion or a contrast change to be noticed, not just a change in their value.

### Cited Findings
- Preattentive processing is "rapid, automatic, and spatially parallel". Features detected this way include hue, intensity, orientation, size and motion. Healey's longer list adds shape, curvature, line length, flicker, direction of motion and lighting direction — [Healey, Perception in Visualization](https://www.csc2.ncsu.edu/faculty/healey/PP/index.html)
- Detection time stays roughly flat as distractors are added (parallel search), and pop-out objects are grasped in under 250 ms — [Healey publication PDF](https://healey.csc.ncsu.edu/publications/15832.pdf); [Rutgers InfoVis lecture handout](https://aspoerri.comminfo.rutgers.edu/Teaching/InfoVisOnline/Lectures/Lecture2/Lecture2Handout.pdf)
- Rapid, accurate estimation works for both hue and orientation (Healey, Booth & Enns) — [UBC TR-93-51](https://www.cs.ubc.ca/sites/default/files/tr/1993/TR-93-51_0.pdf)
- Healey's TVCG review covers change blindness, inattentional blindness and the attentional blink: a value change in an unattended area can go unseen — [Healey TVCG 2011](https://www.csc2.ncsu.edu/faculty/healey/download/tvcg.11.pdf)
- In AR HUD driving studies, inattentional blindness grew as the visual demand of the central task rose. Hazards briefly overlapped by a peripheral HUD graphic were missed more often — [arXiv 2505.00879](https://arxiv.org/abs/2505.00879v1); [PubMed 36939683](https://pubmed.ncbi.nlm.nih.gov/36939683/)
- Most participants did not notice degraded change (lower refresh rate) in peripheral view while focused on a main task, but telling them about it in advance improved detection — [PMC12356812](https://pmc.ncbi.nlm.nih.gov/articles/PMC12356812)
- A UX column (opinion, March 2026) argues that constant micromovements at screen margins feel different from stable edges. Peripheral vision is always active, so idle animation at the edges is a cost — [UXmatters](https://www.uxmatters.com/mt/archives/2026/03/designing-with-peripheral-vision-in-mind.php)
- Accessibility guidance says no essential information should be conveyed by colour alone. Reinforce colour with a symbol, or let players choose colours. Xbox guidance is stricter: aim for no cue to depend on colour — [Xbox Accessibility Guideline 103](https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/103); [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/?p=21)
- Pair colour with shape, icon, pattern, position or text. Common failures are status shown only by tint and map markers separated only by hue — [Bugnet QA guide](https://bugnet.io/blog/qa-testing-for-colorblind-modes)
- Gameplay-critical information should go through more than one channel (text, audio, visuals) — [Unity Learn, Practical Game Accessibility](https://learn.unity.com/course/practical-game-accessibility/unit/design-and-development/tutorial/important-information-and-communication)

### Inferences (TD HUD application; my reasoning, not sourced)
- **One feature, one meaning.** Reserve motion for "something just changed that needs action", saturated warm hue for "danger / lives", and size for "current wave". If idle sheen loops, bobbing icons and pulsing cash all compete, motion stops working as a signal. Roughly: one thing animating at a time.
- **Change, then settle.** The lives counter sits in the periphery, so a lost life should trigger a short, one-off motion (shake or scale punch plus a red flash) and then go still. A silent number change risks change blindness.
- **Static edges.** Keep the wave/lives/cash/kills bar free of idle loops. Save looping motion for the single affordable "upgrade ready" or "wave start" button.
- **Redundant coding on tower cards.** Show "can't afford" with greyed text plus a lock icon or strike, not red alone. Mark tower rarity or type with an icon or border shape as well as colour.
- **Luminance check.** Desaturate a screenshot (Roblox Studio screenshot plus a greyscale filter). If priority order still reads in greyscale, the hierarchy holds for colour-blind players too. The squint/blur test is the same idea at low spatial frequency.

### Gaps
- I found no study specifically on peripheral motion detection for game HUDs. The evidence comes from driving AR HUD research and general visual-search literature.
- I did not verify the origin of the squint/blur test or a citable "attention budget" source.

## What eye-tracking or playtest studies exist on HUD reading in games?

### Takeaway
The evidence base is small: case studies plus one systematic review of 10 studies. It consistently shows that players fixate the screen centre and miss edge UI, that experts and novices scan differently, and that HUD-versus-world conflicts confuse players.

### Cited Findings
- SXPD racing eye-tracking playtest: players focused on the screen centre and missed buttons at the edges. A countdown before controls unlocked helped them notice the fire buttons, but they still overlooked the brake buttons, and they ignored the arrows marking enemies behind them — [UXPA, Better Games: Insights from Eye Tracking](https://oldmagazine.uxpa.org/?p=98)
- Systematic review (2015–2025, 10 studies): expert and novice players differ in fixation and saccade patterns, depending on genre (FPS/RTS vs MOBA vs racing). Differing methods make studies hard to compare — [JAIC review](https://jurnal.polibatam.ac.id/index.php/JAIC/article/view/13341)
- Destiny 2 eye-tracking study (9 participants): found places where the HUD and the game world gave conflicting information, which confused players — [SIGDOC 2020](https://sigdoc.acm.org/conference/2020/wp-json/wp/v2/posts/420)
- Commercial FPS eye tracking plus interviews produced recommendations on HUD font, style, colour and placement — [KeyLime Interactive case study](https://info.keylimeinteractive.com/hubfs/Case%20Studies/KeyLime_case-study_GamerEyeTracking.pdf)
- Early eye-tracking work on attention in 3D game play — [Sennersten, IMEKO 2008](https://events.listic.univ-smb.fr/imeko2008/papers/Sennersten_16.pdf)
- NYU Game Center write-up on HUD and player experience — [NYU](https://game.engineering.nyu.edu/hud-in-games-and-player-experience/)

### Inferences
- On a phone-heavy platform like Roblox, the corners of the screen are the least-seen area. Put "wave incoming" and "lives lost" cues near the play area, or animate them briefly. The SXPD countdown suggests that a pre-event moment, such as "Wave 12 in 3...2...1", draws the eye to controls players otherwise miss.
- Avoid HUD/world conflict. For example, enemies' on-screen health bars and a separate boss bar should never disagree.

### Gaps
- I found no TD-specific or Roblox-specific HUD eye-tracking study.

## Which acclaimed games use unusual hierarchy techniques, and what exactly do they do?

### Takeaway
The best-documented cases are diegetic UI (Dead Space), menus as entertainment with strict two-colour discipline (Persona 5), ruthless clarity over ideas (Into the Breach), visible enemy intent (Slay the Spire) and deliberately withheld results with escalating juice (Balatro). Primary design rationale for Hades, Vampire Survivors and Clash Royale was not found.

### Cited Findings
- **Dead Space:** health is a glowing spine bar on Isaac's suit that shifts from green to red. Lead UI designer Dino Ignacio moved all non-diegetic information onto the RIG suit to keep the screen uncluttered — [Wikipedia, Isaac Clarke](https://en.wikipedia.org/wiki/Isaac_Clarke)
- The goal was to remove a "wall of safety" between player and game. The health bar, inventory, weapon selector and locator were presented at GDC 2013 — [Game Developer](https://gamedeveloper.com/design/video-designing-i-dead-space-i-s-immersive-user-interface); menus as suit-projected holograms — [Game Developer](https://www.gamedeveloper.com/design/game-ui-discoveries-what-players-want)
- **Persona 5:** art director Masayoshi Sudou (Suto) chose black-and-white text against the crimson palette after trying alternatives, drew on website menus and treated menus as "graphical entertainment" — [Segabits / Famitsu interview](https://segabits.com/?p=54918)
- The typography references ransom-note Sex Pistols covers, and the battle commentary references TV sports graphics — [DT Next](https://www.dtnext.in/amp/story/edit/exuberant-video-game-menus-designed-with-da-vinci-in-mind-807823)
- Sakurai calls the Persona 5 UI unconventionally cluttered and says it takes time to get used to: a tradeoff, not a free win — [Source Gaming, Sakurai column 515](https://sourcegaming.info/2016/11/24/the-aims-of-ui-sakurais-famitsu-column-vol-515/)
- Persona 3 Reload's UI quality is credited to keeping key UI staff — [Push Square](https://www.pushsquare.com/news/2024/02/persona-3-reloads-sexy-ui-result-of-retaining-key-staff-says-atlus)
- **Into the Breach:** GDC 2019 design postmortem by Matthew Davis. A developer quote via secondary coverage says they would sacrifice cool ideas for clarity every time, and UI work ran alongside content work — [GDC Vault](https://gdcvault.com/play/1025772/-Into-the-Breach-Design); [80.lv](https://origin.80.lv/articles/gdc-2019-an-inside-look-at-into-the-breach/)
- **Slay the Spire:** each enemy shows its next action as an icon plus a number (damage × hits, shield for block, buff/debuff icons), so the player has near-complete information to plan. StS2 places multiple intents side by side instead of stacking them — [Untapped StS2 guide](https://sts2.untapped.gg/guides/how-to-read-enemy-intent); [roytang.net](https://roytang.net/2019/02/slay-the-spire/)
- **Balatro:** hides the score preview to speed up play and build suspense on each hand. The total stays calculable ("hidden but attainable") — [video essay transcript, Amara](https://amara.org/videos/qZaMrU6iDy4J/en/4529388). Third-party analysis (not developer-confirmed): layered feedback of card animation, slot-reel rolling chip digits, screen effects, particles and audio — [Blake Crosley guide](https://blakecrosley.com/es/guides/design/balatro)
- "Juice It or Lose It" (Jonasson & Purho, GDC 2012). Its staples include numbers that tick upward instead of appearing, and sound that rises in pitch as a streak builds — [PSU](https://www.psu.com/news/why-winning-feels-so-good-reward-design-from-arcades-to-balatro/)
- **Hades:** only secondary analysis was found. It describes controlled brightness and detail density so gameplay stays readable, and enemies readable by pose, timing and silhouette amid particles — [GeekChamp](https://geekchamp.com/the-art-of-hades-showcases-the-talent-that-went-into-this-beautifully-vibrant-game/); [80.lv VFX](https://80.lv/articles/a-behind-the-scenes-look-at-the-effects-in-hades/)

### Inferences (TD application)
- **Slay the Spire-style intent on waves:** a "next wave preview" strip with enemy icons, counts and trait icons (flying, armored, fast) is the TD version of intents. It is an anticipation cue that turns surprise into planning.
- **Balatro-style rolling counters** for cash and kills, with pitch rising on rapid kill streaks. Keep the roll short (about 0.2–0.4 s) so values are never stale when the player needs to buy.
- **Dead Space-style semi-diegetic UI:** show turret range, level pips and ready-to-upgrade glow on the turret model (BillboardGui/SurfaceGui) instead of only in the panel.
- **Persona 5's discipline:** limit to two to three palette roles and use strong type contrast, so a stylised lobby (research/quests/shop) can be loud without losing hierarchy.
- **Into the Breach's rule:** cut any HUD element that doesn't support a decision.

### Gaps
- I found no primary sources on UI hierarchy in Hades, Vampire Survivors or Clash Royale.
- I did not get the full slides or transcripts of the Into the Breach or Dead Space GDC talks.
- I did not research perceived-value shop tricks (anchoring, sheen sweeps) or Fitts's law and Gestalt sources within budget.

## Which tricks are cheap to implement in Roblox?

### Takeaway
Most of these techniques reduce to TweenService on Text, Transparency, Size and Position, plus discipline in palette and motion. Official docs confirm tweening text reveal and transparency. Rolling counters have a known easing pitfall.

### Cited Findings
- The TextLabel docs show tweening `MaxVisibleGraphemes` for a typewriter reveal and `TextTransparency` for a fading banner, which covers fade-when-idle HUDs and wave banners — [Roblox TextLabel docs](https://create.roblox.com/docs/en-us/reference/engine/classes/TextLabel)
- A tweened number counter drifted (showed 206 instead of 200). Replies pointed to elastic easing or improper text setting. Tween a NumberValue with non-overshooting easing and set the final text explicitly — [DevForum](https://devforum.roblox.com/t/text-isnt-updating-correctly/2860070)
- UI tweens must target PlayerGui, not StarterGui — [DevForum](https://devforum.roblox.com/t/2663447)

### Inferences (cheap Roblox recipes; not separately sourced)
- Rolling counter: tween a NumberValue (Quad/Out) and update the label on `.Changed`. Format as 1.2K / 3.4M, and snap the exact value at the end.
- Tabular digits: use a monospaced-digit font, or a fixed-width label with right alignment, so cash doesn't jitter while it rolls. Whether Roblox fonts support OpenType `tnum` was not verified.
- Idle fade: drop the group's opacity to about 0.4 after N seconds without input (CanvasGroup GroupTransparency), and restore it on hover, tap or event.
- Anticipation: a 3-2-1 banner before each wave, plus a red vignette pulse for 1 s before a boss.
- Squint test: take a Studio screenshot, then blur and desaturate it in any image tool.

### Gaps
- I did not verify Roblox font support for tabular figures or CanvasGroup performance costs on mobile.
