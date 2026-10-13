# Spend each visual signal on one meaning

Top-tier hierarchy for Onslaught's chunky, bevelled TD UI comes from discipline more than new art. Give each pre-attentive feature (hue, brightness, size, motion) exactly one job. Keep a strict colour-role code like Clash Royale's yellow/green/blue/red. Put actions big and low in the thumb zone and status small at the top edges. Use motion only for one-off "this just changed" events, because players fixate the screen centre and miss static edge UI. In Figma, the highest-leverage techniques are hard (blur-0) stacked inner and drop shadows for bevels, variable modes for rarity and state theming, and component variants for affordable, unaffordable, locked, selected and pressed. All of these can be layered onto the existing UI v2 frames without redrawing them. Only part of Figma's effect stack survives the trip to Roblox. Hard shadows, strokes, corners and linear, radial and conical gradients map to UIStroke, UICorner, UIGradient and UIShadow. Noise, glass, blur and multi-inner-shadow bevels must be baked into 9-slice images. The unconventional wins are cheap: Slay the Spire-style wave intent previews, Balatro-style rolling counters, a 3-2-1 pre-wave countdown that pulls eyes to the edge controls, idle-fading the stat bar, and a greyscale squint test as the acceptance gate. The evidence base for game-specific HUD numbers is thin. Several recommendations below are reasoned from perception science and Clash Royale, not from studies of tower defense games, and they are flagged where that applies.

## Pre-attentive features pop out in under 250 ms, so ration them

