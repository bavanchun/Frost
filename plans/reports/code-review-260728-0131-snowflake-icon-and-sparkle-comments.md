# Code Review — snowflake icon and Sparkle plist comments

Branch: `feat/snowflake-icon-and-sparkle-comments` (3 commits, `main..HEAD`)
Plan: `plans/260728-0123-snowflake-icon-and-sparkle-plist-comments/`
Date: 2026-07-28

## Scope

- Files: 12 changed (2 Swift model/settings, 1 migration, 1 defaults, 2 call sites, 4 asset files, `Info.plist`, `CHANGELOG.md`)
- LOC: +53 / -37
- Focus: branch diff vs `main`, plus every reader of the touched contracts
- No test target exists in `Frost.xcodeproj`, so migration correctness was verified by a standalone Swift decode harness (below) and by call-chain tracing, not by repo tests.

## Overall assessment

Sound. No critical or high-severity defect. The migration is correctly sequenced, cannot strand a `.custom` icon, and the asset move preserves the exact artwork bytes. Two medium items are latent silent-failure risks in the new migration, not present-tense bugs. The plan's own success criteria contain two errors the implementation was right to ignore.

## The deliberate deviation (decode-failure detection instead of a `deprecatedRawValue` literal)

**Verdict: sound. Reasoning holds, verified empirically.**

Reproduced the old on-disk shape and decoded it against the new types:

```
old blob: {"hidden":{"catalog":{"_0":"IceCubeStroke"}},"name":"Ice Cube","visible":{"catalog":{"_0":"IceCubeFill"}}}
ice decodes as new?     false
dot decodes as new?     true
custom decodes as new?  true
```

`Name` is a synthesized `String`-raw-value `Codable` enum, so an unknown raw value throws `DecodingError.dataCorrupted`. Removing the `iceCube` case therefore makes the old blob undecodable, and `(try? decode) == nil` is a faithful proxy for "this blob names the retired icon". Every other icon and a fresh install (`Defaults.data(forKey: .frostIcon) == nil`) take the early-return path untouched — matching the plan's stated intent and phase-1 functional requirements 3 and 4.

Cost of the deviation, accepted by phase-01 step 5 explicitly: the migration is name-blind, so a blob that is undecodable for *any* other reason is also rewritten to Snowflake instead of falling back to Dot. Since such a blob was being discarded anyway, no user data is lost that would otherwise have survived. See Medium #2 — the missing log is what makes this indistinguishable in the field.

## Critical

None.

## High

None.

## Medium

### M1 — `first(where:)` lookup can silently no-op and permanently mark the migration done
`Frost/Utilities/MigrationManager.swift:335`

```swift
let snowflake = ControlItemImageSet.userSelectableFrostIcons.first(where: { $0.name == .snowflake })
```

Failure scenario: a later change renames, reorders out, or removes the `.snowflake` entry from `userSelectableFrostIcons` (a UI-facing collection, edited for UI reasons). The `guard` then falls through to `return` with no error, `migrate1_1_0` completes "successfully", `hasMigrated1_1_0` is set to `true`, and the still-undecodable blob stays on disk — the exact silent revert-to-Dot this phase exists to prevent, now unrepeatable because the flag blocks a retry. The compiler cannot catch it; the collection is `[ControlItemImageSet]`, not keyed by name.

Change: make the target total at compile time, e.g. add `static let snowflakeFrostIcon` alongside `defaultFrostIcon` in `ControlItemImageSet.swift` and have both `userSelectableFrostIcons` and the migration reference it, or construct the image set literally inside the migration. Either removes the optional and the silent branch.

### M2 — the migration rewrites user data with no log at the point of rewrite
`Frost/Utilities/MigrationManager.swift:331-340`

The only log is the generic `"Successfully migrated to 1.1.0 settings"` (line 320), emitted equally when nothing happened. Because the detection is decode-failure-based, there is no way to tell from a user's log whether their icon was migrated from Ice Cube, or their blob was corrupt and got replaced, or the key was absent. That is the diagnostic that matters if a field report says "my icon changed".

Change: log at the write, e.g. `Logger.migration.info("Replaced an undecodable Frost icon with the snowflake image set")` immediately before or after the `Defaults.set` on line 339.

## Low

### L1 — "retry on next launch" does not actually hold
`Frost/Settings/SettingsManagers/GeneralSettingsManager.swift:105-114` and `:127-143`

Phase-01's risk section reasons that setting `hasMigrated1_1_0` only after a successful write leaves the migration retryable. It does not. If `encoder.encode` threw, the flag stays false, but *this* launch still runs `loadInitialState()`, fails the decode, leaves `frostIcon` at `.dot`, and then `configureCancellables()`'s `$frostIcon` sink fires immediately with that default and writes Dot back to `.frostIcon` (line 137-138). The next launch's retry sees a perfectly decodable Dot blob and early-returns. Encoding a small static `Codable` struct cannot realistically throw, so this is theoretical — but the flag ordering is buying less safety than the plan claims. No change required; recorded so the reasoning is not reused as-is in a future migration where the encode input is user-supplied.

