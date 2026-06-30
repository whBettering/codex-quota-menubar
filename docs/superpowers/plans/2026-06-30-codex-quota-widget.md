# Codex Quota Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS top-center floating widget that reads and displays the user's real Codex quota.

**Architecture:** A Swift package contains a testable `CodexQuotaCore` library plus a `CodexQuotaWidget` AppKit/SwiftUI executable. The core parses `account/rateLimits/read` JSON-RPC responses, maps them into display models, formats text, and talks to the local Codex app-server. The executable creates a borderless always-on-top panel and renders compact/expanded SwiftUI views.

**Tech Stack:** Swift Package Manager, Swift 6, a lightweight executable Swift test runner, Foundation `Process`/`Pipe`, AppKit `NSPanel`, SwiftUI.

---

## File Structure

- Create `Package.swift`: defines `CodexQuotaCore`, `CodexQuotaWidget`, and `CodexQuotaCoreTests`.
- Create `Sources/CodexQuotaCore/QuotaModels.swift`: Codable response DTOs and display-domain structs.
- Create `Sources/CodexQuotaCore/QuotaMapping.swift`: selects the `codex` bucket and maps raw snapshots into display models.
- Create `Sources/CodexQuotaCore/QuotaFormatting.swift`: compact labels, window labels, percent strings, and reset-time strings.
- Create `Sources/CodexQuotaCore/JSONRPC.swift`: JSON-RPC request builders and response extraction.
- Create `Sources/CodexQuotaCore/CodexAppServerClient.swift`: launches `codex app-server --stdio` and reads quota data.
- Create `Sources/CodexQuotaWidget/main.swift`: app lifecycle, store, panel controller, and SwiftUI views.
- Create `Tests/CodexQuotaCoreTests/QuotaMappingTests.swift`: parser and mapper tests using the executable test runner.
- Create `Tests/CodexQuotaCoreTests/QuotaFormattingTests.swift`: deterministic display formatting tests registered in the executable test runner.
- Create `Tests/CodexQuotaCoreTests/JSONRPCTests.swift`: request/response protocol tests registered in the executable test runner.
- Create `scripts/build-app.sh`: builds a release executable and wraps it in `dist/CodexQuotaWidget.app`.

---

### Task 1: Swift Package Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexQuotaCore/Module.swift`
- Create: `Sources/CodexQuotaWidget/main.swift`
- Create: `Tests/CodexQuotaCoreTests/QuotaMappingTests.swift`

- [ ] **Step 1: Create the package manifest and empty module scaffold**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexQuotaWidget",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexQuotaCore", targets: ["CodexQuotaCore"]),
        .executable(name: "CodexQuotaWidget", targets: ["CodexQuotaWidget"])
    ],
    targets: [
        .target(name: "CodexQuotaCore"),
        .executableTarget(name: "CodexQuotaWidget", dependencies: ["CodexQuotaCore"]),
        .testTarget(name: "CodexQuotaCoreTests", dependencies: ["CodexQuotaCore"])
    ]
)
```

```swift
// Sources/CodexQuotaCore/Module.swift
// Module intentionally starts empty; tests drive behavior into focused files.
```

```swift
// Sources/CodexQuotaWidget/main.swift
print("CodexQuotaWidget scaffold")
```

- [ ] **Step 2: Write the first failing mapping test**

```swift
// Tests/CodexQuotaCoreTests/QuotaMappingTests.swift
import Foundation
import CodexQuotaCore

