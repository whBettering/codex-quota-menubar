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

    public init(
        primary: QuotaWindow?,
        secondary: QuotaWindow?,
        planType: String?,
        resetCreditsAvailable: Int?,
        fetchedAt: Date
    ) {
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
        self.resetCreditsAvailable = resetCreditsAvailable
        self.fetchedAt = fetchedAt
    }
}

public struct QuotaWindow: Equatable {
    public let usedPercent: Int
    public let durationMinutes: Int?
    public let resetsAt: Date?

    public init(usedPercent: Int, durationMinutes: Int?, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt
    }
}
