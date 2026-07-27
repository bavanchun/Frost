---
phase: 5
title: "Release flow update and final verification"
status: completed
priority: P1
effort: "1.5h"
dependencies: [4]
---

# Phase 5: Release flow update and final verification

## Overview

Re-run the full personal-release pipeline (documented in `docs/release-guide.md` from the prior Ice → com.vchun.Ice rebrand) against the newly-renamed Frost project: unsigned build, manual codesign inside-out, zip, Sparkle-sign, appcast, GitHub release, install, smoke test. Update `docs/release-guide.md` itself so future releases reference `Frost` throughout instead of `Ice`. This phase is both the final verification gate for the whole rebrand and the deliverable that gives the user a working, rebranded, installed app.

## Requirements

- Functional: a signed `Frost.app` launches, shows correct bundle ID/display name, and passes the same smoke-test checklist used for the `v0.11.12` Ice-vc release
- Functional: `docs/release-guide.md` no longer references `Ice`, `Ice.xcodeproj`, `Ice.app`, or `com.vchun.Ice` anywhere
- Non-functional: whole-plan consistency — no phase left a stray `Ice` reference anywhere in tracked files (final repo-wide grep)

## Architecture

The signing flow itself doesn't change — only identifiers do. Recap of the verified-working approach (do NOT attempt `xcodebuild archive`, confirmed broken on this Personal Team + Xcode 26.6 combination regardless of signing style):

```
xcodebuild build (unsigned, CODE_SIGNING_ALLOWED=NO)
  → copy Frost.app to clean signing path
  → codesign inside-out:
      1. Sparkle XPC services (Downloader.xpc, Installer.xpc)
      2. Sparkle Updater.app
      3. Sparkle.framework itself
      4. Frost.app (main bundle, with Ice.entitlements — filename can stay as-is, an internal path)
  → codesign --verify (must show "valid on disk")
  → ditto zip
  → sign_update (Sparkle EdDSA signature, same Keychain-stored key — no new keypair needed, key isn't tied to app name)
  → write appcast.xml (title/link update to Frost + bavanchun/Frost)
  → git tag + gh release create (assets: Frost-1.0.0.zip, appcast.xml)
  → install to /Applications/Frost.app
  → re-grant Accessibility + Screen Recording (fresh TCC identity, per Phase 3)
  → smoke test
```

The Sparkle Ed25519 keypair from the prior session (`~/.config/ice-vc/sparkle-private-ed25519-key` backup, public key in Keychain) is reused as-is — it's tied to the signing identity/Keychain account, not the app's bundle ID or name. No new keypair generation needed.

<!-- Updated: Validation Session 1 - version fixed to 1.0.0 / build 1118, no longer an open decision --> Version: `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1118` (both Debug and Release configs) — marks Frost's first release as an independent product, decoupled from upstream Ice's version lineage. Since the bundle ID itself changes (`com.vchun.Ice` → `com.vchun.Frost`), Sparkle treats this as a fresh app anyway, not an in-place update — the version bump is about clean history, not update-mechanics necessity.

## Related Code Files

- Modify: `docs/release-guide.md` — replace all `Ice`/`Ice.xcodeproj`/`Ice.app`/`com.vchun.Ice` references with `Frost` equivalents
- Create (ephemeral, gitignored): `.release-output/sign/Frost.app`, `.release-output/Frost-1.0.0.zip`, `.release-output/appcast.xml`
- No code changes — this phase operates on already-renamed Phase 1-4 output

## Implementation Steps

