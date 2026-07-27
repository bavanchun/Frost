---
phase: 1
title: "Xcode project, target, scheme, and folder rename"
status: completed
priority: P1
effort: "2h"
dependencies: []
---

# Phase 1: Xcode project, target, scheme, and folder rename

## Overview

Rename the structural containers first — Xcode project file, target, scheme, and the top-level source folder — and verify the project still builds before touching a single Swift symbol. This isolates project-file breakage (the highest-risk step) from symbol-rename noise.

## Requirements

- Functional: `Frost.xcodeproj` opens and builds; `Frost.app` is produced by `xcodebuild build`
- Non-functional: git history for every moved file is preserved (`git mv`, not delete+recreate)

## Architecture

`Ice.xcodeproj/project.pbxproj` uses a `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ "synced folder" group) for the source tree:

```
71BDFBE12C978E2A00EF145F /* Ice */ = {isa = PBXFileSystemSynchronizedRootGroup; ... path = Ice; sourceTree = "<group>"; };
```

This means the group's `path` must match the actual folder name on disk — unlike classic PBXGroup, there is no separate list of file references to update; Xcode discovers files by scanning the folder. Renaming `Ice/` → `Frost/` on disk and updating `path = Ice;` → `path = Frost;` must happen atomically in the same step.

Separately, the project also has "Ice" baked into: the `.xcodeproj` bundle name itself, the `PBXNativeTarget` name (`name = Ice;`), the two `XCConfigurationList` comments (cosmetic, but grep-visible), and the shared scheme file (`Ice.xcscheme`, referencing `BuildableName = "Ice.app"` and `BlueprintName = "Ice"` three times each for build/test/launch/profile/archive actions).

## Related Code Files

- Rename: `Ice.xcodeproj/` → `Frost.xcodeproj/` (directory rename, `git mv`)
- Rename: `Ice.xcodeproj/xcshareddata/xcschemes/Ice.xcscheme` → `Frost.xcscheme`
- Rename: `Ice/` → `Frost/` (top-level source folder, `git mv`)
- Modify: `Frost.xcodeproj/project.pbxproj` — `path = Ice;` → `path = Frost;`, `name = Ice;` → `name = Frost;`, cosmetic comment strings `"Ice"` → `"Frost"`
- Modify: `Frost.xcodeproj/xcshareddata/xcschemes/Frost.xcscheme` — `BuildableName = "Ice.app"` → `"Frost.app"` (3×), `BlueprintName = "Ice"` → `"Frost"` (3×)
- No change needed: `Ice.xcodeproj/project.xcworkspace/contents.xcworkspacedata` — uses `location = "self:"`, a relative self-reference, not a hardcoded name

## Implementation Steps

1. `git status` — confirm clean working tree before a bulk rename (stash/commit anything uncommitted first).
2. `git mv Ice.xcodeproj Frost.xcodeproj`
3. `git mv Frost.xcodeproj/xcshareddata/xcschemes/Ice.xcscheme Frost.xcodeproj/xcshareddata/xcschemes/Frost.xcscheme`
4. `git mv Ice Frost` (top-level source folder — this moves all 116 Swift files, Assets.xcassets, Resources, Info.plist, entitlements in one operation preserving history)
5. Edit `Frost.xcodeproj/project.pbxproj`:
   - `path = Ice;` → `path = Frost;` (the `PBXFileSystemSynchronizedRootGroup` entry — critical, this is what makes Xcode find the renamed folder)
   - `name = Ice;` → `name = Frost;` (`PBXNativeTarget` name)
   - Cosmetic: `/* Ice */` comment → `/* Frost */`, `"Ice"` in `XCConfigurationList` comments → `"Frost"` (safe to batch-replace remaining standalone `Ice` tokens in this file after the two structural ones above are confirmed correct)
6. Edit `Frost.xcodeproj/xcshareddata/xcschemes/Frost.xcscheme`:
   - `BuildableName = "Ice.app"` → `"Frost.app"` (3 occurrences)
   - `BlueprintName = "Ice"` → `"Frost"` (3 occurrences)
7. Also update `INFOPLIST_FILE = Ice/Info.plist;` and `CODE_SIGN_ENTITLEMENTS = Ice/Ice.entitlements;` in `project.pbxproj` to `Frost/Info.plist` and `Frost/Ice.entitlements` (entitlements filename itself can stay `Ice.entitlements` for this phase — it's an internal path, not user-visible; rename it too here if doing a single pass is preferred, just keep the path reference consistent).
8. Build-verify (unsigned, matches the known-working flow from `docs/release-guide.md` — do not attempt `xcodebuild archive`):
   ```bash
   xcodebuild -resolvePackageDependencies -scheme Frost -project Frost.xcodeproj
   xcodebuild build \
     -scheme Frost \
     -project Frost.xcodeproj \
     -configuration Release \
     -derivedDataPath .release-output/DerivedData-phase1-check \
     CODE_SIGNING_ALLOWED=NO \
     CODE_SIGNING_REQUIRED=NO
   ```
9. Confirm `find .release-output/DerivedData-phase1-check -name "Frost.app" -type d` finds the built app, then `rm -rf .release-output/DerivedData-phase1-check` (throwaway verification build).

## Success Criteria

- [x] `git mv` used for every rename (verify with `git log --follow` on a moved file still shows pre-rename history)
- [x] `Frost.xcodeproj` exists, `Ice.xcodeproj` does not
- [x] `project.pbxproj` has zero remaining `path = Ice;` or `name = Ice;`
- [x] `Frost.xcscheme` has zero remaining `"Ice.app"` or `BlueprintName = "Ice"`
- [x] `xcodebuild build -scheme Frost -configuration Release CODE_SIGNING_ALLOWED=NO` exits 0 and produces `Frost.app`
- [x] No Swift symbol names touched yet (deferred to Phase 2)

## Risk Assessment

**Risk**: `PBXFileSystemSynchronizedRootGroup` behaves differently from classic Xcode groups — if `path` isn't updated correctly, Xcode may silently show an empty/missing group rather than a clear error.
**Mitigation**: The build-verify step in this phase is mandatory and blocking — do not proceed to Phase 2 until `xcodebuild build` succeeds and `Frost.app` is confirmed present on disk.

**Risk**: Scheme file has `container:Ice.xcodeproj` references beyond just `BuildableName`/`BlueprintName`.
**Mitigation**: After editing, `grep -c "Ice" Frost.xcodeproj/xcshareddata/xcschemes/Frost.xcscheme` should return 0; if not, inspect remaining hits before building.
