---
phase: 3
title: "Display strings, bundle ID, and permissions"
status: pending
priority: P1
effort: "1.5h"
dependencies: [2]
---

# Phase 3: Display strings, bundle ID, and permissions

## Overview

Change everything a user actually sees or that macOS uses to identify the app: the bundle ID, the window/menu title strings, copyright, and Sparkle feed URL (all in `Frost.xcodeproj/project.pbxproj` and `Frost/Info.plist` — same pattern as the prior `com.jordanbaird.Ice` → `com.vchun.Ice` rebrand, just one more hop to `com.vchun.Frost`). Then handle the operational consequence: macOS treats a new bundle ID as a different app, so Accessibility/Screen Recording permissions must be re-granted and the old installed app removed.

## Requirements

- Functional: app displays "Frost" everywhere a user looks (Settings title, About pane, window title, right-click menu, Dock/menu bar tooltip via `CFBundleName`)
- Functional: `com.vchun.Ice` fully removed from `/Applications` and TCC re-granted for `com.vchun.Frost`
- Non-functional: Sparkle feed URL and public key stay pointed at the fork's own GitHub Release infrastructure (already correct from the prior session — just confirm the URL path segment doesn't need to change, since it's keyed by repo not by app name)

## Architecture

Known display-string locations (line numbers as of the pre-Phase-1 codebase; re-verify with grep after Phase 1/2 renames since file moves don't change line numbers but this phase runs after them):

- `Frost/Utilities/Constants.swift` — `static let settingsWindowTitle = "Ice"` → `"Frost"`
- `Frost/Settings/SettingsView.swift:56` — `Text("Ice")` → `Text("Frost")`
- `Frost/Settings/SettingsPanes/AboutSettingsPane.swift:81` — `Text("Ice")` → `Text("Frost")`
- `Frost/MenuBar/MenuBarManager.swift:330` — `NSMenu(title: "Ice")` → `NSMenu(title: "Frost")`
- `Frost/MenuBar/ControlItem/ControlItem.swift:425` — `NSMenu(title: "Ice")` → `NSMenu(title: "Frost")`

Bundle identity (in `Frost.xcodeproj/project.pbxproj`, both Debug and Release configs — same 2× pattern as the prior rebrand):

- `PRODUCT_BUNDLE_IDENTIFIER = com.vchun.Ice;` → `com.vchun.Frost;`

Sparkle (`Frost/Info.plist`): `SUFeedURL` currently points to `https://github.com/bavanchun/Ice-vc/releases/latest/download/appcast.xml` — this references the **repo name**, which changes in Phase 4 to `Frost`. Update it here to the new expected URL (`.../bavanchun/Frost/releases/...`) even though the repo rename hasn't happened yet in dependency order — it will be correct once Phase 4 completes; do not leave it stale.

`SUPublicEDKey` (the Sparkle Ed25519 public key) does not need to change — it's tied to the signing identity, not the app name.

`CFBundleName`/`CFBundleDisplayName` are not explicitly set in `Info.plist` (project uses `GENERATE_INFOPLIST_FILE = YES` with `PRODUCT_NAME = $(TARGET_NAME)`), so once the target is renamed to `Frost` in Phase 1, `PRODUCT_NAME` auto-resolves to `Frost` — no separate edit needed here, just confirm via `defaults read`/`PlistBuddy` after building.

## Related Code Files

- Modify: `Frost.xcodeproj/project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER` (2× occurrences, Debug + Release)
- Modify: `Frost/Info.plist` — `SUFeedURL`
- Modify: `Frost/Utilities/Constants.swift` — `settingsWindowTitle`
- Modify: `Frost/Settings/SettingsView.swift` — `Text("Ice")`
- Modify: `Frost/Settings/SettingsPanes/AboutSettingsPane.swift` — `Text("Ice")`
- Modify: `Frost/MenuBar/MenuBarManager.swift` — `NSMenu(title:)`
- Modify: `Frost/MenuBar/ControlItem/ControlItem.swift` — `NSMenu(title:)`

## Implementation Steps

1. `grep -rn '"Ice"' Frost/ --include="*.swift"` — re-confirm the 5 known hits above are still the complete set after Phase 1/2 renames (file moves don't change string literals, but re-verify rather than trust stale line numbers).
2. Edit each of the 5 display-string sites: `"Ice"` → `"Frost"`.
3. Edit `Frost.xcodeproj/project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER = com.vchun.Ice;` → `com.vchun.Frost;` (both configs — use `sed`/`Edit` with `replace_all` since both lines are identical text).
4. Edit `Frost/Info.plist`: `SUFeedURL` → `https://github.com/bavanchun/Frost/releases/latest/download/appcast.xml`.
5. Build + codesign a throwaway copy to test bundle identity (reuse the Phase-5 signing flow at small scale, or just build unsigned and inspect `Info.plist` inside the built `.app`):
   ```bash
   xcodebuild build -scheme Frost -project Frost.xcodeproj -configuration Release \
     -derivedDataPath .release-output/DerivedData-phase3-check \
     CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
   APP=$(find .release-output/DerivedData-phase3-check -name "Frost.app" -type d | head -1)
   /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Contents/Info.plist"
   /usr/libexec/PlistBuddy -c "Print :CFBundleName" "$APP/Contents/Info.plist"
   rm -rf .release-output/DerivedData-phase3-check
   ```
   Expect `CFBundleIdentifier = com.vchun.Frost` and `CFBundleName = Frost`.
6. Remove the old installed app and its TCC grants are naturally orphaned (macOS ties TCC to bundle ID, not just app name):
   ```bash
   pgrep -fl "Ice.app/Contents/MacOS/Ice" && killall Ice 2>/dev/null
   rm -rf /Applications/Ice.app
   ```
7. Note (do not automate — requires GUI interaction): after Phase 5 installs `/Applications/Frost.app`, the user must re-grant Accessibility and Screen Recording in System Settings → Privacy & Security, since `com.vchun.Frost` is a fresh TCC identity with no prior grants.

## Success Criteria

- [ ] Zero remaining `"Ice"` string literals in `Frost/**/*.swift` (verified by grep, not just the 5 known sites — in case Phase 1/2 surfaced more)
- [ ] `PRODUCT_BUNDLE_IDENTIFIER = com.vchun.Frost;` in both Debug and Release configs
- [ ] `SUFeedURL` points to `bavanchun/Frost` releases
- [ ] Built app's `Info.plist` shows `CFBundleIdentifier = com.vchun.Frost` and `CFBundleName = Frost`
- [ ] Old `/Applications/Ice.app` removed
- [ ] `xcodebuild build` still exits 0 after all edits

## Risk Assessment

**Risk**: Editing `SUFeedURL` to reference `bavanchun/Frost` before Phase 4 actually renames the repo means the URL is temporarily "wrong" (repo doesn't exist yet under that name).
**Mitigation**: Acceptable — this phase only builds and inspects locally; the URL isn't exercised over the network until Phase 5's release flow, by which point Phase 4's repo rename has completed. Order dependency is intentional (see plan.md phase table).

**Risk**: User loses menu bar hide/show state or hotkey bindings when the old `com.vchun.Ice` UserDefaults domain is abandoned for a fresh `com.vchun.Frost` domain.
**Mitigation**: Expected and acceptable for a personal-use rebrand — this is the same trade-off already made in the prior `com.jordanbaird.Ice` → `com.vchun.Ice` rebrand (fresh state, documented in the scout report). Not a regression introduced by this phase.
