---
phase: 1
title: "Snowflake picker entry and migration"
status: complete
priority: P1
effort: "2h"
dependencies: []
---

# Phase 1: Snowflake picker entry and migration

## Overview

Replace the `iceCube` case in `ControlItemImageSet.Name` with `snowflake`, backed by SF Symbols instead of the asset catalog, and add a migration so an existing `FrostIcon` blob holding `"Ice Cube"` becomes Snowflake rather than silently falling back to Dot.

## Requirements

**Functional**

- Picker shows **Snowflake** in place of Ice Cube; every other entry is untouched.
- Hidden state renders `snowflake.circle.fill`, visible state renders `snowflake.circle`.
- A persisted blob naming the old icon resolves to Snowflake after upgrade.
- A persisted blob naming any other icon, or absent entirely, is unaffected.

**Non-functional**

- No reference to an asset catalog image remains in `ControlItemImageSet`.
- Migration follows the existing `MigrationManager` shape: version-named private method, `hasMigrated…` guard, registered in `migrateAll`.

## Architecture

`ControlItemImageSet` is `Codable` and is stored whole as JSON under the `FrostIcon` defaults key (`Defaults.swift:144`). The blob therefore carries three things that change in this phase: `name`'s `rawValue`, and both `hidden`/`visible` `ControlItemImage` cases.

Because the image cases change kind (`.catalog` → `.symbol`) and not merely their payload, the migration **replaces the whole image set** rather than patching fields. Patching each field would be longer and easier to get wrong for no benefit.

Ordering is already correct and needs no new machinery:

```
FrostApp.init()
  └─ MigrationManager.migrateAll(appState:)            FrostApp.swift:15

AppDelegate.applicationDidFinishLaunching              AppDelegate.swift:27
  └─ DispatchQueue.main.asyncAfter(+0.1s)              AppDelegate.swift:46
       └─ appState.performSetup()                      AppDelegate.swift:54
            └─ settingsManager.performSetup()          AppState.swift:187
                 └─ generalSettingsManager.performSetup()   SettingsManager.swift:34
                      └─ loadInitialState()            GeneralSettingsManager.swift:79
                           └─ decode FrostIcon blob    GeneralSettingsManager.swift:105-114
```

`App.init()` runs before `applicationDidFinishLaunching`, and setup is deferred a further 0.1 s, so the migration always lands before the decode. It also runs unconditionally, whereas `performSetup()` is skipped when permissions are missing — the safe direction.

The migration is registered in the **throwing** block list (`MigrationManager.swift:23-26`), not the `MigrationResult` list, because it has no user-facing alert case.

Legacy `rawValue` strings elsewhere in this file are kept in `private extension … { var deprecatedRawValue: String }` helpers (`MigrationManager.swift:393-400`). Follow that placement so `"Ice Cube"` lives in the migration layer rather than lingering in the live model.

## Related Code Files

- Modify: `Frost/MenuBar/ControlItem/ControlItemImageSet.swift` — `Name.iceCube` → `Name.snowflake`; image set entry switches to `.symbol`
- Modify: `Frost/Utilities/MigrationManager.swift` — register and implement `migrate1_1_0`
- Modify: `Frost/Utilities/Defaults.swift` — add `hasMigrated1_1_0` case alongside the existing keys at lines 181-184

## Implementation Steps

1. In `ControlItemImageSet.swift`, rename the enum case and its `rawValue`:

   ```swift
   case snowflake = "Snowflake"
   ```

   Keep the case in its current alphabetical slot among the others.

2. In the same file, update the `userSelectableFrostIcons` entry to use SF Symbols:

   ```swift
   ControlItemImageSet(
       name: .snowflake,
       hidden: .symbol("snowflake.circle.fill"),
       visible: .symbol("snowflake.circle")
   ),
   ```

   Note the orientation: `hidden` is the filled variant, `visible` is the outline. The old Ice Cube entry had these inverted relative to every sibling (`Dot` is `DotFill`/`DotStroke`, `Sunglasses` is `sunglasses.fill`/`sunglasses`); this corrects it.

3. Add `case hasMigrated1_1_0 = "hasMigrated1_1_0"` to the defaults key enum in `Defaults.swift`, following the existing four entries verbatim in style.

4. In `MigrationManager.swift`, add `manager.migrate1_1_0` to the `performAll(blocks:)` array alongside `migrate0_8_0` and `migrate0_10_0`.

