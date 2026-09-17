# Adversarial and Iterative Verification Loops for AI-Generated Work

> **Scope.** A reference chapter for a team that wants a *maximally rigorous* multi-agent QA
> process over AI-generated Luau game code and technical documentation, where the acceptance bar
> is "provably faithful to an original game." It starts with a specific named technique — Matt
> Shumer's **Gauntlet Loop** — establishes exactly what is and is not verifiable about it, then
> surveys the well-documented technique family it belongs to, then proposes a concrete staged
> gauntlet this team can actually run in CI.
>
> **Verification policy for this chapter.** Every claim carries a confidence marker:
>
> | Marker | Meaning |
> |---|---|
> | `[PRIMARY]` | I read the primary artifact directly — the author's own repo file, the paper, the official docs. Quoted verbatim where it matters. |
> | `[SECOND-HAND]` | Reported by a third party (blog, news article, search-result summary) that I could read, but I could not open the primary artifact. |
> | `[SEARCH-SUMMARY]` | Sourced only from a search engine's summary of a page I could not open. Weakest tier. Treat as a lead, not a fact. |
> | `[INFERENCE]` | My own synthesis or judgement, not a reported fact. |
> | `[UNVERIFIED]` | Commonly repeated, could not confirm. |
>
> **Network constraint, stated up front.** This environment's egress proxy blocked `x.com`,
> `arxiv.org`, `aclanthology.org`, and most of the marketing-blog coverage of the Gauntlet Loop.
> `github.com` / `raw.githubusercontent.com` were reachable, which is fortunate: the single most
> load-bearing primary source for this chapter — Matt Shumer's original prompt — lives in a GitHub
> repo he owns, and I read it raw. Where a claim rests on a paper I could not open, it is marked
> `[SEARCH-SUMMARY]` and the arXiv ID is given so you can check it yourself. I have not pretended
> to have read anything I did not read. See [Sources](#sources).

---

## Outline

1. [TL;DR](#tldr)
2. [What is verifiable about the Gauntlet loop](#what-is-verifiable-about-the-gauntlet-loop)
3. [Matt Shumer's other published techniques](#matt-shumers-other-published-techniques)
4. [The technique family](#the-technique-family)
5. [What the evidence actually supports](#what-the-evidence-actually-supports)
6. [The proposed gauntlet for this project](#the-proposed-gauntlet-for-this-project)
7. [Anti-patterns](#anti-patterns)
8. [Sources](#sources)

---
