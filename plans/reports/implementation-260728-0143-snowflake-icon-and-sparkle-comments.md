# Implementation report — Snowflake icon and Sparkle plist comments

Plan: [`plans/260728-0123-snowflake-icon-and-sparkle-plist-comments/plan.md`](../260728-0123-snowflake-icon-and-sparkle-plist-comments/plan.md)
Branch: `feat/snowflake-icon-and-sparkle-comments` — 4 commits, not yet pushed
Date: 2026-07-28

## Result

All three phases implemented. Build clean, no new warnings. Code review returned
no critical or high findings; both medium findings fixed before this report.

| Phase | Commit | State |
|---|---|---|
| 1 — Snowflake picker entry and migration | `a293761` | Complete |
| 2 — Retire the Ice Cube asset | `8d9368a` | Complete |
| 3 — Sparkle plist comments and changelog | `ffc7944` | Complete |
| Review fixes | `650cdde` | Complete |

## What changed

- `ControlItemImageSet.Name.iceCube` → `.snowflake`; image set moved from asset
  catalog to SF Symbols (`snowflake.circle.fill` hidden, `snowflake.circle` visible).
  Hoisted to `static let snowflakeFrostIcon`, referenced by both the picker array
  and the migration.
- `migrate1_1_0` + `hasMigrated1_1_0`. Detects the old icon by decode failure,
  rewrites the blob to Snowflake, logs the rewrite.
- `IceCubeStroke.imageset` → `FrostMarkStroke.imageset` at catalog root;
  `IceCubeFill` deleted; two call sites updated.
- Three rationale comments on the Sparkle keys in `Frost/Info.plist`, no value changed.
- `CHANGELOG.md` `[Unreleased]`; one new divergence bullet in `docs/UPSTREAM.md`.

## Deviation from the plan

Phase 1 step 6 required the `"Ice Cube"` literal to survive in a `deprecatedRawValue`
helper inside `MigrationManager.swift`. That contradicts the plan's own criterion that
`Frost/` contain no `ice ?cube` string — `MigrationManager.swift` is under `Frost/`.

Resolved by dropping the literal. Removing the enum case makes a blob naming it
undecodable, so decode failure *is* the detection signal. Behavior matches step 5,
which already routed decode failures to Snowflake. Reviewer independently reproduced
the on-disk shape and confirmed the proxy is faithful.

## Verification

Empirical, via a standalone Swift harness mirroring the real `Codable` shapes —
encode with the old enum, decode with the new. Repo has **no test target**, so this
is a throwaway check, not a committed test.

| Check | Result |
|---|---|
| Saved ice cube blob | fails to decode → migrates to Snowflake |
| Saved Door / Dot / `.custom` | decode → left alone |
| Snowflake replacement | round-trips |
| Truncated blob | fails to decode → migrates |
| Build (Debug, unsigned) | BUILD SUCCEEDED, no new warnings |
| `grep -rin "ice ?cube" Frost/` | zero hits |
| `plutil -lint Frost/Info.plist` | OK |
| `Info.plist` diff | 3 comment lines only |
| `ControlItemImages/` | only `Dot/`, `Ellipsis/` |
| `snowflake.circle{,.fill}` availability | macOS 12.0, target is 14 |

Migration ordering re-verified against the real call chain
(`FrostApp.swift:15` → `AppDelegate.swift:27,46,54` → `AppState.swift:187` →
`GeneralSettingsManager.swift:79,105`): migration always precedes the decode, same
thread, no race.

## Review findings and disposition

| ID | Finding | Disposition |
|---|---|---|
| M1 | Optional lookup into `userSelectableFrostIcons` could silently no-op while marking the migration done, locking out a retry | Fixed — `static let snowflakeFrostIcon`, no optional |
| M2 | User data rewritten with no log at the write | Fixed — `Logger.migration.info` at the rewrite |
| L1 | Phase-01's flag-ordering rationale is wrong (ordering itself is fine) | Recorded as a correction in the phase file |
| L2 | CHANGELOG "Removed" entry names an internal artifact | Kept — phase 3 step 3 prescribed this wording verbatim; not silently reversed |
| L3 | `hasMigrated1_1_0` hardcodes an unreleased version | Kept — plan settled this as the existing convention |

Two plan criteria are themselves wrong; both recorded in the phase file:

1. "`ControlItemImageSet.swift` contains no `.catalog(` call" — unmeetable. Dot and
   Ellipsis still use `.catalog` and are explicit non-goals. **Unmet by design.**
2. Phase 1 step 6 vs. the `ice ?cube` criterion — the contradiction above.

Minor: the plan calls the symbols "SF Symbols 1"; `CoreGlyphs` `name_availability.plist`
puts them at 2021 / macOS 12.0. Conclusion unchanged, provenance wrong.

## Not done

Every remaining criterion needs a running app with Accessibility permissions:

- Picker lists **Snowflake**; filled variant when hidden, outline when visible
- Upgrade check by hand: current build → select Ice Cube → new build → expect
  Snowflake, not Dot
- About tab and search panel settings button still render the mark
- Sparkle still finds the feed, no new updater errors

Static evidence points the right way — the picker label is
`imageSet.name.rawValue` (`GeneralSettingsPane.swift:93`), the generated
`.frostMarkStroke` symbol compiles, and the PNG blob is byte-identical to the old
one — but none of it has been seen rendering.

`MARKETING_VERSION` untouched at 1.0.1, no tag cut, nothing pushed.

## Unresolved questions

1. Should a corrupt blob that never named Ice Cube land on Snowflake, or on the Dot
   default? Current behavior sends both to Snowflake, per the plan.
2. Is 1.1.0 final? `hasMigrated1_1_0` cannot be renamed after release.
3. Is downgrade-after-upgrade in scope? An older build reading a Snowflake blob
   fails to decode and falls back to Dot.
4. Should the PR wait on the manual upgrade check, or open now with it listed as
   an outstanding reviewer step?