1. Set version in `Frost.xcodeproj/project.pbxproj`: `MARKETING_VERSION = 1.0.0;` and `CURRENT_PROJECT_VERSION = 1118;` (both Debug and Release configs — 2 occurrences each, same pattern as the prior `com.jordanbaird.Ice` → `com.vchun.Ice` rebrand).
2. Rewrite `docs/release-guide.md`: search-replace `Ice` → `Frost` throughout, being careful with the two intentionally-Ice-referencing exceptions if any remain (there should be none — the guide is entirely this fork's own operational doc, not GPL-attribution-bearing).
3. Run the build steps from the (now Frost-named) release guide:
   ```bash
   xcodebuild -resolvePackageDependencies -scheme Frost -project Frost.xcodeproj
   rm -rf .release-output/
   xcodebuild build -scheme Frost -project Frost.xcodeproj -configuration Release \
     -derivedDataPath .release-output/DerivedData \
     CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
   APP_PATH=$(find .release-output -name "Frost.app" -type d | head -1)
   mkdir -p .release-output/sign
   cp -R "$APP_PATH" .release-output/sign/Frost.app
   ```
4. Codesign inside-out (same cert as before, `security find-identity -v -p codesigning` to reconfirm it's still valid):
   ```bash
   APP=".release-output/sign/Frost.app"
   CERT=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk -F'"' '{print $2}')
   SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
   codesign --force --options runtime --sign "$CERT" "$SPARKLE/XPCServices/Downloader.xpc"
   codesign --force --options runtime --sign "$CERT" "$SPARKLE/XPCServices/Installer.xpc"
   codesign --force --options runtime --sign "$CERT" "$SPARKLE/Updater.app"
   codesign --force --options runtime --sign "$CERT" "$APP/Contents/Frameworks/Sparkle.framework"
   codesign --force --options runtime --entitlements Frost/Ice.entitlements --sign "$CERT" "$APP"
   codesign --verify --verbose=4 "$APP"
   ```
5. Zip, Sparkle-sign, appcast (mirror Phase-3-verified process from the prior release, substituting Frost naming and the new bundle ID):
   ```bash
   cd .release-output/sign && ditto -c -k --keepParent Frost.app ../Frost-1.0.0.zip && cd ../..
   SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData/Frost-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update)
   "$SIGN_UPDATE" ".release-output/Frost-1.0.0.zip"
   ```
   Write `.release-output/appcast.xml` with `<title>Frost</title>`, `<link>https://github.com/bavanchun/Frost/releases</link>`, `<sparkle:version>1118</sparkle:version>`, `<sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>`, enclosure URL `https://github.com/bavanchun/Frost/releases/download/v1.0.0/Frost-1.0.0.zip`.
6. Tag + release:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   gh release create v1.0.0 .release-output/Frost-1.0.0.zip .release-output/appcast.xml \
     --repo bavanchun/Frost --title "1.0.0" --notes "Frost 1.0.0 — first independent release, rebranded from Ice-vc."
   ```
7. Verify Sparkle feed resolves: `curl -sIL https://github.com/bavanchun/Frost/releases/latest/download/appcast.xml` → expect 302→302→200.
8. Install:
   ```bash
   pgrep -fl "Ice.app/Contents/MacOS/Ice" && killall Ice 2>/dev/null   # old app, if still running
   rm -rf /Applications/Ice.app /Applications/Frost.app
   cp -R .release-output/sign/Frost.app /Applications/
   xattr -cr /Applications/Frost.app
   open /Applications/Frost.app
   ```
9. Re-grant permissions: System Settings → Privacy & Security → Accessibility → enable Frost; → Screen Recording → enable Frost (manual GUI step, cannot be scripted).
10. Smoke test (mirror the checklist used for `v0.11.12`):
    - [x] Process alive: `pgrep -fl "Frost.app/Contents/MacOS/Frost"`
    - [x] `defaults read com.vchun.Frost` shows fork-owned keys (fresh domain, not inherited from `com.vchun.Ice`)
    - [ ] Settings window shows "Frost" title, About pane shows "Frost" + correct copyright
    - [ ] Right-click menu bar context menu shows "Frost" as title
    - [ ] Menu bar hide/show toggle works
    - [ ] Settings → About → Check for Updates reaches the new appcast without error
11. Final whole-repo consistency sweep:
    ```bash
    grep -rniE '\bice\b' . \
      --include="*.swift" --include="*.plist" --include="*.pbxproj" \
      --include="*.md" --include="*.xcscheme" \
      --exclude-dir=.git --exclude-dir=.release-output \
      | grep -v "LICENSE:"   # LICENSE's two Jordan Baird notices (source-header + interactive-mode templates) are expected and correct
    ```
    Should return zero unexpected hits.

## Success Criteria

- [x] `Frost.app` builds, signs (`codesign --verify` passes), zips, and Sparkle-signs successfully
- [x] GitHub release published at `bavanchun/Frost` with correct assets
- [x] Sparkle feed URL resolves correctly (302→302→200)
- [x] `Frost.app` installed, running, showing correct identity everywhere in the UI
- [ ] Accessibility + Screen Recording re-granted (manual GUI step — pending user)
- [x] `docs/release-guide.md` fully updated to Frost naming
- [x] Final repo-wide grep shows zero unexpected `Ice` references outside the required `LICENSE` attribution line

## Risk Assessment

**Risk**: This phase repeats the exact signing flow that failed multiple times in the prior session before landing on the working unsigned-build + manual-codesign approach — a regression back to attempting `xcodebuild archive` would waste time re-discovering the same dead end.
**Mitigation**: Implementation steps above explicitly specify `xcodebuild build` (not `archive`) from the start — this plan encodes the already-learned lesson, no re-discovery needed.

**Risk**: Reusing the Sparkle Ed25519 keypair across a bundle-ID change could be assumed to require regeneration.
**Mitigation**: Confirmed in Architecture section — the keypair is tied to the signing Keychain account, not the app identity. No new keypair needed; reusing avoids invalidating trust with any hypothetical future installs signed by the same key.

**Risk**: Old `com.vchun.Ice` UserDefaults/TCC state lingers on disk even after `/Applications/Ice.app` is deleted, causing confusion if the user later wonders why old settings don't apply to Frost.
**Mitigation**: This is expected and consistent with the deliberate fresh-start decision made in Phase 3 — not a defect to fix in this phase, just worth noting in the release notes if the user wants a record of it.