5. Implement the migration in its own `// MARK: - Migrate 1.1.0` extension, mirroring `migrate0_8_0`'s guard-and-set shape:

   - Return early when `Defaults.bool(forKey: .hasMigrated1_1_0)` is already true.
   - Read `Defaults.data(forKey: .frostIcon)`; when absent, set the flag and return — nothing to migrate.
   - Decode the blob. If it decodes and its `name` is not the legacy icon, set the flag and return unchanged.
   - When the blob names the legacy icon **or fails to decode**, encode the Snowflake image set from `ControlItemImageSet.userSelectableFrostIcons` and write it back under `.frostIcon`.
   - Set `hasMigrated1_1_0` after the write succeeds. Decode failure is caught and handled as above, not rethrown; only an **encode** failure propagates, where `migrateAll`'s existing `logError` picks it up.

   Treating a decode failure as "migrate to Snowflake" is deliberate: an old blob whose `rawValue` no longer maps is exactly the case this phase exists to repair, and a corrupt blob was going to be discarded anyway.

6. Put the literal `"Ice Cube"` only inside the migration, in a `deprecatedRawValue`-style helper matching `MigrationManager.swift:393-400`. It must not remain in `ControlItemImageSet.swift`.

## Implementation Note — deviation from step 6

Step 6 required the `"Ice Cube"` literal to survive inside the migration as a
`deprecatedRawValue` helper. That contradicts this plan's own success criterion
that `Frost/` contain no `ice ?cube` string (plan.md, phase 2 step 7), since
`MigrationManager.swift` is under `Frost/`.

Resolved by dropping the literal. Removing the `iceCube` case makes a blob that
names it undecodable, so decode failure *is* the detection signal and the string
is not needed. Behavior is identical to what step 5 specified — step 5 already
routed decode failures to Snowflake.

Verified empirically rather than by reading: a script mirroring the real `Codable`
shapes encoded blobs with the old enum and decoded them with the new one. Saved
ice cube fails to decode (migrates); Door, Dot, and `.custom` all decode and are
left alone; the Snowflake replacement round-trips; a truncated blob fails to
decode and migrates. Six of six as intended.

## Corrections to this phase document

**The `.catalog(` success criterion below is unmeetable and stays unmet.** Dot and
Ellipsis still use `.catalog` and are explicit non-goals, so the file will always
contain `.catalog(` calls. The criterion should have read "no `.catalog(` call for
the snowflake entry", which is met.

**The flag-ordering rationale in Risk Assessment is wrong**, though the ordering it
prescribes is right for a different reason. Setting the flag only after the write
does *not* buy a retry on the next launch: if the encode threw, this launch leaves
`frostIcon` at Dot, and `GeneralSettingsManager`'s `$frostIcon` sink writes Dot
straight back to defaults, so the next launch finds a valid blob and returns early
either way. Encoding a static struct cannot actually throw, so this is theoretical —
but the reasoning should not be reused in a future migration.

## Success Criteria

- [ ] Project builds clean, no new warnings
- [ ] Settings → General → Frost icon lists **Snowflake**; no "Ice Cube" entry
- [ ] Selecting Snowflake shows the filled snowflake when the section is hidden and the outline when visible
- [ ] Fresh install (no `FrostIcon` key) still defaults to Dot and logs no migration error
- [ ] Manual upgrade check: run the current build, select Ice Cube, quit, run the new build → icon is Snowflake, **not** Dot
- [ ] Selecting a different icon (e.g. Door) before upgrade leaves that icon untouched after upgrade
- [ ] `ControlItemImageSet.swift` contains no `.catalog(` call and no `"Ice Cube"` string

## Risk Assessment

**Migration runs but the user had a custom image.** `.custom` blobs carry `.data(...)`, decode fine, and have a name that is not the legacy icon — the early-return path leaves them alone. Verify by selecting a custom image before upgrading.

**`hasMigrated1_1_0` set before the write completes** would strand the blob — the flag says "done" while the old value is still on disk, and the guard prevents a retry. Set it only after the successful write. `migrate0_11_10` demonstrates this ordering (`MigrationManager.swift:262-266`); copy its sequencing, not its `MigrationResult` return type, since this migration uses the throwing flavor.

**Symbol name typo** yields a nil image and a blank menu bar icon with no log — same silent class as the catalog case. The manual check in Success Criteria is what catches it; do not rely on the build.
