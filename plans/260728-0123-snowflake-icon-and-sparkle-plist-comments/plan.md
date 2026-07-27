---
title: "Snowflake icon and Sparkle plist comments"
description: "Replace the Ice-branded 'Ice Cube' menu bar icon option with a Snowflake SF Symbol, migrate the persisted icon setting, retire the IceCube asset, and document the three Sparkle keys in Info.plist."
status: complete
priority: P2
effort: "3h"
tags: [rebrand, icons, migration, sparkle]
created: 2026-07-28
---

# Snowflake icon and Sparkle plist comments

## Overview

Two leftovers from the Ice → Frost rebrand, shipped together as one PR because both are small and neither touches the other's files.

1. **`"Ice Cube"` still shows in Settings → General → Frost icon.** The string is `ControlItemImageSet.Name.iceCube`'s `rawValue` (`ControlItemImageSet.swift:16`), which is simultaneously the picker label (`GeneralSettingsPane.swift:94`) and the persisted key inside the `FrostIcon` defaults blob. It is replaced by a **Snowflake** entry backed by SF Symbols, with a migration so anyone who selected Ice Cube lands on Snowflake instead of silently resetting to Dot.
2. **`SUEnableAutomaticChecks` has no explanation in `Frost/Info.plist`.** The reason lives in `CHANGELOG.md` and `docs/UPSTREAM.md` but not at the point of use. All three Sparkle keys get a one-line comment.

Decisions and the evidence behind them are recorded in
[`plans/reports/brainstorm-260728-0107-icecube-label-and-sparkle-comment.md`](../reports/brainstorm-260728-0107-icecube-label-and-sparkle-comment.md)
(read both addenda). This plan does not re-open them.

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Picker offers **Snowflake** (SF Symbol) instead of Ice Cube; no `"Ice Cube"` string anywhere in the app | P1 |
| 2 | Existing users who selected Ice Cube are migrated to Snowflake, not reset to Dot | P1 |
| 3 | `IceCube` asset folder gone; the app-mark image renamed to `FrostMarkStroke` | P2 |
| 4 | All three Sparkle keys in `Frost/Info.plist` carry a one-line rationale comment | P3 |

## Constraints

- **`rawValue` is persisted data, not just a label.** `GeneralSettingsManager.swift:105-114` decodes the `FrostIcon` blob; on decode failure it only logs and leaves `frostIcon` at `.defaultFrostIcon` (`.dot`). Changing `rawValue` without a migration silently downgrades the user's choice.
- **Missing catalog assets fail silently.** `ControlItemImage.nsImage(for:)`'s `.catalog` case returns `nil` from `NSImage(named:)` — no throw, no log, blank menu bar icon. This is why the persisted blob must stop referencing catalog names before the asset is touched, and why phase order is not negotiable.
- **Deployment target is macOS 14.** Only SF Symbols available on macOS 14 may be used. `snowflake.circle` / `snowflake.circle.fill` were verified present in `/System/Library/CoreServices/CoreGlyphs.bundle` and date from SF Symbols 1.
- **Migration ordering is already safe — verified, do not re-engineer.** `FrostApp.init()` calls `MigrationManager.migrateAll` (`FrostApp.swift:15`); `GeneralSettingsManager.loadInitialState()` is reached only via `AppDelegate.applicationDidFinishLaunching` → `DispatchQueue.main.asyncAfter(+0.1s)` → `appState.performSetup()` (`AppDelegate.swift:27,46,54` → `AppState.swift:187` → `SettingsManager.swift:34` → `GeneralSettingsManager.swift:79`). Migration always completes first.
- **Version bump belongs to the release PR, not this one.** `docs/DEVELOPMENT_WORKFLOW.md` §23 puts "version and changelog update" in a separate release preparation PR. This PR edits `CHANGELOG.md` under `[Unreleased]` only and leaves `MARKETING_VERSION = 1.0.1` alone.
- **Migration symbols are named for the release they ship in** (`migrate0_11_10`, `hasMigrated0_11_10`). Target release **1.1.0** is approved, so this PR writes `migrate1_1_0` / `hasMigrated1_1_0` before `MARKETING_VERSION` is bumped elsewhere. That is the existing convention, not an inconsistency.

