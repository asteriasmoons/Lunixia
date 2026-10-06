//
//  StreakCalculator.swift
//  Lunixia
//
//  Shared streak math used by BOTH Journal and Mood. Each feature supplies its
//  own completion dates and its own StreakConfiguration; the semantics are
//  identical across features.
//
//  Rules honored (see spec):
//   - Completion dates are normalized to calendar days (multiple entries on one
//     day count once).
//   - Today is never treated as a missed day while it is still in progress.
//   - The current week is never treated as failed while it is still in progress.
//   - Scheduled: unscheduled weekdays are NEUTRAL (never advance, never break).
//   - Frequency weeks are Monday-based, matching the rest of Lunixia
//     (LunixiaPointsManager.weekStartDayKey uses the same (weekday + 5) % 7).
//

import Foundation

enum StreakCalculator {

    // MARK: - Public API

    /// Current streak for the given mode.
    /// - consecutive: number of consecutive completed calendar days ending today
    ///   (or yesterday if today isn't done yet).
    /// - scheduled: number of consecutive completed scheduled occurrences ending
    ///   at the most recent required scheduled day (today, if scheduled, is
    ///   neutral until completed).
    /// - frequency: number of consecutive successful Monday-based weeks (a met
    ///   current week counts; an unmet current week is neutral, not a failure).
    static func currentStreak(
        type: StreakType,
        completionDates: [Date],
        scheduledWeekdays: [Int] = [],
        weeklyTarget: Int = 3,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let days = normalizedDays(completionDates, calendar: calendar)
        switch type {
        case .consecutive:
            return consecutiveCurrent(days: days, now: now, calendar: calendar)
        case .scheduled:
            return scheduledCurrent(
                days: days,
                weekdays: validWeekdays(scheduledWeekdays),
                now: now,
                calendar: calendar
            )
        case .frequency:
            return frequencyCurrent(
                days: days,
                target: clampTarget(weeklyTarget),
                now: now,
                calendar: calendar
            )
        }
    }

    /// Longest historical streak for the given mode (same units as `currentStreak`).
    static func bestStreak(
        type: StreakType,
        completionDates: [Date],
        scheduledWeekdays: [Int] = [],
        weeklyTarget: Int = 3,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let days = normalizedDays(completionDates, calendar: calendar)
        switch type {
        case .consecutive:
            return consecutiveBest(days: days, now: now, calendar: calendar)
        case .scheduled:
            return scheduledBest(
                days: days,
                weekdays: validWeekdays(scheduledWeekdays),
                now: now,
                calendar: calendar
            )
        case .frequency:
            return frequencyBest(
                days: days,
                target: clampTarget(weeklyTarget),
                now: now,
                calendar: calendar
            )
        }
    }

    /// Number of distinct goal-eligible completion days in the current
    /// Monday-based week. Scheduled mode ignores completions on unselected days.
    static func currentWeekCompletionCount(
        type: StreakType,
        completionDates: [Date],
        scheduledWeekdays: [Int] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let days = normalizedDays(completionDates, calendar: calendar)
        let weekStart = mondayOfWeek(for: now, calendar: calendar)
        guard let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return 0
        }

