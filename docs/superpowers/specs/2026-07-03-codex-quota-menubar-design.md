# Codex Quota Menu Bar Design

Date: 2026-07-03

## Goal

Move the Codex quota utility from a draggable floating desktop panel into the macOS menu bar, using a copied project at `/Users/wuhan/wh/myProject/codex-quota-menubar`.

The new app should remain lightweight and glanceable: the menu bar item shows the compact quota summary, and clicking it opens a native popover with the detailed quota view.

## Scope

In scope:

- Build in the copied project only.
- Use a native macOS menu bar app surface.
- Keep the existing Codex app-server quota fetcher.
- Keep the 2-minute automatic refresh loop and manual refresh action.
- Keep the existing compact text and detailed quota content.
- Remove floating-panel behavior from the app runtime.
- Package as a menu bar utility using `LSUIElement`.

Out of scope:

- Launch-at-login support.
- Custom menu bar icons or SF Symbol-only mode.
- Multi-account support.
- Direct reads of Codex auth or account files.
- Reworking the JSON-RPC protocol layer.

## User Experience

The app appears in the macOS menu bar. Its title is the existing compact quota string, for example:

```text
Codex 剩余 85% / 周 98%
```

When no quota snapshot is available, it shows:

```text
Codex --
```

Clicking the menu bar item opens a popover. The popover shows:

- plan badge when available,
- 5-hour and weekly quota rows,
- remaining percentages and progress bars,
- reset times,
- last refresh time,
- current fetch error when present,
- refresh and quit controls.

The app no longer draws or moves a borderless always-on-top window. Hover expansion and drag positioning are removed because the menu bar popover is opened by macOS.

## Architecture

Use SwiftUI `MenuBarExtra` as the app shell. This follows the reference project's intended architecture and keeps the behavior native to macOS.

Keep the existing `CodexQuotaCore` target unchanged except for small display helpers if tests need a focused unit. The app executable owns:

- `QuotaStore`: observable fetch state and timer.
- `QuotaPopoverView`: detailed SwiftUI popover content.
- `CodexQuotaMenuBarApp`: SwiftUI `@main` entry point with `MenuBarExtra`.

The previous `FloatingPanelController`, `FloatingPanelPositionStore`, drag gesture handling, and hover expansion state are deleted from the executable.

## Data Flow

1. App launches as an accessory-style menu bar app.
2. `QuotaStore.start()` runs once from the menu bar scene.
3. The store fetches quota immediately through `CodexAppServerClient`.
4. A timer refreshes every 120 seconds.
5. `MenuBarExtra` title reads `QuotaFormatting.compactText(for: store.snapshot)`.
6. The popover reads the same store and triggers `store.refresh()` for manual refresh.

## Packaging

The existing `scripts/build-app.sh` remains the packaging entry point. It should build the renamed menu bar product and write an app bundle under `dist`.

The generated `Info.plist` must include:

```xml
<key>LSUIElement</key>
<true/>
```

This keeps the app as a menu bar utility instead of a Dock app.

## Testing

Automated tests continue to use the current executable test runner:

```bash
swift run CodexQuotaCoreTests
```

Add a small core test only if the menu bar title behavior needs a new helper. UI popover behavior is verified by build and packaging checks because SwiftUI menu bar scenes are not practical to exercise in the existing command-line test harness.

Final verification:

- `swift run CodexQuotaCoreTests`
- `swift build`
- `./scripts/build-app.sh`
- inspect packaged `LSUIElement`

## Success Criteria

- Source changes are only in `/Users/wuhan/wh/myProject/codex-quota-menubar`.
- The app uses `MenuBarExtra`, not `NSPanel`, as its primary UI.
- The menu bar title shows current compact quota text.
- Clicking the menu bar item opens detailed quota information.
- The package builds and the app bundle is created.
- The packaged app declares `LSUIElement=true`.
