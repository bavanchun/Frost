---
title: "Rebrand Ice-vc to Frost"
description: "Full mechanical rebrand of the personal Ice fork to Frost: Xcode project/target/scheme, source folder, 18 Swift symbols, display strings, bundle ID, README, and GitHub repo."
status: pending
priority: P1
effort: "1d"
tags: [rebrand, xcode, swift]
created: 2026-07-27
---

# Rebrand Ice-vc to Frost

## Overview

`bavanchun/Ice-vc` is a personal-use fork of [jordanbaird/Ice](https://github.com/jordanbaird/Ice). A prior session already rebranded the bundle ID (`com.jordanbaird.Ice` → `com.vchun.Ice`), dev team, copyright, and Sparkle feed, and shipped a signed personal release (`v0.11.12`, see `docs/release-guide.md`). The user now wants every remaining trace of "Ice" removed at every layer they or a viewer would see: GitHub repo name, Xcode project/target/scheme, source folder, 18 Swift type names, 11 filenames, 5 user-visible display strings, and the README. Custom icon design is explicitly out of scope (separate creative follow-up); the current icon assets stay as-is.

The user explicitly chose the highest-effort rebrand option (full code rename, not just repo/product-name cleanup), accepting the trade-off that future upstream syncs will conflict heavily. This is a one-time mechanical transformation, not an ongoing sync strategy.

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Rename Xcode project/target/scheme/source folder from Ice → Frost, verified buildable | P1 |
| 2 | Rename all 18 `Ice*` Swift symbols and 11 `Ice*.swift` files to `Frost*` | P1 |
| 3 | Replace bundle ID, display strings, and menu titles; re-grant macOS permissions | P1 |
| 4 | Rewrite README as Frost's own, keep required GPL-3.0 attribution to Jordan Baird, rename GitHub repo | P1 |
| 5 | Update `docs/release-guide.md` for new identifiers and confirm a full signed release still works | P1 |

## Constraints

- **GPL-3.0 legal requirement**: `LICENSE` must keep both original Jordan Baird notices verbatim — the source-file header template (line ~635, `Copyright (C) 2024 Jordan Baird`) and the interactive-mode startup notice template (line ~655, `Ice Copyright (C) 2024 Jordan Baird`). Add the user's own copyright as fork maintainer beneath each — never replace either. This is non-negotiable, not a style choice.
- **Fragile project file**: `Ice.xcodeproj/project.pbxproj` uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ synced folder groups) where `path = Ice;` ties the file group directly to the `Ice/` folder on disk. Renaming the folder and this path must happen together, atomically, followed immediately by a build-verify gate — before any Swift symbol renames — so a broken project reference is caught in isolation.
- **Bundle ID change breaks TCC grants**: macOS treats `com.vchun.Frost` as a different app from `com.vchun.Ice`. Accessibility and Screen Recording permissions must be re-granted; the old `/Applications/Ice.app` (bundle ID `com.vchun.Ice`, currently installed and possibly still running) should be removed to avoid confusion between two menu bar icons.
- **Known-fragile signing flow must survive**: per `docs/release-guide.md`, `xcodebuild archive` does not work on this Personal (free) Apple Developer team on Xcode 26.6 — regardless of automatic or manual signing style, it fails with "No signing certificate 'Mac Development' found". The verified working path is `xcodebuild build` (unsigned) + manual `codesign` inside-out (XPC services → Updater.app → Sparkle.framework → main app). Phase 5 must re-run this exact flow with new identifiers, not attempt archive again.

## Non-Goals

- Custom app icon design (separate follow-up; current `AppIcon.appiconset` assets are kept unchanged in this plan)
- Any tooling or process for pulling future updates from `jordanbaird/Ice` upstream
- Notarization or Mac App Store distribution
- Changing any actual behavior/feature of the app — this is a rename-only pass

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: Xcode project, target, scheme, and folder rename](./phase-01-start.md) | Pending |
| 2 | [Phase 2: Swift symbol and file rename](./phase-02-swift-symbol-and-file-rename.md) | Pending |
| 3 | [Phase 3: Display strings, bundle ID, and permissions](./phase-03-display-strings-bundle-id-and-permissions.md) | Pending |
| 4 | [Phase 4: README, LICENSE attribution, and GitHub repo rename](./phase-04-readme-license-attribution-and-github-repo-rename.md) | Pending |
| 5 | [Phase 5: Release flow update and final verification](./phase-05-release-flow-update-and-final-verification.md) | Pending |

Each phase ends with its own build/verify gate. A failure in one phase does not require redoing prior phases — only the failing phase is retried.

## Success Criteria

- [ ] `xcodebuild build -scheme Frost -configuration Release CODE_SIGNING_ALLOWED=NO` exits 0 after every phase that touches the project
- [ ] `grep -rniE '\bice\b' Frost/ --include="*.swift"` returns zero matches except intentional GPL-derived comments (if any remain, they must be justified, not accidental)
- [ ] App launches, Settings/About/menu bar context menu all display "Frost", bundle ID is `com.vchun.Frost`
- [ ] `LICENSE` contains both original Jordan Baird notices verbatim (required) and the user's own Frost fork copyright line beneath each
- [ ] GitHub repo lives at `bavanchun/Frost`; local `git remote -v` matches
- [ ] A full signed release (unsigned build + manual codesign inside-out) succeeds with the new bundle ID and produces a launchable `/Applications/Frost.app`
- [ ] Old `/Applications/Ice.app` removed; Accessibility + Screen Recording permissions re-granted to the new bundle ID

