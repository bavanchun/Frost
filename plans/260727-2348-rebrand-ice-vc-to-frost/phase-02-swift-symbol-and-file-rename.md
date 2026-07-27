---
phase: 2
title: "Swift symbol and file rename"
status: completed
priority: P1
effort: "2h"
dependencies: [1]
---

# Phase 2: Swift symbol and file rename

## Overview

Rename the 18 `Ice*`-prefixed Swift types and their 11 corresponding filenames to `Frost*`, plus the two `IceUI`/`IceBar` folders and the `IceCube` asset catalog symbol references. Build-verify again before moving to display strings, since a symbol-rename typo (e.g., a missed call site) produces a compile error, not a runtime bug — cheap to catch here, expensive to debug later mixed with string changes.

## Requirements

- Functional: project compiles with zero `Ice*` symbol names remaining (except where `Ice` is deliberately kept as historical/legal reference, which does not apply to any of these 18 symbols — they are all this fork's own code)
- Non-functional: every declaration site AND every call site is renamed consistently (a partial rename breaks the build, which is the point of the build-verify gate)

## Architecture

18 declarations across 11 files, all under `Frost/UI/` and `Frost/Main/` (paths below reflect the Phase 1 folder rename):

```
Frost/Main/IceApp.swift:9              struct IceApp: App
Frost/UI/IceBar/IceBar.swift:11        final class IceBarPanel: NSPanel
Frost/UI/IceBar/IceBar.swift:194       private final class IceBarHostingView: NSHostingView<AnyView>
Frost/UI/IceBar/IceBar.swift:234       private struct IceBarContentView: View
Frost/UI/IceBar/IceBar.swift:352       private struct IceBarItemView: View
Frost/UI/IceBar/IceBar.swift:415       private struct IceBarItemClickView: NSViewRepresentable
Frost/UI/IceBar/IceBarColorManager.swift:9   final class IceBarColorManager: ObservableObject
Frost/UI/IceBar/IceBarLocation.swift:9       enum IceBarLocation: Int, CaseIterable, Identifiable
Frost/UI/IceUI/IceForm.swift:8         struct IceForm<Content: View>: View
Frost/UI/IceUI/IceForm.swift:72        private struct IceFormToggleStyle: ToggleStyle
Frost/UI/IceUI/IceGroupBox.swift:8     struct IceGroupBox<Header, Content, Footer>: View
Frost/UI/IceUI/IceLabeledContent.swift:8     struct IceLabeledContent<Label, Content>: View
Frost/UI/IceUI/IceMenu.swift:8         struct IceMenu<Title, Label, Content>: View
Frost/UI/IceUI/IcePicker.swift:8       struct IcePicker<Label, SelectionValue, Content>: View
Frost/UI/IceUI/IceSection.swift:8      struct IceSectionOptions: OptionSet
Frost/UI/IceUI/IceSection.swift:18     struct IceSection<Header, Content, Footer>: View
Frost/UI/IceUI/IceSection.swift:132    private struct IceSectionLayout: _VariadicView_UnaryViewRoot
Frost/UI/IceUI/IceSlider.swift:9       struct IceSlider<Value, ValueLabel, ValueLabelSelectability>: View
```

These are used throughout the rest of the codebase (e.g., `IceForm` is used in every Settings pane). A global find-replace of the exact identifier strings (word-boundary matched) across all `.swift` files is safe because `Ice*` is not a common English-word collision risk — but must run AFTER the declarations are renamed, or IDE/compiler tooling will not help catch stragglers.

Two folders share the prefix cosmetically: `Frost/UI/IceBar/` and `Frost/UI/IceUI/` — rename these too for consistency, since `PBXFileSystemSynchronizedRootGroup` auto-discovers files by path, no pbxproj edit needed for subfolder renames.

Separately, `IceCubeStroke`/`IceCubeFill` are asset catalog image names (`.catalog("IceCubeStroke")`/`.catalog("IceCubeFill")` in `ControlItemImageSet.swift:75-76`) referencing `Frost/Assets.xcassets/ControlItemImages/IceCube/`. This is icon-adjacent — out of scope per the plan's non-goals (icon design is a separate follow-up) — so **do not rename `IceCube`,`IceCubeStroke`, or `IceCubeFill`**; leave the asset catalog and its code references exactly as-is. They'll be revisited together with the new icon design.

## Related Code Files

- Rename: `Frost/Main/IceApp.swift` → `FrostApp.swift`
- Rename: `Frost/UI/IceBar/` → `Frost/UI/FrostBar/` (folder), and within it:
  - `IceBar.swift` → `FrostBar.swift`
  - `IceBarColorManager.swift` → `FrostBarColorManager.swift`
  - `IceBarLocation.swift` → `FrostBarLocation.swift`
- Rename: `Frost/UI/IceUI/` → `Frost/UI/FrostUI/` (folder), and within it:
  - `IceForm.swift` → `FrostForm.swift`
  - `IceGroupBox.swift` → `FrostGroupBox.swift`
  - `IceLabeledContent.swift` → `FrostLabeledContent.swift`
  - `IceMenu.swift` → `FrostMenu.swift`
  - `IcePicker.swift` → `FrostPicker.swift`
  - `IceSection.swift` → `FrostSection.swift`
  - `IceSlider.swift` → `FrostSlider.swift`
- Modify: every `.swift` file under `Frost/` that references any of the 18 renamed symbols (call sites — discover via grep, not by memory)
- Leave unchanged: `IceCube`, `IceCubeStroke`, `IceCubeFill` (asset catalog + `ControlItemImageSet.swift:75-76` references) — deferred to icon-design follow-up

## Implementation Steps

1. `git mv Frost/Main/IceApp.swift Frost/Main/FrostApp.swift`
2. `git mv Frost/UI/IceBar Frost/UI/FrostBar` (moves all 3 files inside in one operation)
3. Rename the 3 files inside `FrostBar/`: `git mv Frost/UI/FrostBar/IceBar.swift Frost/UI/FrostBar/FrostBar.swift`, similarly for `IceBarColorManager.swift` and `IceBarLocation.swift`
4. `git mv Frost/UI/IceUI Frost/UI/FrostUI`
5. Rename the 7 files inside `FrostUI/` similarly (`IceForm.swift`→`FrostForm.swift`, etc.)
6. Global symbol rename — for each of the 18 symbols, replace the exact identifier everywhere it appears as a whole word (declaration + every call site: initializers, type annotations, generic constraints, extension targets). Do this per-symbol, not as one giant regex, to keep each substitution auditable:
   ```bash
   # Example for one symbol — repeat pattern for all 18, longest names first to avoid partial-match collisions
   # (e.g., rename IceBarColorManager before IceBar, so "IceBar" substring inside "IceBarColorManager" isn't double-replaced)
   grep -rl '\bIceBarColorManager\b' --include="*.swift" Frost/ | xargs sed -i '' 's/\bIceBarColorManager\b/FrostBarColorManager/g'
   ```
   Order of replacement (longest-identifier-first to avoid double-substitution artifacts):
   `IceBarColorManager` → `IceBarItemClickView` → `IceBarHostingView` → `IceBarContentView` → `IceBarItemView` → `IceBarLocation` → `IceBarPanel` → `IceBar` → `IceFormToggleStyle` → `IceForm` → `IceGroupBox` → `IceLabeledContent` → `IceSectionOptions` → `IceSectionLayout` → `IceSection` → `IceSlider` → `IcePicker` → `IceMenu` → `IceApp`
   (Prefix each replacement with `Frost` in place of `Ice`, e.g. `IceBarColorManager` → `FrostBarColorManager`.)
7. After all 18 substitutions, grep for stragglers: `grep -rnE '\bIce(App|Bar[A-Za-z]*|Form[A-Za-z]*|GroupBox|LabeledContent|Menu|Picker|Section[A-Za-z]*|Slider)\b' --include="*.swift" Frost/` — must return zero hits.
8. <!-- Updated: Validation Session 1 - added file-header batch-rename step --> Batch-rename the Xcode auto-generated file-header comment. Every one of the 116 `.swift` files carries a 4-line header block (`//`, `//  <Filename>.swift`, `//  Ice`, `//`) where the third line names the project — this is cosmetic (not a compiled symbol) but is caught by the Phase 5 final repo-wide grep sweep, so it must be cleared here while already touching every file:
   ```bash
   grep -rl '^//  Ice$' --include="*.swift" Frost/ | xargs sed -i '' 's/^\/\/  Ice$/\/\/  Frost/'
   # Verify: should return 0
   grep -rl '^//  Ice$' --include="*.swift" Frost/ | wc -l
   ```
9. Build-verify:
   ```bash
   xcodebuild build \
     -scheme Frost \
     -project Frost.xcodeproj \
     -configuration Release \
     -derivedDataPath .release-output/DerivedData-phase2-check \
     CODE_SIGNING_ALLOWED=NO \
     CODE_SIGNING_REQUIRED=NO
   ```
10. On success, `rm -rf .release-output/DerivedData-phase2-check`. On compile error, the error location pinpoints the missed call site — fix and rebuild, do not proceed until clean.

## Success Criteria

- [x] All 11 files renamed via `git mv` (history preserved)
- [x] `FrostBar/` and `FrostUI/` folders exist; `IceBar`/`IceUI` folders do not
- [x] Zero remaining word-boundary matches for any of the 18 old symbol names in `.swift` files
- [x] Zero remaining `//  Ice` file-header comments across all 116 `.swift` files
- [x] `IceCube`/`IceCubeStroke`/`IceCubeFill` deliberately left untouched (verify still present — confirms nothing over-matched into the asset layer)
- [x] `xcodebuild build -scheme Frost -configuration Release CODE_SIGNING_ALLOWED=NO` exits 0

## Risk Assessment

**Risk**: Blind regex rename could partially match inside longer identifiers (e.g., renaming `IceBar` before `IceBarPanel` would corrupt `IceBarPanel` into `FrostBarPanel`... actually still correct here since both share the `Ice`→`Frost` prefix substitution — but the real risk is `IceBar` matching inside `IceBarColorManager` if that longer name hasn't been substituted first, leaving a mixed `FrostBarColorManager`-vs-partial state).
**Mitigation**: Fixed replacement order above goes longest-identifier-first; run the straggler grep (step 7) before building, not after.

**Risk**: A symbol used only in a SwiftUI `body` closure or trailing-closure call site is easy to miss with a manual read but not with `grep -rl`.
**Mitigation**: Steps 6-7 use `grep`/`sed` across the whole `Frost/` tree per symbol, not manual file-by-file editing — this is exhaustive by construction.

**Risk**: The file-header sed pattern (`^//  Ice$`) could miss files with inconsistent header formatting (extra whitespace, different line count).
**Mitigation**: Step 8's verify sub-step re-greps for the exact same pattern after substitution — if any file has a divergent header format, it surfaces as a non-zero count immediately, not silently at Phase 5's final sweep.
