import Foundation
import CodexQuotaCore

func testCompactTextShowsRemainingPrimaryAndWeeklyPercentages() throws {
    let snapshot = QuotaSnapshot(
        primary: QuotaWindow(usedPercent: 15, durationMinutes: 300, resetsAt: nil),
        secondary: QuotaWindow(usedPercent: 2, durationMinutes: 10080, resetsAt: nil),
        planType: "plus",
        resetCreditsAvailable: 1,
        fetchedAt: Date()
    )

    try expectEqual(QuotaFormatting.compactText(for: snapshot), "Codex 剩余 85% / 周 98%", "compact text")
}

func testRemainingPercentIsClampedToDisplayBounds() throws {
    try expectEqual(
        QuotaFormatting.remainingPercent(for: QuotaWindow(usedPercent: 37, durationMinutes: 300, resetsAt: nil)),
        63,
        "remaining percent"
    )
    try expectEqual(
        QuotaFormatting.remainingPercent(for: QuotaWindow(usedPercent: -4, durationMinutes: 300, resetsAt: nil)),
        100,
        "negative used percent remaining"
    )
    try expectEqual(
        QuotaFormatting.remainingPercent(for: QuotaWindow(usedPercent: 140, durationMinutes: 300, resetsAt: nil)),
        0,
        "over-limit used percent remaining"
    )
}

func testCompactTextShowsUnavailableState() throws {
    try expectEqual(QuotaFormatting.compactText(for: nil), "Codex --", "unavailable compact text")
}

func testWindowLabelsUseKnownDurations() throws {
    try expectEqual(QuotaFormatting.windowLabel(durationMinutes: 300), "5小时", "5-hour label")
    try expectEqual(QuotaFormatting.windowLabel(durationMinutes: 10080), "周额度", "weekly label")
    try expectEqual(QuotaFormatting.windowLabel(durationMinutes: 60), "60分钟", "minute label")
    try expectEqual(QuotaFormatting.windowLabel(durationMinutes: nil), "额度", "unknown label")
}

func testResetTextUsesTimeForSameDayAndDateForOtherDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let now = DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: 2026,
        month: 6,
        day: 30,
        hour: 3,
        minute: 30
    ).date!
    let sameDay = DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: 2026,
        month: 6,
        day: 30,
        hour: 14,
        minute: 47
    ).date!
    let otherDay = DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: 2026,
        month: 7,
        day: 7,
        hour: 1,
        minute: 20
    ).date!

    try expectEqual(QuotaFormatting.resetText(for: sameDay, now: now, calendar: calendar), "14:47", "same-day reset")
    try expectEqual(QuotaFormatting.resetText(for: otherDay, now: now, calendar: calendar), "7/7", "other-day reset")
    try expectEqual(QuotaFormatting.resetText(for: nil, now: now, calendar: calendar), "--", "missing reset")
}