## Unresolved Questions

- None at plan time. Icon design is deferred to a separate follow-up per user's explicit scope decision.

## Validation Log

### Verification Results
- **Tier:** Full (5 phases)
- **Claims checked:** 19
- **Verified:** 17 | **Failed:** 2 | **Unverified:** 0

#### Failures
1. [Fact Checker] `LICENSE` — plan (Phase 4) says one `Ice Copyright (C) 2024 Jordan Baird` line exists; actual: **two** notices in the "How to Apply These Terms" section — line 635 (`Copyright (C) 2024 Jordan Baird`, the source-file header template) and line 655 (`Ice Copyright (C) 2024 Jordan Baird`, the interactive-mode startup notice template). Both are part of the same legally-required attribution block and must both be preserved verbatim.
2. [Fact Checker] Phase 2 (Swift symbol rename) and Phase 3 (display strings) together do not account for the **116 of 116** Swift files carrying a `//  Ice` header comment (Xcode's auto-generated file-header convention: blank `//`, `//  <Filename>.swift`, `//  Ice`, blank `//`). This is pure cosmetic metadata (not a compiled symbol, not user-visible at runtime) but it IS caught by the plan's own Phase 5 final consistency-sweep grep (`grep -rniE '\bice\b' ... --include="*.swift"`), which would fail as currently scoped unless these headers are also addressed.

### Session 1 — 2026-07-27
**Trigger:** Post-creation validation interview (Full tier, 5 phases) after verification pass surfaced 2 failures.
**Questions asked:** 3

#### Questions & Answers

1. **[Risk]** LICENSE actually has two "...Jordan Baird" lines (635, 655), not one as originally planned. Both belong to the same GPL-3.0-required "How to Apply These Terms" block. How to handle?
   - Options: Keep both verbatim, add Frost copyright next to both (Recommended) | Only add copyright next to the first line (635)
   - **Answer:** Keep both verbatim, add Frost copyright next to both
   - **Rationale:** Line 655 is the interactive-mode startup notice template — if Frost ever prints a similar startup notice, it needs its own attribution alongside the preserved original, not just the source-header template at 635.

2. **[Assumptions]** 116/116 Swift files carry a `//  Ice` Xcode-convention header comment, uncounted in Phase 2/3. Which phase absorbs this batch rename?
   - Options: Add to end of Phase 2 as a batch sed step (Recommended) | New standalone step in Phase 5 before final grep sweep
   - **Answer:** Add to end of Phase 2 as a batch sed step
   - **Rationale:** Phase 2 already touches every `.swift` file directly (renames + symbol substitution) — folding the header-comment sed into the same phase avoids a redundant full-tree pass later and keeps Phase 5 focused purely on release/verification.

3. **[Scope]** Phase 5 left version numbering open — ship as a build bump of 0.11.12, or a version bump marking the rebrand milestone?
   - Options: Bump to 1.0.0 (Recommended) | Keep 0.11.12, bump build number only
   - **Answer:** Bump to 1.0.0
   - **Rationale:** Marks Frost's first release as an independent product, decoupled from upstream Ice's version lineage.

#### Confirmed Decisions
- LICENSE: add `Frost (fork of Ice) Copyright (C) 2026 VChun` directly beneath BOTH line 635 and line 655 — never remove either original Jordan Baird line
- Header comments: batch `sed` rename of `//  Ice` → `//  Frost` folded into Phase 2, run across all 116 (soon-renamed) `.swift` files after symbol substitution, before Phase 2's build-verify gate
- Version: `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION` bumped to next integer (1118) in Phase 5, both Debug and Release configs

#### Action Items
- [ ] Phase 2: add file-header batch-rename step + update its Success Criteria to include header-comment check
- [ ] Phase 4: update LICENSE step to reference both line locations (635 and 655)
- [ ] Phase 5: resolve the "decide version" step to the confirmed 1.0.0 / build 1118, remove the open-ended framing

#### Impact on Phases
- Phase 2: new implementation step (file-header sed) + updated Success Criteria
- Phase 4: LICENSE step now explicit about two insertion points
- Phase 5: version step now a fixed instruction, not a decision point; example commands updated with concrete version/build numbers

### Whole-Plan Consistency Sweep
- Files reread: plan.md, phase-01-start.md, phase-02-swift-symbol-and-file-rename.md, phase-03-display-strings-bundle-id-and-permissions.md, phase-04-readme-license-attribution-and-github-repo-rename.md, phase-05-release-flow-update-and-final-verification.md
- Decision deltas checked: 3 (LICENSE two-line handling, header-comment batch rename ownership, fixed version 1.0.0/1118)
- Reconciled stale references: 7 (plan.md Constraints section + Success Criteria updated from one-notice to two-notice LICENSE framing; Phase 2 Success Criteria gains header-comment check; Phase 4 LICENSE implementation step + Related Code Files entry now cite both line numbers instead of "one line"; Phase 5 version step, final-grep-sweep comment, and all example commands — including the Architecture-section recap diagram — now use concrete `1.0.0`/`1118` instead of `<version>` placeholders)
- Unresolved contradictions: 0

Note: the plan's own `## Failures` / `## Confirmed Decisions` entries above (which describe the *original* one-notice/one-line state as evidence of what was wrong) are intentionally left as historical record, not stale — only the plan's forward-looking Constraints/Success-Criteria/implementation-step text was reconciled.

<!-- slug: rebrand-ice-vc-to-frost -->
