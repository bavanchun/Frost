---
title: "Frost app icon artwork"
description: "Replace Ice's blue cube AppIcon with Frost artwork, redraw FrostMarkStroke to match, and decide whether to adopt Icon Composer alongside the classic PNG set."
status: pending
priority: P2
effort: "unknown — gated on artwork"
tags: [rebrand, icons, artwork, design]
created: 2026-07-28
---

# Frost app icon artwork

## Overview

The last Ice-branded artwork in the repo. Two assets, both still drawing a cube:

| Asset | What it is today | Where it shows |
|---|---|---|
| `AppIcon.appiconset` | Blue rounded square, white 3D cube. Ice's icon, unmodified. | Dock, Finder, notifications, Sparkle's update dialog, Settings → About (rendered at 225 pt), `README.md` header |
| `FrostMarkStroke.imageset` | Black isometric wireframe cube, template-rendered, single 2x slot at 1.4 KB | Settings → About tab icon, search panel settings button |

Both were left alone by the Ice → Frost rebrand and by
[`260728-0123-snowflake-icon-and-sparkle-plist-comments`](../260728-0123-snowflake-icon-and-sparkle-plist-comments/plan.md),
which renamed the mark but explicitly kept its art and named this work as its
follow-up. That plan's precondition — the mark already carrying its final name —
is now satisfied.

**This plan is gated on artwork that does not exist yet.** Phases 2 and 3 are
mechanical and cheap; phase 1 is the whole cost, and it is a design decision, not
an engineering one.

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | No cube anywhere in Frost's artwork; the app reads as Frost at a glance in the Dock | P1 |
| 2 | `FrostMarkStroke` is visually of a piece with the app icon, not a leftover from a different design | P2 |
| 3 | Icon renders correctly from 16 pt to 1024 pt, and legibly as a 16 pt template mark | P2 |
| 4 | A deliberate, recorded decision on Icon Composer vs. the classic PNG set | P3 |

## Constraints

- **Deployment target is macOS 14**, but the toolchain is Xcode 26.6 on macOS 26.5.2 with `Icon Composer.app` present. Whatever format is chosen must still produce a correct icon on macOS 14.
- **`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`** (`project.pbxproj:306,338`). Keeping the asset name `AppIcon` avoids touching the project file.
- **`FrostMarkStroke` is a template image.** It is tinted by the system, so it must read as a silhouette — no gradients, no colour, no interior detail that collapses at 16 pt.
- **`README.md:2` hardlinks `icon_256x256.png`.** If the filename set changes, that link breaks silently on GitHub.
- **Sparkle shows the app icon in its update dialog.** A broken or missing icon is user-visible during every update.
- **Existing PNG slots are the standard mac idiom set**: 16, 32, 128, 256, 512, each at 1x and 2x. Ten files.

## Non-Goals

- Changing the menu bar control item icons. Those were settled by the previous plan and Snowflake is the shipped default option.
- Redesigning any other UI surface, colour scheme, or the accent colour.
- Rebranding beyond artwork — names, strings, and identifiers are already done.
- Animated or seasonal icon variants.

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: Decide format and produce artwork](./phase-01-decide-format-and-produce-artwork.md) | Pending |
| 2 | [Phase 2: Swap the app icon](./phase-02-swap-the-app-icon.md) | Pending |
| 3 | [Phase 3: Redraw the Frost mark](./phase-03-redraw-the-frost-mark.md) | Pending |

Phase 2 and 3 both depend on phase 1. They are independent of each other and can
land in either order, or together — but shipping phase 2 without phase 3 leaves a
cube in Settings → About next to a non-cube app icon, which is more obviously
wrong than today's consistent-but-stale pair. Prefer landing them together.

## Branch and PR

Single branch, single PR into `main` per `docs/DEVELOPMENT_WORKFLOW.md`:

```
feat/frost-app-icon-artwork
```

## Success Criteria

- [ ] Dock, Finder, and `⌘Tab` show the new icon after a clean install
- [ ] Settings → About shows it at 225 pt with no visible softness or artefacts
- [ ] Settings → About tab icon and the search panel settings button show the new mark
- [ ] The mark is legible at 16 pt and reads correctly in both light and dark menu bars
- [ ] `README.md` header image resolves on GitHub
- [ ] Sparkle's update dialog shows the icon
- [ ] No cube remains in `Frost/Assets.xcassets/`
- [ ] Clean build, no asset catalog warnings

## Risks

**The artwork is the entire project and cannot be produced by tooling in this
repo.** Phases 2 and 3 are perhaps an hour combined. Phase 1 is unbounded and
depends on a designer, a commission, a generator, or the maintainer drawing it.
Estimating this plan before phase 1 resolves would be fiction — hence
`effort: unknown`.

**A 16 pt template mark is the hard constraint, not the 1024 pt icon.** Detail
that survives at 512 pt routinely turns to mud at 16 pt. Design the mark first at
16 pt and scale up; doing it the other way round usually means redrawing.

**Icon Composer is a one-way door in practice.** Adopting `.icon` means the
artwork lives in a format the classic pipeline cannot round-trip. Worth it for
the macOS 26 look, but decide deliberately in phase 1 rather than drifting into it.

**Asset catalog failures are silent.** A missing or misnamed slot yields no icon
with no build error — the same class of failure the previous plan designed around.
The manual checks in Success Criteria are what catch it.

## Unresolved questions

1. **What is Frost's mark?** A snowflake pairs with the new menu bar icon and the
   name, but the app icon repeating the control item icon may be too literal.
   Unresolved and blocking phase 1.
2. **Icon Composer or classic PNGs?** Decided in phase 1; see that file for the
   trade-off.
3. **Who draws it?** Commission, generate, or hand-draw. Changes the timeline by
   an order of magnitude but not the plan's shape.
4. Does the accent colour (`AccentColor.colorset`) need to move with the icon, or
   stay as is? Currently out of scope; revisit if the new artwork clashes.

<!-- slug: frost-app-icon-artwork -->
