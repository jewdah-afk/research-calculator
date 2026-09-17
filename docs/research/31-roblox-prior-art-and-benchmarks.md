# Prior Art, Open-Source Libraries, and Real Measured Benchmarks for Roblox Runtime Content Generation

> **Chapter status:** archaeology. Everything below is evidence collected from public sources
> (GitHub source code, Wally registry, web-search summaries of DevForum threads, Roblox's own
> documentation as mirrored in the `Roblox/creator-docs` GitHub repository). The goal is that
> this team **reuses rather than reinvents**, and that its performance expectations rest on
> measured numbers rather than hope.
>
> **Confidence markers used throughout:**
> - `[DOCUMENTED]` — Roblox's own documentation or Roblox-authored source, read directly
>   (via the `Roblox/creator-docs` GitHub mirror, since `create.roblox.com` is unreachable here).
> - `[SOURCE-READ]` — I fetched and read the actual open-source code. Highest confidence for
>   *architecture* claims; the code is the artifact.
> - `[COMMUNITY, SECOND-HAND]` — reported by developers on the DevForum / YouTube / blogs, reaching
>   me only through web-search result summaries. `devforum.roblox.com` is 403-blocked from this
>   environment, so **I could not open the original threads**. Treat every number as a claim, not
>   a measurement, and re-measure before you bet on it.
> - `[INFERRED]` — my own arithmetic on top of the above. The inputs are cited; the output is mine.
>
> **Sources that were blocked (403) and are therefore absent:** `create.roblox.com`,
> `devforum.roblox.com`, `luau.org`. Where a Roblox doc claim appears below it came from the
> `Roblox/creator-docs` GitHub repository, which is the same content under an open license.