### L2 — `CHANGELOG.md` "Removed" entry describes an internal artifact
`CHANGELOG.md:18-20`. "The Ice Cube image assets" are never user-visible; the Changed entry above it already states the whole user-facing effect. Phase-03 step 3 asked for "user-facing effect first, no internal symbol names". Consider dropping the Removed section or rewording to the visible consequence (the old icon is no longer selectable).

### L3 — migration key name presumes the release number
`Frost/Utilities/Defaults.swift:185`. `hasMigrated1_1_0` ships before `MARKETING_VERSION` is bumped; if the tag lands as anything other than 1.1.0 the key is misleading forever (it cannot be renamed without re-running the migration). This matches the existing convention and the plan approved 1.1.0 — noted only so the release PR treats the number as already committed.

## Plan defects found (implementation was right to diverge)

1. Phase-01 non-functional requirement "No reference to an asset catalog image remains in `ControlItemImageSet`" and success criterion "`ControlItemImageSet.swift` contains no `.catalog(` call" are **unmeetable and contradict the plan's own non-goals** — `Dot` (`ControlItemImageSet.swift:65-66`) and `Ellipsis` (`:70-71`) still use `.catalog`, and changing them is an explicit non-goal. The criteria were meant to say "no *catalog-backed Ice Cube* reference remains". Unmet, correctly.
2. Phase-01 step 6 (keep `"Ice Cube"` in a `deprecatedRawValue` helper) contradicts the plan's `ice ?cube`-returns-nothing criterion. Resolved as described above.
3. Plan constraint says `snowflake.circle` / `snowflake.circle.fill` "date from SF Symbols 1". Actual: SF Symbols 2021 release, macOS 12.0 (from `/System/Library/CoreServices/CoreGlyphs.bundle/.../name_availability.plist`). Still safely below the macOS 14 target — conclusion unchanged, provenance wrong.

## Verification performed

**(a) Statically checkable acceptance criteria**

| Criterion | Result |
|---|---|
| `grep -rni "ice ?cube\|icecube" Frost/` | zero hits |
| Repo-wide `ice ?cube` outside `plans/` | zero hits |
| `ControlItemImages/` contains only `Dot/` and `Ellipsis/` | pass |
| `FrostMarkStroke.imageset` at catalog root, `filename` updated, `template-rendering-intent: template`, 2x slot only | pass |
| PNG artwork preserved | pass — blob `47d8709f…` identical to `IceCubeStroke.png` on `main`; `IceCubeFill.png` (`81c566c3…`) deleted |
| PNG move recorded as a rename | pass (`git diff -M` pairs it; the `Contents.json` pairing is cosmetic noise from similarity detection) |
| `plutil -lint Frost/Info.plist` | OK |
| No Sparkle key value changed | pass — diff is three comment lines only |
| `CHANGELOG.md` `[Unreleased]` covers rename + automatic migration | pass |
| Migration follows existing shape, registered in `migrateAll` | pass (`MigrationManager.swift:26`) |
| No stale `IceCube`/`FrostMark` reference in `project.pbxproj` | pass (none; imagesets are not individually referenced) |
| SwiftLint | binary not installed locally; `line_length` is disabled in `.swiftlint.yml`, no new line exceeds 120 chars anyway |
| `ControlItemImageSet.swift` has no `.catalog(` | **not met** — see Plan defects #1 |

Unverifiable statically, still open: the two manual upgrade checks (select Ice Cube on the old build → upgrade → icon is Snowflake; select Door → upgrade → Door untouched) and the visual check of Settings → About / search panel.

**(b) Business logic at the touchpoints** — traced every reader of `ControlItemImageSet.Name` and the `FrostIcon` blob:

- `GeneralSettingsManager.swift:105-114` — sole decoder. On failure it logs and leaves `frostIcon` at `.defaultFrostIcon`; after migration no undecodable blob reaches it.
- `GeneralSettingsManager.swift:111-113` / `:133-135`, `GeneralSettingsPane.swift:98,169`, `ControlItem.swift:354` — all `.custom` readers. A `.custom` blob decodes successfully (proven above), so the migration's second guard clause returns early and never touches it. `lastCustomFrostIcon` is derived from `frostIcon` at load time and is not separately persisted, so nothing is stranded.
- `GeneralSettingsPane.swift:123` (`userSelectableFrostIcons` in the picker), `:149`, `:92-109` (`menuItem(for:)` renders `imageSet.hidden`) — Snowflake's `hidden` is the filled variant, matching Dot/Ellipsis/Sunglasses. No inversion.
- `ControlItem.swift:347-352` — reads `icon.hidden` / `icon.visible` for the status item; `.symbol` path sets `isTemplate = true`, same as the four existing symbol-backed icons.
- `Frost/Utilities/Defaults.swift:144` is the only `.frostIcon` key; nothing else in the app reads or writes it.

