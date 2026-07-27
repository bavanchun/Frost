---
phase: 3
title: "Sparkle plist comments and changelog"
status: complete
priority: P3
effort: "20m"
dependencies: []
---

# Phase 3: Sparkle plist comments and changelog

## Overview

Give each of the three Sparkle keys in `Frost/Info.plist` a one-line comment explaining why it holds the value it does, and record the icon change under `CHANGELOG.md`'s `[Unreleased]`.

## Requirements

**Functional**

- Each Sparkle key carries a comment stating its rationale and pointing at the fuller source.
- No key's value changes.
- `CHANGELOG.md` `[Unreleased]` describes the icon change and the automatic migration.

**Non-functional**

- The plist still parses and the app still builds.
- Comments state the constraint and cite the source; they do not duplicate the full explanation already written elsewhere.

## Architecture

`Frost/Info.plist` is a checked-in partial plist: `project.pbxproj` sets both `GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_FILE = Frost/Info.plist` (lines 318-319, 350-351), so Xcode merges this file with generated keys at build time. The build output is a fresh binary plist, so comments never ship — they are purely source-level documentation.

All three keys diverge from upstream Ice and are already listed as divergences in `docs/UPSTREAM.md:26`; the rationale for `SUEnableAutomaticChecks` specifically is in `CHANGELOG.md` under `[1.0.1] > Fixed`. The comments point at those rather than restating them.

**Known fragility, accepted:** Xcode's Property List GUI editor rewrites the file on save and strips XML comments. These comments can therefore disappear silently in an unrelated commit. That is tolerable because `CHANGELOG.md` and `docs/UPSTREAM.md` remain the authoritative record — the comments are a convenience at the point of use, not the source of truth. Edit this file as source, not through the GUI editor.

## Related Code Files

- Modify: `Frost/Info.plist` — add three comments, change no values
- Modify: `CHANGELOG.md` — add entries under `[Unreleased]`

## Implementation Steps

1. Add an XML comment above each key in `Frost/Info.plist`, one line each:

   | Key | Comment content |
   |---|---|
   | `SUEnableAutomaticChecks` | As a menu bar accessory, Frost cannot bring Sparkle's update-permission dialog to the front, so checks are enabled up front to skip that prompt. See `docs/UPSTREAM.md`. |
   | `SUFeedURL` | Points at this fork's releases, not upstream Ice's. |
   | `SUPublicEDKey` | This fork's Ed25519 public key; the private key lives in the Keychain — see `docs/release-guide.md`. |

   Keep each to a single line and let the referenced docs carry the detail.

2. Verify the plist still parses:

   ```bash
   plutil -lint Frost/Info.plist
   ```

3. Add to `CHANGELOG.md` under `[Unreleased]`:

   - **Changed** — the menu bar icon option formerly named "Ice Cube" is now **Snowflake**, drawn from SF Symbols. Anyone who had selected the old icon is moved to Snowflake automatically on first launch; no action needed.
   - **Removed** — the `IceCube` image assets, the last Ice-branded artwork outside the app icon.

   Match the existing entries' voice: full sentences, user-facing effect first, no internal symbol names.

4. Build once to confirm the merged plist is still valid.

## Success Criteria

- [ ] All three Sparkle keys in `Frost/Info.plist` have a comment directly above them
- [ ] No Sparkle key's value changed (`git diff` shows comment lines only)
- [ ] `plutil -lint Frost/Info.plist` reports OK
- [ ] Project builds clean
- [ ] `CHANGELOG.md` `[Unreleased]` covers both the rename and the automatic migration
- [ ] Sparkle still finds the feed on launch (no new updater errors in the log)

## Risk Assessment

**Comments stripped by Xcode's plist GUI editor.** Accepted, as reasoned above — the authoritative record stays in `CHANGELOG.md` and `docs/UPSTREAM.md`, so the loss is cosmetic. No mitigation beyond editing the file as source.

**A malformed comment breaks the plist.** `plutil -lint` at step 2 catches it before the build does.

**Overstating the change in `CHANGELOG.md`.** The migration is invisible and needs no user action; the entry should say so plainly rather than implying a manual upgrade step.