func testMapsCodexRateLimitsIntoDisplaySnapshot() throws {
        let json = """
        {
          "rateLimits": {
            "limitId": "codex",
            "limitName": null,
            "primary": { "usedPercent": 15, "windowDurationMins": 300, "resetsAt": 1782805238 },
            "secondary": { "usedPercent": 2, "windowDurationMins": 10080, "resetsAt": 1783392038 },
            "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
            "individualLimit": null,
            "planType": "plus",
            "rateLimitReachedType": null
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "limitName": null,
              "primary": { "usedPercent": 15, "windowDurationMins": 300, "resetsAt": 1782805238 },
              "secondary": { "usedPercent": 2, "windowDurationMins": 10080, "resetsAt": 1783392038 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "individualLimit": null,
              "planType": "plus",
              "rateLimitReachedType": null
            }
          },
          "rateLimitResetCredits": { "availableCount": 1 }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: json)
        let snapshot = try QuotaMapper.makeSnapshot(from: response, fetchedAt: Date(timeIntervalSince1970: 1_782_800_000))

        try expectEqual(snapshot.primary?.usedPercent, 15, "primary used percent")
        try expectEqual(snapshot.primary?.durationMinutes, 300, "primary duration")
        try expectEqual(snapshot.secondary?.usedPercent, 2, "secondary used percent")
        try expectEqual(snapshot.secondary?.durationMinutes, 10080, "secondary duration")
        try expectEqual(snapshot.planType, "plus", "plan type")
        try expectEqual(snapshot.resetCreditsAvailable, 1, "reset credits")
}
```

- [ ] **Step 3: Run the test and verify RED**

Run: `swift run CodexQuotaCoreTests`

Expected: FAIL at compile time because `GetAccountRateLimitsResponse` and `QuotaMapper` are not defined.

- [ ] **Step 4: Commit scaffold and RED test**

```bash
git add Package.swift Sources Tests
git commit -m "test: add quota mapping red test"
```

---

### Task 2: Quota Models and Mapping

**Files:**
- Create: `Sources/CodexQuotaCore/QuotaModels.swift`
- Create: `Sources/CodexQuotaCore/QuotaMapping.swift`
- Modify: `Tests/CodexQuotaCoreTests/QuotaMappingTests.swift`

- [ ] **Step 1: Implement the minimal DTOs and display models**

```swift
import Foundation

public struct GetAccountRateLimitsResponse: Codable, Equatable {
    public let rateLimits: RateLimitSnapshot
    public let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    public let rateLimitResetCredits: RateLimitResetCreditsSummary?
}

public struct RateLimitSnapshot: Codable, Equatable {
    public let limitId: String?
    public let limitName: String?
    public let primary: RateLimitWindow?
    public let secondary: RateLimitWindow?
    public let credits: CreditsSnapshot?
    public let individualLimit: String?
    public let planType: String?
    public let rateLimitReachedType: String?
}

public struct RateLimitWindow: Codable, Equatable {
    public let usedPercent: Double
    public let windowDurationMins: Int?
    public let resetsAt: TimeInterval?
}

public struct CreditsSnapshot: Codable, Equatable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?
}

public struct RateLimitResetCreditsSummary: Codable, Equatable {
    public let availableCount: Int
}

public struct QuotaSnapshot: Equatable {
    public let primary: QuotaWindow?
    public let secondary: QuotaWindow?
    public let planType: String?
    public let resetCreditsAvailable: Int?
    public let fetchedAt: Date
}

public struct QuotaWindow: Equatable {
    public let usedPercent: Int
    public let durationMinutes: Int?
    public let resetsAt: Date?
}
```

- [ ] **Step 2: Implement the minimal mapper**

```swift
import Foundation

public enum QuotaMappingError: Error, Equatable {
    case missingCodexRateLimit
}

public enum QuotaMapper {
    public static func makeSnapshot(from response: GetAccountRateLimitsResponse, fetchedAt: Date = Date()) throws -> QuotaSnapshot {
        let raw = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        guard raw.limitId == nil || raw.limitId == "codex" else {
            throw QuotaMappingError.missingCodexRateLimit
        }

        return QuotaSnapshot(
            primary: raw.primary.map(makeWindow),
            secondary: raw.secondary.map(makeWindow),
            planType: raw.planType,
            resetCreditsAvailable: response.rateLimitResetCredits?.availableCount,
            fetchedAt: fetchedAt
        )
    }

    private static func makeWindow(from window: RateLimitWindow) -> QuotaWindow {
        QuotaWindow(
            usedPercent: Int(window.usedPercent.rounded()),
            durationMinutes: window.windowDurationMins,
            resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: $0) }
        )
    }
}
```

- [ ] **Step 3: Run the mapping test and verify GREEN**

Run: `swift run CodexQuotaCoreTests`

Expected: PASS.

- [ ] **Step 4: Add fallback and error tests**

Add tests that confirm `rateLimits` is used when `rateLimitsByLimitId` is `null`, and non-`codex` fallback buckets throw `QuotaMappingError.missingCodexRateLimit`.

- [ ] **Step 5: Run all mapping tests**

Run: `swift run CodexQuotaCoreTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodexQuotaCore Tests/CodexQuotaCoreTests
git commit -m "feat: map Codex quota snapshots"
```

---

### Task 3: Quota Formatting

**Files:**
- Create: `Sources/CodexQuotaCore/QuotaFormatting.swift`
- Create: `Tests/CodexQuotaCoreTests/QuotaFormattingTests.swift`

- [ ] **Step 1: Write failing formatting tests**

```swift
import Foundation
import CodexQuotaCore

func testCompactTextShowsPrimaryAndWeeklyPercentages() throws {
        let snapshot = QuotaSnapshot(
            primary: QuotaWindow(usedPercent: 15, durationMinutes: 300, resetsAt: nil),
            secondary: QuotaWindow(usedPercent: 2, durationMinutes: 10080, resetsAt: nil),
            planType: "plus",
            resetCreditsAvailable: 1,
            fetchedAt: Date()
        )

        try expectEqual(QuotaFormatting.compactText(for: snapshot), "Codex 15% / 周 2%", "compact text")
}

func testWindowLabelsUseKnownDurations() throws {
        try expectEqual(QuotaFormatting.windowLabel(durationMinutes: 300), "5小时", "5-hour label")
        try expectEqual(QuotaFormatting.windowLabel(durationMinutes: 10080), "周额度", "weekly label")
        try expectEqual(QuotaFormatting.windowLabel(durationMinutes: 60), "60分钟", "minute label")
}

func testResetTextUsesTimeForSameDayAndDateForOtherDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 30, hour: 3, minute: 30).date!
        let sameDay = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 30, hour: 14, minute: 47).date!
        let otherDay = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 7, day: 7, hour: 1, minute: 20).date!

        try expectEqual(QuotaFormatting.resetText(for: sameDay, now: now, calendar: calendar), "14:47", "same-day reset")
        try expectEqual(QuotaFormatting.resetText(for: otherDay, now: now, calendar: calendar), "7/7", "other-day reset")
}
```

- [ ] **Step 2: Run formatting tests and verify RED**

Run: `swift run CodexQuotaCoreTests`

Expected: FAIL because `QuotaFormatting` is not defined.

- [ ] **Step 3: Implement formatting**

```swift
import Foundation

public enum QuotaFormatting {
    public static func compactText(for snapshot: QuotaSnapshot?) -> String {
        guard let snapshot else { return "Codex --" }
        let primary = snapshot.primary.map { "\($0.usedPercent)%" } ?? "--"
        let weekly = snapshot.secondary.map { "\($0.usedPercent)%" } ?? "--"
        return "Codex \(primary) / 周 \(weekly)"
    }

    public static func windowLabel(durationMinutes: Int?) -> String {
        switch durationMinutes {
        case 300:
            return "5小时"
        case 10080:
            return "周额度"
        case let minutes?:
            return "\(minutes)分钟"
        case nil:
            return "额度"
        }
    }

    public static func resetText(for date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "--" }
        let components = calendar.dateComponents([.hour, .minute, .month, .day], from: date)
        if calendar.isDate(date, inSameDayAs: now), let hour = components.hour, let minute = components.minute {
            return String(format: "%02d:%02d", hour, minute)
        }
        return "\(components.month ?? 0)/\(components.day ?? 0)"
    }
}
```

- [ ] **Step 4: Run formatting tests and verify GREEN**

Run: `swift run CodexQuotaCoreTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexQuotaCore/QuotaFormatting.swift Tests/CodexQuotaCoreTests/QuotaFormattingTests.swift
git commit -m "feat: format quota display text"
```

---

### Task 4: JSON-RPC Helpers

**Files:**
- Create: `Sources/CodexQuotaCore/JSONRPC.swift`
- Create: `Tests/CodexQuotaCoreTests/JSONRPCTests.swift`

- [ ] **Step 1: Write failing JSON-RPC tests**

```swift
import Foundation
import CodexQuotaCore

func testBuildsAccountRateLimitRequestLine() throws {
        let line = try JSONRPC.makeRequestLine(id: 2, method: "account/rateLimits/read")
        let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]

        try expectEqual(object?["id"] as? Int, 2, "request id")
        try expectEqual(object?["method"] as? String, "account/rateLimits/read", "request method")
        try expectEqual(line.hasSuffix("\n"), true, "request newline")
}

func testExtractsResultForMatchingResponseId() throws {
        let line = #"{"id":2,"result":{"rateLimits":{"limitId":"codex","limitName":null,"primary":null,"secondary":null,"credits":null,"individualLimit":null,"planType":"plus","rateLimitReachedType":null},"rateLimitsByLimitId":null,"rateLimitResetCredits":null}}"#

        let data = try JSONRPC.extractResultData(fromLine: line, matchingId: 2)
        let response = try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: data)

        try expectEqual(response.rateLimits.limitId, "codex", "response limit id")
        try expectEqual(response.rateLimits.planType, "plus", "response plan type")
}

func testIgnoresNotificationLines() throws {
        let line = #"{"method":"account/rateLimits/updated","params":{}}"#
        try expectEqual(try JSONRPC.extractResultData(fromLine: line, matchingId: 2) == nil, true, "notification ignored")
}
```

- [ ] **Step 2: Run JSON-RPC tests and verify RED**

Run: `swift run CodexQuotaCoreTests`

Expected: FAIL because `JSONRPC` is not defined.

- [ ] **Step 3: Implement JSON-RPC helpers**

Create request-line builders for requests and notifications, plus an extractor that returns result payload data for the matching response id and throws a readable error for JSON-RPC error objects.

- [ ] **Step 4: Run JSON-RPC tests and verify GREEN**

Run: `swift run CodexQuotaCoreTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexQuotaCore/JSONRPC.swift Tests/CodexQuotaCoreTests/JSONRPCTests.swift
git commit -m "feat: add JSON-RPC helpers"
```

---

### Task 5: Codex App-Server Client

**Files:**
- Create: `Sources/CodexQuotaCore/CodexAppServerClient.swift`
- Modify: `Tests/CodexQuotaCoreTests/JSONRPCTests.swift`

- [ ] **Step 1: Add a test for binary path resolution**

```swift
func testUsesEnvironmentOverrideForCodexBinaryPath() {
    let path = CodexAppServerClient.resolveCodexBinaryPath(environment: ["CODEX_QUOTA_CODEX_BIN": "/tmp/codex-test"])
    try expectEqual(path, "/tmp/codex-test", "environment override path")
}
```

- [ ] **Step 2: Run the targeted test and verify RED**

Run: `swift run CodexQuotaCoreTests`

Expected: FAIL because `CodexAppServerClient` is not defined.

- [ ] **Step 3: Implement client path resolution and protocol**

Implement:

```swift
public protocol QuotaFetching {
    func fetchQuota() async throws -> QuotaSnapshot
}

public final class CodexAppServerClient: QuotaFetching {
    public static func resolveCodexBinaryPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String
}
```

The default candidates are `/Applications/Codex.app/Contents/Resources/codex`, `/opt/homebrew/bin/codex`, and `/usr/local/bin/codex`.

- [ ] **Step 4: Implement `fetchQuota()`**

Launch `codex app-server --stdio`, send `initialize`, `initialized`, and `account/rateLimits/read`, wait up to 8 seconds for response id `2`, decode `GetAccountRateLimitsResponse`, map it with `QuotaMapper`, then terminate the process.

- [ ] **Step 5: Run tests**

Run: `swift run CodexQuotaCoreTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodexQuotaCore/CodexAppServerClient.swift Tests/CodexQuotaCoreTests
git commit -m "feat: fetch quota from Codex app server"
```

---

### Task 6: macOS Floating Widget

**Files:**
- Replace: `Sources/CodexQuotaWidget/main.swift`

- [ ] **Step 1: Implement app lifecycle and store**

Create an accessory AppKit app with:

- `QuotaStore`: `ObservableObject`, `snapshot`, `isRefreshing`, `errorMessage`, `lastRefresh`, `refresh()`, and 120-second timer.
- `FloatingPanelController`: creates a transparent `NSPanel`, positions it at top center of `NSScreen.main?.visibleFrame`, and resizes between compact and expanded dimensions.
- `QuotaView`: SwiftUI compact pill and expanded card with hover expansion, refresh button, quit button, and progress bars.

- [ ] **Step 2: Build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 3: Run manually**

Run: `swift run CodexQuotaWidget`

Expected: a top-center floating pill appears and fetches real quota. Stop it with the quit button or `Ctrl+C`.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodexQuotaWidget/main.swift
git commit -m "feat: add floating macOS quota widget"
```

---

### Task 7: App Bundle Script

**Files:**
- Create: `scripts/build-app.sh`
- Create: `.gitignore`

- [ ] **Step 1: Add ignored build outputs**

```gitignore
.build/
dist/
.DS_Store
```

- [ ] **Step 2: Add bundle script**

The script should run `swift build -c release`, copy the release executable into `dist/CodexQuotaWidget.app/Contents/MacOS/`, write an `Info.plist` with `LSUIElement` set to `true`, and ad-hoc sign the app when `codesign` is available.

- [ ] **Step 3: Run bundle script**

Run: `chmod +x scripts/build-app.sh && scripts/build-app.sh`

Expected: `dist/CodexQuotaWidget.app` exists.

- [ ] **Step 4: Commit**

```bash
git add .gitignore scripts/build-app.sh
git commit -m "build: add macOS app bundle script"
```

---

### Task 8: Final Verification

**Files:**
- No planned file changes.

- [ ] **Step 1: Run tests**

Run: `swift run CodexQuotaCoreTests`

Expected: PASS.

- [ ] **Step 2: Run debug build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 3: Run release bundle build**

Run: `scripts/build-app.sh`

Expected: PASS and `dist/CodexQuotaWidget.app` exists.

- [ ] **Step 4: Smoke-test real quota read**

Run the app or a small client probe through `swift run CodexQuotaWidget` and confirm the UI shows a compact `Codex <percent>% / 周 <percent>%` label instead of `Codex --`.

- [ ] **Step 5: Report exact verification results**

Report commands, pass/fail status, app path, and any manual smoke-test caveats.
