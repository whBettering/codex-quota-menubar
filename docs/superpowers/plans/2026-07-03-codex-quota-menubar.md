# Codex Quota Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the copied Codex quota utility into a native macOS menu bar app.

**Architecture:** Keep `CodexQuotaCore` as the tested quota protocol and formatting library. Replace the AppKit floating panel executable with a SwiftUI `MenuBarExtra` executable that shares the existing `QuotaStore` refresh behavior and renders a fixed-size popover.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI `MenuBarExtra`, Foundation timers, existing executable Swift test runner, shell packaging script.

---

## File Structure

- `Package.swift`
  - Rename the package and executable product to `CodexQuotaMenubar`.
  - Keep `CodexQuotaCore` and the executable test runner.
- `Sources/CodexQuotaWidget/CodexQuotaWidgetApp.swift`
  - Replace AppKit `NSPanel` runtime with SwiftUI `MenuBarExtra`.
  - Keep `--print-quota`.
  - Keep `QuotaStore`.
  - Replace `QuotaView` with `QuotaPopoverView`.
- `Tests/CodexQuotaCoreTests/QuotaFormattingTests.swift`
  - Add a focused test for the compact menu bar title behavior if needed.
- `Tests/CodexQuotaCoreTests/QuotaMappingTests.swift`
  - Register any new test.
- `scripts/build-app.sh`
  - Build `CodexQuotaMenubar`.
  - Emit `dist/CodexQuotaMenubar.app`.
  - Add `CFBundleName`, version keys, minimum system version, and `LSUIElement=true`.
- `docs/superpowers/specs/2026-07-03-codex-quota-menubar-design.md`
  - Design record.

## Task 1: Establish Copied Project Baseline

**Files:**
- Read: `Package.swift`
- Read: `Sources/CodexQuotaWidget/CodexQuotaWidgetApp.swift`
- Read: `scripts/build-app.sh`

- [ ] **Step 1: Verify the copied project path**

Run:

```bash
pwd
```

Expected: `/Users/wuhan/wh/myProject/codex-quota-menubar`.

- [ ] **Step 2: Run the existing executable test runner**

Run:

```bash
swift run CodexQuotaCoreTests
```

Expected: existing quota mapping, formatting, JSON-RPC, and floating placement tests pass before menu bar edits begin.

## Task 2: Add A Red Test For Menu Bar Display Text

**Files:**
- Modify: `Tests/CodexQuotaCoreTests/QuotaFormattingTests.swift`
- Modify: `Tests/CodexQuotaCoreTests/QuotaMappingTests.swift`
- Modify: `Sources/CodexQuotaCore/QuotaFormatting.swift`

- [ ] **Step 1: Write the failing test**

Append to `Tests/CodexQuotaCoreTests/QuotaFormattingTests.swift`:

```swift
func testMenuBarTitleUsesCompactQuotaText() throws {
    let snapshot = QuotaSnapshot(
        primary: QuotaWindow(usedPercent: 20, durationMinutes: 300, resetsAt: nil),
        secondary: QuotaWindow(usedPercent: 45, durationMinutes: 10080, resetsAt: nil),
        planType: "plus",
        resetCreditsAvailable: 1,
        fetchedAt: Date()
    )

    try expectEqual(QuotaFormatting.menuBarTitle(for: snapshot), "Codex 剩余 80% / 周 55%", "menu bar title")
    try expectEqual(QuotaFormatting.menuBarTitle(for: nil), "Codex --", "missing menu bar title")
}
```

Register it in `TestRunner.tests`:

```swift
("testMenuBarTitleUsesCompactQuotaText", testMenuBarTitleUsesCompactQuotaText),
```

- [ ] **Step 2: Verify RED**

Run:

```bash
swift run CodexQuotaCoreTests
```

Expected: compile failure because `QuotaFormatting.menuBarTitle(for:)` does not exist.

- [ ] **Step 3: Implement the helper**

Add to `Sources/CodexQuotaCore/QuotaFormatting.swift`:

```swift
public static func menuBarTitle(for snapshot: QuotaSnapshot?) -> String {
    compactText(for: snapshot)
}
```

- [ ] **Step 4: Verify GREEN**

Run:

```bash
swift run CodexQuotaCoreTests
```

Expected: all registered executable tests pass.

## Task 3: Replace Floating Panel With MenuBarExtra

**Files:**
- Modify: `Sources/CodexQuotaWidget/CodexQuotaWidgetApp.swift`

- [ ] **Step 1: Rewrite the executable shell**

Replace the AppKit manual lifecycle, `FloatingPanelController`, `FloatingPanelPositionStore`, hover expansion, and drag gesture code with:

