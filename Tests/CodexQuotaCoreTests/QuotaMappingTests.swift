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

@main
struct TestRunner {
    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("testMapsCodexRateLimitsIntoDisplaySnapshot", testMapsCodexRateLimitsIntoDisplaySnapshot)
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
