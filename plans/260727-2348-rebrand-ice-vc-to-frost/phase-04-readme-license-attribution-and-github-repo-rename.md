---
phase: 4
title: "README, LICENSE attribution, and GitHub repo rename"
status: pending
priority: P1
effort: "1h"
dependencies: [3]
---

# Phase 4: README, LICENSE attribution, and GitHub repo rename

## Overview

Rewrite `README.md` as Frost's own (currently it's an almost-verbatim copy of upstream's README, complete with upstream's release badge, donate link, and sponsor link). Add the user's own copyright to `LICENSE` alongside — never instead of — the required GPL-3.0 attribution to Jordan Baird. Rename the GitHub repo `bavanchun/Ice-vc` → `bavanchun/Frost` and update the local git remote.

## Requirements

- Functional: README describes Frost as the user's own personal fork, with no dangling links to upstream's release page, donate page, or sponsor page presented as if they were Frost's own
- Legal: `LICENSE` keeps `Ice Copyright (C) 2024 Jordan Baird` verbatim (GPL-3.0 §4 requires preserving existing copyright/license/notice statements in copies) and gains an additional copyright line for the Frost fork
- Operational: `git remote -v` in the local clone points at the renamed repo URL after the GitHub-side rename

## Architecture

Current `README.md` copies these upstream-specific elements that must be decided per-line (not blanket deleted, since some badges are generically informative rather than upstream-specific):

