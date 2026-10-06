//
//  LunixiaMoodWidgetWriter.swift
//  Lunixia
//
//  Mirrors the pattern used in HealthKitManager.swift:
//  - Snapshot struct defined here (main app target only)
//  - Widget target has an identical Codable struct in LunixiaMoodWidget.swift
//  - Both sides share the same App Group key, so JSONDecoder works across targets
//

import Foundation
import WidgetKit

// MARK: - Snapshot (main app side)
// Must stay byte-for-byte Codable-identical to LunixiaMoodWidgetSnapshot in LunixiaMoodWidget.swift

struct LunixiaMoodWidgetSnapshot: Codable {
    var wellnessPercent: Int
    var wellnessLabel: String
    var streak: Int
    var totalLogs: Int
    var sevenDayLogCount: Int
    var positivePct: Int
    var neutralPct: Int
    var negativePct: Int
    var topEmotion: String
    var topActivity: String
    var lastUpdated: Date
}

// MARK: - Writer

enum LunixiaMoodWidgetWriter {

    private static let widgetDefaults = UserDefaults(suiteName: "group.com.asteriasmoons.Lunixia")
    private static let snapshotKey    = "lunixiaMoodWidgetSnapshot"

    // MARK: - Activity Sets (mirrors MoodTabView)

    private static let wellnessActivities: Set<String> = [
        "self-care", "meditation", "mindfulness", "therapy", "fitness",
        "exercise", "yoga", "swimming", "health", "hygiene", "medication",
        "sleep", "rest", "healing"
    ]

    private static let socialActivities: Set<String> = [
        "friends", "family", "dating", "community", "calls", "texting", "party"
    ]

    private static let enrichmentActivities: Set<String> = [
        "reading", "art", "music", "writing", "journaling", "hobby",
        "education", "creative", "spirituality", "religion", "mindfulness"
    ]

    // MARK: - Score Helpers

    private static func momentumScore(_ entry: MoodEntry) -> Int {
        let supportiveEmotionScore = entry.resolvedEmotions.reduce(0) { acc, emotion in
            switch emotion.category {
            case .positive: return acc + 2
            case .neutral:  return acc + 1
            case .negative: return acc
            }
        }
        let negativeEmotionPenalty = entry.resolvedEmotions.reduce(0) { acc, emotion in
            emotion.category == .negative ? acc + 2 : acc
        }
        let activityScore = entry.activityNames.reduce(0) { acc, name in
            let normalizedName = name.lowercased()
            if wellnessActivities.contains(normalizedName)    { return acc + 2 }
            if socialActivities.contains(normalizedName)      { return acc + 1 }
            if enrichmentActivities.contains(normalizedName)  { return acc + 1 }
            return acc
        }
        let cappedSupportiveScore = min(supportiveEmotionScore + activityScore, 20)
        return max(cappedSupportiveScore - negativeEmotionPenalty, 0)
    }

    private static func sevenDayMomentum(_ entries: [MoodEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + momentumScore($1) }
        return Int((Double(total) / Double(entries.count * 20)) * 100)
    }

    private static func momentumLabel(_ percent: Int, hasEntries: Bool) -> String {
        guard hasEntries else { return "Nothing logged yet" }
        switch percent {
        case 0..<25:  return "Low energy"
        case 25..<50: return "Building up"
        case 50..<70: return "Steady flow"
        case 70..<90: return "Strong momentum"
        default:      return "Thriving"
        }
    }

    private static func streak(_ entries: [MoodEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        var count = 0
        var checkDate = Calendar.current.startOfDay(for: .now)
        let calendar = Calendar.current
        while true {
            if entries.contains(where: { calendar.isDate($0.timestamp, inSameDayAs: checkDate) }) {
                count += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else { break }
        }
        return count
    }

    private static func emotionBreakdown(_ entries: [MoodEntry]) -> (pos: Int, neu: Int, neg: Int) {
        let emotions = entries.flatMap { $0.resolvedEmotions }
        guard !emotions.isEmpty else { return (0, 0, 0) }
        let total = Double(emotions.count)
        let pos = Double(emotions.filter { $0.category == .positive }.count)
        let neu = Double(emotions.filter { $0.category == .neutral  }.count)
        let neg = Double(emotions.filter { $0.category == .negative }.count)
        return (Int(pos / total * 100), Int(neu / total * 100), Int(neg / total * 100))
    }

    private static func topName(in arrays: [[String]]) -> String {
        let flat = arrays.flatMap { $0 }
        guard !flat.isEmpty else { return "" }
        return flat.reduce(into: [:]) { $0[$1, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key ?? ""
    }

    /// Streak for the widget. Uses the feature's configured mode when a config is
    /// supplied (so the widget matches the in-app streak), otherwise falls back to
    /// the legacy consecutive calculation.
    private static func resolvedStreak(_ entries: [MoodEntry], config: StreakConfiguration?) -> Int {
        guard let config else { return streak(entries) }
        return StreakCalculator.currentStreak(
            type: config.type,
            completionDates: entries.map { $0.timestamp },
            scheduledWeekdays: config.normalizedScheduledWeekdays,
            weeklyTarget: config.clampedWeeklyTarget
        )
    }

    // MARK: - Public Write

    static func write(allEntries: [MoodEntry], streakConfig: StreakConfiguration? = nil) {
        let cutoff7   = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let sevenDay  = allEntries.filter { $0.timestamp >= cutoff7 }
        let momentum  = sevenDayMomentum(sevenDay)
        let (pos, neu, neg) = emotionBreakdown(sevenDay)

        let snapshot = LunixiaMoodWidgetSnapshot(
            wellnessPercent:  momentum,
            wellnessLabel:    momentumLabel(momentum, hasEntries: !sevenDay.isEmpty),
            streak:           resolvedStreak(allEntries, config: streakConfig),
            totalLogs:        allEntries.count,
            sevenDayLogCount: sevenDay.count,
            positivePct:      pos,
            neutralPct:       neu,
            negativePct:      neg,
            topEmotion:       topName(in: allEntries.map { $0.emotionNames }),
            topActivity:      topName(in: allEntries.map { $0.activityNames }),
            lastUpdated:      Date()
        )

        do {
            let data = try JSONEncoder().encode(snapshot)
            widgetDefaults?.set(data, forKey: snapshotKey)
            WidgetCenter.shared.reloadTimelines(ofKind: "LunixiaMoodMediumWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "LunixiaMoodLargeWidget")
        } catch {
            print("[LunixiaMoodWidgetWriter] encode error: \(error)")
        }
    }
}
