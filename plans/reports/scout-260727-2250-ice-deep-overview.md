# Ice — Deep Scout Report

> Fork `Ice-vc` by vchun of [jordanbaird/Ice](https://github.com/jordanbaird/Ice). macOS menu bar manager. Hides/shows menu bar items via 3-section model, with appearance customization, drag-drop layout, search, Ice Bar popover, hotkeys, auto-rehide.

## 0. Identity & Build

| | |
|---|---|
| Bundle ID | `com.jordanbaird.Ice` |
| Target | macOS 14.0+, Swift 5.0, SwiftUI + AppKit |
| License | GPL-3.0 |
| LOC / Files | ~18,156 / 116 Swift |
| App Sandbox | **OFF** (required for private CGS APIs + global event taps) |
| Entitlements | `app-sandbox=false`, `files.user-selected.read-only=true` |
| Code sign | Automatic, Team `K2ATHQPJDP` (upstream author) |
| Scheme | `Ice.xcscheme` (single) |
| CI | `.github/workflows/lint.yml` — SwiftLint `--strict` on ubuntu-latest (no build/test CI) |
| Upstream | Jordan Baird (1118 commits); fork adds 0 commits on top currently |

### SPM Dependencies

| Pkg | Use |
|---|---|
| `AXSwift` | Accessibility API — used ONLY for `AXSwift.checkIsProcessTrusted()` permission probe |
| `Ifrit` | Fuse.js fuzzy search for menu bar item search panel |
| `CompactSlider` | `IceSlider` UI component |
| `LaunchAtLogin-Modern` | "Launch at login" toggle |
| `Sparkle` 2.6.4 | Auto-updates; feed `jordanbaird.github.io/ice-releases/appcast.xml`, Ed25519 signed |

**Note:** AXSwift presence is misleading — actual menu bar item detection uses **CGWindowList + ScreenCapture**, not Accessibility API.

---

## 1. High-Level Architecture

```
@main IceApp (SwiftUI App)
  └── AppDelegate (NSApplicationDelegateAdaptor)
       └── AppState (@MainActor ObservableObject — THE hub)
            ├── navigationState: AppNavigationState
            ├── hotkeyRegistry: HotkeyRegistry (nonisolated, Carbon)
            ├── menuBarManager ──┐
            ├── itemManager      │  Coordinates via weak appState refs
            ├── appearanceManager│
            ├── eventManager     │
            ├── imageCache       │
            ├── settingsManager ─┤
            │    ├── generalSettingsManager
            │    ├── advancedSettingsManager
            │    └── hotkeySettingsManager
            ├── permissionsManager
            ├── updatesManager (Sparkle)
            └── userNotificationManager
```

**Boot flow:** `IceApp.init()` → swizzle `NSSplitViewItem.canCollapse` → `MigrationManager.migrateAll()` → assign appState to AppDelegate → on `applicationDidFinishLaunching`, check permissions → setup or show PermissionsWindow.

---

## 2. Module Map

### 2.1 Main & Lifecycle (`Ice/Main/`)

- `IceApp.swift:8` — `@main`, declares 2 window scenes (Settings + Permissions)
- `AppState.swift:10` — `@MainActor final class`, 9 lazy manager properties, `performSetup():181` orchestrates init, window management, activation policy, ShowOnHover lock (`preventShowOnHover`/`allowShowOnHover`)
- `AppDelegate.swift` — permission gate on launch, background cursor enable
- `Navigation/AppNavigationState.swift:9` — 5 `@Published` flags: `isAppFrontmost`, `isSettingsPresented`, `isIceBarPresented`, `isSearchPresented`, `settingsNavigationIdentifier`
- `NavigationIdentifier.swift` / `SettingsNavigationIdentifier.swift` — 6-tab enum: `.general`, `.menuBarLayout`, `.menuBarAppearance`, `.hotkeys`, `.advanced`, `.about`

### 2.2 MenuBar Feature (`Ice/MenuBar/`) — Heart of the app

**Coordinator:** `MenuBarManager.swift:12` owns 3 `MenuBarSection`s, `IceBarPanel`, `MenuBarSearchPanel`. `performSetup()` → `initializeSections()` + `configureCancellables()`.

**3-section model** (`MenuBarSection.swift:12`):
- `.visible` — Ice icon control, left section
- `.hidden` — toggleable middle section
- `.alwaysHidden` — right section

Each section owns a `ControlItem` (`ControlItem.swift:10`) = `NSStatusItem` with autosave name:
- `"SItem"` (iceIcon), `"HItem"` (hidden), `"AHItem"` (alwaysHidden)
- `isVisible` toggles section presence; lengths: `standard=variable`, `expanded=10000` (forces showing neighbors)
- Position persisted via `StatusItemDefaults[.preferredPosition]`

**Hide/Show triggers** (EventManager):
- Click (`handleShowOnClick:148`), Hover (`handleShowOnHover:348`), Scroll (`handleShowOnScroll:401`)
- Hotkey via Carbon registry → `section.toggle()`
- No native swipe — scroll proxies

**Rehide strategies** (`RehideStrategy.swift:9`):
- `.smart` — rehide on click into regular app window (waits 0.25s, validates window)
- `.timed` — auto-hide after interval (UniversalEventMonitor tracks mouse below menu bar)
- `.focusedApp` — frontmost app change → hide after 0.1s delay

**Item introspection** — **NO AXSwift**:
- `WindowInfo.swift:9` wraps `CGWindowListCopyWindowInfo`; menu bar items = `layer == kCGStatusWindowLevel`
- `MenuBarItemManager.getMenuBarItems():174` filters by display bounds, on-screen, active space
- `MenuBarItemInfo` encoded as `"namespace:title"` string

**Image cache** (`MenuBarItemImageCache.swift:102`):
- Primary: composite `ScreenCapture.captureWindows()` of all item windows
- Fallback: per-window capture
- CG options `[.boundsIgnoreFraming, .bestResolution]`
- Throttle 0.5s, min interval 3s

**Drag-and-drop rearrange:**
- `MenuBarItemManager.move(item:to:):1075` injects CGEvents simulating ⌘+drag at `(20000, 20000)` (off-screen coordinate trick)
- 5 retries with `wakeUpItem` fallback
- Section boundaries enforced by control-item ordering

**Appearance engine** (`MenuBarAppearanceManager.swift:11`):
- Manages `MenuBarAppearanceConfigurationV2` (light/dark/static modes)
- `MenuBarOverlayPanel.swift:12` — `NSPanel` at `.statusBar` level, ignores mouse, transparent
- Drawing pipeline (`:646-787`): wallpaper capture → shape path (full/split/none + square/round caps) → shadow → border (doubled line width hack) → tint (solid/gradient @ 0.2 opacity)
- V1→V2 migration on first launch (`MenuBarAppearanceConfigurationV1.swift:34`)

**Ice Bar** (`Ice/UI/IceBar/IceBar.swift:11-190`):
- `NSPanel` at `.mainMenu + 1` level, `.fullScreenAuxiliary` collection behavior
- 3 positioning modes: `.dynamic`, `.mousePointer`, `.iceIcon` — all clamped to screen bounds
- Show → cache items → update image cache → host SwiftUI view → `orderFrontRegardless()`
- Click → `itemManager.tempShowItem()` (moves to visible, executes click after 25ms)

**Search panel** (`MenuBarSearchPanel.swift:11`):
- `NSPanel` `.floating` + `.utilityWindow`
- Fuse.js fuzzy matching via Ifrit, threshold 0.5
- Real-time filter, keyboard navigation, Escape/outside-click to close
- Click → `tempShowItem()` → 25ms delay → execute

**Spacing manager** (`MenuBarItemSpacingManager.swift:10`):
- Writes **private** UserDefaults keys: `NSStatusItemSpacing`, `NSStatusItemSelectionPadding`
- Applies via `defaults -currentHost write -globalDomain` shell command
- Then **relaunches every menu-bar-bearing app** in parallel (skip ControlCenter + Ice)
- Force-terminate after 1s, suggests logout on failure

### 2.3 UI Layer (`Ice/UI/`)

**Design-system (reusable):**
- `IceForm`, `IceGroupBox`, `IceSection`, `IceLabeledContent`, `IcePicker`, `IceMenu`, `IceSlider` — SwiftUI wrappers mimicking macOS native form patterns
- ViewModifiers: `bottomBar`, `layoutBarStyle`, `localEventMonitor`, `onFrameChange`, `onKeyDown`, `once`, `readWindow`, `erasedToAnyView`, `RemoveSidebarToggle`
- `AnnotationView`, `BetaBadge`, `SectionedList`, `VisualEffectView`

**Feature-specific:**
- `IceBar/IceBarPanel` + `IceBarColorManager` (samples avg menu bar color for adaptive bg)
- `LayoutBar/*` — drag-drop arrange UI (`LayoutBarContainer` is core, calls `itemManager.slowMove`)
- `HotkeyRecorder/HotkeyRecorderModel.swift:9` — `isRecording` flag, `LocalEventMonitor` for keyDown, validates against system-reserved combos
- `CustomGradientPicker` — gradient editor (add/drag/distribute/delete stops), used for menu bar tint
- `CustomColorPicker` — `NSColorWell` wrapper via `NSViewRepresentable`
- `Shapes/AnyInsettableShape` — type-erased insettable shape for menu bar shape picker

### 2.4 Settings (`Ice/Settings/`)

- `SettingsWindow.swift` + `SettingsView.swift:8` — `NavigationSplitView` w/ sidebar (190/210/230 width tiers) + detail
- `SettingsManager` base — `performSetup()` calls `loadInitialState()` + `configureCancellables()`
- Each `@Published` prop bidirectionally synced to `Defaults` (custom UserDefaults wrapper) via Combine sink
- `ControlItemImageSet` encoded as JSON data, hotkeys as `[HotkeyAction.rawValue: Data]`
- Per-pane: `GeneralSettingsPane` (icon, show/hide, rehide, spacing), `MenuBarLayoutSettingsPane` (per-section LayoutBar), `MenuBarAppearanceSettingsPane` (wraps editor), `HotkeysSettingsPane` (HotkeyRecorder per action), `AdvancedSettingsPane`, `AboutSettingsPane`

### 2.5 Events & Hotkeys

**Event monitors** (`Ice/Events/`):
- `LocalEventMonitor` — `NSEvent.addLocalMonitorForEvents` (app-local)
- `GlobalEventMonitor` — `NSEvent.addGlobalMonitorForEvents` (system-wide, observe-only)
- `UniversalEventMonitor` — combines local+global
- `RunLoopLocalEventMonitor` — CFRunLoop-based w/ interception
- `EventTap.swift:11` — low-level `CGEvent.tapCreate()` wrapper (locations: `.hidEventTap`, `.sessionEventTap`, `.annotatedSessionEventTap`, `.pid(pid_t)`)

**EventManager** (`EventManager.swift:11`):
- 5 `UniversalEventMonitor` instances: mouseDown/Up/Dragged/Moved/ScrollWheel
- Handlers: `handleShowOnClick`, `handleShowOnHover`, `handleShowOnScroll`, `handleSmartRehide`, `handleShowRightClickMenu`

**Hotkeys** (`Ice/Hotkeys/`) — **legacy Carbon**:
- `KeyCode` (kVK_* constants), `Modifiers` (OptionSet), `KeyCombination`, `Hotkey` (comb+action)
- `HotkeyRegistry.swift:11` uses `RegisterEventHotKey()` Carbon API, signature `OSType(1231250720)`
- Auto-unregister during menu tracking, re-register after
- 6 actions (`HotkeyAction.swift:6`): `toggleHiddenSection`, `toggleAlwaysHiddenSection`, `searchMenuBarItems`, `enableIceBar`, `showSectionDividers`, `toggleApplicationMenus`

### 2.6 Support Services

**Updates** (`UpdatesManager.swift:10`): Sparkle SPUStandardUpdaterController; published `canCheckForUpdates`/`lastUpdateCheckDate`; non-user-initiated updates → local notification; debug mode disables checks.

**Permissions** (`Ice/Permissions/`):
- `Permission` base (`@MainActor ObservableObject`) w/ 1s polling timer, async `waitForPermission()` via `withCheckedContinuation`
- **AccessibilityPermission** (REQUIRED) — via `AXSwift.checkIsProcessTrusted()`; needed for item arrange/real-time info
- **ScreenRecordingPermission** (OPTIONAL) — via `ScreenCapture.checkPermissions()`; needed for appearance editor + item images; opens `x-apple.systempreferences:...Privacy_ScreenCapture`
- State machine: `.missingPermissions` → `.hasRequiredPermissions` → `.hasAllPermissions`

**UserNotifications** — single ID `.updateCheck`; UserNotificationManager requests badge/alert/sound perms.

### 2.7 Utilities (`Ice/Utilities/`) — 20 files

| File | Purpose |
|---|---|
| `Constants.swift` | App version/build, bundle ID, window IDs |
| `Defaults.swift` | Type-safe UserDefaults wrapper (30+ keys) |
| `MigrationManager.swift` | Multi-version migration: 0.8.0, 0.10.0, 0.10.1, 0.11.10 |
| `ObjectStorage.swift` | ObjC runtime associated objects |
| `ScreenCapture.swift` | Permission checks, SCShareableContent on macOS 15+ |
| `StatusItemDefaults.swift` | NSStatusItem autosave proxy |
| `WindowInfo.swift` | CGWindowList wrapper, menu bar item detection |
| `RehideStrategy.swift` | smart/timed/focusedApp enum |
| `SystemAppearance.swift` | Light/dark detection |
| `Logging.swift` | OSLog wrapper, category-based |
| `MouseCursor.swift` | CGEvent cursor ops (location/hide/show/warp) |
| `Notifications.swift` | DistributedNotificationCenter interfaceTheme |
| `Predicates.swift` | Window predicates (wallpaper, menuBar, sections) |
| `TaskTimeout.swift` | TaskGroup-based timeout |
| `CodableColor.swift` | CGColor Codable via ICC profile |
| `IconResource.swift` | `.systemSymbol` / `.assetCatalog` |
| `BindingExposable.swift` | `@dynamicMemberLookup` SwiftUI Binding |
| `Injection.swift` | `update()` / `with()` functional helpers |
| `LocalizedErrorWrapper.swift` | LocalizedError wrap |
| `Extensions.swift` | 400+ lines: Bundle/CGColor/CGImage/NSBezierPath/NSImage/NSScreen/NSStatusItem/Publisher |

### 2.8 Bridging & Swizzling

**`Bridging.swift:8`** — wraps private **Core Graphics Window Server (CGS)** APIs:
- `CGSConnection`: `setConnectionProperty` ("SetsCursorInBackground"), `getConnectionProperty`
- `CGSWindow`: `getWindowFrame`, window list ops (count, on-screen, menu bar)
- `CGSSpace`: `activeSpaceID`, `getSpaceList`, `isWindowOnActiveSpace`, `isSpaceFullscreen`
- Process responsivity: `GetProcessForPID` + `CGSEventIsAppUnresponsive`

**Private shims** (`Bridging/Shims/Private.swift`): 13+ `@_silgen_name` decls for `CGSMainConnectionID`, `CGSCopyConnectionProperty`, `CGSGetActiveSpace`, `CGSGetWindowList`, `CGSGetProcessMenuBarWindowList`, etc.

**Deprecated shims** (`Deprecated.swift`): `GetProcessForPID`.

**NSSplitViewItem swizzling** (`Swizzling/...:8`): `method_exchangeImplementations` on `canCollapse` → returns false in Settings window to prevent sidebar collapse.

---

## 3. Key Patterns & Decisions

- **State ownership:** AppState owns 9 lazy `@MainActor` managers; managers weak-ref appState (no retain cycles).
- **Observation:** Legacy `ObservableObject` + `@Published` everywhere; **`@Observable` (Swift 5.9+) NOT used**.
- **Reactive:** Combine sinks sync `@Published` ↔ `Defaults` (UserDefaults).
- **Persistence:** UserDefaults (via `Defaults` wrapper) for primitives + JSON-encoded structs (appearance configs, ControlItemImageSet, hotkey dicts).
- **AppKit/SwiftUI mix:** SwiftUI for settings/UI; AppKit `NSPanel`/`NSStatusItem` for menu bar overlay and Ice Bar; bridged via `NSViewRepresentable`.
- **Window levels:** Ice Bar `.mainMenu + 1`, Overlay `.statusBar`, Search `.floating`.
- **Migrations:** Linear, version-stamped; no rollback path.
- **Logging:** OSLog w/ category-based static loggers, `.public` privacy.

---

## 4. Risks & Tech Debt

| Risk | Detail |
|---|---|
| **Private API dependence** | CGS Window Server (`CGSGetWindowList`, etc.) undocumented; could break any macOS release. Spacing keys `NSStatusItemSpacing`/`NSStatusItemSelectionPadding` also private. |
| **Carbon hotkeys** | `RegisterEventHotKey` deprecated; modern alternative (`CGEventTap` + custom dispatch) not adopted. |
| **CGEvent injection** | Drag-drop uses ⌘+drag simulation at (20000, 20000); 5 retries suggest fragility. `scrombleEvent()` dual-tap complexity hints at macOS-version quirks. |
| **App Sandboxing off** | Required for private APIs but blocks Mac App Store distribution. |
| **No test CI** | Only SwiftLint; no unit/UI tests in CI. |
| **Mixed observation** | Could modernize to `@Observable` for perf. |
| **Sparkle feed hardcoded** | `SUFeedURL` points to upstream author's appcast.xml; fork may auto-update over upstream. |
| **Process relaunch for spacing** | Kills & restarts all menu-bar apps in parallel; Spotlight special-cased; logout fallback. |
| **Hardcoded team `K2ATHQPJDP`** | Fork uses upstream author's dev team in pbxproj. |

---

## 5. Unresolved Questions

1. **Fork intent** — Why was `Ice-vc` created? No commits ahead of upstream; is this a personal build, planned contribution fork, or derivative work?
2. **Sparkle feed ownership** — Does the fork intend to ship its own appcast.xml, or rely on upstream's (risk of fork auto-updating back to upstream Ice)?
3. **Drag-drop reliability** — Empirical success rate of CGEvent injection across macOS 14/15/16?
4. **Multi-display/notch edge cases** — Code has notch + multi-display special cases; do section boundaries ever desync across displays?
5. **ScreenCaptureKit migration** — `ScreenCapture.swift` references SCShareableContent on macOS 15+; is full ScreenCaptureKit migration planned?
6. **Permission UX** — Accessibility required vs ScreenRecording optional; what features silently degrade without ScreenRecording?
7. **Test coverage** — Are there any tests at all? (CI only lints.)
8. **`scrombleEvent` semantics** — Why dual event taps + null events for CGEvent injection? Tied to specific macOS bug?
9. **Hotkey signature `1231250720`** — What's the meaning/source of this magic OSType?
10. **Appearance V1→V2 downgrade** — Is there any path back if users prefer V1?