- `<h1>Ice</h1>` → `<h1>Frost</h1>`
- Descriptive paragraph ("Ice is a powerful menu bar management tool...") → reword for Frost, first-person-fork framing
- `[Download]` badge → `https://github.com/jordanbaird/Ice/releases/latest` — **must** change to `bavanchun/Frost/releases/latest` (currently points to upstream's releases, not this fork's)
- `Platform`/`Requirements` badges — generic, keep as-is (not upstream-specific)
- `[Sponsor]` badge → `https://github.com/sponsors/jordanbaird` — this is upstream author's personal sponsor link; remove or replace with nothing (do not point Frost's README at someone else's donation page)
- `[Website]` badge → `https://icemenubar.app` — upstream's own product site; remove
- `[License]` badge → `https://github.com/jordanbaird/Ice?style=flat-square` (repo query param) — update to `bavanchun/Frost`, license itself stays GPL-3.0
- "Buy Me A Coffee" link (`buymeacoffee.com/jordanbaird`) — upstream author's personal donation; remove
- Feature roadmap checklist — this describes actual shipped functionality inherited from Ice; keep the content (it's accurate for Frost too) but it's app-feature documentation, not upstream-attribution — no legal reason to remove
- Gallery screenshots — currently hosted on `github.com/user-attachments` under upstream's repo; these images may 404 or remain accessible depending on GitHub's attachment CDN behavior after repo rename — flag as a known cosmetic gap, not blocking

A dedicated **Credits** or **Acknowledgments** section should replace the removed upstream-specific badges/links, stating plainly that Frost is a fork of `jordanbaird/Ice` under GPL-3.0 — this satisfies both the spirit of open-source attribution norms and keeps the README honest about provenance, without pretending Frost is written from scratch.

`LICENSE` (GPL-3.0 full text) has **two** existing project-specific notices, both in the "How to Apply These Terms to Your New Programs" section near the end (not the license body itself), verified by direct read of the file:

```
Line 634-635 (source-file header template):
    Ice - A powerful menu bar manager for macOS
    Copyright (C) 2024 Jordan Baird

Line 655 (interactive-mode startup notice template):
    Ice Copyright (C) 2024 Jordan Baird
```

<!-- Updated: Validation Session 1 - LICENSE has two notices, not one; both keep the original text and both gain a Frost line beneath them --> Both must remain verbatim — line 655 is a separate template for what a program should print when it starts in interactive mode, distinct from the source-header template at 634-635. Add a new line beneath **each**:

```
Frost (fork of Ice) Copyright (C) 2026 VChun
```

## Related Code Files

- Modify: `README.md` — full rewrite per the itemized decisions above
- Modify: `LICENSE` — add a Frost copyright line beneath each of the two existing notices (line ~635 and line ~655), do not remove or alter either existing Jordan Baird notice
- External: GitHub repo settings for `bavanchun/Ice-vc` → rename to `Frost`
- Modify (local): `.git/config` via `git remote set-url` (or let `gh repo rename` handle it automatically — confirm which)

## Implementation Steps

1. Rewrite `README.md`:
   - Title → "Frost"
   - Intro paragraph reframed as personal fork (keep it honest: "Frost is a personal fork of Ice, a menu bar management tool for macOS...")
   - Download badge → `https://github.com/bavanchun/Frost/releases/latest`
   - Remove Sponsor badge, Website badge, Buy Me A Coffee link (all point to upstream author's personal accounts)
   - License badge → `https://github.com/bavanchun/Frost` query, GPL-3.0 unchanged
   - Keep Platform/Requirements badges as-is
   - Keep the feature roadmap checklist (accurate app documentation)
   - Add a **Credits** section: "Frost is a fork of [jordanbaird/Ice](https://github.com/jordanbaird/Ice), licensed under GPL-3.0."
   - Leave gallery images as-is for now; note in the PR/commit message that image hosting may need re-upload post-rename (not a blocking item for this phase)
2. Edit `LICENSE`: locate BOTH notices — line 634-635 (`Ice - A powerful menu bar manager for macOS` / `Copyright (C) 2024 Jordan Baird`) and line 655 (`Ice Copyright (C) 2024 Jordan Baird`) — and add `Frost (fork of Ice) Copyright (C) 2026 VChun` directly beneath each. Do not touch anything else in the file (it's the GPL-3.0 canonical text otherwise).
3. Rename the GitHub repo:
   ```bash
   gh repo rename Frost --repo bavanchun/Ice-vc
   ```
   (GitHub auto-redirects the old `Ice-vc` URL to `Frost` for existing clones/links — confirm this in step 5.)
4. Update the local git remote (check first whether `gh repo rename` already updated it automatically before running this manually — avoid a redundant/conflicting `set-url`):
   ```bash
   git remote -v
   # if still pointing at Ice-vc:
   git remote set-url origin git@github.com:bavanchun/Frost.git
   git remote -v  # confirm
   ```
5. Verify the old URL redirects: `curl -sIL https://github.com/bavanchun/Ice-vc` should 30x-redirect to `https://github.com/bavanchun/Frost`.
6. Commit README + LICENSE changes on `main`, push.

## Success Criteria

- [ ] `README.md` has zero links to `jordanbaird/Ice/releases`, `icemenubar.app`, `github.com/sponsors/jordanbaird`, or `buymeacoffee.com/jordanbaird`
- [ ] `README.md` has a Credits section correctly attributing upstream Ice
- [ ] `LICENSE` still contains BOTH original notices verbatim (line ~635 and line ~655), each with a new Frost fork copyright line directly beneath it
- [ ] GitHub repo is `bavanchun/Frost`; old `bavanchun/Ice-vc` URL redirects to it
- [ ] `git remote -v` in the local clone resolves to the renamed repo

## Risk Assessment

**Risk**: `gh repo rename` may not automatically update the local git remote depending on `gh` version/config.
**Mitigation**: Step 4 explicitly checks `git remote -v` before deciding whether a manual `set-url` is needed — avoids blindly overwriting a remote that's already correct (which could silently point at the wrong protocol, e.g. https vs ssh, if not careful).

**Risk**: Deleting the Sponsor/Website/donate links might read as stripping legitimate attribution rather than removing unrelated personal accounts.
**Mitigation**: The added Credits section explicitly names and links `jordanbaird/Ice` as the upstream project — this preserves attribution while removing links to Jordan Baird's *personal* payment accounts, which have no place in a fork's README regardless of license terms (GPL-3.0 requires preserving copyright/license notices, not donation links).