```swift
import CodexQuotaCore
import SwiftUI

@main
@MainActor
struct CodexQuotaMenuBarApp: App {
    @StateObject private var store = QuotaStore(fetcher: CodexAppServerClient())

    init() {
        if CommandLine.arguments.contains("--print-quota") {
            Self.printQuotaAndExit()
        }
    }

    var body: some Scene {
        MenuBarExtra(QuotaFormatting.menuBarTitle(for: store.snapshot)) {
            QuotaPopoverView(store: store)
                .onAppear {
                    store.start()
                }
        }
        .menuBarExtraStyle(.window)
    }

    private static func printQuotaAndExit() -> Never {
        Task {
            do {
                let snapshot = try await CodexAppServerClient().fetchQuota()
                print(QuotaFormatting.compactText(for: snapshot))
                exit(0)
            } catch {
                fputs("\(error)\n", stderr)
                exit(1)
            }
        }
        dispatchMain()
    }
}
```

Keep `QuotaStore` with its timer and refresh behavior.

- [ ] **Step 2: Add the popover view**

Create `QuotaPopoverView` in the same file using the existing expanded card content. It should:

- have a stable width around `360`,
- use a `VStack` with plan badge, refresh button, quit button, quota rows, last update, and error text,
- call `store.refresh()` from the refresh button,
- call `NSApp.terminate(nil)` from the quit button.

- [ ] **Step 3: Remove floating-only code**

Delete:

- `AppRuntime`,
- `FloatingPanelController`,
- `FloatingPanelPositionStore`,
- `QuotaView`,
- drag gesture state,
- hover expansion callbacks,
- `FloatingWindowPlacement` usage from the app target.

- [ ] **Step 4: Build**

Run:

```bash
swift build
```

Expected: build succeeds with no references to removed floating panel types.

## Task 4: Rename Product And Package App As Menu Bar Utility

**Files:**
- Modify: `Package.swift`
- Modify: `scripts/build-app.sh`

- [ ] **Step 1: Rename package and executable product**

Update `Package.swift`:

```swift
let package = Package(
    name: "CodexQuotaMenubar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexQuotaCore", targets: ["CodexQuotaCore"]),
        .executable(name: "CodexQuotaMenubar", targets: ["CodexQuotaWidget"]),
        .executable(name: "CodexQuotaCoreTests", targets: ["CodexQuotaCoreTests"])
    ],
    targets: [
        .target(name: "CodexQuotaCore"),
        .executableTarget(name: "CodexQuotaWidget", dependencies: ["CodexQuotaCore"]),
        .executableTarget(
            name: "CodexQuotaCoreTests",
            dependencies: ["CodexQuotaCore"],
            path: "Tests/CodexQuotaCoreTests"
        )
    ]
)
```

- [ ] **Step 2: Update the packaging script**

Set:

```bash
APP_NAME="CodexQuotaMenubar"
BUNDLE_ID="local.codex.quota-menubar"
```

Add Info.plist keys:

```xml
<key>CFBundleName</key>
<string>$APP_NAME</string>
<key>CFBundleDisplayName</key>
<string>$APP_NAME</string>
<key>CFBundleShortVersionString</key>
<string>0.1.0</string>
<key>CFBundleVersion</key>
<string>1</string>
<key>LSMinimumSystemVersion</key>
<string>14.0</string>
<key>LSUIElement</key>
<true/>
```

- [ ] **Step 3: Package the app**

Run:

```bash
./scripts/build-app.sh
```

Expected: prints `/Users/wuhan/wh/myProject/codex-quota-menubar/dist/CodexQuotaMenubar.app`.

- [ ] **Step 4: Verify packaged menu bar metadata**

Run:

```bash
/usr/libexec/PlistBuddy -c "Print :LSUIElement" "dist/CodexQuotaMenubar.app/Contents/Info.plist"
test -x "dist/CodexQuotaMenubar.app/Contents/MacOS/CodexQuotaMenubar"
```

Expected: first command prints `true`; second exits 0.

## Task 5: Final Verification

**Files:**
- Read: `docs/superpowers/specs/2026-07-03-codex-quota-menubar-design.md`
- Read: `docs/superpowers/plans/2026-07-03-codex-quota-menubar.md`

- [ ] **Step 1: Run executable tests**

Run:

```bash
swift run CodexQuotaCoreTests
```

Expected: all registered tests pass.

- [ ] **Step 2: Run debug build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 3: Run app packaging**

Run:

```bash
./scripts/build-app.sh
```

Expected: app bundle exists under `dist/CodexQuotaMenubar.app`.

- [ ] **Step 4: Inspect changed files**

Run:

```bash
git diff -- Package.swift Sources/CodexQuotaWidget/CodexQuotaWidgetApp.swift Sources/CodexQuotaCore/QuotaFormatting.swift Tests/CodexQuotaCoreTests scripts/build-app.sh docs/superpowers
```

Expected: diff only reflects the menu bar migration and copied-project docs.