## Non-Goals

- **New AppIcon artwork.** `AppIcon.appiconset` is still Ice's blue cube; replacing it is a separate plan (see Follow-up). This plan renames the app-mark asset but keeps its current art.
- New artwork for `FrostMarkStroke` — the rename lands now, the redraw lands with the AppIcon plan.
- Changing any other `ControlItemImageSet.Name` case, or the picker's structure.
- Bumping `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, or cutting a tag.

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: Snowflake picker entry and migration](./phase-01-snowflake-picker-entry-and-migration.md) | Complete |
| 2 | [Phase 2: Retire the Ice Cube asset](./phase-02-retire-the-ice-cube-asset.md) | Complete |
| 3 | [Phase 3: Sparkle plist comments and changelog](./phase-03-sparkle-plist-comments-and-changelog.md) | Complete |

Phase 2 depends on phase 1: `IceCubeFill` only becomes an orphan once the picker stops referencing it, and the persisted blob must be free of catalog names before the asset moves. Phase 3 is independent and may land in any order.

## Branch and PR

Single branch, single PR into `main` per `docs/DEVELOPMENT_WORKFLOW.md`:

```
feat/snowflake-icon-and-sparkle-comments
```

Conventional Commits, one commit per phase.

## Success Criteria

- [ ] Searching `Frost/` for `ice ?cube` (case-insensitive) returns nothing
- [ ] Settings → General → Frost icon lists **Snowflake**; selecting it shows the snowflake in the menu bar in both hidden and visible states
- [ ] Upgrade check by hand: install current build → select Ice Cube → install new build → icon is Snowflake, **not** Dot
- [ ] `Frost/Assets.xcassets/ControlItemImages/IceCube/` no longer exists; `FrostMarkStroke.imageset` renders in Settings → About and in the search panel's settings button
- [ ] All three Sparkle keys in `Frost/Info.plist` have a comment; app still builds and the plist parses (`plutil -lint`)
- [ ] `CHANGELOG.md` `[Unreleased]` describes the icon change and its migration
- [ ] Clean build with no new warnings

## Risks

**Versioning policy tension — flag for the maintainer at tag time.** `docs/release-guide.md` lists "schema changes needing migration" and "removed features" under MAJOR, and this change has a migration and drops an icon option. Read the other way, the migration is automatic and invisible, nothing becomes incompatible, and Ice Cube is replaced 1:1 by Snowflake rather than removed — which lands on MINOR, matching the guide's own "prefer MINOR over MAJOR when unclear" tiebreak. **1.1.0 is approved and this plan proceeds on it**; noted here so the number is a deliberate call at tag time and not a surprise.

**Silent-failure asset risk is designed out, not mitigated.** Phase 1 converts the picker entry from `.catalog` to `.symbol`, so after migration no persisted blob points at an asset catalog name. The phase-2 rename then cannot produce a blank icon. Running phase 2 first would reintroduce exactly the failure mode this ordering avoids.

**Generated asset symbols make rename errors cheap.** `Image(.iceCubeStroke)` and `.assetCatalog(.iceCubeStroke)` use Xcode-generated symbols, so a missed call site is a compile error, not a runtime bug.

## Follow-up

A separate plan replaces `AppIcon.appiconset` (still Ice's blue cube) and redraws `FrostMarkStroke` to match. It depends on this plan landing first so the asset already carries its final name. Until then the app-mark keeps Ice's artwork under a Frost name — a mismatch that already exists today and that this plan does not worsen.

<!-- slug: snowflake-icon-and-sparkle-plist-comments -->
