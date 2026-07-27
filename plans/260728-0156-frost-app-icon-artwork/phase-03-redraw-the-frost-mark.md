---
phase: 3
title: "Redraw the Frost mark"
status: pending
priority: P2
effort: "30m once artwork exists"
dependencies: [1]
---

# Phase 3: Redraw the Frost mark

## Overview

Replace `FrostMarkStroke.png` with the phase 1 silhouette. The imageset already
carries its final name and structure — only the pixels change.

## Requirements

**Functional**

- Settings → About tab icon and the search panel settings button show the new mark.
- It reads correctly in both light and dark appearances, at its rendered size.

**Non-functional**

- `template-rendering-intent: template` stays. The system tints this image; without
  that intent it renders as raw black in dark mode.
- The imageset keeps its name, so the generated `.frostMarkStroke` symbol is
  unchanged and neither call site needs editing.

## Architecture

`Frost/Assets.xcassets/FrostMarkStroke.imageset/` currently holds one 2x PNG
(1.4 KB) with empty 1x and 3x slots — the shape it inherited when
[`260728-0123`](../260728-0123-snowflake-icon-and-sparkle-plist-comments/phase-02-retire-the-ice-cube-asset.md)
moved it out of `ControlItemImages/`. That worked, so the slot layout is left alone.

Two consumers, both via the Xcode-generated symbol:

| Consumer | Line | Role |
|---|---|---|
| `Frost/Settings/SettingsView.swift` | 105 — `case .about: .assetCatalog(.frostMarkStroke)` | About tab icon |
| `Frost/MenuBar/Search/MenuBarSearchPanel.swift` | 360 — `Image(.frostMarkStroke)` | search panel settings button |

Because the name does not change, neither line is touched and there is no compile-time
signal if the image is wrong — only a visual one.

## Related Code Files

- Replace: `Frost/Assets.xcassets/FrostMarkStroke.imageset/FrostMarkStroke.png`
- Unchanged: that imageset's `Contents.json`, both call sites

## Implementation Steps

1. Export the phase 1 silhouette at 2x for its rendered size. Match the existing
   file's pixel dimensions unless the new design needs different proportions; if it
   does, keep the aspect ratio the call sites expect.

2. Replace the PNG in place, keeping the filename exactly. Do not touch
   `Contents.json` — its `filename` and `template-rendering-intent` are already right.

3. Build and check both call sites by eye, in light and dark mode. There is no
   compile-time check here.

## Success Criteria

- [ ] Clean build, no asset catalog warnings
- [ ] Settings → About tab icon shows the new mark
- [ ] Search panel settings button shows the new mark
- [ ] Legible at rendered size in both light and dark menu bars
- [ ] `Contents.json` unchanged (`git diff` shows the PNG only)
- [ ] No cube remains anywhere in `Frost/Assets.xcassets/`

## Risk Assessment

**Exporting the app icon instead of the silhouette.** The icon has colour and
depth; as a template image it renders as a tinted blob. These are two distinct
deliverables from phase 1 for exactly this reason.

**Losing `template-rendering-intent`** by editing `Contents.json` or re-adding the
imageset through Xcode's GUI. The mark then draws solid black and is invisible in
dark mode. Replace the PNG only.

**No compile-time safety net.** Unlike the phase 2 rename in the previous plan,
nothing here is a compile error — the symbol name is unchanged, so a wrong or
corrupt image builds cleanly and fails only on screen. The visual checks are the
only gate.
