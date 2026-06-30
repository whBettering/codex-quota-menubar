import Foundation

public enum QuotaFormatting {
    public static func compactText(for snapshot: QuotaSnapshot?) -> String {
        guard let snapshot else {
            return "Codex --"
        }

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
        guard let date else {
            return "--"
        }

        let components = calendar.dateComponents([.hour, .minute, .month, .day], from: date)
        if calendar.isDate(date, inSameDayAs: now), let hour = components.hour, let minute = components.minute {
            return String(format: "%02d:%02d", hour, minute)
        }

        return "\(components.month ?? 0)/\(components.day ?? 0)"
    }
}