Hue, intensity, size, orientation, motion and flicker are processed "rapidly, automatically, and spatially parallel." A target carrying one of them is found in **under about 250 ms, regardless of how many distractors surround it** ([Healey](https://www.csc2.ncsu.edu/faculty/healey/PP/index.html); [Rutgers handout](https://aspoerri.comminfo.rutgers.edu/Teaching/InfoVisOnline/Lectures/Lecture2/Lecture2Handout.pdf)). This only works when the feature is unique. If the cash pill, the lives heart, the send-wave button and an idle sheen all pulse, motion stops signalling anything. The working rule for Onslaught is **one feature, one meaning**:

- Saturated warm red means danger or lives.
- Yellow means the single primary call to action.
- Motion means "act now."
- Size means "most-used action."

Clash Royale shows the stakes. It reserves **yellow for the most important buttons, green for secondary actions, blue for backgrounds and red for notifications**. When a 2017 update made a free-reward button yellow, the change broke that code and was reverted ([The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)). Persona 5 makes the same point from the opposite aesthetic. Art director Masayoshi Sudou kept loud menus legible by restricting text to black and white against crimson ([Segabits/Famitsu](https://segabits.com/?p=54918)). Even so, Sakurai calls that UI cluttered and says it takes time to learn ([Source Gaming](https://sourcegaming.info/2016/11/24/the-aims-of-ui-sakurais-famitsu-column-vol-515/)). That is a warning for the lobby: research, quests and the shop can be loud, but only if the palette roles stay few.

Edges need motion, not just a new value. Change blindness and inattentional blindness mean a value that changes in an unattended area often goes unseen ([Healey TVCG](https://www.csc2.ncsu.edu/faculty/healey/download/tvcg.11.pdf)). In AR HUD driving studies, inattentional blindness **rose with the visual load of the central task** ([arXiv](https://arxiv.org/abs/2505.00879v1)). An eye-tracking playtest of the racing game SXPD found players **fixated the centre and missed edge buttons**. A pre-race countdown helped them notice the fire controls ([UXPA](https://oldmagazine.uxpa.org/?p=98)). Peripheral vision does register motion and contrast changes ([UXmatters](https://www.uxmatters.com/mt/archives/2026/03/designing-with-peripheral-vision-in-mind.php)). For Onslaught, a lost life should be a short punch: shake, a red flash, then stillness. It should not be a silent number change or an endless loop. The same UXmatters column argues that constant micromovement at the margins is a cost in itself, so the wave/lives/cash/kills bar should have no idle loops.

Colour can never carry a state alone. Xbox Accessibility Guideline 103 says no cue should depend on colour ([Xbox](https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/103)). Gameplay-critical information should also go through more than one channel ([Unity Learn](https://learn.unity.com/course/practical-game-accessibility/unit/design-and-development/tutorial/important-information-and-communication)). Every state on a tower card therefore needs an icon, a shape or a text cue as well as its tint.

## Onslaught's HUD ranks into six tiers by size, saturation and position

The documented convention puts large action controls at the bottom-centre, small persistent stats in the top corners, and the screen centre only for brief alerts. It also says to trim the HUD if more than five persistent elements are on screen ([creation.dev](https://www.creation.dev/blog/roblox-ui-design-best-practices), a community source). Clash Royale keeps its key functions in the **lower 50% of the screen**. Its popups are partial overlays that close when the player taps the background ([The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)). There is also a useful split between peripheral information, which is fixed at the edges, and contextual information, which sits next to its object ([UXmatters](https://www.uxmatters.com/mt/archives/2026/03/designing-with-peripheral-vision-in-mind.php)).

Applied to the existing Onslaught elements, without moving the layout, gives this ranking. The ranking is inferred, not tested.

| Tier | Element | Hierarchy treatment |
|---|---|---|
| 1 | Build palette and turret upgrade panel | Largest, most saturated, bottom or thumb zone |
| 2 | Send-wave | The only yellow CTA. It breathes (scale 1.0 to 1.04 over about 1 s) only when it can be pressed |
| 3 | Cash | Large numerals at the top, because cash gates every purchase |
| 4 | Lives | Red heart. It stays quiet until a leak, then gives a one-off shake and flash |
| 5 | Wave counter | Medium size, top-centre |
| 6 | Kills, speed and pause | Smallest, in the corners |

Each state on a card needs at least two cues. Clash Royale shows **unaffordable prices in red text**. It once removed this cue, players got confused, and it was restored. Its cards show a **radial fill until they can be afforded** ([The Rookies](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/)). The standard TD placement ghost is tinted green on a valid spot and red on an invalid one ([Construct forum](https://construct.net/en/forum/construct-2/how-do-i-18/tower-defense-ui-65831)). Build these as Figma variants on the existing card component:

- **Affordable:** full colour, with a white price and a dark stroke.
- **Unaffordable:** the card dimmed to about 55%, a red price and a small lock or strike. The icon stays visible so players can plan.
- **Locked:** grey, with a padlock, and the unlock requirement replaces the price.
- **Selected:** a thick yellow or white outline.
- **Just affordable:** a 1.0 to 1.08 scale pop or a shine sweep.

Prices must come from data, not be baked into the art. BTD6 alone has patched individual upgrade costs, for example **Triple Shot from $400 to $450** ([Bloons Wiki](https://www.bloonswiki.com/Update_history:Bloons_TD_6/Version_47.0)).

For the upgrade panel, show filled tier pips, one big next-tier button that follows the same affordability rules as the cards, and greyed, locked maxed paths. Keep the red Sell button physically apart from Upgrade.

Touch sizing sets the floor. Targets should be at least **44 pt (Apple) or 48 dp (Material)**, and WCAG AAA is 44×44 ([OpenReplay](https://blog.openreplay.com/improving-tap-targets-mobile-ux/)). Text contrast should be **at least 4.5:1, or 3:1 for large bold text**, tested over the busiest background behind it ([tessl summary](https://tessl.io/registry/skills/github/alirezarezvani/claude-skills/apple-hig-expert)). Put interactive GUI inside **CoreUISafeInsets**, which avoids both notches and the Roblox top bar ([Roblox ScreenInsets](https://create.roblox.com/docs/en-us/reference/engine/enums/ScreenInsets.md)). Give small icons an invisible larger hit area ([skills.sh](https://skills.sh/taozhuo/game-dev-skills/ui-ux)). One correction: a community claim that 44 px is "0.06 scale at 1080p" is wrong. It is about **0.04**.

## Hard-edged Figma effect stacks build bevels that survive the trip to Roblox

Figma now allows **8 drop shadows and 8 inner shadows per layer**, plus 2 noise, 1 texture, 1 blur and 1 glass ([Figma Help](https://help.figma.com/hc/en-us/articles/360041488473-Apply-effects-to-layers)). Glass came out of beta on **January 27, 2026** ([Figma forum](https://forum.figma.com/product-updates-3/glass-is-officially-out-of-beta-50185)), but it disappears on code export ([forum](https://forum.figma.com/report-a-problem-6/glass-effect-does-not-export-to-flutter-51026)). For chunky cartoon UI, elevation means a **lip offset plus a hard shadow, not blur**.

The synthesized recipe below is not sourced from a professional tutorial. It is meant to be applied as effect styles to the existing UI v2 components, not as a redraw. Layers, from top to bottom:

1. A gloss ellipse at about 30% white, masked to the top half.
2. The body, with a light-to-mid linear gradient.
3. Inner shadows on the body: a white highlight at 0,+4 with blur 0 at about 50%, a dark lip at 0,-6 with blur 0, and a soft inner glow with blur 8.
4. A 3 to 4 px outside stroke in a dark tone.
5. A darker base duplicate offset 0,+6.
6. A hard drop shadow at 0,+4 with blur 0 at about 25% black.

The **pressed variant removes the base and shifts the body down 4 to 6 px**. This matches the guidance that drop shadows read as raised and inner shadows as pressed in ([Skyeng](https://skyeng.ru/it-industry/design/sozdaniye-teney-dlya-obyektov-v-figma-poshagovaya-instruktsiya/)).

Theme with variables, not copies. Variables hold solid colours only, but **individual gradient stops can be bound to colour variables** ([Figma forum](https://forum.figma.com/suggest-a-feature-11/support-gradient-values-in-variables-56401)). Set up a Role collection with one mode per rarity or tower colour and the variables fill-top, fill-bottom, base, stroke, highlight and text-stroke. Switching the mode on a card instance then recolours the whole bevel. Name the number tokens after their Roblox counterparts (cornerRadius, strokeThickness and so on) so the Luau theme table exports directly. Extended collections suit themes, but creating them through the Plugin API is **Enterprise-only** ([Update 121](https://developers.figma.com/docs/plugins/updates/2025/11/20/version-1-update-121)).

What maps to Roblox:

- **UIStroke** now supports **Inner, Center and Outer positions and ZIndex stacking**. Avoid tweening its Thickness on text, which flickers ([UIStroke](https://create.roblox.com/docs/en-us/reference/engine/classes/UIStroke.md)).
- **UIGradient** supports Linear, Radial and Conical gradients with TileMode.
- **UICorner** supports per-corner radii.
- **UIShadow** (beta) adds Offset, Spread and Inset ([Appearance modifiers](https://create.roblox.com/docs/en-us/ui/appearance-modifiers.md)).

Everything else, including noise, glass, blur, diamond gradients and multi-inner-shadow bevels, should be baked into 9-slice images. Corners stay fixed and edges stretch ([9-slice docs](https://create.roblox.com/docs/ui/9-slice)). A sticker outline becomes two UIStrokes with different ZIndex values. Of the community exporters, **roimport** is free and converts inner shadows to inner strokes, but supports only their spread value ([DevForum](https://devforum.roblox.com/t/free-figma-to-roblox-plugin-roimport/4731967)). **UILint v2** lints the design and rebuilds the hierarchy in Studio ([DevForum](https://devforum.roblox.com/t/plugin-uilint-v2-import-figma-ui-into-roblox-studio/4765869)). None of these plugins has been vetted for reliability.

## Five tricks borrowed from Slay the Spire, Balatro and Dead Space

**Show the next wave's intent.** Slay the Spire shows each enemy's next action as an icon plus a number, which turns surprise into planning ([Untapped](https://sts2.untapped.gg/guides/how-to-read-enemy-intent)). The TD equivalent is a small strip previewing the next wave: enemy icons, counts, and trait badges for flying, armoured or fast.

**Roll the counters.** "Juice It or Lose It" made numbers that tick up a staple, and pitch that rises with a streak ([PSU](https://www.psu.com/news/why-winning-feels-so-good-reward-design-from-arcades-to-balatro/)). Balatro adds slot-reel digit rolls, though that analysis is third-party ([Blake Crosley](https://blakecrosley.com/es/guides/design/balatro)). Keep cash rolls under about 0.4 s so the value is never stale when the player buys. Tween a NumberValue with non-overshooting easing and set the final text explicitly, because elastic easing has been reported to leave counters showing **206 instead of 200** ([DevForum](https://devforum.roblox.com/t/text-isnt-updating-correctly/2860070)).

**Count down before each wave.** The SXPD countdown pulled players' eyes to controls they otherwise missed ([UXPA](https://oldmagazine.uxpa.org/?p=98)). A "Wave 12 in 3…2…1" banner can do the same for send-wave and speed. Tween `MaxVisibleGraphemes` and `TextTransparency` for the banner reveal ([TextLabel docs](https://create.roblox.com/docs/en-us/reference/engine/classes/TextLabel)).

**Put state on the turret itself.** Dead Space moved health onto the suit's spine to remove the "wall" between player and game ([Game Developer](https://gamedeveloper.com/design/video-designing-i-dead-space-i-s-immersive-user-interface)). Onslaught can show level pips and a ready-to-upgrade glow on the turret through a BillboardGui. The world and the panel must never disagree, since HUD/world conflicts confused players in a Destiny 2 eye-tracking study ([SIGDOC](https://sigdoc.acm.org/conference/2020/wp-json/wp/v2/posts/420)).

**Make cuts by Into the Breach's rule.** Its developers would sacrifice cool ideas for clarity every time ([80.lv](https://origin.80.lv/articles/gdc-2019-an-inside-look-at-into-the-breach/)). Two further low-cost tricks are reasoned rather than sourced. First, idle-fade the stat bar to about 0.4 GroupTransparency through a CanvasGroup when nothing has changed, and restore it on any event. Its cost on mobile is unverified. Second, make a greyscale and blur squint test the acceptance gate: if the six tiers still read in order in a desaturated Studio screenshot, the hierarchy also holds for colour-blind players.

For motion timing, keep press feedback within **0 to 50 ms** of the input. Compress the button to **0.95 to 0.97, overshoot to about 1.02 and settle**. Run menus over **0.2 to 0.3 s** with Quad or Back easing, and add the bevel lip drop on press ([creation.dev](https://www.creation.dev/blog/roblox-ui-design-best-practices); [bugnet](https://bugnet.io/blog/how-to-fix-ui-button-pop-easing-feels-stiff)).

## Conclusion

Onslaught's existing art probably already has enough richness. What is missing is a contract: a written mapping of which feature means what, enforced through Figma variants and variable modes, and verified with a greyscale screenshot. The most important insight is that a signal's force depends on its scarcity. A HUD where only one thing moves at a time, and only yellow means "press me", will out-read a glossier HUD where everything shimmers. The second insight is practical: build bevels from blur-0 effects, and the Figma file becomes a near-literal Roblox spec instead of a mockup that has to be re-interpreted.

Some things remain unknown. No TD-specific or Roblox-specific HUD eye-tracking study exists. The BTD6 and Kingdom Rush layouts were not verified. Glass, noise and texture have no native Roblox equivalent. The tier ranking and the timing numbers should therefore be treated as hypotheses to validate in playtests on phones, where edge blindness will be worst.
