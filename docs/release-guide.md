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

### 2. Apple ID in Xcode (for automatic signing)

If using automatic signing, open **Xcode → Settings → Accounts → +** and add the Apple ID (`van0328728779@icloud.com`). The team is `LC6N3KUML9` (Personal Team, free).

If the Apple ID is not added, archive will fail with `No Account for Team "LC6N3KUML9"`. Workaround: override flags on `xcodebuild archive` (see [Troubleshooting](#troubleshooting)).

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

### Step 3 — Resolve deps, archive, export

```bash
# Refresh SPM deps (only if Package.resolved changed)
xcodebuild -resolvePackageDependencies -scheme Ice -project Ice.xcodeproj

# Clean + archive (output dir avoids the literal word 'build' which trips some hooks)
rm -rf .release-output/
xcodebuild archive \
  -scheme Ice \
  -project Ice.xcodeproj \
  -configuration Release \
  -archivePath .release-output/Ice.xcarchive \
  -allowProvisioningUpdates

# Export the .app from the archive
xcodebuild -exportArchive \
  -archivePath .release-output/Ice.xcarchive \
  -exportOptionsPlist .release-output/ExportOptions.plist \
  -exportPath .release-output/export

# Verify signing
codesign -dv --verbose=4 .release-output/export/Ice.app
```

Expected codesign output: `Authority=Apple Development: van0328728779@icloud.com (LC6N3KUML9)`, `TeamIdentifier=LC6N3KUML9`, `Runtime Hardened`.

The `ExportOptions.plist` lives at `.release-output/ExportOptions.plist`:

```xml
<plist version="1.0">
<dict>
  <key>method</key><string>development</string>
  <key>teamID</key><string>LC6N3KUML9</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
```

### Step 4 — Zip, sign zip, generate appcast

```bash
VERSION=0.11.12
BUILD=1117

# Zip preserving .app bundle structure
cd .release-output/export
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
cp -R .release-output/export/Ice.app /Applications/

# Clear quarantine (Personal Team signing — Gatekeeper may warn)
xattr -cr /Applications/Ice.app

open /Applications/Ice.app
```

On first launch: grant Accessibility (required) and ScreenRecording (optional, for Ice Bar + appearance editor) permissions.

## Troubleshooting

### `No Account for Team "LC6N3KUML9"`

Xcode automatic signing can't reach Apple's provisioning servers. Either:

- Add the Apple ID in **Xcode → Settings → Accounts**, OR
- Override signing at the command line:

  ```bash
  xcodebuild archive ... \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM=LC6N3KUML9 \
    CODE_SIGN_REQUIRE_APPROVAL=NO
  ```

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
- [ ] `xcodebuild archive` + `-exportArchive` → `.release-output/export/Ice.app`
- [ ] `ditto` zip + `sign_update` for EdDSA signature
- [ ] Update `appcast.xml` (append `<item>`, bump `pubDate`)
- [ ] `git tag v<x.y.z>` + `git push origin v<x.y.z>`
- [ ] `gh release create v<x.y.z> Ice-<x.y.z>.zip appcast.xml`
- [ ] Verify `curl -sIL .../releases/latest/download/appcast.xml` → 302 to new release
- [ ] Install locally, confirm Settings → About → Check for Updates reports current version

## Pitfalls

- **Appcast must be on the latest release.** GitHub's `releases/latest/download/<file>` only resolves assets on the most recent published release.
- **Bundle ID conflict.** If upstream `com.jordanbaird.Ice` is also installed, both apps share UserDefaults + keychain. Fork uses `com.vchun.Ice` to avoid this — do not revert.
- **Private key safety.** `~/.config/ice-vc/sparkle-private-ed25519-key` is the only offline backup of the Sparkle signing key. If lost, all future updates require shipping a new `SUPublicEDKey` (forces a manual reinstall, breaking auto-update).
- **Personal Team non-distributability.** Apps signed with the free Personal Team cert run only on Macs registered to the same Apple ID. Notarization requires a paid Apple Developer Program membership.
