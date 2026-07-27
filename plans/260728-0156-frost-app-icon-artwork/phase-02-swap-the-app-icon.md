---
phase: 2
title: "Swap the app icon"
status: pending
priority: P2
effort: "45m once artwork exists"
dependencies: [1]
---

# Phase 2: Swap the app icon

## Overview

Replace the ten PNGs in `AppIcon.appiconset` with exports of the phase 1 master.
Purely mechanical; the only thing that can go wrong is a slot silently missing.

## Requirements

**Functional**

- Every existing slot filled: 16, 32, 128, 256, 512, each at 1x and 2x.
- The icon appears in Dock, Finder, `⌘Tab`, notifications, Sparkle's update dialog,
  and Settings → About.
- `README.md`'s header image still resolves.

**Non-functional**

- Asset name stays `AppIcon` so `ASSETCATALOG_COMPILER_APPICON_NAME`
  (`project.pbxproj:306,338`) needs no edit.
- Filenames stay as they are, so `README.md:2`'s hardlink to `icon_256x256.png`
  keeps working.

## Architecture

`AppIcon.appiconset/Contents.json` already declares the full mac idiom set and
does not change — only the PNGs behind it do. Keeping both the asset name and the
ten filenames means this phase touches no Swift, no project file, and no docs.

Consumers, all indirect:

| Consumer | How |
|---|---|
| macOS (Dock, Finder, `⌘Tab`, notifications) | Bundle icon, via the compiled catalog |
| `AboutSettingsPane.swift:68` | `NSImage(named: NSImage.applicationIconName)`, drawn at 225 pt |
| Sparkle update dialog | Bundle icon |
| `README.md:2` | Direct path to `icon_256x256.png` in the repo |

`MenuBarSearchPanel.swift:424`'s `appIcon` is unrelated — it renders *other*
applications' icons and must not be touched.

The 225 pt draw in About is the quality floor: it is the largest the icon is ever
shown at inside the app, so softness there is visible in a way the Dock hides.

## Related Code Files

- Replace: all ten PNGs in `Frost/Assets.xcassets/AppIcon.appiconset/`
- Unchanged: that folder's `Contents.json`, `project.pbxproj`, `README.md`

## Implementation Steps

1. Export from the phase 1 master at each required pixel size:

   | Slot | Pixels |
   |---|---|
   | 16 1x / 2x | 16, 32 |
   | 32 1x / 2x | 32, 64 |
   | 128 1x / 2x | 128, 256 |
   | 256 1x / 2x | 256, 512 |
   | 512 1x / 2x | 512, 1024 |

   Note the overlaps: `icon_16x16@2x.png` and `icon_32x32.png` are both 32 px,
   as are the 256/512 pairs. Today's files confirm this — the duplicated sizes
   have matching byte counts. Export each file anyway; do not symlink.

2. Replace the ten files in place, keeping the existing names exactly.

3. Confirm `Contents.json` is untouched and still lists ten entries.

4. Build, then verify the icon actually landed in the product rather than trusting
   the build:

   ```bash
   /usr/libexec/PlistBuddy -c "Print CFBundleIconName" <product>/Frost.app/Contents/Info.plist
   ```

5. Install and check every surface in Success Criteria. A stale Dock icon is
   usually the icon cache, not the build — `killall Dock` before concluding
   anything is wrong.

## Success Criteria

- [ ] Clean build, no asset catalog warnings
- [ ] Dock, Finder, and `⌘Tab` show the new icon after a clean install
- [ ] Settings → About renders it at 225 pt with no visible softness
- [ ] Sparkle's update dialog shows it
- [ ] `README.md` header image resolves on GitHub
- [ ] `AppIcon.appiconset/` contains exactly ten PNGs with the original names
- [ ] `Contents.json` unchanged (`git diff` shows PNG changes only)

## Risk Assessment

**A missing or misnamed slot produces no icon and no build error.** Same silent
class as the asset failures the previous plan designed around. Step 4's
`PlistBuddy` check and the install check are what catch it; the build will not.

**Renaming the files breaks `README.md:2` silently** — the GitHub image simply
stops rendering, and nothing in CI notices. Keep the names.

**Dock icon caching makes a correct build look broken.** Do not start debugging
the asset catalog before `killall Dock` and a fresh install.
