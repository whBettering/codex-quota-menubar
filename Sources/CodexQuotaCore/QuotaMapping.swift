import Foundation

public enum QuotaMappingError: Error, Equatable {
    case missingCodexRateLimit
}

public enum QuotaMapper {
    public static func makeSnapshot(
        from response: GetAccountRateLimitsResponse,
        fetchedAt: Date = Date()
    ) throws -> QuotaSnapshot {
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