        let selectedWeekdays = validWeekdays(scheduledWeekdays)
        return days.reduce(into: 0) { count, day in
            guard day >= weekStart, day < nextWeekStart else { return }
            if type != .scheduled || selectedWeekdays.contains(calendar.component(.weekday, from: day)) {
                count += 1
            }
        }
    }

    // MARK: - Normalization helpers

    private static func normalizedDays(_ dates: [Date], calendar: Calendar) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    private static func validWeekdays(_ weekdays: [Int]) -> Set<Int> {
        Set(weekdays.filter { (1...7).contains($0) })
    }

    private static func clampTarget(_ target: Int) -> Int {
        min(max(target, 1), 7)
    }

    /// Monday of the week containing `date`. Mirrors
    /// `LunixiaPointsManager.weekStartDayKey` so week boundaries never compete.
    private static func mondayOfWeek(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    // MARK: - Consecutive

    private static func consecutiveCurrent(days: Set<Date>, now: Date, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: now)

        let anchor: Date
        if days.contains(today) {
            anchor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  days.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = anchor
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private static func consecutiveBest(days: Set<Date>, now: Date, calendar: Calendar) -> Int {
        let sorted = days.sorted()
        guard !sorted.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let current = sorted[index]
            if let nextExpected = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(nextExpected, inSameDayAs: current) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return max(best, consecutiveCurrent(days: days, now: now, calendar: calendar))
    }

    // MARK: - Scheduled

    private static func scheduledCurrent(
        days: Set<Date>,
        weekdays: Set<Int>,
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard !weekdays.isEmpty, let earliest = days.min() else { return 0 }
        let today = calendar.startOfDay(for: now)

        var streak = 0
        var cursor = today
        while cursor >= earliest {
            let weekday = calendar.component(.weekday, from: cursor)
            if weekdays.contains(weekday) {
                if days.contains(cursor) {
                    streak += 1
                } else if calendar.isDate(cursor, inSameDayAs: today) {
                    // Today is a scheduled day but isn't completed yet: still in
                    // progress → neutral. Do not break; keep looking backward.
                } else {
                    // A required scheduled day passed without completion.
                    break
                }
            }
            // Unscheduled days are neutral: skip.
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private static func scheduledBest(
        days: Set<Date>,
        weekdays: Set<Int>,
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard !weekdays.isEmpty, let earliest = days.min() else { return 0 }
        let today = calendar.startOfDay(for: now)

        // Walk forward from the earliest completion to today, counting runs of
        // completed scheduled occurrences. Unscheduled days are neutral; a missed
        // required scheduled day resets the run; today-incomplete is neutral.
        var best = 0
        var run = 0
        var cursor = earliest
        while cursor <= today {
            let weekday = calendar.component(.weekday, from: cursor)
            if weekdays.contains(weekday) {
                if days.contains(cursor) {
                    run += 1
                    best = max(best, run)
                } else if calendar.isDate(cursor, inSameDayAs: today) {
                    // in progress, neutral
                } else {
                    run = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return best
    }

    // MARK: - Frequency (Monday-based weeks)

    /// Distinct completion days grouped by the Monday of their week.
    private static func completionsByWeek(
        days: Set<Date>,
        calendar: Calendar
    ) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for day in days {
            let monday = mondayOfWeek(for: day, calendar: calendar)
            counts[monday, default: 0] += 1
        }
        return counts
    }

    private static func frequencyCurrent(
        days: Set<Date>,
        target: Int,
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard !days.isEmpty else { return 0 }
        let counts = completionsByWeek(days: days, calendar: calendar)
        guard let earliestMonday = counts.keys.min() else { return 0 }
        let currentMonday = mondayOfWeek(for: now, calendar: calendar)

        var streak = 0
        var weekCursor = currentMonday
        while weekCursor >= earliestMonday {
            let met = (counts[weekCursor] ?? 0) >= target
            if calendar.isDate(weekCursor, inSameDayAs: currentMonday) {
                // Current week: count it only if already met; never a failure
                // while time remains.
                if met { streak += 1 }
            } else {
                if met {
                    streak += 1
                } else {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -7, to: weekCursor) else { break }
            weekCursor = previous
        }
        return streak
    }

    private static func frequencyBest(
        days: Set<Date>,
        target: Int,
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard !days.isEmpty else { return 0 }
        let counts = completionsByWeek(days: days, calendar: calendar)
        guard let earliestMonday = counts.keys.min() else { return 0 }
        let currentMonday = mondayOfWeek(for: now, calendar: calendar)

        var best = 0
        var run = 0
        var weekCursor = earliestMonday
        while weekCursor <= currentMonday {
            let met = (counts[weekCursor] ?? 0) >= target
            let isCurrent = calendar.isDate(weekCursor, inSameDayAs: currentMonday)
            if met {
                run += 1
                best = max(best, run)
            } else if isCurrent {
                // Current week in progress: neutral, don't reset the finished run.
            } else {
                run = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekCursor) else { break }
            weekCursor = next
        }
        return best
    }
}