**(c) Migration correctness**

- Flag set only after a successful write: yes. `performAll` (`:348-361`) collects and rethrows, so a throwing `migrateFrostIcon1_1_0` skips `Defaults.set(true, forKey: .hasMigrated1_1_0)` at `:319`. Mirrors `migrate0_11_10`'s sequencing (`:263-270`).
- Runs before the decode: confirmed against the real call chain — `FrostApp.swift:15` (`App.init`) → `AppDelegate.swift:27,46,54` (`applicationDidFinishLaunching` + 0.1 s) → `AppState.swift:187` → `SettingsManager` → `GeneralSettingsManager.swift:79,105`. `AppState.init` does not call `performSetup`, and `performSetup` is additionally skipped when permissions are missing — both fail in the safe direction. Same main thread throughout; no race.
- Throwing flavor is correct: no user-facing alert case, so `MigrationResult` would be dead weight. Placement in the throwing block list (`:23-27`) matches `migrate0_8_0` / `migrate0_10_0`. Blocks in `performAll` are independent (`Result(catching:)` per block), so a failure in `migrate0_8_0` does not skip `migrate1_1_0`.

**(d) Public contracts** — `ControlItemImageSet` and its `Name` are app-internal types with no library consumers; the only external contract is the `FrostIcon` UserDefaults blob, which the migration covers. `Defaults.Key.hasMigrated1_1_0` is purely additive. No other breaking change. (Downgrading to 1.0.1 after upgrading leaves a `"Snowflake"` blob the old build cannot decode → it falls back to Dot. Downgrade is not a supported path; noted for completeness.)

**(e) Conventions** — `migrate1_1_0` is a structural copy of `migrate0_8_0` (`:59-70`): guard on the flag, `performAll` over sub-blocks, set flag, info log. Doc comment wording is copied verbatim and is still accurate. Defaults key entry matches the four siblings. Commits are one per phase, Conventional Commits, bodies explain intent and risk rather than restating the diff; the `Claude-Session` trailer matches every existing commit on `main`.

**(f) Silent-failure sweep**

- Symbol names: `snowflake.circle` and `snowflake.circle.fill` both exist since macOS 12.0 per `name_availability.plist`, so `NSImage(systemSymbolName:)` will not return nil on the macOS 14 floor. This was the highest-value check because a typo here yields a blank menu bar icon with no log (`ControlItemImage.swift:31-35`).
- Catalog rename: `Contents.json` `filename` updated to match the renamed PNG, so no empty imageset. The generated symbol `.frostMarkStroke` derives from the directory name `FrostMarkStroke.imageset`, which matches; both call sites (`SettingsView.swift:105`, `MenuBarSearchPanel.swift:360`) use generated symbols, so a mismatch would have been a compile error, and the caller reports BUILD SUCCEEDED.
- Missing-catalog risk from the phase ordering is genuinely designed out: after migration no persisted blob names a catalog image that this build does not ship.
- Remaining silent paths are M1 and M2 above.

Also checked and clean: no PII/secret exposure (`SUPublicEDKey` is the public half by definition, `SUFeedURL` is HTTPS), no `any`/`try!` widening, no lint suppression, no swallowed error beyond the intentional `try?`, no scope drift (every changed file is named by the plan), no new abstraction or parallel helper.

## Recommended actions

1. M1 — replace the `first(where:)` lookup with a compile-time-total reference to the snowflake image set (`MigrationManager.swift:335`).
2. M2 — log at the point of rewrite (`MigrationManager.swift:339`).
3. Run the two manual upgrade checks before merge; they are the only thing that can confirm the Ice Cube → Snowflake path end to end, and the repo has no test target to stand in.
4. Optional: reword or drop the `CHANGELOG.md` Removed entry (L2).
5. Fix the two wrong success criteria in `phase-01` (`.catalog(` and the `deprecatedRawValue` step) so the plan record matches what shipped. Plan mutation belongs to the lead/planner, not this review.

## Metrics

- Type coverage: n/a (Swift, fully typed); no `Any`, force-unwrap, or `try!` introduced
- Test coverage: 0 — no test target in `Frost.xcodeproj`; migration verified via a standalone decode harness
- Linting: SwiftLint not installed locally; no line exceeds 120 chars in the changed files, and `line_length` is disabled in `.swiftlint.yml`
- Build: BUILD SUCCEEDED (per caller), no new warnings

## Unresolved questions

1. Should a blob that fails to decode for a reason *other* than the retired name land on Snowflake (current behavior, plan-sanctioned) or on the app default Dot? The current choice silently promotes corruption to a specific non-default icon.
2. `hasMigrated1_1_0` hardcodes the release number before the tag is cut. Confirm 1.1.0 is final; the key cannot be renamed later without re-running the migration.
3. Is downgrade to 1.0.1 after this ships a scenario worth caring about? It leaves the user on Dot with their Snowflake blob undecodable and the migration flag already set.
