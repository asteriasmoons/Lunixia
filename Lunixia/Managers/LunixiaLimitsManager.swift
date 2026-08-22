//
//  LunixiaLimitsManager.swift
//  Lunixia
//

import Foundation
import SwiftData

// ============================================================
// MARK: - Lunixia Limits Manager
// ============================================================
//
// This file is the universal source of truth for Lunixia free-tier limits.
//
// Premium can come from:
// - App Store purchase/subscription
// - Self-Care Points premium redemption
//
// The rest of the app should not hardcode free limits directly.
// It should ask this manager instead.
//

enum LunixiaLimitsManager {

    // MARK: - Free Tier Limits

    static let freeJournalBookLimit: Int = 2
    static let freeJournalEntriesPerBookLimit: Int = 20

    static let freeMoodLogsPerDayLimit: Int = 1
    static let freeMoodHistoryDaysLimit: Int = 7

    static let freeCompleteVitalsEntriesPerDayLimit: Int = 2
    static let freeVitalsHistoryDaysLimit: Int = 7

    static let freeExerciseLogsPerDayLimit: Int = 2
    static let freeExerciseHistoryDaysLimit: Int = 7
    static let freeWaterHistoryDaysLimit: Int = 7
    static let freeStepsHistoryDaysLimit: Int = 7

    static let freeMedicationCardLimit: Int = 4
    static let freeMedicationHistoryDaysLimit: Int = 7

    static let freeSymptomLogsPerSevenDaysLimit: Int = 14

    static let freeStickyNoteTabLimit: Int = 2
    static let freeNotesPerStickyNoteTabLimit: Int = 20

    // MARK: - Premium Limits

    static let premiumUnlimitedLimit: Int = Int.max

    // MARK: - Limit Access

