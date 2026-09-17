# Roblox VFX, Audio and Game Feel

> Chapter 45 of the internal Roblox mastery corpus.
> **Audience:** the team building the full presentation layer of a large incremental/idle game.
> **Thesis:** two games with identical mechanics can feel worlds apart. This chapter is that difference.
> **Sibling chapters:** 23 (rendering/lighting/materials), 40 (EditableImage cookbook), 41 (EditableMesh cookbook), 43 (3D math toolkit), 63 (incremental UI). Cross-referenced, not duplicated.

Every engine claim below is sourced from the Roblox `creator-docs` reference YAML or the live API dump (see **Sources**). Claims that could not be verified against a primary source are marked `[UNVERIFIED]`. Community knowledge obtained only through search summaries is marked `[COMMUNITY, SECOND-HAND]`.

## Contents

1. [TL;DR](#tldr)
2. [ParticleEmitter mastery](#1-particleemitter-mastery)
3. [Beam: the general-purpose textured quad](#2-beam-the-general-purpose-textured-quad-strip)
4. [Trail](#3-trail)
5. [The juice toolkit](#4-the-juice-toolkit)
6. [Lighting as VFX](#5-lighting-as-vfx)
7. [Post-processing as feedback](#6-post-processing-as-feedback)
8. [The no-shader workarounds](#7-the-no-shader-workarounds)
9. [Audio: the other half of game feel](#8-audio-the-other-half-of-game-feel)
10. [Performance discipline](#9-performance-discipline)
11. [The make-it-feel-expensive checklist](#the-make-it-feel-expensive-checklist)
12. [Sources](#sources)

