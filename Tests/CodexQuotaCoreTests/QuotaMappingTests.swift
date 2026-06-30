import Foundation
import CodexQuotaCore

enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message):
            return message
        }
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw TestFailure.assertion("\(message): expected \(expected), got \(actual)")
    }
}

func expectThrows<E: Error & Equatable>(_ expected: E, _ message: String, _ operation: () throws -> Void) throws {
    do {
        try operation()
    } catch let error as E {
        try expectEqual(error, expected, message)
        return
    } catch {
        throw TestFailure.assertion("\(message): expected \(expected), got \(error)")
    }

    throw TestFailure.assertion("\(message): expected \(expected), got no error")
}

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
    let snapshot = try QuotaMapper.makeSnapshot(
        from: response,
        fetchedAt: Date(timeIntervalSince1970: 1_782_800_000)
    )

    try expectEqual(snapshot.primary?.usedPercent, 15, "primary used percent")
    try expectEqual(snapshot.primary?.durationMinutes, 300, "primary duration")
    try expectEqual(snapshot.secondary?.usedPercent, 2, "secondary used percent")
    try expectEqual(snapshot.secondary?.durationMinutes, 10080, "secondary duration")
    try expectEqual(snapshot.planType, "plus", "plan type")
    try expectEqual(snapshot.resetCreditsAvailable, 1, "reset credits")
}

func testFallsBackToLegacyRateLimitsWhenBucketMapIsMissing() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "codex",
        "limitName": null,
        "primary": { "usedPercent": 37, "windowDurationMins": 300, "resetsAt": null },
        "secondary": null,
        "credits": null,
        "individualLimit": null,
        "planType": "plus",
        "rateLimitReachedType": null
      },
      "rateLimitsByLimitId": null,
      "rateLimitResetCredits": null
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: json)
    let snapshot = try QuotaMapper.makeSnapshot(from: response)

    try expectEqual(snapshot.primary?.usedPercent, 37, "fallback primary used percent")
    try expectEqual(snapshot.planType, "plus", "fallback plan type")
}

func testRejectsNonCodexLegacyRateLimit() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "chatgpt",
        "limitName": null,
        "primary": { "usedPercent": 91, "windowDurationMins": 300, "resetsAt": null },
        "secondary": null,
        "credits": null,
        "individualLimit": null,
        "planType": "plus",
        "rateLimitReachedType": null
      },
      "rateLimitsByLimitId": null,
      "rateLimitResetCredits": null
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: json)

    try expectThrows(QuotaMappingError.missingCodexRateLimit, "non-Codex legacy bucket") {
        _ = try QuotaMapper.makeSnapshot(from: response)
    }
}

@main
struct TestRunner {
    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("testMapsCodexRateLimitsIntoDisplaySnapshot", testMapsCodexRateLimitsIntoDisplaySnapshot),
            ("testFallsBackToLegacyRateLimitsWhenBucketMapIsMissing", testFallsBackToLegacyRateLimitsWhenBucketMapIsMissing),
            ("testRejectsNonCodexLegacyRateLimit", testRejectsNonCodexLegacyRateLimit),
            ("testCompactTextShowsPrimaryAndWeeklyPercentages", testCompactTextShowsPrimaryAndWeeklyPercentages),
            ("testCompactTextShowsUnavailableState", testCompactTextShowsUnavailableState),
            ("testWindowLabelsUseKnownDurations", testWindowLabelsUseKnownDurations),
            ("testResetTextUsesTimeForSameDayAndDateForOtherDays", testResetTextUsesTimeForSameDayAndDateForOtherDays),
            ("testBuildsAccountRateLimitRequestLine", testBuildsAccountRateLimitRequestLine),
            ("testExtractsResultForMatchingResponseId", testExtractsResultForMatchingResponseId),
            ("testIgnoresNotificationLines", testIgnoresNotificationLines),
            ("testThrowsForMatchingErrorResponse", testThrowsForMatchingErrorResponse),
            ("testUsesEnvironmentOverrideForCodexBinaryPath", testUsesEnvironmentOverrideForCodexBinaryPath),
            ("testDefaultFloatingWindowOriginUsesTopCenterOfVisibleFrame", testDefaultFloatingWindowOriginUsesTopCenterOfVisibleFrame),
            ("testResizingPreservesDraggedTopCenter", testResizingPreservesDraggedTopCenter),
            ("testConstrainedOriginMovesSavedPositionBackIntoVisibleFrame", testConstrainedOriginMovesSavedPositionBackIntoVisibleFrame)
        ]

        var failures = 0
        for (name, test) in tests {
            do {
                try test()
                print("PASS \(name)")
            } catch {
                failures += 1
                fputs("FAIL \(name): \(error)\n", stderr)
            }
        }

        if failures > 0 {
            exit(1)
        }
    }
}
