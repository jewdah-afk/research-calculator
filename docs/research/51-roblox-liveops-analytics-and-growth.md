# Roblox Live Operations, Analytics, Monetization and Growth

*The business and operational craft: being found, being kept, and being paid.*

Chapter compiled **2026-09-17**. Every figure below carries a source and a date. Where a number is Roblox's own published figure it is marked **[Roblox official]**; where it is my arithmetic on top of Roblox figures it is marked **[derived]**; where it is creator-reported or third-party it is marked **[third-party]** and treated as weaker evidence.

---

## TL;DR for builders

- **Discovery is a retention machine, not a popularity machine.** Roblox's Recommended-For-You ranks on *per-user averages* of organically-acquired players, in three windows — D1, D2–7, D8–28. Its two highest-priority signals are **play-through rate** and **first-play bounce rate** (a negative signal, bucketed at `<60s` and `61–180s`). Total player count is explicitly *not* a ranking input. **[Roblox official, `discovery.md`, updated 2026-07-07]**
- **The attribution firewall is the single most important structural fact.** Roblox does *not* count engagement, retention or monetization from ads, search, friends, curation or social media in the *ranking* stage of RFY. Only the behaviour of players who arrived *through RFY itself* moves your RFY ranking. You cannot buy your way up the organic sort; you can only buy your way into consideration. **[Roblox official, `discovery.md`, 2026-07-07]**
- **Most games die in the first sixty seconds.** Roblox's own onboarding reference funnel shows a **70% drop-off between funnel step 1 and step 2**. Its guidance is blunt: get players to the fun in **five minutes or less**, ideally faster. **[Roblox official, `funnel-events.md` / `retention.md`]**
- **The DevEx rate is 0.0038 USD per Earned Robux** (30,000 Robux → $114), raised from 0.0035 on **2025-09-05 10:00 PT**. A higher **0.0054** rate applies to Earned Robux from **age-verified 18+ U.S. players** in games meeting an R15/articulation bar, effective **2026-06-08**. **[Roblox official, `developer-exchange.md` / `18-plus-devex-rate.md`, updated 2026-07-07 / 2026-06-08]**
- **Engagement-Based Payouts is dead.** It was deprecated **2025-07-24** and replaced by **Creator Rewards**: 5 Robux per day per "Active Spender" who plays your game 10+ minutes *and* whose visit is one of their first three experiences that day, plus a 35% revenue share on the first $100 of platform-wide spend from new/reactivated users you brought to Roblox. **[Roblox official, `creator-rewards.md`]**
- **Roblox now ships first-party A/B testing.** `ConfigService` (remote config, up to 1,000 keys, publish in 15s–1min) plus **Experiments** (14–60 day runs, control + up to 2 variants, minimum-detectable-effect calculator, confidence intervals). Roblox's own warning: **games under ~1,000 DAU will struggle to get usable experiment data.** **[Roblox official, `experiments.md`, updated 2026-08-18]**
- **Revenue share is 70/30 on in-game Robux purchases** — confirmed explicitly in the Roblox Plus subsidy table (100 Robux item → 70 Robux to creator). Subscriptions priced in local currency are better: **70% month one, 100% from month two.** **[Roblox official, `roblox-plus.md`, `subscriptions.md`]**
- **The whale number Roblox publishes is 15/50, not 5/50.** "On average, the top 15% of active payers account for roughly 50% of revenue." Note the denominator: top 15% *of payers*, not of players. **[Roblox official, `analytics/get-started.md`]**
- **Loot boxes are legal on Roblox but heavily regulated by Roblox itself.** Any paid random item — direct or indirect, including luck boosts and pity systems — must disclose **numerical odds summing to exactly 100%**, dynamically updated, before purchase. You must call `PolicyService:GetPolicyInfoForPlayerAsync()` and honour `ArePaidRandomItemsRestricted` / `IsPaidItemTradingAllowed`, with one of six prescribed fallbacks. **[Roblox official, `paid-random-items.md`]**
- **Filtering user text is not optional and not advisory.** "If Roblox receives reports or automatically detects that your game doesn't apply text filtering, then the system removes the game until you add filtering." Use `TextService:FilterStringAsync()` server-side, then `GetNonChatStringForBroadcastAsync()` or `GetNonChatStringForUserAsync()`. Chat must go through `TextChatService`. **[Roblox official, `ui/text-filtering.md`, `chat/guidelines.md`]**
- **Launching in 2026 means launching to 16+ first, by default.** New games reach under-16 audiences only after an evaluation requiring **250 unique plays from highly engaged age-checked users within a 60-day window**, plus creator age verification, 2FA, and either a 2-month Roblox Plus/Premium subscription or a refundable **1,000 Robux** publishing fee (or **50,000 Robux** to expedite). **[Roblox official, `kids-and-select.md`, `publish-games-and-places.md`]**
- **Ship weekly; monthly is the floor.** Roblox's own guidance: "A weekly cadence for updates is ideal. At the bare minimum, aim for monthly updates," with smaller content every 2–4 weeks and major systems every 2–3 months. Publishing an update also triggers content-quality reclassification, which is your route out of a demotion. **[Roblox official, `monetization/index.md`, `retention.md`, `discovery.md`]**
- **The earnings power law is brutal and quantifiable.** Roblox states **$1.5B paid to creators in the last 12 months** and **$7M average per top-100 creator**. That implies roughly **$700M — about 47% of all creator payouts — went to 100 creators.** **[Roblox official figures, `creator-programs/jumpstart.md`, updated 2026-07-01; ratio derived]**
- **Do not launch to the algorithm before you are ready — but the damage is a rolling window, not a scar.** Use **Beta Mode** (public, excluded from RFY) to iterate. The ranking windows are rolling 28-day averages, and quality classification is re-run on every update. What *is* durable: your public like ratio, moderation history, and the Kids/Select evaluation clock.

---

## 0. How this chapter was sourced — and what it cannot tell you

**Method.** Roblox's canonical creator documentation (`create.roblox.com/docs`) is published open-source at `github.com/Roblox/creator-docs`, synchronised from Roblox's internal teams by a bot. This chapter is built primarily on a direct read of ~70 of those documents plus the engine API YAML reference, retrieved **2026-09-17** from the `main` branch. Where useful I cite each file's most recent sync date, which is the best available "as of" stamp for a Roblox policy number.

**What I could not reach, and therefore did not assert.** Network egress in this research environment blocked `corp.roblox.com`, `ir.roblox.com`, `devforum.roblox.com`, `en.help.roblox.com`, `youtube.com` and all third-party press and analytics sites. Consequently this chapter contains:

- **No Roblox quarterly investor figures** (DAU, bookings, hours engaged, total DevEx paid by quarter). The only platform-scale numbers here come from Roblox's own creator-docs marketing copy.
- **No RDC talk content.** Any RDC-sourced claim you have seen elsewhere is not verified here.
- **No third-party earnings estimates** (RoMonitor, Rolimon's, etc.).
- **No Robux retail price verification.** The commonly cited ~$0.0125/Robux consumer rate is marked UNVERIFIED wherever used, and all creator-side math is given in Earned Robux and DevEx dollars, which *are* verified.

One web search returned before the session's search budget was exhausted; its summary of a Roblox DevForum RFY announcement is corroborated line-for-line by the official `discovery.md` signal table, so I cite the official doc rather than the search result.

**How to read the confidence markers.**

| Marker | Meaning |
| --- | --- |
| **[Roblox official]** | Stated verbatim in Roblox creator documentation, with file and sync date. |
| **[Roblox illustrative]** | A worked example in Roblox docs. Real-shaped, but explicitly hypothetical. |
| **[derived]** | My arithmetic on Roblox-published numbers. Arithmetic shown. |
| **[third-party]** | Reported elsewhere; not verifiable in this session. Treat as a hypothesis. |
| **[inferred]** | My reading of mechanism from documented behaviour. Not stated by Roblox. |

---

## 1. Discovery, honestly

### 1.1 The machine: retrieval, then ranking

Roblox's Home **Recommended for You** (RFY) sort runs in two stages. **[Roblox official, `discovery.md`, updated 2026-07-07]**

**Stage 1 — Retrieval.** "The algorithm selects a subset of games that each user might enjoy playing based on key signals like engagement, retention, and monetization." Crucially, retrieval is *ecumenical* about where your early players came from:

> "Signals from sponsored ads, curation, search, charts, friends, teleport, notifications, curated games, and other social media sharing can accelerate your consideration for organic discovery from Recommended for You. Games that have even a small number of people playing can signal to the system that the game is worth considering for distribution to more users."

**Stage 2 — Ranking.** This is where the firewall sits:

> "How far your game goes and how much organic distribution it gets from Recommended For You depends entirely on the engagement and retention of users who come to your game through Recommended for You. Roblox doesn't count the engagement, monetization, or retention of users first acquired from ads, curation, friends, search, social media, or any other source in the ranking stage."

**What this means operationally.** Paid and social acquisition are *keys to the door*, not *rungs on the ladder*. A creator who spends heavily on Sponsored to manufacture a DAU number will get into consideration, and will then be ranked purely on how the RFY-sourced cohort behaves. If your ad-acquired players retain well but your RFY-acquired players bounce, your RFY distribution shrinks regardless of your headline DAU. **[inferred from the documented firewall]**

Roblox spells out the corollary with a worked example: a game acquiring 10k daily players on 25k RFY impressions that adds 5k players from Sponsored "will continue to get around the same traffic from recommendations on the Home page" as long as the RFY cohort's behaviour is unchanged. Ads *extend* reach; they do not *lever* organic reach. **[Roblox official, `discovery.md`]**

### 1.2 The ranked signal list — documented, in priority order

This is the highest-value table in Roblox's entire public documentation, and it is unusually explicit. **[Roblox official, `discovery.md`, updated 2026-07-07]**

**Most important**

| Signal | Definition | Time segments |
| --- | --- | --- |
| **Play-through rate** | Rate at which users play your game after seeing it in RFY. | N/A |
| **First-play bounce rate** *(negative signal)* | Rate at which users leave after a short session. "High bounce rates suggest players aren't finding enough to stay engaged early in their session." | `<60 seconds` average rate; `61–180 seconds` average rate |
| **Play days per user** | Average number of unique days users engage. | D1 / D2–7 / D8–28 averages |
| **Playtime per user** | Average time spent. **Capped at 60 minutes per user, per game, per day.** | D1 / D2–7 / D8–28 averages |

**Important**

| Signal | Definition | Time segments |
| --- | --- | --- |
| **Intentional co-play days per user** | Unique days users return *with friends* — via join, invites, or private servers. | D1 / D2–7 / D8–28 |
| **Qualified play sessions per user** | Average "meaningful" sessions per RFY-clicked user; "filters out accidental clicks or quick bounces." | D1 / D2–7 / D8–28 |
| **Spend days per user** | Unique days users spend Robux in your game. | D1 / D2–7 / D8–28 |
| **Robux spent per user** | Average Robux spent per user. | D1 / D2–7 / D8–28 |

Five consequences worth internalising:

1. **The 60-minute playtime cap is a design constraint.** Optimising for marathon sessions past an hour buys you *zero* additional ranking credit on the playtime signal. Optimising for a player returning tomorrow buys you credit on play-days, co-play-days, qualified sessions *and* spend-days. **Frequency beats duration.** **[derived from the documented cap]**
2. **Bounce is measured in two buckets under three minutes.** Your entire ranking exposure on the second-most-important signal is decided before a player has been in your game for 180 seconds.
3. **Monetization is a ranking signal, but the *lowest*-priority tier.** Spend days and Robux spent sit in "Important," below all four engagement/retention signals. Games that monetize aggressively at the expense of bounce rate are trading a high-weight signal for a low-weight one. **[derived]**
4. **"Intentional co-play days" is the only signal that directly rewards social design.** Invites, friend-joins and private servers are ranking inputs, not just nice-to-haves.
5. **Averages, not totals.** Roblox explicitly answers the question "do these favour larger games?" with: "No. These recommendation signals are calculated as averages per user, not total values. This ensures that smaller games with highly engaged users are not disadvantaged."

### 1.3 Explore and expand

> "Roblox's recommendation system uses **explore and expand** phases... you might see a spike in new users from recommendations (explore) after a content update. If that new user cohort has good engagement and monetization, Roblox is more likely to continue to recommend your game to more such user cohorts (expand)." **[Roblox official, `discovery.md`]**

This is a bandit. An update buys you a metered trial with a fresh audience; your retention on that trial decides whether the meter opens further. Roblox also warns that during expansion "you may notice a temporary drop in play through rate when your impressions increase... this is a normal occurrence."

It also warns about the part nobody wants to hear: "If other games are significantly more successful at engaging players, your game's distribution may decrease, even if your own engagement signals remain steady." Distribution is a zero-sum auction against every other game on the platform.

### 1.4 The four things that move your impression count

Roblox names exactly four. **[Roblox official, `discovery.md`]**

1. What you do — updates and gameplay changes influencing your signals.
2. What Roblox does — algorithm changes.
3. Total Home-page traffic — weekly seasonality (peaks Saturday), summer/back-to-school, holidays.
4. Competitive pressure from other games.

Two of the four are outside your control. Read your impression charts with that in mind before you attribute a dip to your last patch.

### 1.5 The other surfaces

RFY is not the whole platform. **[Roblox official, `discovery.md`, `acquisition.md`]** The Acquisition dashboard enumerates every attributable source:

| Source | Surface |
| --- | --- |
| Home recommendations | RFY on Home |
| Continue play | Continue Play row |
| Today's Picks | Curated daily sort (nominate via survey; editorial review) |
| Home other | Favorites and residual Home traffic |
| Friends | Friend Activity section |
| Search | Organic search + "Recommended Experiences" on detail pages |
| Charts | All sorts on the Discover page |
| Sponsored ads | Sponsored experiences + Sponsored Takeovers |
| Search ads | Keyword-targeted ads |
| Portal ads | Immersive portal ad teleports |
| Teleport | Traffic from another game |
| Other | Unattributed, including all external traffic |

Note the last row: **all off-platform traffic lands in "Other" unless you use a share link.** If you run YouTube or TikTok campaigns without share links, your acquisition dashboard is blind to them.

**Curated sorts you can apply to** (all reviewed by humans, all "nominate and wait"):

- **Standout Games** — daily curation of *novel* games. Roblox states what it is hunting: "RPG, strategy, puzzle, and shooter games are heavily underrepresented despite strong demand from older age groups," plus visual styles that make players think "Wait, that's Roblox?" It explicitly says "Games that seem like a copy or reskin of a popular Roblox game are a hard sell." **[Roblox official, `standout-games.md`]**
- **Today's Picks on Home** — editorial, ongoing review, re-apply on every notable update. **[Roblox official, `todays-picks-home.md`]**
- **Learn & Explore** — educational sort; eligibility requires **like ratio above 50% and at least 15 concurrent users**, and explicitly disqualifies "aggressive monetization as a part of their first time user experience." **[Roblox official, `learn-explore-sort.md`]**
- **Live Events** — quest-linked limited-time event sort.

**Search** is moving from keyword matching to intent: "you can now use semantic search for all of our officially supported languages to find games through natural language queries, such as 'food games' or 'avatar editors'." **[Roblox official, `discovery.md`]** Practical implication: your description should read like a *description*, not a keyword dump — and Roblox penalises keyword dumps directly (see §1.7).

**Notifications** are a real re-engagement surface but heavily throttled — see §6.5.

### 1.6 Top of funnel: icon, title, description, thumbnail

This is the only part of the funnel where a solo creator can get a double-digit percentage win in an afternoon.

**Icon.** 512×512 minimum, square, must stay legible when scaled to 150×150. Should express theme, tone and/or genre. One icon per locale. **[Roblox official, `experience-icons.md`]**

**Thumbnails.** Up to 10 images or videos per detail page; 16:9, ideally 1920×1080. Uploaded gameplay video is free with a **monthly quota of 3 uploads**, and rejected videos still count against the quota. Video rules are strict and worth reading before you shoot: camera work, minor post-processing, curated highlight sequences, in-game UI text and catalogue music are all fine; **voice-over, narration and music with lyrics are not permitted**, nor is real-life footage or artificially enhanced graphics. **[Roblox official, `thumbnails.md`]**

**Thumbnail personalization** is the single best-documented conversion lever Roblox offers, and it is free:

> "During testing, games using thumbnail personalization had an average increase of **+8.5% in their qualified play through rate**. Some games had an increase of **+50%**." **[Roblox official, `thumbnails.md`]**

Mechanics: activate **2–5** thumbnails (it does nothing with one). The system shows each thumbnail to a random slice of users, measures qualified play-through rate per user group, then gives more impressions to the per-group winner while retaining exploration traffic for the others. Roblox's explicit warning is to **keep multiple thumbnails active** rather than crowning a winner, "as this allows personalization to adapt to changing user trends," and to **test new thumbnails with every major update**. **[Roblox official, `thumbnails.md`]**

**Title and description.** Roblox's stated rules: keep the name consistent (renaming hurts findability), avoid keyword repetition, use at most one or two well-placed emoji. Summarise the game in the *first sentence* of the description — that sentence is the strongest signal to both players and the discovery system. Include genuinely relevant keywords naturally; a keyword-stuffed description is called out in the docs as grounds for demotion. **[Roblox official, `publish-games-and-places.md`]**

### 1.7 Documented ways to get demoted

Roblox lists three "issues that limit exposure," each with an example. **[Roblox official, `discovery.md`]**

| Issue | Roblox's example |
| --- | --- |
| **Leading with giveaways** | A game titled "Robux! Play now!" gets less exposure because the title leads with monetary implications. |
| **Mismatched metadata and content** | "The Great Dinosaur Quest" with dinosaur thumbnails but generic obby gameplay is not recommended and is less visible in search. |
| **Non-unique games** | Games whose metadata and place files closely resemble existing games "are no longer prioritized for recommendations and might rank lower in search results." |

Two operational details you should act on:

- **There is a public diagnostic.** "Games with reduced exposure display a banner that updates daily" on the Creator Dashboard, "provid[ing] the latest status about quality and visibility." Check it before you theorise about a traffic drop.
- **Demotion is not permanent.** "Roblox continually reclassifies content quality with every update, giving all games the opportunity to improve their reach." Shipping a genuine update is the documented remedy.

Roblox also states a policy that catches a lot of growth-hacking: "You should not rely on promotional monetary rewards to drive engagement. Instead, your metadata should reflect what your game is about."

### 1.8 Documented vs inferred — a scorecard

| Claim | Status |
| --- | --- |
| RFY is two-stage retrieval → ranking | **Documented** |
| Signal list, priority tiers, D1/D2–7/D8–28 windows | **Documented** |
| Playtime capped at 60 min/user/game/day for ranking | **Documented** |
| Bounce buckets at `<60s` and `61–180s` | **Documented** |
| Ranking ignores non-RFY-sourced users | **Documented** |
| Signals are per-user averages, not totals | **Documented** |
| Updates create a "freshness" boost in Trending/Recommended | **[third-party]** — widely creator-reported; Roblox documents the *explore/expand* re-trial after updates and quality reclassification on update, but does not document a discrete "freshness boost" |
| Exact weights of each signal | **Not documented.** Roblox gives ordinal priority only, and states weights change over time |
| Like ratio is a ranking input | **Not documented** for RFY. It *is* a published eligibility criterion for the Learn & Explore sort and is displayed publicly |
| CCU is a ranking input | **Not documented**; the documented signals are all per-user averages |

---

## 2. The funnel and its metrics

### 2.1 The stages

```
impression  →  click  →  join/load  →  first 60s  →  first session  →  D1  →  D7  →  D30
   RFY /         play-through      first-play        qualified        play days per user
 search /        rate              bounce rate       play session     (D1 / D2-7 / D8-28)
 sponsored
```

Roblox's own metric names map cleanly onto this:

| Stage | Roblox metric | Where you see it |
| --- | --- | --- |
| Impression | *Unique users with impressions by source* | Analytics ▸ Acquisition |
| Click → play | *Play through rate*; *Conversion rate* ("percent of new users who played after viewing an impression") | Acquisition; Home Recommendations tab |
| First 60s | *First-play bounce rate* (`<60s`, `61–180s`) | Home Recommendations tab |
| First session | *New User First Session Retention* — "how many new users are still playing X minutes after joining for the first time" | Analytics ▸ Engagement |
| Session quality | *Average session time* | Engagement |
| D1 / D7 / D30 | Retention cohorts, x-axis = first-play date | Analytics ▸ Retention |
| Monetization | Conversion rate, ARPPU, ARPDAU, revenue | Analytics ▸ Monetization |

**[Roblox official, `acquisition.md`, `engagement.md`, `retention.md`, `discovery.md`]**

### 2.2 What "good" looks like — and the honest caveat

**Roblox will not publish absolute benchmarks, and for a defensible reason: it gives you *your own* percentile band instead.** The dashboard shows, per KPI, the **50th–90th percentile range of "games with similar players"** — a model-selected peer set of games your players also play, refreshed daily, requiring peers with at least 100 DAU. If the model can't find enough similar games it falls back to **Genre**, then to **All experiences**. **[Roblox official, `analytics-dashboard.md`]**

Available similar-game benchmark KPIs:

- **Retention** — all KPIs
- **Engagement** — average session time
- **Monetization** — ARPPU, ARPDAU, conversion rate
- **Acquisition** — play-through rate

Roblox's worked example, which is the closest thing to a published absolute number in the docs:

> "For example, if you see your Day 1 Retention benchmark's 50th–90th percentile is **12.11% – 18.73%**, it means that: 50% of games with similar players have a Day 1 Retention of 12.11% or lower. 10% of games with similar players have a Day 1 Retention of 18.73% or higher." **[Roblox illustrative, `analytics-dashboard.md`]**

Treat that band as *shape*, not *truth*: it is an example in documentation, not a published platform statistic. But the shape is informative — it says a median Roblox game's D1 retention lives in the low teens, and top-decile in the high teens. If your own dashboard band looks wildly different, trust the dashboard.

For "overall success" KPIs (as distinct from per-user behaviour), the benchmark pool is different: **the top 1,000 games by total playtime over a rolling 30 days, excluding games under 30 days old**, banded into **Top 200 / Top 500 / Top 1000** tiers. **[Roblox official, `analytics-dashboard.md`]**

**Crucially, Roblox states that benchmarks are not an algorithm input:** "Benchmarks and benchmark games do not impact the Recommended for You algorithm in any way." They are a mirror, not a lever.

### 2.3 Where games actually die

The documented answer is: **the first minute, then the first week.**

- **First-play bounce rate is the #2 ranking signal**, and it is evaluated entirely inside 180 seconds. **[Roblox official, `discovery.md`]**
- Roblox's own reference project funnel (*Plant*) shows a **70% drop-off between step 1 ("In Farm") and step 2 ("Plant Seed")** — i.e. seven in ten players who load in never complete the first action of the core loop. **[Roblox official, `funnel-events.md`]** This is Roblox's *demonstration* game, built to be exemplary, and it still loses 70% at step one.
- Roblox's retention guidance names the causes of low D1 explicitly: "A low D1 is indicative of low retention, often as a result of a poor user onboarding game. This usually means the player is confused or frustrated, or they're not getting to the fun fast enough." **[Roblox official, `analytics/get-started.md`]**

And the diagnosis ladder, which is worth memorising because it's Roblox's own:

| Metric weak | Roblox's stated root cause | Where to fix |
| --- | --- | --- |
| **D1** | Core loop, first-time user experience, performance | Onboarding, FTUE, device performance |
| **D7** | Progression system — "players not having a tangible reason to see themselves playing your game a week from when they started" | Goals, content variety, difficulty balance |
| **D30** | "Ending system" — lack of end-game content or end-game goal | New content cadence, social mechanics (trading, parties, guilds, PvP, tournaments, leaderboards) |

**[Roblox official, `retention.md`, `analytics/get-started.md`]**

### 2.4 FTUE design implications

Roblox's documented FTUE doctrine, condensed:

1. **Get to the fun in ≤5 minutes.** "Avoid a complex or time consuming FTUE, as you want to get users to the fun as quickly as possible, ideally in 5 minutes or less after entering your game." Given the `<60s` bounce bucket, treat 5 minutes as the *outer* bound and 60 seconds as the real target. **[Roblox official, `retention.md`]**
2. **No long tutorials.** "If you lock all the fun of your game behind a lengthy tutorial, users might get bored and move on." Make learning **contextual and action-based** — short unobtrusive pop-ups when a player first meets a feature, tooltips in the shop. **[Roblox official, `engagement.md`]**
3. **Give starter items and currency** so players can run the core loop immediately.
4. **Deliver a joyful moment** the first time a player completes the core loop, and **preview the progress** available from repeating it.
5. **Design visually, not textually.** "Many younger users struggle to read text-heavy interfaces, and regardless of ability many younger users are more reading-averse. Visual UI is also easier to translate." **[Roblox official, `design-for-roblox.md`]**
6. **Match genre conventions.** "The closer your design patterns and user experience are to the most popular games in that genre, the less you have to explain upfront." Novelty belongs in your content, not your control scheme.
7. **Remove barriers to social interaction.** Roblox states plainly that "single-player games often find it harder to build and retain an audience on Roblox."
8. **Performance is an FTUE feature.** "Most users play Roblox on mobile devices, and the audience is sensitive to friction and load times." A 30-second load on a mid-range Android *is* your bounce rate.

And the instrumented version of all of the above: Roblox tells you to list your core loop's steps, mark completion of each with a tracked event, "track both positive and negative experiences" (e.g. both win *and* loss in an FTUE battle), and fix the biggest drop-off. **[Roblox official, `retention.md`]**

### 2.5 Instrumenting each stage

| Stage | Instrument |
| --- | --- |
| Impression → click | Nothing to instrument in-game. Read *play through rate* on Acquisition; A/B it with **thumbnail personalization** (§1.6) |
| Join | `AnalyticsService:LogOnboardingFunnelStepEvent(player, 1, "Player Joined")` fired on `Players.PlayerAdded` — Roblox documents exactly this pattern |
| First 60s | Onboarding funnel steps 2..n on each first-time action; cross-check *New User First Session Retention* chart |
| Core-loop completion | A custom event per loop completion (e.g. `HarvestPlant`) with a custom field for variant |
| Progression | `LogProgressionStartEvent` / `LogProgressionCompleteEvent` / `LogProgressionFailEvent`, or `LogJourneyEvent` for non-linear paths |
| Economy | `LogEconomyEvent` on every source and sink, *after* the transaction succeeds |
| Shop | A recurring funnel with a GUID `funnelSessionId` per shop-open |
| Crashes/perf | Performance + Crashes dashboards; **Alerts** with webhook delivery |

Full API detail in §3.

---

## 3. Analytics

### 3.1 The built-in dashboards, and the eligibility gates

Roblox's Creator Hub analytics is genuinely good and genuinely free. But almost every feature has a population gate, and knowing them saves you from hunting for a dashboard you can't have yet.

| Feature | Gate | Source |
| --- | --- | --- |
| Full KPI dashboard access | **>10 DAU and 10 play hours for 7 consecutive days**; verified email + 2FA; accept ToS | `analytics-dashboard.md` |
| Similar-game benchmark scorecards | **100+ DAU** | `analytics/index.md` |
| Insights (major metric movements) | **100+ DAU**, updated daily | `insights.md` |
| Performance dashboard & **Alerts** | **100+ DAU** | `performance.md`, `alerts.md` |
| AI-generated weekly/monthly reports | **1,000+ DAU** | `insights.md` |
| Player-feedback reports | **20+ feedback comments** | `insights.md` |
| Experiments (usable results) | Roblox: games under **1,000 DAU** "might struggle to get useful data" | `experiments.md` |
| Price optimization | **~60,000 transactions in the previous 30 days** | `price-optimization.md` |
| Experience notifications | **100 visits since launch** | `experience-notifications/eligibility` |
| Rewarded video ads | **2,000 unique visitors/month**, 13+, ID-verified | `rewarded-video-ads.md` |

**[All Roblox official, retrieved 2026-09-17]**

**Dashboard sections:** Retention, Engagement, Acquisition, Demographics, Feedback, Monetization — plus Economy, Funnels and Custom once you emit the corresponding events. **[Roblox official, `analytics-dashboard.md`]**

**Monetization KPIs Roblox tracks for you:** revenue (split by developer products, passes, commissions), **conversion rate** ("percent of daily active users who are also paying users"), paying users, **ARPPU**, **ARPDAU**. **[Roblox official, `analytics/monetization.md`]**

**Retention cohorts** are indexed on *first-play date*, not calendar date, which is the correct construction: "the date 06/20 on all three charts shows you the same cohort." Daily cohorts cover the first 10 days; weekly cohorts cover 10 weeks. Each cohort carries down-funnel metrics: **7D cumulative playtime per user, 7D cumulative payer conversion, 7D cumulative revenue per user, 30D cumulative revenue per user** — which is how you answer "did the players my Halloween event brought in actually monetize?" **[Roblox official, `retention.md`]**

**Segmentation** is the most underused feature. Available breakdowns/filters include Age Group, Platform, OS, Country, Language, **Active payer status**, **When user first played**, **Platform spender status**, **In-experience activity status**, **User engagement**. **[Roblox official, `analytics-dashboard.md`, `configs.md`]**

**The Explore page** (unlocked by emitting custom events) gives you a real analysis surface: pick a source and metric, break down by segment or custom field, choose chart type, and — importantly — build **calculated metrics** with `+ - * /` and constants. Roblox's suggested formulas are exactly the right ones:

- **Win rate** = `RoundWins / RoundsPlayed` — tracks difficulty drift over time
- **Economy health** = `CurrencySources - CurrencySinks` — real-time inflation monitor
- **Feature adoption** = `EquippedWeapon / TotalPlayers`

Plus **overlays** (benchmark line, period-over-period at a chosen offset such as 28 days) and **7-day moving-average smoothing** to strip weekly seasonality. Chart URLs encode your configuration, so you can bookmark and share a view. **[Roblox official, `analytics-dashboard.md`]**

**Sales data** is downloadable as transaction records — buyer, sale date, revenue, hold status — updated every 48 hours, with "Revenue" defined as "the item listing price excluding any Marketplace fees, Affiliate Fees, and Recurring Group Payouts." **[Roblox official, `analytics-dashboard.md`]**

### 3.2 `AnalyticsService`: the API surface

All events are **server-only and published-game-only**. They cannot be sent from the client or from Studio. **[Roblox official, `custom-events.md`, `funnel-events.md`, `economy-events.md`]**

**Economy events** — one call per source or sink, after the transaction succeeds:

```lua
local AnalyticsService = game:GetService("AnalyticsService")

AnalyticsService:LogEconomyEvent(
    player,
    Enum.AnalyticsEconomyFlowType.Sink,   -- or .Source
    "Coins",                               -- currency name (max 10 resource types)
    80,                                    -- amount, ALWAYS positive
    20,                                    -- balance AFTER the transaction
    Enum.AnalyticsEconomyTransactionType.Shop.Name,
    "Obsidian Sword",                      -- itemSku (optional)
    {                                      -- up to 3 custom fields, string values only
        [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "Category - Weapon",
        [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = "Class - Warrior",
        [Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = "Level - 10",
    }
)
```

Built-in transaction types: `IAP`, `TimedReward`, `Onboarding`, `Shop`, `Gameplay`, `ContextualPurchase`. You may supply your own names, but the six defaults are what the dashboard is built around. **[Roblox official, `economy-events.md`]**

**Funnel events** — two flavours:

```lua
-- One-time funnel (onboarding). No session id needed.
AnalyticsService:LogOnboardingFunnelStepEvent(player, 1, "In Farm")
AnalyticsService:LogOnboardingFunnelStepEvent(player, 2, "Plant Seed")

-- Recurring funnel (shop). Session id distinguishes repeat runs.
local funnelSessionId = HttpService:GenerateGUID()
AnalyticsService:LogFunnelStepEvent(player, "ArmoryCheckout", funnelSessionId, 1, "Opened Store")
AnalyticsService:LogFunnelStepEvent(player, "ArmoryCheckout", funnelSessionId, 2, "Viewed Item")
AnalyticsService:LogFunnelStepEvent(player, "ArmoryCheckout", funnelSessionId, 3, "Added to Cart")
```

Semantics you must know or your funnels will lie to you: **[Roblox official, `funnel-events.md`]**

- Repeated steps count **only the first instance**.
- Skipped steps **auto-complete all earlier steps** — logging step 3 without 1 and 2 marks 1 and 2 complete.
- Filters apply **only to the first step**, so a player who switches from mobile to desktop mid-funnel is attributed to mobile.
- Funnels are cohorted by **entry date**, not completion date.
- Only the **10 most recent unique `funnelSessionId` values per user per funnel** are tracked.
- For item-upgrade funnels spanning sessions, build a deterministic key like `<playerId>-<itemId>` rather than a GUID.

**Journey events** are newer and under-used — non-linear graph traversal rendered as a **Sankey diagram** in Creator Hub:

```lua
AnalyticsService:LogJourneyEvent(player, "LobbyToMatch", "ChoseLoadout", journeySessionId, customFields)
```

Node names cannot contain `,` `"` `'` or newlines, and cannot start with `__`. **[Roblox official, `AnalyticsService.yaml`]** Use this where funnels are the wrong shape — e.g. an open-world hub where players can go to the shop, the arena or the quest board in any order.

**Progression events**: `LogProgressionStartEvent`, `LogProgressionCompleteEvent`, `LogProgressionFailEvent`, `LogProgressionEvent`. **[Roblox official, `AnalyticsService.yaml`]**

**Custom events** — counters and values:

```lua
AnalyticsService:LogCustomEvent(player, "MissionStarted")                  -- counter
AnalyticsService:LogCustomEvent(player, "MissionCompletedDuration", 120)   -- with value
```

Aggregations available on every event: count, unique users, average, sum, min, max, average-per-user. **[Roblox official, `custom-events.md`]**

### 3.3 Limits — the table you will hit

| Scope | Limit | Value |
| --- | --- | --- |
| Global | `AnalyticsService` requests per minute | **120 + (20 × CCU)** |
| All event types | Custom fields | **3** |
| All event types | Unique values across all custom fields | Unlimited, but **after 8,000 combined values, grouped as "Other"** |
| Economy | Resource types | **10** |
| Economy | `transactionTypes` | After **20**, grouped as "Other" |
| Economy | `itemSkus` | After **100**, grouped as "Other" |
| Funnel | Number of funnels | **10** |
| Funnel | Steps per funnel | **100** |
| Custom | `eventNames` | **100** |
| All | Data retention | **Rolls off 90 days after last data received** |

**[Roblox official, `event-types.md`]**

**The cardinality lesson Roblox repeats three times:** use custom fields, not event names. Instead of `PlantCabbage` / `PlantTurnip` / `PlantPepper` (three of your 100 event names), emit one `PlantSeed` event with custom field `Plant - Cabbage` etc. You get the total *and* the per-variant comparison in one visualization, and you burn one name instead of three.

**Validation.** Every event page has a **View Events** button giving a near-real-time feed of recent events — use it before you wait 24 hours for charts. Roblox's own gotcha: if you see more events than expected, check that you're logging **after** a successful operation, not on attempt. **[Roblox official, `event-types.md`]**

**Exploiter hygiene.** Roblox documents the pattern explicitly: clients fire a `RemoteEvent`, the server validates the step number against a known maximum before logging. Without this, a single exploiter can poison your onboarding funnel. **[Roblox official, `funnel-events.md`]**

### 3.4 Runtime segmentation: `GetPlayerSegmentsAsync`

A newer, genuinely useful API: server-only, returns coarse segment buckets for a player, cached per player for the server session. **[Roblox official, `AnalyticsService.yaml`, `analytics/index.md`]**

Returns a dictionary with `HasData` (bool), `ActivePayerStatus`, `WhenUserFirstPlayed`, `PlatformSpenderStatus`. If segment data is unavailable it does **not** throw — it returns `HasData = false` with all enums `Unknown`, so write your fallback path first.

Documented uses: show lower-cost entry items to never-spenders and bundles to prior purchasers; give players in their first 30 days extra tutorials and tooltips while routing veterans to end-game content.

Caveat: these are *coarse* buckets, and the underlying statuses are "calculated daily," so don't build anything that needs same-session precision on them.

### 3.5 What is actually worth logging

A defensible minimum set for a small team, in order of value:

1. **Onboarding funnel, 4–7 steps**, step 1 on `PlayerAdded`, subsequent steps on each first-time core-loop action. This is where your D1 lives.
2. **Core-loop completion**, as one custom event with a variant custom field.
3. **Every currency source and sink**, via `LogEconomyEvent`, with correct post-transaction balances. Without this you cannot see inflation, and inflation is what kills a Roblox economy over a 6-month horizon.
4. **Shop funnel**, recurring, GUID per open: opened → viewed item → initiated purchase → completed. The gap between "initiated" and "completed" is your purchase friction.
5. **Progression milestones** (level reached, zone unlocked) as a progression or journey event. This is how you diagnose D7.
6. **Failure states** — deaths, losses, quest abandons — with a custom field for cause. Roblox explicitly tells you to "track both positive and negative experiences."
7. **Feature adoption** — did anyone open the new menu you shipped? One counter per feature, retired after the question is answered.

**What is *not* worth logging:** anything you can already read from the built-in dashboards (DAU, session time, revenue, retention — Roblox computes these for free and better than you will); per-frame or per-tick telemetry (you will hit `120 + 20×CCU`/min); anything you have no decision attached to. Every custom event name you spend is 1% of a hard budget of 100, permanently.

**Batch, don't spam.** Roblox's own guidance: send "10 zombies killed instead of 1 zombie killed ten times" using the value parameter.

### 3.6 Rolling your own telemetry

Three viable routes, in increasing order of effort:

**DataStore-based.** Fine for *state* (a player's funnel position, their A/B assignment if you need cross-session continuity), useless for *analysis* — DataStores are key-value, not queryable, and you'll pay in request budget. Roblox's own reminder is worth heeding for a different reason: "Roblox doesn't automatically record product or purchase information. To prevent data loss, you must carefully store this data using `DataStoreService` or another data storage service hosted outside of Roblox." **[Roblox official, `monetization/index.md`]** Purchase receipts are the one thing you *must* persist yourself.

**External endpoint via `HttpService`.** The standard path for teams that want SQL. Practical constraints: server-only, subject to `HttpService` rate limits, and you are now responsible for an ingestion endpoint, its uptime, and its cost. Batch aggressively (accumulate in memory, flush every 30–60s and on `BindToClose`). Do not send anything that could identify a minor beyond a Roblox `UserId`.

**Open Cloud webhooks.** Roblox fires webhook notifications for four subscription events — **cancelled, purchased, refunded, renewed** — "immediately, so you can respond in real time or create your own custom analytics." **[Roblox official, `subscriptions.md`]** If you sell subscriptions, this is the cheapest accurate revenue pipeline available.

**Alerts** deserve a mention as ops telemetry: up to **20 alerts per experience**, evaluated at minute / half-hour / hourly / daily granularity, with a **1–10 consecutive-breach duration**, optional filters (including **place version**) and breakdowns, and **webhook delivery** to PagerDuty or Discord. Roblox's worked example is the right one: "Client crash rate is above 5%" for 5 minutes, critical severity, fired right after a deploy. **[Roblox official, `alerts.md`]**

### 3.7 A/B testing on Roblox — it is first-party now

This is the biggest change to the analytics story in the last two years, and a lot of older advice about rolling your own bucketing is now obsolete.

**`ConfigService` — remote config.** Up to **1,000 active configs**; types string / number / boolean / JSON; string and JSON capped at **100,000 characters**. Changes go to a **staged** state visible only to your team in Studio, then publish "almost instantly (roughly between 15 seconds and 1 minute)" or gradually over 15 minutes. **[Roblox official, `configs.md`, updated through 2026]**

```lua
local ConfigService = game:GetService("ConfigService")
local configSnapshot = ConfigService:GetConfigAsync()
local bossHealth = configSnapshot:GetValue("bossHealth")
```

**Conditional configs** target by: Country, Language, New vs returning, **Source** (how the player found you — recommendation, search, sponsored ad), When user first played, In-experience active payer status, In-experience activity status, User engagement, Platform spender status, Platform activity status. Rules are ordered globally; first match wins. **[Roblox official, `configs.md`]**

**Experiments — proper A/B tests.**

| Parameter | Value |
| --- | --- |
| Duration | **14–60 days** |
| Variants | Control + **up to 2 variants** (in-game); up to 3 variants (matchmaking, split equally) |
| Rollout | You choose the % of players eligible; splits are *within* that rollout |
| Tracked metrics (always, regardless of goal) | D1 retention, D7 retention, playtime, ARPU, ARPPU, payer conversion rate, session time |
| Concurrency | One active experiment per config key |
| Config safety | The config key **and any global conditions it references are locked** for the duration |
| Viable scale | "Games with fewer than **1,000 daily active users** might struggle to get useful data" |

**[Roblox official, `experiments.md`, updated 2026-08-18]**

**Assignment.** Use `GetConfigForPlayerAsync()` (not `GetConfigAsync()`), then call `GetValue()`. Enrollment happens **on the first `GetValue()` call** for that key, and only the first call is random — every subsequent call returns the same assignment for the experiment's duration.

```lua
local function onPlayerAdded(player)
    local playerConfig = ConfigService:GetConfigForPlayerAsync(player)
    local leaderboardColor = playerConfig:GetValue("leaderboardColor")
end
Players.PlayerAdded:Connect(onPlayerAdded)
```

Roblox's own best-practice here is subtle and important: **"Wait to call `GetValue()` until you need it. Calling `GetValue()` too early can cause you to enroll players who never interact with the part of the game you're experimenting on."** Enrolling players who never see the variant dilutes your effect toward zero and wastes sample.

**Per-session evaluation gotcha.** Targeting attributes are evaluated *per session*. A player who matched "first 30 days" on day 0 stops receiving the experiment value once they age out — "if your experiment needs continuity beyond eligibility — for example, a multi-session onboarding flow targeted at new players — persist the value yourself, such as in a data store." Their *data* stays attributed to their original arm (D7 retention still counts them correctly). **[Roblox official, `experiments.md`]**

**Sample size and significance.** Roblox computes a **minimum detectable effect (MDE)** from your goal metric, DAU, rollout %, duration and variant split. Its guidance: "If the MDE is too high for your goal metric (for example, more than 100%), it's unlikely you can reach statistical significance." Significance is read off the confidence interval: **"A metric is statistically significant when the confidence interval for its percent change does not overlap with 0%."** Roblox's example: D1 retention up 17.4%, CI [8.02%, 22.03%] — significant.

**Roblox's experiment discipline, verbatim and worth adopting wholesale:**

- **Start with a hypothesis** — "a cause-and-effect statement about what you changed, what you expect to happen, and why."
- **Let experiments run their full duration.** "The novelty effect... can heavily skew early results, sometimes causing them to swing in and out of statistical significance."
- **Don't act without statistical significance.** "If a change isn't statistically significant, ignore it."
- **Avoid changes during experiments** — "changes to game content can impact player behavior and invalidate your results, even if the changes *seem* unrelated."
- **Prefer simple 50/50 tests on large rollouts.** "The experiments are easier to configure, and the results are easier to interpret."
- **Document findings and decisions**, win or lose.

**Making the decision** is a guided flow: Roblox warns you about significance and duration, then rolls the winning variant into your permanent configs (with defined rules for how a *targeted* winner is merged back into your condition stack).

**Price optimization** is a separate, Roblox-run price test (see §4.8) and does not use the Experiments system.

**What Experiments cannot do.** No multi-variate testing beyond 2 variants; no experimenting on subscriptions' prices; no experiment on a config key that another experiment is using; and the whole system is useless below ~1,000 DAU. Below that scale, your honest options are: qualitative feedback, funnel drop-off analysis, and sequential before/after with a period-over-period overlay — accepting that you are reading correlation.

### 3.8 The analysis loop

Roblox states the loop; it is the right one. **[Roblox official, `analytics/index.md`, `get-started.md`]**

1. **Analyse** metrics against your similar-game benchmark bands to find the weakest one.
2. **Change one thing** via a config or an experiment.
3. **Monitor** across *all* tracked metrics, not just your goal — "If one metric is significantly up and another significantly down, you have to decide whether the trade-off is worth it."
4. **Repeat.**

And the sequencing rule that most small teams get backwards:

> "**Before driving too many new users to your game**, grow [D1 retention, average session time, then D7/D30, then payer conversion and ARPPU] to a level that's comparable to or above the benchmarks for similar games." **[Roblox official, `analytics/index.md`]**

Then, and only then, drive acquisition. Then monitor after every update: D1 and D7 retention, average session time, payer conversion / ARPPU / revenue, new users and play-through rate.

---

## 4. Monetization models

### 4.1 Robux, Earned Robux, and DevEx

**Earned Robux** is the only kind that converts to money. It comes from: in-game item sales (developer products, passes, subscriptions), fees from in-game Marketplace purchases, Robux Transfers via the Transfer API, paid private servers, paid access in Robux, Roblox Plus incentives, in-game ad publishing, Creator Store model/plugin sales, Marketplace avatar item sales, and **Creator Rewards**. **[Roblox official, `developer-exchange.md`, updated 2026-07-07]**

Explicitly **not** Earned Robux: purchased Robux, subscription stipends, trading/resale of items you didn't create, received transfers, gift-card redemptions, passes on template games with no legitimate visits, and moderated content.

**The DevEx rates, with dates:**

| Rate | Value (USD per Earned Robux) | Effective | Source |
| --- | --- | --- | --- |
| Standard | **0.0038** (30,000 Robux → **$114**) | since **2025-09-05, 10:00 PT** | `developer-exchange.md` |
| Legacy standard | 0.0035 (30,000 → $105) | before 2025-09-05 | `developer-exchange.md` |
| **U.S. 18+ rate** | **0.0054** | from **2026-06-08** | `18-plus-devex-rate.md` |

**[All Roblox official]**

Balances earned before 2025-09-05 cash out at 0.0035 and **must be cleared first** before any newer balance converts at 0.0038. Spending Robux on-platform does not clear the legacy balance — only cashing out does.

**The 18+ rate is conditional on your character rig, which is a genuinely odd and consequential rule.** To qualify, Earned Robux must come from developer products, passes, subscriptions or private servers purchased by **U.S. players age-verified 18+** (via facial age estimation or government ID), *and* your game must have player characters that spend **100% of active playtime** as either: a standard/advanced **R15** platform avatar; a custom human-form character with ~1 head / 2 arms / 2 legs, 12 limb parts or joints equally distributed, a 2-part torso and full bipedal articulation; or a custom non-human-form character. Animation packs must be R15, not R6. **If a player can spawn into or switch to an R6 rig at any point, the game is not eligible.** Games with no visible player character (e.g. top-down strategy) qualify under the non-human-form criteria. Roblox runs ongoing background compliance checks. **[Roblox official, `18-plus-devex-rate.md`, updated 2026-06-08]**

**Cash-out mechanics:** minimum **30,000 Earned Robux**; 13+; verified email; W-9/W-8 on file; **one completed request per calendar month**; ~10 business days for first-timers, ~5 for returning. Tipalti charges a transaction fee, plus **1.9%–3% FX** if converting to local currency. **[Roblox official, `developer-exchange.md`, `devex-portal.md`]**

**Tax note with a live deadline:** "If you provide valid tax information by **October 31, 2026**, **0% to 30% U.S. tax withholding** will apply on your DevEx payments related to sales to U.S. players, depending on your country of residence and whether you successfully claim a tax treaty." **[Roblox official, `tax-information.md`]** If you are a non-U.S. creator, this is the single highest-value administrative task on your list.

### 4.2 The revenue-share table

| Product | Creator share | Notes | Source |
| --- | --- | --- | --- |
| **Developer products / passes (in-game Robux)** | **70%** | Confirmed in the Roblox Plus subsidy table: 100 Robux item → 70 Robux to creator → "Effective revenue share 70%" | `roblox-plus.md` |
| **Subscriptions priced in Robux** | **70% every month** | Hold ~5 days (same as passes). No refunds. | `subscriptions.md` |
| **Subscriptions priced in local currency** | **70% month 1, then 100%** | Converted at **US $0.01 → 1 Robux**. 30-day hold. Refund inside the hold window cancels your payout. | `subscriptions.md` |
| **Paid access in local currency** | **50% / 60% / 70%** at $9.99 / $29.99 / $49.99 | Three fixed price points. 48-hour refund window. | `paid-access-local-currency.md` |
| **Paid access in Robux** | Robux price you set, 25–1,000 Robux | Escrow up to 7 days. **No refunds.** Incompatible with private servers. Not on Xbox. | `paid-access-robux.md` |
| **Private servers** | Monthly Robux fee you set | **Changing the price cancels all active subscriptions.** | `private-servers.md` |
| **Marketplace avatar item, bought in the Marketplace** | **30% base**, rising progressively with price above the floor | 1× floor → 30%; 1.3× → 37%; 2× → 50%; 3× → 62%; **6× and above → 70% (cap)** | `marketplace-fees-and-commissions.md` |
| **Marketplace avatar item, bought inside a game** | **Item creator 30%, game owner 40%** | Progressive share does *not* apply in-game — base 30% only | `marketplace-fees-and-commissions.md` |
| **Limited item resale** | **10% original-creator commission** on every resale | Up to 30-day holding period before resale. Resale requires Roblox Plus or Premium. | `marketplace-fees-and-commissions.md` |
| **Creator Store models/plugins (USD)** | "Market-leading" — "only taxes and payment processing fees are deducted" | Min price $4.99 plugins / $2.99 models. **30-day escrow.** | `monetization/index.md` |

**[All Roblox official, retrieved 2026-09-17]**

**Escrow/hold periods, collected:** passes & developer products ~5 days; subscriptions in Robux ~5 days; subscriptions in local currency 30 days; paid access in Robux up to 7 days; Marketplace commissions 30 days; Creator Store 30 days; **Creator Rewards 60 days**; Roblox Plus sign-up bonuses 60 days. Plan cash flow accordingly — a launch spike arrives in your bank account roughly 6–10 weeks later. **[derived from the above]**

**Worked DevEx math [derived]:**

- A **100 Robux pass**: creator receives 70 Earned Robux → **70 × 0.0038 = $0.266**. At the 18+ U.S. rate: 70 × 0.0054 = **$0.378** — a **42% uplift** on identical revenue.
- A **$5.00/month local-currency subscription** (500 Robux base): month 1 → 350 Robux = **$1.33**; month 2+ → 500 Robux = **$1.90**. So a $5 subscription nets the creator ~38% of face value in DevEx dollars from month two.
- **30,000 Robux** (the cash-out minimum) = **$114** standard, **$162** at the 18+ rate.
- A **$49.99 paid-access** sale at the 70% tier = ~$34.99 gross to the creator before taxes/VAT — the highest per-transaction margin on the platform, and the reason paid access remains attractive for premium 18+ titles despite crushing the top of your funnel.

### 4.3 Which product fits which genre

| Product | Best fit | Why |
| --- | --- | --- |
| **Passes** (one-time, permanent) | Anything with an aspirational permanent unlock: 2× speed, VIP area, a permanent pet slot, a cosmetic tier | Lowest friction, highest comprehension for younger players. Min 1 Robux, max 1 billion. |
| **Developer products** (repeatable) | Currency packs, consumables, revives, boosters, gacha keys | The workhorse of simulators, tycoons and RPGs. Repeatability is what makes ARPPU move. |
| **Subscriptions** | Games with a genuine ongoing service: daily currency drip, exclusive rotating cosmetics, a persistent perk | Local-currency pricing is *dramatically* better economics from month 2 (100% share). Warning: **single-tier only** — "Tiering of the same suite of benefits, like offering 'Bronze,' 'Silver,' and 'Gold' tiers that are mutually exclusive, is not currently available." |
| **Private servers** | Roleplay, social hangout, content-creator-friendly games, competitive practice | Recurring revenue *and* it feeds the "intentional co-play days" ranking signal. Don't price it so high that friend groups can't play together. |
| **Paid access** | Premium/18+ titles with proven retention; or a deliberately gated closed beta | Roblox itself suggests "temporarily enable paid access to create a closed beta so that their most engaged users can have early access." Kills discovery volume. |
| **Limiteds / collectibles** | Games with trading, status economies, long-lived communities | Highest complexity and highest regulatory surface. Requires trading-policy compliance. |
| **Avatar items (Marketplace)** | Fashion, roleplay, brand-forward games | The in-game purchase split (creator 30% / game owner 40%) means hosting *other people's* items is a real revenue line. |

Roblox's own framing, which is a better segmentation than "whale/dolphin/minnow": **tourists vs locals**. Tourists hop between games and "prefer items with immediate effects, either through making gameplay more fun or through making them stand out." Locals "engage more deeply, and typically form almost all a game's engaged user base" and "are more interested in items with long term benefits, such as a battle pass." Sell impulse to tourists and progression to locals; note that "many locals start out as tourists." **[Roblox official, `monetization/index.md`, `design-for-roblox.md`]**

Roblox also names patterns that **do not work on Roblox specifically**: "appointment mechanics and timers which can be removed or brought forward may work well on other platforms, but these mechanics are unpopular with Roblox users who take issue with their fun coming to a premature end." Energy systems are a mobile-F2P import that this audience rejects. **[Roblox official, `monetization/index.md`]**

### 4.4 Creator Rewards — what replaced engagement-based payouts

**Engagement-Based Payouts (the old Premium-playtime-share system) was deprecated on 2025-07-24**, alongside the Creator Affiliate program, and both were replaced by **Creator Rewards**. **[Roblox official, `engagement-based-payouts.md`, `creator-rewards.md`, `creator-affiliate.md`]**

Roblox's stated reason is worth quoting because it explains the design:

> "With Engagement Based Payouts, we found that creators lacked transparency into which actions drove higher earnings and predictability in how those earnings would evolve over time."

**Daily Engagement Rewards — how it actually calculates:**

> Creators earn **5 Robux each day** if their experience is **one of the first three** an **Active Spender** plays for **10+ minutes**.

- **Active Spender** = a user who, on that day, (a) has made Qualifying Purchases totalling **at least $9.99 USD anywhere on Roblox within the past 60 days**, and (b) was not a New or Reactivated User during the past 60 days. Qualifying Purchases = Robux, Roblox Premium, or UGC subscriptions.
- The 10 minutes are **cumulative across the day** in that experience, but the **first-three-experiences** test is by *order of launch*.
- Roblox's own Example 2 makes the trap explicit: a user visits A(2m), B(10m), C(15m), D(5m), E(15m), A(15m). A, B and C earn. **E earns nothing despite 15 minutes, because it was the fourth experience launched that day.**

**[Roblox official, `creator-rewards.md`]**

**What this incentivises, honestly:** being someone's *first* game of the day, and holding them ten minutes. That is a re-engagement problem (notifications, daily rewards, streaks, events with known start times) far more than a content problem. It also means **session-time optimisation has a hard, valuable threshold at 10 minutes** — Roblox even tells you to check "Engagement ▸ Average Playtime" filtered to Active Spenders and warns: "If average playtime is close to or below this threshold, many players may not meet the requirement." **[Roblox official, `analytics/get-started.md`]**

**Audience Expansion Rewards:** a **35% revenue share on a qualifying user's first $100 of Qualifying Purchases anywhere on Roblox during their first 60 days**, for New Users (completely new to Roblox) or Reactivated Users (lapsed 60+ days) you bring in. Three qualifying paths — share link click; direct link as their first session of the join/rejoin day; or searching your experience *by name* as their first session — each requiring **10+ minutes of play that day** *and* that **your experience maintains an average of 100+ DAU for the 60 days afterward**. **[Roblox official, `creator-rewards.md`]**

Eligibility: Daily Engagement Rewards are automatic for all creators since 2025-07-24. Audience Expansion requires an **ID-verified account in good standing and a valid DevEx account** (for group-owned games, held by a member with group-revenue configuration permission).

**Anti-abuse rules you must not trip:** no bots, automated tools, browser extensions or teleport manipulation to generate visits/referrals/engagement time; **no encouraging alt accounts** (Audience Expansion is one reward per user, detected via device ID, IP and payment data); no impersonation; rewards may be withheld for accounts with disproportionate chargebacks. Penalties escalate to forfeiture, removal from the program, and account termination. **[Roblox official, `creator-rewards.md`]**

**Dashboard:** Monetization ▸ Creator Rewards shows rewards earned (split Daily Engagement / New Audience Expansion / Reactivated Audience Expansion), **daily rewarded active spenders** with a 50th–90th percentile benchmark, and **rewarded signups / reactivations** with 90th–95th percentile benchmarks. Share Link analytics add clicks, signups, reactivations, spenders, qualifying spend per spender, and estimated payout.

**Scale check [derived]:** 1,000 qualifying Active Spenders per day × 5 Robux × 30 days = **150,000 Robux/month = $570** at the standard DevEx rate. Creator Rewards is a meaningful supplement at mid scale and a rounding error at small scale. Don't build a business plan on it.

**Paid-access games are eligible** for Creator Rewards. **[Roblox official, `creator-rewards.md`]**

### 4.5 Roblox Plus — the new subscription layer you can earn from

Roblox Plus is a consumer subscription that creates four distinct creator revenue lines. **[Roblox official, `roblox-plus.md`; launch date not stated in the docs]**

1. **Discount subsidy.** Subscribers get **10% off eligible Robux purchases for their first two months, then 20% from month three**. **Roblox covers the discount** — your per-purchase earnings are unchanged. The published table:

   | User | Item price | User pays | Roblox subsidy | Creator earns | Effective share |
   | --- | --- | --- | --- | --- | --- |
   | Non-subscriber | 100 | 100 | — | 70 | 70% |
   | Plus (10% off) | 100 | 90 | 10 | 70 | **78%** |
   | Plus (20% off) | 100 | 80 | 20 | 70 | **88%** |

2. **Sign-up bonus.** `MarketplaceService.PromptRobloxSubscriptionPurchase` → **250 Robux/month for the subscriber's first three consecutive months, up to 750 Robux per new subscriber**. 60-day hold. You only earn if they subscribe *through your game* via that prompt.

3. **Paid private server time.** Up to **100 Robux per subscriber per month** when they spend **60+ minutes** in your paid private servers. (Plus subscribers get paid private servers free; you're still compensated.) Worked examples in the doc: a 100-Robux server → 70 Robux; a 200-Robux server → **100 Robux (capped)**; a 50-Robux server → 35 Robux.

4. **Robux transfers.** **10% of any transfer** a Plus subscriber initiates via `PromptRobuxTransferAsync` inside your game — the recipient gets 90%, you get 10%. **This amount is DevEx-eligible** (received transfers themselves are not).

**The hard-coded price bug this creates, which you should fix today:**

> "**If you hard-code prices, your in-game UI might display incorrect pricing to Plus subscribers.** While subscribers are still charged the discounted price, your game might show them the full price instead."

Use `MarketplaceService.GetProductInfoAsync` / `GetDeveloperProductsAsync` and render the returned price. Hard-coded prices also make you ineligible for regional pricing and price optimization (§4.8). This is the highest-leverage one-hour fix in Roblox monetization engineering.

### 4.6 Ads as a revenue line

**Rewarded video ads.** Eligibility: 13+, ID-verified, public game with **2,000+ unique visitors per month**. Earnings = **EPM (earnings per 1,000 impressions) × impressions**. Roblox's design guidance: **rewards worth the equivalent of 3–10 Robux**; rewards **must be developer products** — "You can't reward users with Robux"; place units in lobbies and menus where traffic concentrates. There's an in-dashboard calculator under Monetization ▸ Ads ▸ Eligibility. Reported metrics include EPM, AEPDUV (average earning per daily unique viewer), eligible DAU, and viewer rate. **[Roblox official, `rewarded-video-ads.md`]**

**Immersive ads** (image, video, portal units placed in your 3D world). Payment models: click-to-play video pays on a **15-second view**; autoplay video pays per **video impression** (≥0.5s look, ≥1.5% of viewport, ≤55° angle, ≥50% pixels visible); image ads pay per **image impression** (≥1s look, same geometry); **portal ads pay per successful teleport**. Payouts land on the **25th of the following month**. Publisher eligibility requires 13+, identity verification and 2FA (persistent — disabling either loses eligibility), and an approved Maturity & Compliance questionnaire; **resubmitting the questionnaire temporarily removes ads eligibility** while under review. **[Roblox official, `immersive-ads.md`]**

**Honest assessment.** Ad revenue on Roblox is a supplement, not a strategy, for almost every game. Its ceiling is set by eligible-user density and advertiser demand, neither of which you control, and portal ads actively teleport your players into a competitor's game. Rewarded video is the better of the two because you control the placement and the reward, and because it monetizes non-payers — but it does so by spending the scarcest thing you have, which is early-session attention. Keep it out of the first sixty seconds.

### 4.7 The whale reality

The documented figure is:

> "In many games, a small group of players generates a large share of revenue. **On average, the top 15% of active payers account for roughly 50% of revenue.**" **[Roblox official, `analytics/get-started.md`]**

Read the denominator carefully. That is 15% **of active payers** — not 15% of players. Since payer conversion on Roblox is typically a low single-digit percentage of DAU (Roblox does not publish a platform-wide figure; your dashboard gives you your own percentile band), the top 15% of payers is a *very* small fraction of your total player base. The popular "5–10% of players are whales" framing is the wrong shape: on Roblox it is closer to "a fraction of a percent of players produce half the revenue." **[derived]**

Roblox tells you exactly how to read this on your own dashboard: Monetization ▸ Overview ▸ Breakdown by **Active Payer Status**, cross-checked across time intervals. And it gives you the diagnostic in both directions:

- **Top 15% contributing much less than ~50%?** "You may have opportunities to better retain or monetize top spenders."
- **Top 15% contributing much more?** "You may need to strengthen the value proposition for mid- and lower-tier spenders."

The second case is the dangerous one and the one teams miss. A game where 90% of revenue comes from the top 15% of payers is not a healthy economy — it is a fragile one, over-indexed on a handful of accounts, and typically one that has priced out everyone else.

One more segmentation Roblox flags: **"Active spenders typically retain better than average players. Declines in this segment may indicate opportunities to improve engagement for highly invested players."** Watch that segment's DAU/WAU/MAU share over time as a leading indicator. **[Roblox official, `analytics/get-started.md`]**

### 4.8 Pricing: managed pricing, price optimization, regional pricing

**Managed pricing** unifies regional pricing and price optimization; you opt in once and Roblox keeps prices tuned across products and regions. **[Roblox official, `managed-pricing.md`]**

**Regional pricing** adjusts by "purchasing power, currency exchange rates, and local spending behavior." Bounds: **regional prices sit between 30% and 100% of your default price** — never discounted more than 70%, never above your default. **[Roblox official, `managed-pricing.md`, `regional-pricing.md`]**

**Price optimization** is Roblox-run price A/B testing for passes and developer products:

- **Requires ~60,000 transactions in the previous 30 days** to produce significant data.
- Users are split into test groups automatically, "optimized to choose the smallest cohort of users to run the test."
- Runs roughly **3 weeks**; you get an email and a recommendation with estimated long-term revenue impact.
- **"After the test, optimized prices are applied only if it results in positive incremental total revenue."**
- Tests re-run **at least every 90 days**.
- **Not available for subscriptions.**
- **Requires dynamically scripted prices.** There's a **Dynamic Price Check** tool (up to 5 test accounts, "price pinned" or "location pinned") that reveals which of your prices are hard-coded.

**[Roblox official, `price-optimization.md`]**

Subscription price changes are constrained separately: Robux-priced subscriptions can change price **once every 60 days**, with increases requiring **30 days' notice** to users; **local-currency subscription prices cannot be changed at all** — you must delete and recreate, which forces refunds to all active subscribers and zero Robux to you. **[Roblox official, `subscriptions.md`]**

---

## 5. Monetization design that isn't predatory

### 5.1 What Roblox requires, not just recommends

Roblox's monetization policy is unusually prescriptive, and it is enforced. The governing principle:

> "Users must never be misled, confused, or pressured into purchases in ways they did not intend, and they should always have the freedom to make a clear, deliberate choice." **[Roblox official, `monetization/index.md`]**

**Discounts must be genuine and fair:**

- "A discount is **not genuine** if an item is always 'on sale' for the same amount of Robux."
- "A discount is **not fair** if it's only offered for a very short time, pressuring users to make a purchase as quickly as possible."

**Prohibited at all times:**

- Claiming an item is almost out of stock or time-limited when it isn't.
- **"Don't use a countdown timer that isn't accurate or automatically restarts for the same item."**

Roblox's own example of the violation: a "deal of the day" claiming 24-hour availability that reappears on every login and never actually expires. That is the single most common dark pattern in mobile F2P, and it is against the rules here.

**Language guidance for a young audience** — Roblox publishes a substitution table:

| Avoid | Use instead |
| --- | --- |
| "GET IT NOW" | "View Item" |
| "LAST CHANCE, ACT NOW" | "See Price" |
| "BUY BEFORE IT'S GONE!" | "Open Shop" |

**[Roblox official, `monetization/index.md`]**

And the enforcement mechanism that isn't Roblox at all: **"our users are likely to downvote your game if they do not approve of your strategies."** Your like ratio is a public, cumulative, effectively permanent number, and it gates eligibility for at least one curated sort.

### 5.2 Paid random items — the full policy

This is the loot-box question, and Roblox's answer is: permitted, disclosed, and regionally gated.

**What counts as a paid random item** is much broader than "loot box." **[Roblox official, `paid-random-items.md`]**

| Type | Examples |
| --- | --- |
| **Capsule items** | Spin a wheel; hatch an egg; open a chest |
| **Enhancement items** | Potion granting an ability for a random duration; upgrade spell with a chance of working |
| **Combination items** | Consuming/synthesising two rare eggs for a better chance of a higher-quality result |
| **Probability modifier items** | **Luck boosts, pity systems, enhanced resource drops, rate-up scrolls** |

Note that **pity systems and luck boosts are explicitly in scope.** So is indirect purchase: "Paying Robux to buy gems or spin tickets that are spent at a prize wheel" is a paid random item.

**Disclosure requirements:**

- You must indicate **all possible outcomes and the actual numerical odds**.
- Odds "must be displayed as a probability percentage, and the probability percentages of all final outcomes must **sum to exactly 100%**." Rounding is permitted to four or more decimal places below the first non-zero digit, with a disclaimer.
- If there are too many outcomes for the 3D view, an itemised list may live in a **clickable pop-up with an "Info" or "Details" icon visible and accessible before purchase**. "Using a standalone symbol like the (i) icon without a descriptive word is **not** sufficient."
- If a player can only obtain one instance of an outcome, **remaining odds must be updated dynamically for that user**.
- Odds-augmenting items "must be numerically explained," and **"the new odds of the enhanced random items must also be dynamically updated when these items are active to show the user's true odds."**
- Free randomness is exempt: "If your game offers randomized virtual rewards in exchange for completing an action that does not involve the payment of Robux or other in-game currency, you aren't required to disclose the odds."

**Regional gating is mandatory, not optional:**

> "If a user can use Robux or something else that was acquired with Robux to get a random reward, **you are required to use `PolicyService`** to block this feature for users who are not permitted to use random items in exchange for Robux." **[Roblox official, `monetization/index.md`]**

```lua
local PolicyService = game:GetService("PolicyService")
local policy = PolicyService:GetPolicyInfoForPlayerAsync(player)
if policy.ArePaidRandomItemsRestricted then
    -- apply one of the six approved treatments below
end
if not policy.IsPaidItemTradingAllowed then
    -- block trading of paid items / paid random outcomes for this user
end
```

**The six approved treatments for restricted users** — Roblox names all of them, and they are a design menu, not a compliance chore: **[Roblox official, `paid-random-items.md`]**

1. **An unpaid, earnable path** to the random item (mystery eggs granted free at gameplay milestones).
2. **A pre-determined, non-random order** disclosed before purchase (first spin always 5 gems, second always 10, third always 20).
3. **Direct guaranteed purchase priced on expected value** — Roblox's own example: "If a lootbox for a rare sword is 10 Robux with 5% odds, offer the sword to ineligible users for direct purchase priced at 200 Robux."
4. Remove or hide the paid random item.
5. Block the purchase with a clear error message.
6. Remove the user from the areas containing paid random items.

Treatments 1–3 are strictly better products than treatments 4–6, and nothing stops you from shipping them to *everyone*. Option 3 in particular — publishing the expected-value price alongside the gacha — is the single most honest monetization design available on the platform and costs you nothing in revenue from players who were going to buy the box anyway.

You must also **declare paid random items and paid item trading in the Maturity & Compliance Questionnaire**, including whether you respect the two policy flags. **[Roblox official, `content-maturity.md`]**

### 5.3 Age tiers and what they mean for monetization

As of 2026 Roblox operates three account tiers. **[Roblox official, `kids-and-select.md`]**

| | **Roblox Kids** | **Roblox Select** | **Roblox** |
| --- | --- | --- | --- |
| Assignment | Self-declared or age-checked 5–8 | Self-declared 9+ (until age-checked), or age-checked 9–15 | Age-checked 16+ |
| Content ratings | Minimal, Mild | Minimal, Mild, Moderate | All except Restricted (18+) |
| Chat | Off by default; enabled via linked parent account after age check | Off for self-declared; gradually introduced with safeguards after age check | On by default where available |

Age recommendations from the Experience Guidelines questionnaire: **All ages / 9+ / 13+ / 17+**. A game **without** guidelines is treated as **13+** and "cannot contain any 17+ content without risk of moderation." Generating 17+ guidelines immediately restarts your servers to eject non-verified players. **[Roblox official, `experience-guidelines.md`]**

**The monetization consequence:** a very large share of your audience may be under 13, will never see a social media link (16+ verified only — §7.2), may not be able to join private servers depending on parental settings, and is subject to parental spending visibility through age 18. Design your monetization for a player who cannot be marketed to off-platform and whose parent can see every purchase.

### 5.4 Patterns that convert without exploiting

Drawn from Roblox's own monetization-design docs, filtered for things that are both effective and defensible. **[Roblox official, `monetization-foundations.md`, `contextual-purchases.md`, `season-pass-design.md`, `subscription-design.md`]**

**Make the shop findable, contextual and inviting.** Roblox's three shop criteria are: **integrated** (matches the game's aesthetic, obvious to a new player what it is), **contextual** (clearly communicates what items do *in relation to gameplay*), **inviting** (a place worth lingering, that teaches you what matters in the game).

**Contextual purchase points** — offer the thing at the moment its value is legible (Roblox categorises these as in-play, pre-play, lobby, complementary and UI). A revive offered at death is contextual; a revive offered on the loading screen is noise.

**Season passes, free track first.** Roblox's documented parameters: **one month** is a good starting season length; **at least a one-week rest period** between seasons ("protects players from burnout"); **ten tiers** as a starting point; missions unlock daily and reset daily; missions vary in category and difficulty; **"Missions never require spending hard currency. This would exclude free players and require premium season pass players to spend even more."** Premium is a *superset* of free, not a replacement for it. Mid-season upgraders should retroactively receive all premium rewards for tiers already completed.

**Require players to claim rewards manually.** "Automatic rewards run the risk of being overlooked or misunderstood." Manual claiming both confirms value received and drives a return visit into the pass UI.

**Retire the final reward after the season.** Genuine scarcity — an item that really is gone — is honest. Fake scarcity on a restarting timer is a policy violation.

**Welcome/first-purchase bonuses.** Roblox suggests testing a welcome bonus for first-time buyers to lift conversion. The first purchase is the meaningful threshold: "if a player makes an initial purchase, they are much more likely to make a purchase again in the future." **[Roblox official, `analytics/monetization.md`, `get-started.md`]**

**Multiple price points.** Roblox's documented ARPDAU advice is "implement varied price points" — a ladder that lets a player spend 25 Robux or 2,500 without either feeling like the wrong choice.

**Consumables *and* durables.** "Offer both consumable and durable items to suit different player types" — tourists buy consumables, locals buy durables.

**Trading + limited-time content together.** "While both systems can be successful on their own, they are particularly effective when combined." Both feed social engagement, which feeds the co-play ranking signal.

**Publish expected-value pricing next to any gacha.** See §5.2, treatment 3.

### 5.5 The anti-patterns, named

| Anti-pattern | Why it fails on Roblox specifically |
| --- | --- |
| Permanent "24-hour" deals / restarting countdowns | **Explicit policy violation** |
| Energy / appointment mechanics | Roblox states this audience "take[s] issue with their fun coming to a premature end" |
| Pay-to-win over non-payers | For Premium incentives Roblox says outright: don't give "a tactical gameplay advantage... such as an array of ultra-powerful weapons that non-Premium members can't compete against" |
| Paywalling the first session | Destroys first-play bounce rate — your #2 ranking signal. Disqualifies you from the Learn & Explore sort by name |
| Hidden gacha odds / undisclosed luck boosts | **Explicit policy violation**, moderation risk |
| Urgency language at minors | Explicitly discouraged, with a published substitution table |
| Monetizing the notification channel | "Notifications should not be of a generic, advertising nature"; dark patterns in notifications are banned outright |
| Gating gameplay on notification opt-in | "Games should **not** require users to turn on notifications in order to participate or advance in gameplay" |
| Leading metadata with Robux giveaways | Documented cause of reduced discovery exposure |

**[All Roblox official, `monetization/index.md`, `engagement-based-payouts.md`, `learn-explore-sort.md`, `paid-random-items.md`, `experience-notifications` guidelines, `discovery.md`]**

### 5.6 Does fair monetization actually outperform?

The honest answer: **the ranking system is structured so that it should, but I cannot cite a controlled study.**

What *is* documented:

- Engagement and retention signals outrank monetization signals in RFY priority tiers. Aggressive monetization that raises bounce rate trades a top-tier signal for a bottom-tier one. **[Roblox official, `discovery.md`; trade-off derived]**
- Downvotes are the stated community response to disliked monetization, and like ratio is public and cumulative. **[Roblox official, `monetization/index.md`]**
- Roblox's own diagnostic warns about over-concentration in top payers as a problem to fix, not a goal. **[Roblox official, `analytics/get-started.md`]**
- The lowest-friction, highest-margin product on the platform (local-currency subscriptions at 100% share from month two) is a *retention* product — it only pays if the player stays. **[derived]**

What is **not** established: any published A/B result showing a fair-monetization variant beating an aggressive one on LTV. Treat "fair monetization wins" as a well-supported design thesis aligned with the platform's incentives, not as a measured fact. And note that you can now test it yourself: Experiments tracks D1, D7, playtime, ARPU, ARPPU, payer conversion and session time on every run, so a shop-aggressiveness experiment will tell you the answer for *your* game in 14–60 days.

---

## 6. Live operations

### 6.1 Cadence, and what it does to the algorithm

Roblox's stated cadence guidance, from three separate docs:

- **"A weekly cadence for updates is ideal. At the bare minimum, aim for monthly updates."** **[`monetization/index.md`]**
- **"A common frequency is to release smaller updates on the existing mechanics every 2–4 weeks, and bigger updates of new features every 2–3 months."** **[`retention.md`]**
- **"Many games release content cadence updates every two weeks to one month."** **[`content-updates.md`]**
- **"Spending fewer than three weeks' effort on content cadence is recommended."** **[`content-updates.md`]**

The algorithmic effect is documented as **explore/expand** (§1.3) plus **content-quality reclassification**: "Roblox continually reclassifies content quality with every update, giving all games the opportunity to improve their reach." **[`discovery.md`]** The widely-repeated "updates give you a freshness boost in Trending" is **[third-party]** — creator-reported, not in Roblox's documentation. What Roblox does document is that an update triggers a fresh explore phase, which *looks* like a boost and behaves like one, but is conditional on the new cohort retaining.

Roblox also names the theming discipline: keep each update focused on a single theme, because "this makes it easier for users to understand the new update and tell what content is new when they join. It also helps you coordinate your content and promotional assets." **[`monetization/index.md`]**

And the counter-intuitive one: **"Don't be afraid to make users earn their access to new content. New users will flock to play new updates, but if they don't feel like they've achieved something in the game, they may check out soon after."** Content that is consumed in one sitting doesn't retain.

### 6.2 The four update types

Roblox's taxonomy, which is a useful planning grid. **[Roblox official, `liveops-essentials.md`]**

| Type | What it is | Cost | Cadence |
| --- | --- | --- | --- |
| **Content cadence** | New content built *only* on existing systems — pets, vehicles, weapons, maps, quests, avatar items, furniture. "Predominantly art-based, requiring little to no programming or design work." | Low | Weekly–monthly |
| **Major updates** | New or expanded *systems*. Roblox's four categories: **social** (guilds, trading, parties), **competitive** (PvP, leaderboards, tournaments), **collections/achievements** (pet collections, season passes), **live events** (map overhauls, new player roles). | High | Every 2–3 months |
| **Quality of life** | UI layout, UX flow, aesthetic refreshes, accessibility, performance. "Can have an outsized impact... and contribute significantly to player goodwill." | Low–medium | As available |
| **Bug fixes** | Prioritised by severity × effort × players affected. | Variable | Continuous |

The load-bearing insight: **content cadence exists to buy time for major updates.** "Content Cadence releases exclusively build on existing systems, which... allow programming and design resources to concentrate on creating new systems for the upcoming major update."

If your "weekly update" requires an engineer, you have not built a content cadence — you have built a treadmill you will fall off. Roblox's canonical example is *Adopt Me!* pet variants: recolours and pattern variants of an existing pet system, producible by one artist on a schedule.

### 6.3 Seasons and battle passes

Parameters from Roblox's season-pass doc, all **[Roblox official, `season-pass-design.md`]**:

- **Season length:** one month is a good starting point.
- **Rest period:** at least one week between seasons — protects players from burnout, gives the team production time.
- **Tiers:** ten is a good starting point. "Players should feel like they're making progress frequently, but the number of tiers should be short enough that it isn't daunting at the start."
- **Tier rewards:** consumables, small currency amounts, temporary buffs, customization items — "items that players want, but aren't too valuable."
- **Final reward:** a brand-new asset, retired after the season, and **shown as a 3D model, not a 2D icon** — "Items like cars, houses, pets, and avatar clothing are much more compelling 'in person'."
- **Missions:** unlock daily, reset daily, vary in category and difficulty, rarely repeat, **never require hard currency**.
- **Catch-up mechanic:** double XP in the final week.
- **Weekly missions** alongside dailies for high-achievers.
- **Cooperative missions** as a later addition — "This social component reinvigorates the system."

Design the tier spacing against your *actual* average session time: "consider designing the distance between rewards on your season pass relative to the average session time for players who join your experience." **[`monetization-foundations.md`]**

### 6.4 Daily rewards and login streaks — and their retention math

Roblox ships a free **Engagement Rewards feature package** (Creator Store, requires the Core package) implementing daily login streaks and play-session-time rewards, with a default claim UI. Reward types are `Time` (keyed on `requiredSecondsInGame`) and `Daily` (keyed on `requiredDaysVisitedStreak`). You supply a `rewardClaimedHandlerFunction` that actually grants the item. **[Roblox official, `resources/feature-packages/engagement-rewards.md`]**

**The math that makes streaks worth building on Roblox specifically [derived from documented mechanics]:**

- A daily reward converts a player's *decision* to play from "do I feel like it?" to "do I want to keep my streak?" — it moves them from the D2–7 bucket into the D8–28 bucket.
- **Play days per user** is a top-tier RFY signal, evaluated across D1, D2–7 and D8–28. A streak mechanic targets exactly that signal.
- The **playtime credit is capped at 60 minutes/user/day**, but **play days are not capped**. A player who plays 20 minutes on seven days generates strictly more ranking value than one who plays 140 minutes on one day.
- **Creator Rewards pays 5 Robux per Active Spender per day at a 10-minute threshold**, if you are among their first three experiences. A daily reward that takes ~10 minutes of play to claim, positioned early in the day, is directly aligned with that payout.

So: **make the daily claim require ~10 minutes of actual play, not a login tap.** A login-and-leave reward gives you a play-day but fails the Creator Rewards threshold and does nothing for bounce rate.

**Where streaks become predatory:** punishing misses harshly (losing a 60-day streak to one missed day), or escalating rewards so steeply that a lapse feels catastrophic. Streak *insurance* sold for Robux is the version to avoid. Forgiveness mechanics (one free miss per week, or a decaying rather than resetting streak) retain better and don't weaponise loss aversion against a twelve-year-old.

### 6.5 Events, notifications and announcements

**Experience events** are first-party time-based events surfaced on your detail page and a dedicated event page, with opt-in notifications. **[Roblox official, `experience-events.md`]**

- Up to **5 thumbnails** per event with a primary event type.
- Players click **Notify Me** for stream notifications when the event starts, and can opt into **push notifications** to their device.
- Events can point at a **non-start place**, so event joiners spawn directly into the event.
- The event ID lands in the player's `GameJoinContext`, so you can detect event arrivals and personalise for them.
- Certain promotional surfaces require **an active event started within the last 7 days and a minimum of 1,000 RSVPs**.
- For Roblox-curated event promotion: submit **at least 7 days before the event start**; "The best events run for **7–30 days**."

**Update announcements** are separate: **60-character limit**, and you may only announce **once every three days**. Reported metrics include visit rate and unfollow rate from the notification. **[Roblox official, `experience-events.md`]**

**Experience notifications** (the personalised API) — eligibility: **100 visits since launch**, not under moderation, 13+ recipients who have opted in. **[Roblox official, `experience-notifications/eligibility`]**

The throttle is the crucial constraint: **"each user can receive one notification per day from a given experience."** And delivery is earned: **"This spam prevention system is directly informed by user engagement: the more users engage with your notifications, the more reach they'll receive."** **[Roblox official, `experience-notifications/delivery-system`]**

Roblox's good/bad examples are precise about what earns reach:

| Good | Bad |
| --- | --- |
| "You're 2 races away from completing the weekly challenge!" | "A new line of race cars just dropped in Race Car Craze. Check them out!" |
| "Allie @LaterSk8er1 just beat your record on the Tokyo Tour track! Time for revenge?" | "It's been a few days since you participated in a race with Allie." |

The pattern: **personal state + immediate action**. Generic advertising burns your one daily slot and lowers your future reach.

Banned in notifications: disguised ads, false time pressure, bait-and-switch free-item claims, and prompts that lead directly into a pre-loaded purchase flow. Notifications are also subject to **platform-wide** Community Standards and text filtering regardless of your game's age rating — "if your game is a 17+ game, your notifications are still subject to the platform-wide standards." **[Roblox official, `experience-notifications` guidelines]**

### 6.6 Codes and social loops

Promo codes are not a first-party Roblox feature; they are a community convention implemented with a text box, a server-side validation and a DataStore of redemptions. Two hard requirements if you build one:

1. **Filter the input.** A `TextBox` where players type arbitrary strings is user text. Even if you only compare it to a code list, any path where the string is *displayed* (an error message echoing the input, a "who redeemed" leaderboard) must go through `TextService:FilterStringAsync()`. **[Roblox official, `ui/text-filtering.md`]**
2. **Rate-limit it.** Roblox requires rate limits of at least 1 minute on editable text that other users can see; apply the same discipline to redemption attempts to prevent brute-force enumeration. **[Roblox official, `chat/guidelines.md`]**

Codes work on Roblox because they create an off-platform reason to watch a creator's video and an on-platform reason to open the game — but note §7.2: you cannot advertise your Discord or social handles *inside* the game, only on the detail page.

**First-party social loops you should use instead of, or alongside, codes:**

- **Player invite prompts** — `ExperienceInviteOptions` with a custom `PromptMessage`, optional specific `InviteUser`, a custom notification asset, and up to **200 characters of launch data** delivered to the joining friend via `GetJoinData()`. **[Roblox official, `invite-prompts.md`]**
- **Friend referral system** — `player:GetJoinData().ReferredByPlayerId` is populated automatically for all invitation types, letting you reward both inviter and invitee. Roblox specifically tells you to ship a **customized reward banner** at the top of the invite modal so players know what they earn. **[Roblox official, `referral-system.md`]**
- **Experience events** with RSVP notifications (§6.5).

All three feed the **intentional co-play days per user** ranking signal.

### 6.7 The content treadmill, honestly

Roblox is unusually candid here, and it is the most humane paragraph in its documentation:

> "Supporting a live game may at times feel like a grind. It is important for developers to take the time to work on features and content that inspire them, so they remain fulfilled by their work and excited about the game's future. It is also important to be realistic about a team's capabilities: their strengths and weaknesses, their schedules, and the frequency with which they can release updates while maintaining a healthy work-life balance." **[Roblox official, `liveops-essentials.md`]**

**How small teams actually sustain a cadence — the documented mechanics:**

1. **Build systems that accept variants.** The whole content-cadence model depends on having systems (pets, vehicles, maps, quests) where new content is a data row plus an art asset. If every update needs an engineer, you don't have a cadence.
2. **Cap cadence effort at under three weeks.**
3. **Gate consumption.** "Cadence content should not be immediately consumed by the majority of players, otherwise its purpose is defeated." Progression, limited-time earning, and season passes are the three documented mechanisms.
4. **Add permanent content at the *end* of progression**, where veterans are running out of objectives — "Those high-level players will appreciate the fresh content that they can play immediately, while newer players will have more content to look forward to."
5. **Use `ConfigService` to ship content without shipping code.** A JSON config up to 100,000 characters, published in under a minute, with staged testing and a 15-minute gradual rollout option, is a content pipeline. Seasonal events can be scheduled by config rather than by deploy.
6. **Establish a *routine*, not just a frequency.** "Establishing a routine release cadence encourages players to check back often... They may begin to anticipate the next release, and even speculate about it on social media."
7. **Use the rest period.** One week between seasons is design guidance *and* recovery time.

---

## 7. Community and social growth

### 7.1 Groups (Communities)

Creating a group costs **100 Robux**. Groups let multiple creators share assets, split revenue and take credit. Up to three social links on the group profile. **[Roblox official, `projects/groups.md`]**

**Publish to a group, not to a personal account.** Roblox marks the group option **RECOMMENDED** in the publish dialog, and for good reason: group ownership is how a hobby project becomes a studio with succession, role-based permissions and auditable revenue splits.

**Payouts:**

- **One-time payouts** — batch, selectable from a popup or a CSV with `userId,payoutInRobux` columns, gated behind 2FA challenges and eligibility checks.
- **Recurring payouts** — percentage splits across the group *and* per-game, with the remainder flowing to the group balance. Roblox's example: a game split 40/30/10 leaves 20% in the group balance.
- **Group payouts respect the U.S. 18+ DevEx rate**, and both one-time payouts and DevEx requests prioritise the 18+-rate Robux first. **[Roblox official, `18-plus-devex-rate.md`]**
- **Paid access in local currency cannot be split across group members.** **[Roblox official, `groups.md`]**

The warning that matters most: **"If a conflict arises within a group, Roblox cannot help arbitrate or resolve disagreements."** Write the split down, outside Roblox, before there's money in it.

**Group audit logs** exist and should be enabled-by-habit for any team above two people.

### 7.2 Discord — and the platform rule that constrains it

Discord is the de facto companion for Roblox communities; Roblox itself references it repeatedly ("Game groups and social media like Discord allow developers to connect with players and gather their feedback"; the Alerts doc's example webhook target is Discord). **[Roblox official, `liveops-essentials.md`, `alerts.md`]**

**But there is a hard platform rule that catches almost every new creator:**

> "Roblox's Community Standards only permit you to share social media links on your game's main details page. You **cannot** share social media links directly within a game." **[Roblox official, `social-media-links.md`]**

Roblox publishes the allowed and disallowed phrasings:

| Allowed in-game | Not allowed in-game |
| --- | --- |
| "Check out our social media links on our game's page" | "Follow for merch on X.com/abc" |
| "Follow us on social media for merch. Links on our game's page" | "Join our Discord discord.gg/invitecode" |
| "Join us in our Community Server. Links on our game's page" | "Send bug reports to abc@xyz.com" |

**And the visibility ceiling:** social media links are **only visible to users who have verified their age as at least 16**. Users under 16, or unverified, **cannot see them at all**. To *add* links you must be 16+ and age-verified (via facial age estimation or government ID); for group-owned games at least one collaborator must be verified 16+, and if all such collaborators leave, existing links are **auto-deleted after 90 days**. **[Roblox official, `social-media-links.md`]**

**The strategic consequence, stated plainly:** for a game whose audience skews under 13, your Discord is functionally invisible to most of your players, and you are not allowed to tell them about it in-game. Off-platform community building on Roblox is disproportionately a strategy for **older-skewing games**. For younger audiences, your community tools are: the group/community page, in-game events, experience notifications, and the friend/invite system — all first-party, all reachable, all age-appropriate.

### 7.3 Share links, referrals, invites

**Share links** are trackable off-platform links, unlimited in number, creatable per channel. They carry optional custom `LaunchData` readable via `Player:GetJoinData()`, so you can grant a perk to players arriving from a specific campaign. Analytics available per link: **clicks, signups, reactivations, users with qualified plays, 7-day playtime per user, D7 retention, 30-day revenue per user, qualifying spend per spender, estimated Creator Rewards payout.** **[Roblox official, `share-links.md`, `acquisition.md`, `creator-rewards.md`]**

That metric list is the point. Roblox is handing you **per-channel cohort quality**, not just per-channel volume. The question "which YouTuber sent me players who were still here on day 7 and spent money in month one" is answerable in the dashboard. Most creators never create a second share link and therefore never ask it.

Share links are also one of the three qualifying paths for **Audience Expansion Rewards** (§4.4) — the only path that doesn't require the user to type your game's name from memory.

**Group-owned caveat:** for group games, share links must be created from the group account by a member with the **Create and configure share links** permission.

### 7.4 Creators, influencers, YouTube and TikTok

Roblox's documented view of the YouTube relationship:

> "Many Roblox users count Roblox and YouTube as their top two content platforms. Users often follow their favorite YouTubers into new games, especially if it looks like a lot of fun." **[Roblox official, `design-for-roblox.md`]**

And the design instruction that follows from it — which is the actionable part most teams skip:

> "Consider how your game might work in a streaming context when designing: could a streamer make great, fun content with it? Can they easily involve their friends, or other streamers? Can you make their job easier? For instance, **Brookhaven has a 'Creator Cam' where content creators can hide the UI when they're recording a video.**"

**Concrete creator-affordances worth building:**

- A UI-hide key and a free-cam mode.
- Private servers priced so a creator can host their audience without it being a purchase decision.
- Deterministic, repeatable set-pieces a creator can stage on camera.
- Share links issued **per creator** so you can measure who actually delivered retained players.
- Event scheduling the creator can plan a stream around (Experience Events with a fixed start time, RSVP'd).

**On the official programs:** the Creator Affiliate Pilot (up to 50% of new-user Robux spend, capped at $100/user over six months) was **discontinued on 2025-07-24** and folded into Creator Rewards' Audience Expansion. Roblox's **Video Stars** influencer program members can earn both Daily Engagement and Audience Expansion rewards. **[Roblox official, `creator-affiliate.md`, `creator-rewards.md`]**

**On TikTok:** Roblox's documentation names Twitter/X, YouTube, Instagram, LinkedIn and TikTok as places affiliate/share links may be posted, but publishes no Roblox-specific TikTok guidance or data. Any claim about TikTok's efficacy for Roblox discovery is **[third-party]** and unverified here. What *is* verifiable is the measurement method: one share link per platform, then read D7 retention and 30-day revenue per user per link.

**Do not** try to route around the in-game social-link ban by putting handles in your game's chat, on signs, or in NPC dialogue — that is the exact failure mode Roblox's example list is written against.

### 7.5 UGC and player-created content as a growth engine

Roblox lists **user-generated content** as a first-class content-cadence type: "content that the game's player community creates themselves, often through contests and events." **[Roblox official, `liveops-essentials.md`]**

The growth logic is strong — players who build become players who stay, and who recruit. The operational cost is where teams underestimate:

- **Everything a player creates that another player can see is your moderation problem.** See §8.3.
- Roblox's Experience Guidelines have a specific content descriptor for **free-form user creation**, which pushes your age recommendation to **13+**. **[Roblox official, `experience-guidelines.md`]** If your target audience is under 13, in-game free-form creation may be incompatible with your reach strategy.
- The Maturity questionnaire asks separately whether your game lets users **share media captured from gameplay**, whether it has **continuously-loading content feeds or autoplaying audio/video**, and whether users can **view content captured from other Roblox experiences** — each with age-rating consequences. **[Roblox official, `content-maturity.md`]**

A defensible middle path: **curated UGC**. Run build contests where entries are reviewed by you before they go live, and grant winners in-game recognition. You get the community energy and the content cadence without a continuously-open unmoderated pipe.

---

## 8. Operational safety

### 8.1 Text filtering is mandatory and enforced

This is the single most important compliance requirement in this chapter, and it carries an automatic penalty.

> "Roblox automatically filters common text outputs such as messages that have passed through in-game text chat, but **you are responsible for filtering any displayed text that you don't have explicit control over**."
>
> "Because filtering is crucial for a safe environment, Roblox actively moderates the content of games... **If Roblox receives reports or automatically detects that your game doesn't apply text filtering, then the system removes the game until you add filtering.**" **[Roblox official, `ui/text-filtering.md`]**

**Scenarios Roblox explicitly names as requiring filtering:**

- `TextBox` entries, custom GUI keypads, interactive keyboard models in 3D space.
- **Procedurally generated words from random characters** — "there's a chance it will create inappropriate words."
- **Any content fetched from an external web server** and displayed in-game.
- **Text retrieved from DataStores** — e.g. pet names stored earlier.

That third and fourth cases catch people. Text you stored last year is still user text when you display it today.

**The correct usage:**

```lua
local TextService = game:GetService("TextService")

local function getFilterResult(text, fromUserId)
    local filterResult
    local success, errorMessage = pcall(function()
        filterResult = TextService:FilterStringAsync(text, fromUserId)
    end)
    if success then
        return filterResult
    else
        warn("Error generating TextFilterResult:", errorMessage)
    end
end

-- Server-side, on RemoteEvent from client:
local function onInputReceived(player, text)
    if text == "" then return end
    local filterResult = getFilterResult(text, player.UserId)
    if not filterResult then return end             -- FAIL CLOSED
    local ok, filteredText = pcall(function()
        return filterResult:GetNonChatStringForBroadcastAsync()
    end)
    if ok then
        -- safe to display to all users on this server
    else
        warn("Error filtering text!")               -- FAIL CLOSED
    end
end
```

**The rules around it, from the API reference and the guide:** **[Roblox official, `ui/text-filtering.md`, `TextService.yaml`]**

- **Server-side only.** The client must send raw text to the server via a `RemoteEvent`.
- **Call it once per submission**, not per keystroke: "Do not filter text in real time 'per character entered' into a `TextBox`, as doing so yields for text that's only visible to the user typing it."
- **`FilterStringAsync` always yields** and **may throw**. "If it fails, **do not display the text to any user**." Fail closed, always.
- **Do not retry on failure** — "this method implements its own retry logic internally."
- It **throws if `fromUserId` is not online on the current server**. Filtering stored text for an offline author requires care; filter at write time as well as read time, and handle the throw.
- Choose the right result method: **`GetNonChatStringForBroadcastAsync()`** for text everyone on the server will see (a sign, a leaderboard name); **`GetNonChatStringForUserAsync()`** for text shown to one specific user, which returns a result adjusted "based on age and other details."
- The `textContext` parameter (`Enum.TextFilterContext`, default `PrivateChat`) "does not impact the filtered result... and is only used to improve Roblox's text filtering" — set it accurately anyway.

### 8.2 `TextChatService` and the chat guarantees

**All games offering in-game text chat must integrate `TextChatService`**, per the Misusing Roblox Systems Community Standard. Legacy chat and custom chat systems are no longer supported. **[Roblox official, `chat/guidelines.md`]**

**What counts as "chat"** (and must flow through a `TextChannel`): user-to-user chat window communication and team-specific messages. Routing these through `TextChannel` is what "ensures messages respect privacy settings, are visible to moderators, and are properly text-filtered."

**What is *not* chat** (but may still need filtering): developer-authored menu text, game status updates, admin command announcements, a player renaming their pet dog, moderation audit logs, and comments on in-game posts — **unless the comments support replies, in which case they become a conversation and are subject to the chat policy.**

**Additional requirements:** **[Roblox official, `chat/guidelines.md`]**

- **Editable text visible between users — signs, bulletin boards — must be rate-limited to at least 1 minute.**
- Communication must respect user privacy settings. `TextChannel:SendAsync()` handles basic privacy and parental settings automatically; `TextChannel:SetDirectChatRequester()` must be used to mark channels created for direct chat.
- Use `TextChatService:CanUserChatAsync()`, `CanUsersChatAsync()`, `CanUsersDirectChatAsync()` to check eligibility — "Some users might have additional restrictions or constraints depending on which app store they used to install Roblox or their local laws."
- In-game communication should be reportable for abuse; **`TextChannel`s handle this automatically** — which is a strong reason not to roll your own.

Roblox also runs a **Text Chat Nudge** system: "If users repeatedly send messages that violate community standards, Roblox warns and then temporarily prevents them from sending messages."

### 8.3 UGC risk inside your game

If players can create things other players see, you have inherited a moderation surface. The obligations:

1. **Filter every displayed string** (§8.1), including on read-back from storage.
2. **Rate-limit every editable public text input** to ≥1 minute.
3. **Declare it.** "Free-form user creation" is a content descriptor in the Experience Guidelines questionnaire and pushes your rating to **13+**. Media sharing and cross-experience content viewing are separate questions with their own consequences.
4. **Non-text UGC has no automatic filter.** A player arranging blocks into a shape, a drawing system, an emote sequence — Roblox's text filter does nothing here. You need your own reporting affordance and, realistically, your own review queue.
5. **Build a report path.** Roblox's own guidance is that in-game communication "should be reportable for abuse"; extend that to any player-created artefact.
6. **Log for forensics.** When you get a report, you need to know who made the thing and when. Store author `UserId` and timestamp alongside every persisted user artefact.

Remember that **Experience Guidelines cover only content you create** — "They do **not** apply to user-generated content that players bring with them into your experience, such as avatar clothing and accessories." **[Roblox official, `experience-guidelines.md`]** Your rating doesn't protect you from what players bring; your in-game systems have to.

### 8.4 Moderation, maturity, enforcement and appeals

**The Maturity & Compliance questionnaire** is mandatory for public/limited publishing to 16+ and above, and covers: violence, blood, fear, crude humour, unplayable gambling content, strong language, romantic themes, alcohol, social hangout, free-form user creation, sensitive issues, **paid random items**, **paid item trading**, media sharing, and **AI interaction**. **[Roblox official, `content-maturity.md`, `experience-guidelines.md`]**

Answer based on **the most mature or extreme content a player can encounter**, not the average. And critically: **"If you publish an update that changes any of the answers from the questionnaire, you must return and update your answers and resubmit."** A content update that adds a gacha, a trading system or an AI NPC is a questionnaire event, not just a deploy.

The **AI interaction** questions are new and worth flagging: you must declare whether players can interact with generative AI, and whether interactions are **extended** (cross-session memory enabled, or the AI *is* the main purpose with no time limit) or **limited**. **[Roblox official, `content-maturity.md`]**

**Enforcement path when your maturity info is wrong:** private-message notification → moderator feedback on the questionnaire page → a moderation action. Consequences escalate from removal of your maturity label (which **restricts playability for all players** if you end up with no maturity information at all) up to game and account action for repeated inaccuracy. **[Roblox official, `content-maturity.md`]**

**Appeals:** owner/group-owner goes to `roblox.com/report-appeals`, selects the violation, requests appeal with a written explanation. If the violation isn't listed, use Support ▸ "appeal something not shown."

**DevEx consequences of moderation:** "Noncompliance with the Roblox Terms of Use or Community Standards may result in suspension from the DevEx program," and prior approvals are no guarantee of future ones. Roblox explicitly notes that "not all moderation actions result in suspension... Roblox takes into consideration the type of violation and its timing." **[Roblox official, `developer-exchange.md`]**

**Discovery consequences:** ads eligibility is lost while a resubmitted questionnaire is under review; the publishing fee and expedited review fee are **not refunded** if the game is permanently moderated within the refund window. **[Roblox official, `immersive-ads.md`, `publish-games-and-places.md`]**

### 8.5 Production monitoring

**Alerts** (100+ DAU) with webhook delivery is the operational backbone. Roblox's own suggested workflow: create "client crash rate > 5%" with a 5-minute duration and critical severity, wire it to PagerDuty or Discord, deploy, get paged, click through to the dashboard. Filters include **place version**, which is what makes it a deploy-safety tool rather than a general health tool. Up to 20 alerts per experience. **[Roblox official, `alerts.md`]**

**Performance dashboard** metrics include client crash rate, crash count by device type, and server heartbeat percentiles (**P10 / P90**). Note Roblox's statistical caveat: "When the number of ended sessions is low, crash rate breakdowns can become unstable. In these cases, the chart will show a dashed line instead of a solid line" — at low volume, watch crash *count*, not crash *rate*. **[Roblox official, `performance.md`]**

**Error report** exists specifically to catch broken analytics instrumentation: Roblox tells you to "visit your game's error report to see if there are any errors with your event tracking." **[Roblox official, `event-types.md`]**

---

## 9. Release strategy

### 9.1 The 2026 reality: you launch to 16+ first

This is the biggest structural change to Roblox launches, and any release plan written before it is wrong.

**To reach 16+ and Trusted Friends:** account in good standing, ≥2 days old; **age check** via facial age estimation or government ID; complete the **content maturity & compliance questionnaire**. **[Roblox official, `publish-games-and-places.md`]**

**To reach all ages (Roblox Kids and Select), you additionally need:**

1. Verify your account — **facial age estimation if under 18, government ID if 18+**.
2. **2FA enabled.**
3. **Either** an active Roblox Plus or Roblox Premium subscription for **2 consecutive months**, **or** a one-time refundable **1,000 Robux** publishing fee per game.
4. **Pass the evaluation process:**
   - **Trial phase** — the game is available only to age-checked users 16 and older.
   - **Engagement analysis** — verified via account age, play history and platform spend to confirm real users, not bots.
   - **Safety review** — real-time moderation reports and gameplay reviewed for age suitability.
   - **Threshold — 250 unique plays by highly engaged age-checked users within a 60-day window.**

**[Roblox official, `kids-and-select.md`, `publish-games-and-places.md`]**

**"Highly engaged player" is defined by tenure + playtime in your game + platform spend:** "Users who meet the criteria for 'platform spend' have made a minimum purchase anywhere on Roblox in the last 60 days and have spent time in your game within that same window. They don't need to spend anything in your game specifically." Roblox is explicit that free-to-play games are not disadvantaged — "your game doesn't need to be monetized for players to count toward your total."

**Fee mechanics:**

| Fee | Amount | Refund condition |
| --- | --- | --- |
| **Publishing fee** | **1,000 Robux**, one-time, per game | Refunded if the game "maintains 25 highly engaged players for 60 days without moderation." Not refunded if permanently moderated in that window. |
| **Expedited review fee** | **50,000 Robux**, one-time, per game | Requestable after **90 days**, if the game is in good standing and maintains 25 highly engaged players. A minor violation found during the 48-hour review restarts the 48-hour clock on resubmission. |

**[Roblox official, `publish-games-and-places.md`, `kids-and-select.md`]**

**Track it** on the **Audience Reach** dashboard in Creator Hub, in real time.

**The strategic consequence:** if your game targets under-13s, your first 60 days are a *qualification run with a 16+ audience*. Plan content, monetization and marketing for an older cohort during that window, and note Ads Manager's **Engagement objective**, which "reaches age-checked highly engaged players whose sessions count toward your highly engaged player threshold." Roblox's own caveats on it: expect a **higher cost per play** because the audience is smaller; use a **dedicated budget** rather than cannibalising Plays campaigns; and **the campaign will not auto-pause when you hit the threshold** — track and pause it yourself. **[Roblox official, `ads-manager.md`]**

### 9.2 The soft-launch ladder

Roblox gives you four discrete rungs. Use all of them.

| Rung | Mechanism | Who sees it | RFY exposure |
| --- | --- | --- | --- |
| 1 | **Private** | You + Edit permission holders | None |
| 2 | **Limited ▸ Playtesters / Friends / Community Members** | Selected group only; not publicly discoverable | None |
| 3 | **Public + Beta Mode** | Everyone, but **omitted from Recommended For You** | **None** — "Home recommendations metrics are zero" |
| 4 | **Public** | Everyone | Full |

**[Roblox official, `publish-games-and-places.md`, `acquisition.md`]**

**Beta Mode is the single most under-used feature on the platform.** It lets you be publicly playable, fully instrumented, monetizing, and accumulating the highly-engaged-player count toward Kids/Select evaluation — while generating **zero RFY signal**. You can widen reach inside beta by running Sponsored ads ("If you enable sponsored ads, the game's analytics charts might show some users from Recommended For You").

**A defensible launch sequence [inferred, built on documented mechanisms]:**

1. **Private/Limited** — team + playtesters. Fix crashes, verify instrumentation with **View Events**, confirm your onboarding funnel emits correctly.
2. **Public + Beta Mode, small paid traffic.** Buy a small Sponsored budget to get real strangers in. Read: first-session retention curve, onboarding funnel drop-off, crash rate by device, average session time. Iterate here until D1 and session time reach your similar-game benchmark band. This is exactly the sequencing Roblox prescribes: *fix retention before driving users*.
3. **Still in beta:** run price and shop experiments if you have the DAU for it; if not, at least verify that nothing is hard-coded (Dynamic Price Check) and that regional pricing is on.
4. **Leave Beta Mode.** Ship an update the same day — it triggers quality reclassification and an explore phase simultaneously.
5. **Watch the Home Recommendations tab daily** for the first two weeks. Roblox tells you which signals to read first and in what order: play-through rate, play days per user, playtime per user, first-play bounce rate; then co-play days, qualified sessions, spend days, Robux spent; each across D1, D2–7, D8–28.
6. **Expect fluctuation.** "As the Recommended for You algorithm explores which users might be best suited for your game, you might see some fluctuations... before you settle into a new baseline."

### 9.3 "A bad early retention signal is hard to recover from" — verified

**Verdict: directionally true, commonly overstated, and precisely bounded.**

**What supports it:**

- Roblox's own sequencing instruction is explicit: **"Before driving too many new users to your game, grow [retention/engagement/monetization] to a level that's comparable to or above the benchmarks."** **[Roblox official, `analytics/index.md`]**
- Roblox's retention doc notes that a large influx of new users itself depresses retention: "This is a typical and temporary outcome following a large influx of new users." If you spike traffic before the game holds people, you print a bad cohort *and* a bad average simultaneously. **[Roblox official, `retention.md`]**
- The explore/expand bandit is adaptive: a bad explore cohort reduces subsequent expansion.
- Beta Mode exists specifically so you don't have to take that risk.

**What bounds it — and this is the part usually missed:**

- **The ranking signals are rolling averages over D1, D2–7 and D8–28 windows.** A bad cohort ages out of the longest window in about 28 days. There is no documented permanent penalty attached to a historical cohort. **[derived from the documented windows]**
- **Quality classification is re-run on every update:** "Roblox continually reclassifies content quality with every update, giving all games the opportunity to improve their reach." **[Roblox official, `discovery.md`]**
- Roblox publishes a **daily-updating Creator Dashboard banner** telling you whether you're currently quality-limited — so "am I shadow-banned?" is an answerable question, not a superstition.

**What genuinely *is* hard to recover from:**

1. **Like ratio.** Public, cumulative, visible on every impression, and an explicit eligibility criterion for at least one curated sort. Downvotes from a broken launch persist long after the bug is fixed. **[Roblox official, `feedback.md`, `learn-explore-sort.md`]**
2. **Moderation history.** It affects DevEx eligibility, ads eligibility, and fee refunds — and Roblox weighs "the type of violation and its timing."
3. **The Kids/Select evaluation clock.** A 60-day rolling window of 250 highly engaged age-checked plays; a bad launch that fails to accumulate them costs you months of under-16 reach.
4. **Non-unique metadata classification.** A game published as a near-clone starts demoted; that's a content problem, not a signal problem, and shipping differentiated content is the only fix.
5. **Your one shot at curiosity traffic.** Players who bounced at 40 seconds are unlikely to click your icon again.

**Practical rule:** the algorithm forgives in about a month; your audience and your like ratio do not. Ship into Beta Mode.

### 9.4 Versioning, rollback and configs

- **Publishing is per-place**; the game's start place is stored as a `.rblx` in the cloud. Place version is a first-class filter in the Performance dashboard and in Alerts — use it to compare a new version's crash rate against the previous one. **[Roblox official, `publish-games-and-places.md`, `alerts.md`]**
- **`ConfigService` is your rollback mechanism for anything you can parameterise.** Staged changes are visible to your team in Studio only; publishing takes 15 seconds to 1 minute, or gradually over 15 minutes. If a tuning change goes wrong, reverting a config is a minute, not a deploy. **[Roblox official, `configs.md`]** Feature-flag every risky system behind a boolean config on the way in.
- **Configs lock during experiments.** "Roblox locks the config key the moment an experiment starts running" — you can't edit or delete the key or its conditional values, and the lock releases when the experiment completes. Plan around this: don't feature-flag your kill switch on a key you're about to experiment on.
- **Add a descriptive publish message** on every config publish; it appears on the History page.
- **Analytics annotations:** the dashboard annotates benchmark-set transitions, and Alerts write annotations too — build the habit of correlating metric movement with deploy/config timestamps.

### 9.5 Testing with real players before full launch

| Method | What it gets you | Cost |
| --- | --- | --- |
| **Limited ▸ Playtesters** | Controlled group, real devices | Free |
| **Public + Beta Mode** | Real strangers, full analytics, **zero RFY signal** | Free |
| **Paid access as a closed beta** | Roblox explicitly endorses this: "Some developers temporarily use this feature to create a closed beta where their most engaged users can have early access" — and tells you to disclose it: "make sure to let users know that they're purchasing a beta version" | 25–1,000 Robux barrier |
| **Sponsored ads into a beta game** | Traffic on demand, targetable, measurable | Ad budget (Robux convertible to ad credits, min 1 credit; 18+-rate Robux converts first) |
| **Search ads** | Intent-qualified traffic | Ad budget |

**[Roblox official, `publish-games-and-places.md`, `paid-access-robux.md`, `ads-manager.md`]**

Two ads-manager details worth knowing before you spend: campaigns run **automatically in both Home and search results**; and you can include **up to 10 thumbnails per campaign, evenly distributed across players** — which is a second, independent creative test surface alongside thumbnail personalization. Ad creatives also support **launch data**, so Roblox's own suggestion is to "adjust the player's introduction based on the audience targeted by the ad" — tutorial steps for a New Players campaign, a "Welcome back" for a Lapsed Players campaign. **[Roblox official, `ads-manager.md`]**

---

## Metrics benchmark table

Absolute benchmarks are scarce because Roblox deliberately serves you a personalised percentile band instead. Everything below is sourced and dated; illustrative figures are marked.

| Metric | "Good" / threshold | Source | Date |
| --- | --- | --- | --- |
| **D1 retention** | Roblox's worked example band for similar games: **50th pct 12.11%, 90th pct 18.73%** — *illustrative example in docs, not a published statistic* | `analytics-dashboard.md` | retrieved 2026-09-17 |
| **D1 / D7 / D30 retention** | Target: at or above **your own** similar-game 50th–90th band; peers require 100+ DAU | `analytics-dashboard.md`, `analytics/index.md` | 2026-09-17 |
| **First-play bounce** | Measured in two buckets: **`<60s`** and **`61–180s`**. Lower is better; it is a negative ranking signal | `discovery.md` | updated 2026-07-07 |
| **Time to fun (FTUE)** | **≤5 minutes**, "ideally" — treat `<60s` as the real target given the bounce bucket | `retention.md`, `engagement.md` | 2026-09-17 |
| **Onboarding funnel drop-off** | Roblox's own reference game loses **70% between step 1 and step 2** — that's the bar you're beating, not meeting | `funnel-events.md` | 2026-09-17 |
| **Playtime ranking credit** | Capped at **60 minutes per user, per game, per day** | `discovery.md` | 2026-07-07 |
| **Creator Rewards session threshold** | **10+ minutes** by an Active Spender, in their **first three** experiences that day | `creator-rewards.md` | 2026-09-17 |
| **Payer revenue concentration** | **Top 15% of active payers ≈ 50% of revenue** (platform average) | `analytics/get-started.md` | 2026-09-17 |
| **Payer conversion / ARPPU / ARPDAU** | No absolute figure published; use your similar-game 50th–90th band | `analytics-dashboard.md` | 2026-09-17 |
| **Thumbnail personalization lift** | **+8.5% average** qualified play-through rate in testing; **up to +50%** for some games | `thumbnails.md` | 2026-09-17 |
| **Client crash rate** | Roblox's own alert example uses **>5% for 5 minutes = critical** | `alerts.md` | 2026-09-17 |
| **Analytics dashboard eligibility** | **>10 DAU and 10 play hours for 7 consecutive days** | `analytics-dashboard.md` | 2026-09-17 |
| **Benchmarks / Insights / Performance / Alerts** | **100+ DAU** | `analytics/index.md`, `insights.md`, `performance.md`, `alerts.md` | 2026-09-17 |
| **AI analytics reports** | **1,000+ DAU** | `insights.md` | 2026-09-17 |
| **A/B experiments viable** | Roblox: under **1,000 DAU** "might struggle to get useful data" | `experiments.md` | updated 2026-08-18 |
| **Experiment duration** | **14–60 days**; control + up to 2 variants; act only when the CI excludes 0% | `experiments.md` | 2026-08-18 |
| **Price optimization eligibility** | **~60,000 transactions in the previous 30 days** | `price-optimization.md` | 2026-09-17 |
| **Rewarded video eligibility** | **2,000+ unique visitors/month**, 13+, ID-verified | `rewarded-video-ads.md` | 2026-09-17 |
| **Rewarded video reward value** | Equivalent of **3–10 Robux**; must be a developer product | `rewarded-video-ads.md` | 2026-09-17 |
| **Experience notifications eligibility** | **100 visits since launch**; **1 notification per user per day** | `experience-notifications` includes | 2026-09-17 |
| **Event promotion eligibility** | Active event started in last **7 days**, **1,000+ RSVPs**; best events run **7–30 days**; submit **7+ days ahead** | `experience-events.md` | 2026-09-17 |
| **Kids/Select evaluation** | **250 unique plays by highly engaged age-checked users in a 60-day window** | `kids-and-select.md` | 2026-09-17 |
| **Publishing fee refund** | **25 highly engaged players for 60 days** without moderation | `publish-games-and-places.md` | 2026-09-17 |
| **Learn & Explore sort eligibility** | **Like ratio >50%**, **15+ concurrent users**, no aggressive FTUE monetization | `learn-explore-sort.md` | 2026-09-17 |
| **Update cadence** | **Weekly ideal, monthly minimum**; content updates every **2–4 weeks**; major every **2–3 months**; cadence effort **<3 weeks** | `monetization/index.md`, `retention.md`, `content-updates.md` | 2026-09-17 |
| **Season pass shape** | **1 month** season, **1 week** rest, **10 tiers**, daily-resetting missions | `season-pass-design.md` | 2026-09-17 |
| **DevEx standard rate** | **0.0038 USD / Earned Robux** (30,000 → $114) | `developer-exchange.md` | effective 2025-09-05 |
| **DevEx legacy rate** | 0.0035 (30,000 → $105), clears first | `developer-exchange.md` | before 2025-09-05 |
| **DevEx U.S. 18+ rate** | **0.0054**, R15/articulation-gated | `18-plus-devex-rate.md` | effective 2026-06-08 |
| **DevEx minimum / frequency** | **30,000 Earned Robux**; one completed request per calendar month | `developer-exchange.md` | 2026-09-17 |
| **In-game purchase share** | **70% to creator** | `roblox-plus.md` | 2026-09-17 |
| **Subscription share** | Robux-priced: **70%/mo**. Local currency: **70% month 1, 100% after** | `subscriptions.md` | 2026-09-17 |
| **Paid access (local currency) share** | **50% / 60% / 70%** at $9.99 / $29.99 / $49.99 | `paid-access-local-currency.md` | 2026-09-17 |
| **Marketplace item share** | Marketplace: **30% → 70%** progressive (cap at 6× floor). In-game: creator **30%**, game owner **40%** | `marketplace-fees-and-commissions.md` | 2026-09-17 |
| **Creator Rewards — Daily Engagement** | **5 Robux/day** per qualifying Active Spender | `creator-rewards.md` | since 2025-07-24 |
| **Creator Rewards — Audience Expansion** | **35%** of the user's first **$100** platform-wide in **60 days**; requires **100+ avg DAU for 60 days** | `creator-rewards.md` | 2026-09-17 |
| **Roblox Plus sign-up bonus** | **250 Robux/mo × 3 months = up to 750 Robux** per subscriber | `roblox-plus.md` | 2026-09-17 |
| **Roblox Plus private-server bonus** | Up to **100 Robux/subscriber/month** at **60+ min** in paid private servers | `roblox-plus.md` | 2026-09-17 |
| **`AnalyticsService` rate limit** | **120 + (20 × CCU)** requests/minute | `event-types.md` | 2026-09-17 |
| **Event name budget** | **100** custom event names; **10** funnels × **100** steps; **10** economy resource types; **3** custom fields; **8,000** value combos; **90-day** retention | `event-types.md` | 2026-09-17 |
| **Platform scale** | **144M daily active users** (Roblox platform average) | `creator-programs/jumpstart.md` | updated 2026-07-01 |
| **Creator payouts** | **$1.5B paid to creators in the last 12 months** | `creator-programs/jumpstart.md` | updated 2026-07-01 |
| **Top-creator earnings** | **$7M average per top-100 creator**, last 12 months | `creator-programs/jumpstart.md` | updated 2026-07-01 |
| **Implied concentration** | **~$700M ≈ 47% of all creator payouts to 100 creators** | derived from the two figures above | 2026-09-17 |

---

## Sources

All Roblox documentation was read from the open-source mirror at `github.com/Roblox/creator-docs` (`main` branch) on **2026-09-17**; canonical URLs on `create.roblox.com` are given below. File sync dates are noted where checked.

**Discovery and top-of-funnel**
- https://create.roblox.com/docs/discovery — *(last synced 2026-07-07)*
- https://create.roblox.com/docs/production/publishing/publish-games-and-places
- https://create.roblox.com/docs/production/publishing/thumbnails
- https://create.roblox.com/docs/production/publishing/experience-icons
- https://create.roblox.com/docs/production/publishing/descriptions
- https://create.roblox.com/docs/production/publishing/experience-genres

**Analytics**
- https://create.roblox.com/docs/production/analytics
- https://create.roblox.com/docs/production/analytics/get-started
- https://create.roblox.com/docs/production/analytics/analytics-dashboard
- https://create.roblox.com/docs/production/analytics/acquisition
- https://create.roblox.com/docs/production/analytics/engagement
- https://create.roblox.com/docs/production/analytics/retention
- https://create.roblox.com/docs/production/analytics/monetization
- https://create.roblox.com/docs/production/analytics/event-types
- https://create.roblox.com/docs/production/analytics/economy-events
- https://create.roblox.com/docs/production/analytics/funnel-events
- https://create.roblox.com/docs/production/analytics/custom-events
- https://create.roblox.com/docs/production/analytics/custom-fields
- https://create.roblox.com/docs/production/analytics/insights
- https://create.roblox.com/docs/production/analytics/alerts
- https://create.roblox.com/docs/production/analytics/performance
- https://create.roblox.com/docs/production/analytics/crashes
- https://create.roblox.com/docs/production/analytics/feedback
- https://create.roblox.com/docs/reference/engine/classes/AnalyticsService

**A/B testing and remote config**
- https://create.roblox.com/docs/production/experiments — *(last synced 2026-08-18)*
- https://create.roblox.com/docs/production/configs

**Monetization**
- https://create.roblox.com/docs/production/monetization
- https://create.roblox.com/docs/production/monetization/developer-exchange — *(synced 2026-07-07)*
- https://create.roblox.com/docs/production/monetization/18-plus-devex-rate — *(synced 2026-06-08)*
- https://create.roblox.com/docs/production/monetization/devex-portal
- https://create.roblox.com/docs/production/monetization/tax-information
- https://create.roblox.com/docs/production/monetization/passes
- https://create.roblox.com/docs/production/monetization/developer-products
- https://create.roblox.com/docs/production/monetization/subscriptions
- https://create.roblox.com/docs/production/monetization/private-servers
- https://create.roblox.com/docs/production/monetization/paid-access-robux
- https://create.roblox.com/docs/production/monetization/paid-access-local-currency
- https://create.roblox.com/docs/production/monetization/roblox-plus
- https://create.roblox.com/docs/production/monetization/managed-pricing
- https://create.roblox.com/docs/production/monetization/price-optimization
- https://create.roblox.com/docs/production/monetization/regional-pricing
- https://create.roblox.com/docs/production/monetization/paid-random-items
- https://create.roblox.com/docs/production/monetization/engagement-based-payouts — *(deprecated 2025-07-24)*
- https://create.roblox.com/docs/production/monetization/immersive-ads
- https://create.roblox.com/docs/creator-rewards
- https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions

**Game design / liveops**
- https://create.roblox.com/docs/production/game-design/monetization-foundations
- https://create.roblox.com/docs/production/game-design/liveops-essentials
- https://create.roblox.com/docs/production/game-design/liveops-planning
- https://create.roblox.com/docs/production/game-design/content-updates
- https://create.roblox.com/docs/production/game-design/season-pass-design
- https://create.roblox.com/docs/production/game-design/subscription-design
- https://create.roblox.com/docs/production/game-design/contextual-purchases
- https://create.roblox.com/docs/production/game-design/core-loops
- https://create.roblox.com/docs/production/game-design/onboarding
- https://create.roblox.com/docs/production/game-design/onboarding-techniques
- https://create.roblox.com/docs/production/game-design/balance-virtual-economies
- https://create.roblox.com/docs/production/game-design/design-for-roblox
- https://create.roblox.com/docs/production/roblox-user-base
- https://create.roblox.com/docs/resources/feature-packages/engagement-rewards

**Promotion, community, programs**
- https://create.roblox.com/docs/production/promotion
- https://create.roblox.com/docs/production/promotion/ads-manager
- https://create.roblox.com/docs/production/promotion/experience-events
- https://create.roblox.com/docs/production/promotion/experience-notifications
- https://create.roblox.com/docs/production/promotion/invite-prompts
- https://create.roblox.com/docs/production/promotion/referral-system
- https://create.roblox.com/docs/production/promotion/share-links
- https://create.roblox.com/docs/production/promotion/social-media-links
- https://create.roblox.com/docs/production/promotion/rewarded-video-ads
- https://create.roblox.com/docs/production/promotion/content-maturity
- https://create.roblox.com/docs/production/promotion/experience-guidelines
- https://create.roblox.com/docs/projects/groups
- https://create.roblox.com/docs/creator-programs/standout-games
- https://create.roblox.com/docs/creator-programs/todays-picks-home
- https://create.roblox.com/docs/creator-programs/learn-explore-sort
- https://create.roblox.com/docs/creator-programs/jumpstart — *(synced 2026-07-01; source of the 144M DAU / $1.5B / $7M figures)*
- https://create.roblox.com/docs/creator-programs/incubator
- https://create.roblox.com/docs/creator-programs/creator-affiliate — *(deprecated 2025-07-24)*
- https://create.roblox.com/docs/creator-programs/spotlights

**Safety**
- https://create.roblox.com/docs/ui/text-filtering
- https://create.roblox.com/docs/chat/guidelines
- https://create.roblox.com/docs/chat/in-experience-text-chat
- https://create.roblox.com/docs/reference/engine/classes/TextService
- https://create.roblox.com/docs/reference/engine/classes/TextChatService
- https://create.roblox.com/docs/reference/engine/classes/PolicyService
- https://create.roblox.com/docs/production/publishing/kids-and-select
- https://create.roblox.com/docs/production/publishing/account-verification

**Referenced but not retrievable in this session** (egress blocked; listed for follow-up, not cited as evidence)
- https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441
- https://devforum.roblox.com/t/discovery-on-roblox-past-present-and-future-vision/2859111
- https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628
- https://corp.roblox.com/newsroom — Roblox Corporation press and creator-economy reports
- https://ir.roblox.com — quarterly DAU, bookings, hours and DevEx figures
- https://en.help.roblox.com — Community Standards, Terms of Use, DevEx FAQs

---

## The honest picture

**The earnings distribution is a power law, and Roblox publishes enough to compute it.** $1.5B paid to creators in the trailing twelve months; $7M average for each of the top 100 creators. That is roughly **$700M — about 47% of every dollar Roblox paid creators — going to one hundred accounts.** **[Roblox official figures, `jumpstart.md`, updated 2026-07-01; ratio derived]** The remaining ~$800M is spread across a creator population numbering in the millions. I could not retrieve Roblox's published breakdown of how many creators earn above particular thresholds; if you need that number, it lives in Roblox's investor materials and RDC talks, both of which were unreachable here.

**The floor is real and it is high.** Before you see a single dashboard number you need >10 DAU and 10 play hours for 7 consecutive days. Before you get benchmarks, insights, performance data or alerts: 100 DAU. Before A/B testing works: ~1,000 DAU. Before price optimization works: 60,000 transactions in 30 days. Before Audience Expansion Rewards pay out: a 100+ DAU average sustained for 60 days. Before your game reaches anyone under 16: 250 highly engaged age-checked plays inside a 60-day window. **A Roblox game that nobody plays is also a Roblox game you cannot measure, cannot optimise, and cannot monetize at full rate.** The tooling is excellent and almost all of it is gated behind traction you don't have yet.

**Team size at the top is not what the folklore says.** Roblox's own liveops documentation is built around *Adopt Me!*, *Jailbreak*, *Doors*, *Brookhaven* and *Dragon Adventures* — studios, not solo developers. The Incubator program takes cohorts of up to 40 **experienced teams** for six months; Jumpstart's stated purpose is to bring **off-platform studios** onto Roblox. I could not verify headcounts for specific top games in this session, so I will not quote a number — but the structural evidence (a documented weekly content cadence, a separate major-update track every 2–3 months, a moderation surface, a Discord, and a live economy to balance) describes a team, not a person.

**What a small ambitious team should realistically target.** Not "a hit." Target the *gates*, in order:

1. **10 DAU / 10 play hours / 7 days** → analytics unlocked.
2. **A D1 retention number inside your similar-game band** → you have a game, not a demo.
3. **100 DAU** → benchmarks, insights, performance monitoring, and eligibility for Audience Expansion Rewards.
4. **250 highly engaged age-checked plays in 60 days** → your under-16 audience unlocks.
5. **1,000 DAU** → you can run experiments, and you stop guessing.

Each gate is achievable by a competent small team with a genuinely good first sixty seconds. None of them requires a hit. All of them compound.

**Three things that are true and unglamorous.**

*First,* the highest-ROI work available to almost every Roblox team is not a new feature. It is: fixing hard-coded prices so regional pricing, Plus discounts and price optimization can function; turning on thumbnail personalization with 2–5 thumbnails; and instrumenting a four-step onboarding funnel. Those three tasks take a few days and touch, respectively, your revenue per purchase, your play-through rate, and your ability to diagnose D1. **[derived from `roblox-plus.md`, `thumbnails.md`, `funnel-events.md`]**

*Second,* Roblox's incentives and good design are more aligned here than on most platforms, but not perfectly. The ranking system weights retention above monetization; the best-margin product (local-currency subscriptions at 100% from month two) only pays if players stay; the loot-box rules force disclosure; dark patterns are explicitly banned. But Creator Rewards pays you to be in someone's *first three* games of the day, which rewards notification-driven habit formation; the 60-minute playtime cap rewards frequency over depth; and the highest DevEx rate is contingent on your character rig and your players' verified age, which are not quality signals at all. Know which of your design decisions are serving your players and which are serving the payout formula.

*Third,* the most important number in this chapter is 60 seconds. Roblox's second-highest-priority ranking signal is measured entirely within the first three minutes, and its own reference game loses 70% of players before the first core-loop action completes. **Every hour you spend on content a player will never reach is an hour spent behind a door most people do not open.**

---

*Compiled 2026-09-17. Roblox changes its monetization rates, payout programs and publishing requirements frequently — three of the figures in this chapter (the DevEx standard rate, the 18+ rate, and the replacement of Engagement-Based Payouts) changed within the last 14 months. Re-verify every number against `create.roblox.com/docs` before you plan around it.*