    static func journalBookLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeJournalBookLimit
    }

    static func journalEntriesPerBookLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeJournalEntriesPerBookLimit
    }

    static func moodLogsPerDayLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeMoodLogsPerDayLimit
    }

    static func moodHistoryDaysLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeMoodHistoryDaysLimit
    }

    static func completeVitalsEntriesPerDayLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeCompleteVitalsEntriesPerDayLimit
    }

    static func vitalsHistoryDaysLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeVitalsHistoryDaysLimit
    }

    static func exerciseLogsPerDayLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeExerciseLogsPerDayLimit
    }

    static func exerciseHistoryDaysLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeExerciseHistoryDaysLimit
    }

    static func waterHistoryDaysLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeWaterHistoryDaysLimit
    }

    static func stepsHistoryDaysLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeStepsHistoryDaysLimit
    }

    static func medicationCardLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeMedicationCardLimit
    }

    static func medicationHistoryDaysLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeMedicationHistoryDaysLimit
    }

    static func symptomLogsPerSevenDaysLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeSymptomLogsPerSevenDaysLimit
    }

    static func stickyNoteTabLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeStickyNoteTabLimit
    }

    static func notesPerStickyNoteTabLimit(isPremium: Bool) -> Int {
        isPremium ? premiumUnlimitedLimit : freeNotesPerStickyNoteTabLimit
    }

    // MARK: - Creation Checks

    static func canCreateJournalBook(currentCount: Int, isPremium: Bool) -> Bool {
        currentCount < journalBookLimit(isPremium: isPremium)
    }

    static func canCreateJournalEntry(currentCountInBook: Int, isPremium: Bool) -> Bool {
        currentCountInBook < journalEntriesPerBookLimit(isPremium: isPremium)
    }

    static func canCreateMoodLog(todayCount: Int, isPremium: Bool) -> Bool {
        todayCount < moodLogsPerDayLimit(isPremium: isPremium)
    }

    static func canCreateCompleteVitalsEntry(todayCount: Int, isPremium: Bool) -> Bool {
        todayCount < completeVitalsEntriesPerDayLimit(isPremium: isPremium)
    }

    static func canCreateExerciseLog(todayCount: Int, isPremium: Bool) -> Bool {
        todayCount < exerciseLogsPerDayLimit(isPremium: isPremium)
    }

    static func canCreateMedicationCard(currentCount: Int, isPremium: Bool) -> Bool {
        currentCount < medicationCardLimit(isPremium: isPremium)
    }

    static func canCreateSymptomLog(currentSevenDayCount: Int, isPremium: Bool) -> Bool {
        currentSevenDayCount < symptomLogsPerSevenDaysLimit(isPremium: isPremium)
    }

    static func canCreateStickyNoteTab(currentCount: Int, isPremium: Bool) -> Bool {
        currentCount < stickyNoteTabLimit(isPremium: isPremium)
    }

    static func canCreateNoteInStickyNoteTab(currentCountInTab: Int, isPremium: Bool) -> Bool {
        currentCountInTab < notesPerStickyNoteTabLimit(isPremium: isPremium)
    }

    // MARK: - Remaining Counts

    static func remainingJournalBooks(currentCount: Int, isPremium: Bool) -> Int {
        remaining(currentCount: currentCount, limit: journalBookLimit(isPremium: isPremium))
    }

    static func remainingJournalEntries(currentCountInBook: Int, isPremium: Bool) -> Int {
        remaining(currentCount: currentCountInBook, limit: journalEntriesPerBookLimit(isPremium: isPremium))
    }

    static func remainingMoodLogsToday(todayCount: Int, isPremium: Bool) -> Int {
        remaining(currentCount: todayCount, limit: moodLogsPerDayLimit(isPremium: isPremium))
    }

    static func remainingCompleteVitalsEntriesToday(todayCount: Int, isPremium: Bool) -> Int {
        remaining(currentCount: todayCount, limit: completeVitalsEntriesPerDayLimit(isPremium: isPremium))
    }

    static func remainingExerciseLogsToday(todayCount: Int, isPremium: Bool) -> Int {
        remaining(currentCount: todayCount, limit: exerciseLogsPerDayLimit(isPremium: isPremium))
    }

    static func remainingMedicationCards(currentCount: Int, isPremium: Bool) -> Int {
        remaining(currentCount: currentCount, limit: medicationCardLimit(isPremium: isPremium))
    }

    static func remainingSymptomLogsThisWeek(currentSevenDayCount: Int, isPremium: Bool) -> Int {
        remaining(currentCount: currentSevenDayCount, limit: symptomLogsPerSevenDaysLimit(isPremium: isPremium))
    }

    static func remainingStickyNoteTabs(currentCount: Int, isPremium: Bool) -> Int {
        remaining(currentCount: currentCount, limit: stickyNoteTabLimit(isPremium: isPremium))
    }

    static func remainingNotesInStickyNoteTab(currentCountInTab: Int, isPremium: Bool) -> Int {
        remaining(currentCount: currentCountInTab, limit: notesPerStickyNoteTabLimit(isPremium: isPremium))
    }

    private static func remaining(currentCount: Int, limit: Int) -> Int {
        guard limit != premiumUnlimitedLimit else { return premiumUnlimitedLimit }
        return max(limit - currentCount, 0)
    }

    // MARK: - Date Helpers

    static func startOfToday(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: Date())
    }

    static func startOfSevenDayWindow(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -6, to: startOfToday(calendar: calendar)) ?? startOfToday(calendar: calendar)
    }

    static func historyCutoffDate(days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: startOfToday(calendar: calendar)) ?? startOfToday(calendar: calendar)
    }

    static func isWithinFreeHistoryWindow(_ date: Date, historyDays: Int, calendar: Calendar = .current) -> Bool {
        date >= historyCutoffDate(days: historyDays, calendar: calendar)
    }

    static func isWithinSevenDayWindow(_ date: Date, calendar: Calendar = .current) -> Bool {
        date >= startOfSevenDayWindow(calendar: calendar)
    }

    static func isToday(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }

    // MARK: - Limit Messages

    static func journalBookLimitMessage(isPremium: Bool) -> String {
        limitMessage(
            isPremium: isPremium,
            freeLimit: freeJournalBookLimit,
            singular: "journal book",
            plural: "journal books"
        )
    }

    static func journalEntryLimitMessage(isPremium: Bool) -> String {
        limitMessage(
            isPremium: isPremium,
            freeLimit: freeJournalEntriesPerBookLimit,
            singular: "entry per journal book",
            plural: "entries per journal book"
        )
    }

    static func moodLogLimitMessage(isPremium: Bool) -> String {
        limitMessage(
            isPremium: isPremium,
            freeLimit: freeMoodLogsPerDayLimit,
            singular: "mood log per day",
            plural: "mood logs per day"
        )
    }

    static func moodHistoryLimitMessage(isPremium: Bool) -> String {
        historyMessage(
            isPremium: isPremium,
            freeDays: freeMoodHistoryDaysLimit,
            label: "mood history"
        )
    }

    static func completeVitalsLimitMessage(isPremium: Bool) -> String {
        limitMessage(
            isPremium: isPremium,
            freeLimit: freeCompleteVitalsEntriesPerDayLimit,
            singular: "complete vitals entry per day",
            plural: "complete vitals entries per day"
        )
    }

    static func vitalsHistoryLimitMessage(isPremium: Bool) -> String {
        historyMessage(
            isPremium: isPremium,
            freeDays: freeVitalsHistoryDaysLimit,
            label: "vitals history"
        )
    }

    static func exerciseLogLimitMessage(isPremium: Bool) -> String {
        limitMessage(
            isPremium: isPremium,
            freeLimit: freeExerciseLogsPerDayLimit,
            singular: "exercise log per day",
            plural: "exercise logs per day"
        )
    }

    static func exerciseHistoryLimitMessage(isPremium: Bool) -> String {
        historyMessage(
            isPremium: isPremium,
            freeDays: freeExerciseHistoryDaysLimit,
            label: "exercise history"
        )
    }

    static func medicationCardLimitMessage(isPremium: Bool) -> String {
        limitMessage(
            isPremium: isPremium,
            freeLimit: freeMedicationCardLimit,
            singular: "medication card",
            plural: "medication cards"
        )
    }

    static func medicationHistoryLimitMessage(isPremium: Bool) -> String {
        historyMessage(
            isPremium: isPremium,
            freeDays: freeMedicationHistoryDaysLimit,
            label: "medication history"
        )
    }

    static func symptomLogLimitMessage(isPremium: Bool) -> String {
        if isPremium {
            return "Premium allows unlimited symptom logs."
        }

        return "Free access allows up to \(freeSymptomLogsPerSevenDaysLimit) symptom logs every 7 days."
    }

    static func stickyNoteTabLimitMessage(isPremium: Bool) -> String {
        limitMessage(
            isPremium: isPremium,
            freeLimit: freeStickyNoteTabLimit,
            singular: "sticky note tab",
            plural: "sticky note tabs"
        )
    }

    static func stickyNoteLimitMessage(isPremium: Bool) -> String {
        limitMessage(
            isPremium: isPremium,
            freeLimit: freeNotesPerStickyNoteTabLimit,
            singular: "note per sticky note tab",
            plural: "notes per sticky note tab"
        )
    }

    private static func limitMessage(isPremium: Bool, freeLimit: Int, singular: String, plural: String) -> String {
        if isPremium {
            return "Premium allows unlimited \(plural)."
        }

        let label = freeLimit == 1 ? singular : plural
        return "Free access allows \(freeLimit) \(label)."
    }

    private static func historyMessage(isPremium: Bool, freeDays: Int, label: String) -> String {
        if isPremium {
            return "Premium allows unlimited \(label)."
        }

        return "Free access keeps the most recent \(freeDays) days of \(label)."
    }
}
