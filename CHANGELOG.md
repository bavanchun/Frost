# Changelog

All notable changes to Frost are recorded here. Frost follows Semantic Versioning; the bump rules and approval gate are defined in [`docs/release-guide.md`](docs/release-guide.md).

## [Unreleased]

### Added

- Documented development workflow in [`docs/DEVELOPMENT_WORKFLOW.md`](docs/DEVELOPMENT_WORKFLOW.md): trunk-based branching, pull requests into `main`, Conventional Commits, and the upstream synchronization policy.
- Documented the upstream Ice relationship and sync state in [`docs/UPSTREAM.md`](docs/UPSTREAM.md).

### Changed

- Release tags are now SSH-signed. `main` is protected: changes reach it through pull requests only.

## [1.0.1] - 2026-07-28

### Fixed

- Removed Sparkle's update-permission prompt, which appeared on first launch with buttons that could not be clicked. As a menu bar accessory app, Frost cannot bring that dialog to the front. Automatic update checks are now on by default and both settings remain available in Settings → About.

### Changed

- Completed the rebrand in files the initial sweep missed: SwiftLint configuration, funding metadata, issue templates, and the code of conduct now refer to Frost and route to this fork.

## [1.0.0] - 2026-07-28

### Changed

- Renamed the application from Ice to Frost across every visible layer: app name, Xcode project and scheme, source folder, Swift symbols, menu titles, and documentation.
- Changed the bundle identifier to `com.vchun.Frost`.

### Upgrade notes

- macOS treats the new bundle identifier as a different application. **Accessibility and Screen Recording permissions must be granted again**, and settings from the previous build are not carried over.
- Remove any older `Ice.app` build to avoid two menu bar icons competing for the same items.

## [0.11.12] - 2026-07-27

### Added

- First personal build of the fork: own bundle identifier, signing identity, copyright, and Sparkle update feed, so it no longer shares preferences or update channel with upstream Ice.

---

Releases before this fork are documented in [jordanbaird/Ice](https://github.com/jordanbaird/Ice/releases).

[Unreleased]: https://github.com/bavanchun/Frost/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/bavanchun/Frost/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/bavanchun/Frost/compare/v0.11.12...v1.0.0
[0.11.12]: https://github.com/bavanchun/Frost/releases/tag/v0.11.12
