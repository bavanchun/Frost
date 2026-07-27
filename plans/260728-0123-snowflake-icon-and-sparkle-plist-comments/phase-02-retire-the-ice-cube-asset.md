---
phase: 2
title: "Retire the Ice Cube asset"
status: complete
priority: P2
effort: "45m"
dependencies: [1]
---

# Phase 2: Retire the Ice Cube asset

## Overview

With the picker off the asset catalog, `IceCubeFill` has no users and `IceCubeStroke` is left serving only as the app's mark. Delete the first, promote the second to `FrostMarkStroke` at the asset catalog root, and remove the `IceCube` folder — after which no "Ice" string remains in `Frost/`.

## Requirements

**Functional**

- Settings → About and the search panel's settings button render the same image they do today.
- No visual change of any kind; this phase is a rename plus a deletion.

**Non-functional**

- `Frost/Assets.xcassets/ControlItemImages/IceCube/` is gone.
- The surviving imageset keeps `template-rendering-intent: template` and its single 2x slot.

## Architecture

`IceCubeStroke` is currently filed under `ControlItemImages/`, but after phase 1 it is no longer a control item image. Its two remaining consumers both use it as the application mark:

| Consumer | Line | Role |
|---|---|---|
| `Frost/Settings/SettingsView.swift` | 105 — `case .about: .assetCatalog(.iceCubeStroke)` | About tab icon |
| `Frost/MenuBar/Search/MenuBarSearchPanel.swift` | 360 — `Image(.iceCubeStroke)` | search panel settings button |

So it moves to the asset catalog root, where `Warning.imageset` already sits as precedent for a standalone imageset.

`IceCubeFill`'s only reference was `ControlItemImageSet.swift:76`, removed in phase 1. Verified by search: nothing else names it. It is deleted, not renamed.

Both call sites use Xcode-generated asset symbols, so the identifier follows the asset name automatically and a missed update is a compile error.

The artwork itself is unchanged — this phase moves bytes, it does not redraw them. The replacement art arrives with the AppIcon plan.

## Related Code Files

- Move: `Frost/Assets.xcassets/ControlItemImages/IceCube/IceCubeStroke.imageset/` → `Frost/Assets.xcassets/FrostMarkStroke.imageset/`
- Rename: the PNG inside it, `IceCubeStroke.png` → `FrostMarkStroke.png`
- Modify: that imageset's `Contents.json` — the `filename` field must match the renamed PNG
- Delete: `Frost/Assets.xcassets/ControlItemImages/IceCube/` (including `IceCubeFill.imageset/`)
- Modify: `Frost/Settings/SettingsView.swift:105`
- Modify: `Frost/MenuBar/Search/MenuBarSearchPanel.swift:360`

## Implementation Steps

1. Confirm phase 1 has landed and `IceCubeFill` is unreferenced. Search `Frost/` for `IceCubeFill` — expect no hits outside the asset folder itself. If the picker still references it, stop: phase 1 is incomplete.

2. Move the stroke imageset to the catalog root and rename it, using `git mv` so history follows:

   ```
   Frost/Assets.xcassets/ControlItemImages/IceCube/IceCubeStroke.imageset/
     → Frost/Assets.xcassets/FrostMarkStroke.imageset/
   ```

   Rename the PNG inside to `FrostMarkStroke.png`.

3. Update `filename` in the moved `Contents.json` to `FrostMarkStroke.png`. Leave the rest as-is — the 1x and 3x slots stay empty and `template-rendering-intent` stays `template`. Only the `filename` value changes; the file's structure is already correct.

4. Delete `Frost/Assets.xcassets/ControlItemImages/IceCube/` and everything under it.

5. Update the two call sites to the generated symbol for the new name:

   - `SettingsView.swift:105` → `case .about: .assetCatalog(.frostMarkStroke)`
   - `MenuBarSearchPanel.swift:360` → `Image(.frostMarkStroke)`

6. Build. Any missed reference surfaces here as a compile error.

7. Search `Frost/` case-insensitively for `ice ?cube` and confirm zero hits.

## Success Criteria

- [ ] Project builds clean, no new warnings
- [ ] Settings → About shows the mark in its tab, unchanged from before
- [ ] The search panel's settings button shows the mark, unchanged from before
- [ ] `Frost/Assets.xcassets/ControlItemImages/` contains only `Dot/` and `Ellipsis/`
- [ ] Searching `Frost/` for `ice ?cube` (case-insensitive) returns nothing
- [ ] `git status` shows the move as a rename, not an add/delete pair

## Risk Assessment

**Running this before phase 1 breaks the menu bar icon silently.** A persisted blob still pointing at `.catalog("IceCubeStroke")` would resolve to `nil` with no throw and no log. The `dependencies: [1]` field is load-bearing, not decorative.

**`Contents.json` filename left stale** produces an imageset with no image — again silent at build time. Step 3 exists for exactly this; the About-tab check in Success Criteria is what confirms it.

**Name mismatch with the generated symbol.** Xcode derives `.frostMarkStroke` from the imageset directory name, so the directory must be `FrostMarkStroke.imageset` exactly. A wrong name is a compile error at step 6, which is the cheap outcome.
