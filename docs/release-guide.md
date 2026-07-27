# Ice-vc Release Guide

Personal-build release workflow for the `bavanchun/Ice-vc` fork. Targets macOS 14+, signed with a free Personal Apple Developer account (no notarization, runs locally only).

## One-Time Setup

### 1. Sparkle Ed25519 keypair

Sparkle auto-updates require an EdDSA keypair. Private key lives in the macOS Keychain; public key is embedded in `Ice/Info.plist` as `SUPublicEDKey`.

```bash
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData/Ice-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys)

# Generate keys (auto-stored in Keychain); prints the public key + Info.plist snippet
"$SIGN_UPDATE"

# Backup the private key to a file OUTSIDE the repo (in case of Keychain loss)
"$SIGN_UPDATE" -x ~/.config/ice-vc/sparkle-private-ed25519-key
chmod 600 ~/.config/ice-vc/sparkle-private-ed25519-key

# Re-lookup the public key later (for verifying Info.plist)
"$SIGN_UPDATE" -p
```

Copy the printed public key (base64, 44 chars) into `Ice/Info.plist` → `SUPublicEDKey`. Never commit the private key.

### 2. Signing approach: unsigned build + manual codesign

**`xcodebuild archive` does not work with a free Personal Team on Xcode 26.6** — it requires a "Mac Development" certificate distinct from the "Apple Development" cert Xcode issues by default, and Personal (free) accounts cannot provision one. Both automatic (`CODE_SIGN_STYLE=Automatic`) and manual (`CODE_SIGN_STYLE=Manual` + explicit `CODE_SIGN_IDENTITY`) archive attempts fail — see [Troubleshooting](#troubleshooting) for the exact errors hit.

**What actually works:** build unsigned with `xcodebuild build` (not `archive`), then manually `codesign` every nested bundle inside-out with the "Apple Development" identity already in Keychain. This is Step 3 below — do not try `xcodebuild archive` first, it wastes a round-trip.

### 3. GitHub CLI auth

```bash
gh auth login   # choose github.com, account bavanchun, scope: repo
gh auth status  # confirm active account is bavanchun
```

## Per-Release Flow

### Step 1 — Bump version (if needed)

Edit `Ice.xcodeproj/project.pbxproj`:

```
MARKETING_VERSION = <new.version>;       # e.g., 0.11.13
CURRENT_PROJECT_VERSION = <build-num>;   # e.g., 1118
```

Both Debug and Release configs must match. Bump build number for every release, even tiny changes.

### Step 2 — Verify identity settings

Confirm before each release:

```bash
grep -E "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|NSHumanReadableCopyright" Ice.xcodeproj/project.pbxproj | sort -u
```

Expected:
- `PRODUCT_BUNDLE_IDENTIFIER = com.vchun.Ice;`
- `DEVELOPMENT_TEAM = LC6N3KUML9;`
- `INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © <year> VChun";`

### Step 3 — Resolve deps, build unsigned, codesign manually

```bash
# Refresh SPM deps (only if Package.resolved changed)
xcodebuild -resolvePackageDependencies -scheme Ice -project Ice.xcodeproj

# Clean + build UNSIGNED (output dir avoids the literal word 'build' which trips some hooks)
rm -rf .release-output/
xcodebuild build \
  -scheme Ice \
  -project Ice.xcodeproj \
  -configuration Release \
  -derivedDataPath .release-output/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

# Copy to a clean path for signing
APP_PATH=$(find .release-output -name "Ice.app" -type d | head -1)
mkdir -p .release-output/sign
cp -R "$APP_PATH" .release-output/sign/Ice.app
```

Now codesign every nested bundle **inside-out** — XPC services and helper apps first, then the enclosing framework, then the main app last:

```bash
APP=".release-output/sign/Ice.app"
CERT=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk -F'"' '{print $2}')
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"

# 1. XPC services (innermost)
codesign --force --options runtime --sign "$CERT" "$SPARKLE/XPCServices/Downloader.xpc"
codesign --force --options runtime --sign "$CERT" "$SPARKLE/XPCServices/Installer.xpc"

# 2. Updater.app (nested helper)
codesign --force --options runtime --sign "$CERT" "$SPARKLE/Updater.app"

# 3. Sparkle.framework itself
codesign --force --options runtime --sign "$CERT" "$APP/Contents/Frameworks/Sparkle.framework"

# 4. Main app, with entitlements, last
codesign --force --options runtime \
  --entitlements Ice/Ice.entitlements \
  --sign "$CERT" "$APP"

# Verify
codesign --verify --verbose=4 "$APP"
codesign -dv --verbose=4 "$APP"
```

Expected: `Authority=Apple Development: <apple-id> (<TEAM_ID>)` chained to WWDR + Apple Root CA, `flags=0x10000(runtime)` (Hardened Runtime), `Identifier=com.vchun.Ice`. `codesign --verify` must print `valid on disk` + `satisfies its Designated Requirement`.

If any nested bundle is missing from `Contents/Frameworks/`, re-run `find "$APP" -name "*.app" -o -name "*.xpc" -o -name "*.framework"` and sign every hit before the main app.

### Step 4 — Zip, sign zip, generate appcast

```bash
VERSION=0.11.12
BUILD=1117

# Zip preserving .app bundle structure (ditto -k preserves resource forks/signature)
cd .release-output/sign
ditto -c -k --keepParent Ice.app "../Ice-${VERSION}.zip"
cd ../..

# Sign the zip with Sparkle private key (auto-read from Keychain)
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData/Ice-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update)
"$SIGN_UPDATE" ".release-output/Ice-${VERSION}.zip"
# Output: sparkle:edSignature="<sig>" length="<bytes>"
```

### Step 5 — Write `appcast.xml`

Drop the signature + length from Step 4 into the enclosure:

```xml
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Ice-vc</title>
    <link>https://github.com/bavanchun/Ice-vc/releases</link>
    <description>Personal fork of Ice</description>
    <language>en</language>
    <item>
      <title>${VERSION}</title>
      <pubDate>Mon, 27 Jul 2026 00:00:00 +0000</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:edSignature>INSERT_SIGNATURE_HERE</sparkle:edSignature>
      <enclosure
        url="https://github.com/bavanchun/Ice-vc/releases/download/v${VERSION}/Ice-${VERSION}.zip"
        sparkle:os="macos"
        length="INSERT_LENGTH_HERE"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

For subsequent releases, **append** a new `<item>` above the previous one. Sparkle picks the highest `sparkle:version` it can install.

### Step 6 — Push tag, create GitHub release

```bash
git tag v${VERSION}
git push origin v${VERSION}

gh release create v${VERSION} \
  ".release-output/Ice-${VERSION}.zip" \
  ".release-output/appcast.xml" \
  --repo bavanchun/Ice-vc \
  --title "${VERSION}" \
  --notes "Personal build of Ice-vc ${VERSION} (build ${BUILD})."
```

**Both assets must upload to the same release.** Sparkle fetches `releases/latest/download/appcast.xml` (GitHub redirects to the latest release's `appcast.xml`), which then points at the same release's `Ice-${VERSION}.zip`.

### Step 7 — Install locally

```bash
rm -rf /Applications/Ice.app
cp -R .release-output/sign/Ice.app /Applications/

# Clear quarantine (Personal Team signing — Gatekeeper may warn)
xattr -cr /Applications/Ice.app

open /Applications/Ice.app
```

On first launch: grant Accessibility (required) and ScreenRecording (optional, for Ice Bar + appearance editor) permissions. Verify the process is alive and using the fork's own UserDefaults domain:

```bash
pgrep -fl "Ice.app/Contents/MacOS/Ice"
defaults read com.vchun.Ice SUHasLaunchedBefore   # 1 once Sparkle has initialized
```

## Troubleshooting

### `No Account for Team "LC6N3KUML9"` (archive)

Happens with `xcodebuild archive` + automatic signing. Adding the Apple ID in **Xcode → Settings → Accounts** does not fix this on a free Personal Team — see the next error.

### `No signing certificate "Mac Development" found` (archive, any signing style)

This is the actual blocker on Xcode 26.6 with a free Personal Team, confirmed by testing all three: automatic signing, manual signing with plain `CODE_SIGN_IDENTITY=Apple Development`, and manual signing with an SDK-scoped override (`CODE_SIGN_IDENTITY[sdk=macosx*]`). All three fail archive — Xcode's archive action insists on a "Mac Development" cert that free accounts cannot obtain. **Do not keep retrying archive flags.** Switch to `xcodebuild build` (unsigned) + manual `codesign`, as in Step 3.

### `xattr` quarantine warning persists

```bash
xattr -dr com.apple.quarantine /Applications/Ice.app
```

### Sparkle "No updates available" but release is published

- Confirm `appcast.xml` is attached to the **latest** GitHub release (not an older one).
- Confirm `SUFeedURL` in `Ice/Info.plist` is `https://github.com/bavanchun/Ice-vc/releases/latest/download/appcast.xml`.
- Confirm `SUPublicEDKey` matches the Keychain's public key (`generate_keys -p`).
- Confirm `sparkle:edSignature` was generated with the matching private key.
- The shipped `sparkle:version` must be strictly greater than the installed build's `CFBundleVersion`.

### Personal Team cert rotated

Free Personal Team certs can expire. Check:

```bash
security find-identity -v -p codesigning
```

If missing, regenerate through Xcode Accounts → team → "Manage Certificates" → + → Apple Development.

## Future-Release Checklist

- [ ] Bump `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in `Ice.xcodeproj/project.pbxproj` (Debug + Release)
- [ ] Commit changes on `main`
- [ ] `xcodebuild build` (unsigned) → `.release-output/sign/Ice.app`
- [ ] `codesign` inside-out (XPC services → Updater.app → Sparkle.framework → main app)
- [ ] `codesign --verify --verbose=4` confirms "valid on disk"
- [ ] `ditto` zip + `sign_update` for EdDSA signature
- [ ] Update `appcast.xml` (append `<item>`, bump `pubDate`)
- [ ] `git tag v<x.y.z>` + `git push origin v<x.y.z>`
- [ ] `gh release create v<x.y.z> Ice-<x.y.z>.zip appcast.xml`
- [ ] Verify `curl -sIL .../releases/latest/download/appcast.xml` → 302 to new release
- [ ] Install locally, confirm process is running (`pgrep -fl Ice.app`) and `defaults read com.vchun.Ice` shows fork-owned keys
- [ ] Settings → About → Check for Updates reports current version

## Pitfalls

- **Appcast must be on the latest release.** GitHub's `releases/latest/download/<file>` only resolves assets on the most recent published release.
- **Bundle ID conflict.** If upstream `com.jordanbaird.Ice` is also installed, both apps share UserDefaults + keychain. Fork uses `com.vchun.Ice` to avoid this — do not revert.
- **Private key safety.** `~/.config/ice-vc/sparkle-private-ed25519-key` is the only offline backup of the Sparkle signing key. If lost, all future updates require shipping a new `SUPublicEDKey` (forces a manual reinstall, breaking auto-update).
- **Personal Team non-distributability.** Apps signed with the free Personal Team cert run only on Macs registered to the same Apple ID. Notarization requires a paid Apple Developer Program membership.
- **`xcodebuild archive` cannot sign this app on a free Personal Team.** Confirmed across automatic and manual signing styles on Xcode 26.6 — always falls back to `xcodebuild build` (unsigned) + manual `codesign`. Do not spend time retrying archive-based signing flags on a fresh Personal Team; go straight to the unsigned-build path.
- **Sign nested bundles before the outer one.** `codesign` on `Ice.app` alone does not re-sign `Sparkle.framework`'s nested `Updater.app`/`Downloader.xpc`/`Installer.xpc` — each needs its own `codesign` call, innermost first, or the outer signature's sealed resources will mismatch and `codesign --verify` fails.
