# Upstream Relationship

Frost is derived from [jordanbaird/Ice](https://github.com/jordanbaird/Ice), licensed under GPL-3.0. The overwhelming majority of the source code originates from that project.

## Upstream

- Repository: https://github.com/jordanbaird/Ice
- Tracking branch: `upstream/main`
- Last synchronized revision: `11edd39115f3f43a83ae114b5348df6a0e1741cf` ("Update issue templates", 2025-09-20)
- Last synchronized release: none — the fork point is ahead of upstream's most recent tagged release (`0.11.12`, 2024-10-29)

At the fork point Frost contains every upstream `main` commit; the divergence is entirely Frost-side. Add the remote before any sync work:

```bash
git remote add upstream https://github.com/jordanbaird/Ice.git
git fetch upstream
git rev-list --left-right --count main...upstream/main   # left = Frost-only, right = unmerged upstream
```

## Frost-specific changes

- Product identity: app name, `AppIcon` usage, and every user-facing string
- Bundle identifier `com.vchun.Frost` and `DEVELOPMENT_TEAM`, replacing upstream's `com.jordanbaird.Ice`
- Xcode project, target, scheme, and source folder renamed from `Ice` to `Frost`
- Swift symbols and filenames renamed from `Ice*` to `Frost*`
- Menu bar icon options: upstream's "Ice Cube" entry is a Snowflake SF Symbol here, the `IceCube` image assets are gone, and the surviving stroke image is `FrostMarkStroke` at the asset catalog root
- Sparkle update configuration: `SUFeedURL` points at this fork's releases, `SUPublicEDKey` is this fork's key, and `SUEnableAutomaticChecks` suppresses the permission prompt that an accessory app cannot make clickable
- Release infrastructure: unsigned build plus manual inside-out `codesign`, documented in [`release-guide.md`](release-guide.md)
- Documentation: README, `FREQUENT_ISSUES.md`, [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md), and this file
- `LICENSE` carries the fork maintainer's copyright alongside the original Jordan Baird notices, which are preserved verbatim

## Sync policy

Security and critical fixes are prioritized. Features are evaluated individually. All upstream integrations use a dedicated `upstream/ice-vX.Y.Z` branch and a pull request, per [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) § 20.

Upstream is never merged directly into `main`.

## Known conflict areas

Every item under "Frost-specific changes" is a conflict candidate. The renames make conflicts unavoidable rather than occasional: upstream still calls the project `Ice` at the project-file, symbol, filename, and string level, so any upstream commit touching those layers will conflict.

The highest-risk areas, in order:

- `Frost.xcodeproj/project.pbxproj` — upstream's `Ice.xcodeproj` has no shared path with it
- Swift files renamed from `Ice*.swift`, where Git may not detect the rename
- `Frost/Info.plist` — Sparkle keys diverge completely
- User-facing strings and menu titles
- `README.md`, `LICENSE`, and release documentation

After every upstream merge, verify Frost identity is intact before opening the pull request:

```bash
grep -rn "\bIce\b" Frost/ --include="*.swift" --include="*.plist"
grep -E "PRODUCT_BUNDLE_IDENTIFIER|MARKETING_VERSION" Frost.xcodeproj/project.pbxproj | sort -u
```

Update this file after every upstream synchronization.
