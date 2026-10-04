//
//  StreakConfiguration.swift
//  Lunixia
//

import Foundation
import SwiftData

// MARK: - Streak Feature

/// Which feature a streak configuration belongs to. Journal and Mood each own
/// one independent configuration record.
enum StreakFeature: String, CaseIterable {
    case journal
    case mood
}

// MARK: - Streak Type

/// The three (and only three) supported streak modes.
enum StreakType: String, CaseIterable {
    case consecutive
    case scheduled
    case frequency

    var displayName: String {
        switch self {
        case .consecutive: return "Consecutive"
        case .scheduled:   return "Scheduled"
        case .frequency:   return "Frequency"
        }
    }

    var shortExplanation: String {
        switch self {
        case .consecutive: return "Complete every day."
        case .scheduled:   return "Only chosen weekdays count."
        case .frequency:   return "Hit a weekly target any days."
        }
    }
}

// MARK: - Streak Configuration (SwiftData model)

/// Persistent, per-feature streak configuration. One record per `StreakFeature`.
/// CloudKit-safe: every stored property has a default value and there are no
/// unique constraints. Existing users (no record yet) are resolved to a freshly
/// created record that defaults to `.consecutive`, preserving current behavior.
@Model
final class StreakConfiguration {

    /// `StreakFeature` raw value ("journal" / "mood").
    var featureRawValue: String = StreakFeature.journal.rawValue

    /// `StreakType` raw value ("consecutive" / "scheduled" / "frequency").
    var typeRawValue: String = StreakType.consecutive.rawValue

    /// Selected weekdays for `.scheduled`, using `Calendar.component(.weekday)`
    /// convention: 1 = Sunday ... 7 = Saturday.
    var scheduledWeekdays: [Int] = [Int]()

    /// Target completions per (Monday-based) week for `.frequency`. Clamped 1...7.
    var weeklyTarget: Int = 3

    var updatedAt: Date = Date()

    init(feature: StreakFeature = .journal) {
        self.featureRawValue = feature.rawValue
        self.typeRawValue = StreakType.consecutive.rawValue
        self.scheduledWeekdays = []
        self.weeklyTarget = 3
        self.updatedAt = Date()
    }

    // MARK: Convenience

    var feature: StreakFeature {
        StreakFeature(rawValue: featureRawValue) ?? .journal
    }

    var type: StreakType {
        get { StreakType(rawValue: typeRawValue) ?? .consecutive }
        set { typeRawValue = newValue.rawValue }
    }

    /// Weekdays normalized to the valid 1...7 range, de-duplicated and sorted
    /// in Monday-first display order (Mon, Tue, …, Sun).
    var normalizedScheduledWeekdays: [Int] {
        let valid = Set(scheduledWeekdays.filter { (1...7).contains($0) })
        // Sunday-first ordering (1...7), matching the app's existing weekday
        // selector in MedicationCardView.
        return (1...7).filter { valid.contains($0) }
    }

    /// Weekly target clamped to the allowed 1...7 range.
    var clampedWeeklyTarget: Int {
        min(max(weeklyTarget, 1), 7)
    }

    /// Concise supporting text for the streak card (e.g. "Daily",
    /// "Mon • Wed • Fri", "3× per week").
    var displaySummary: String {
        switch type {
        case .consecutive:
            return "Daily"
        case .scheduled:
            let days = normalizedScheduledWeekdays
            guard !days.isEmpty else { return "No days selected" }
            return days.map { StreakConfiguration.shortWeekdayName($0) }.joined(separator: " • ")
        case .frequency:
            return "\(clampedWeeklyTarget)× per week"
        }
    }

    // MARK: Weekday naming (1 = Sunday ... 7 = Saturday)

    static func shortWeekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return ""
        }
    }

    // MARK: Fetch-or-create

    /// Returns the single configuration record for `feature`, creating it (with
    /// the `.consecutive` default) if one does not exist yet. De-duplicates if
    /// CloudKit ever produced more than one record for the same feature.
    @discardableResult
    static func fetchOrCreate(
        _ feature: StreakFeature,
        in context: ModelContext
    ) -> StreakConfiguration {
        let raw = feature.rawValue
        let descriptor = FetchDescriptor<StreakConfiguration>(
            predicate: #Predicate<StreakConfiguration> { $0.featureRawValue == raw }
        )

        let matches = (try? context.fetch(descriptor)) ?? []

        if let existing = matches.first {
            if matches.count > 1 {
                for dupe in matches.dropFirst() {
                    context.delete(dupe)
                }
                try? context.save()
            }
            return existing
        }

        let record = StreakConfiguration(feature: feature)
        context.insert(record)
        try? context.save()
        return record
    }
}
