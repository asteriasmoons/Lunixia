//
//  MedicationAutomationManager.swift
//  Lunixia
//

import Foundation
import SwiftData

@MainActor
enum MedicationAutomationManager {

    // MARK: - Public API

    static func run(
        in modelContext: ModelContext,
        now: Date = Date(),
        shouldProcessRefills: Bool = true,
        shouldProcessAutoDecreases: Bool = true
    ) {
        do {
            let descriptor = FetchDescriptor<LunixiaMedication>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )

            let medications = try modelContext.fetch(descriptor)

            repairMedicationHistory(
                medications: medications,
                modelContext: modelContext,
                now: now,
                shouldRepairRefills: shouldProcessRefills
            )

            if shouldProcessRefills {
                processRefills(
                    medications: medications,
                    modelContext: modelContext,
                    now: now
                )
            }

            if shouldProcessAutoDecreases {
                processAutoDecreases(
                    medications: medications,
                    modelContext: modelContext,
                    now: now
                )
            }

            if modelContext.hasChanges {
                try modelContext.save()
            }
        } catch {
            print("[MedicationAutomationManager] Automation failed: \(error)")
        }
    }

    static func dayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: day)
    }

    // MARK: - Refills

    private static func processRefills(
        medications: [LunixiaMedication],
        modelContext: ModelContext,
        now: Date
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let todayKey = dayKey(for: today)

        for medication in medications {
            guard medication.isActive,
                  let refillDate = medication.refillDate,
                  calendar.startOfDay(for: refillDate) <= today,
                  medication.lastAutoRefillDayKey != todayKey else {
                continue
            }

            let refillDay = calendar.startOfDay(for: refillDate)
            let refillDayKey = dayKey(for: refillDay)

            if let existingRefill = automatedRefillEntry(
                for: medication,
                effectiveDayKey: refillDayKey
            ) {
                reconcileInventoryFromAutomatedRefill(
                    existingRefill,
                    medication: medication,
                    entries: medication.historyEntries ?? [],
                    throughDayKey: todayKey,
                    now: now
                )

                medication.lastAutoRefillDayKey = todayKey
                medication.updatedAt = now

                if let nextRefill = nextRefillDate(
                    after: refillDay,
                    daysSupply: medication.daysSupply,
                    today: today
                ) {
                    medication.refillDate = nextRefill
                }

                MedicationNotificationManager.shared.reschedule(for: medication)
                continue
            }

            let previousAmount = medication.currentAmount

            medication.currentAmount = max(0, medication.supplyAmount)
            medication.lastAutoRefillDayKey = todayKey
            medication.updatedAt = now

            if let nextRefill = nextRefillDate(
                after: refillDay,
                daysSupply: medication.daysSupply,
                today: today
            ) {
                medication.refillDate = nextRefill
            }

            modelContext.insert(
                LunixiaMedHistoryEntry(
                    type: .refilled,
                    amountText: "\(previousAmount) → \(medication.currentAmount)",
                    details: medication.daysSupply > 0
                        ? "Auto-refilled on refill date. Next refill in \(medication.daysSupply) days."
                        : "Auto-refilled on refill date.",
                    effectiveDayKey: refillDayKey,
                    automationKey: autoRefillAutomationKey(
                        for: medication,
                        effectiveDayKey: refillDayKey
                    ),
                    medication: medication
                )
            )

            MedicationNotificationManager.shared.reschedule(for: medication)
        }
    }

    // MARK: - Auto Decrease

    private static func processAutoDecreases(
        medications: [LunixiaMedication],
        modelContext: ModelContext,
        now: Date
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let todayKey = dayKey(for: today)

        for medication in medications {
            guard medication.isActive,
                  medication.autoDecreaseEnabled else {
                continue
            }

            if medication.lastAutoDecreaseDayKey.isEmpty {
                medication.lastAutoDecreaseDayKey = todayKey
                medication.updatedAt = now
                continue
            }

            guard let lastProcessedDay = date(
                fromDayKey: medication.lastAutoDecreaseDayKey
            ) else {
                medication.lastAutoDecreaseDayKey = todayKey
                medication.updatedAt = now
                continue
            }

            guard let firstUnprocessedDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: lastProcessedDay
            ),
            firstUnprocessedDay <= today else {
                continue
            }

            var dayToProcess = firstUnprocessedDay

            while dayToProcess <= today {
                let isToday = calendar.isDate(
                    dayToProcess,
                    inSameDayAs: today
                )

                if isToday {
                    let scheduledTime = automationTime(
                        for: medication,
                        on: dayToProcess
                    )

                    if now < scheduledTime {
                        break
                    }
                }

                let doses = scheduledDoseCount(
                    for: medication,
                    on: dayToProcess
                )

                let processedDayKey = dayKey(for: dayToProcess)

                if doses > 0 {
                    if hasTakenEntry(
                        for: medication,
                        effectiveDayKey: processedDayKey
                    ) {
                        medication.lastAutoDecreaseDayKey = processedDayKey
                        medication.updatedAt = now

                        guard let nextDay = calendar.date(
                            byAdding: .day,
                            value: 1,
                            to: dayToProcess
                        ) else {
                            break
                        }

                        dayToProcess = nextDay
                        continue
                    }

                    let previousAmount = medication.currentAmount
                    let newAmount = max(0, previousAmount - doses)

                    medication.currentAmount = newAmount

                    let formattedDay = dayToProcess.formatted(
                        date: .abbreviated,
                        time: .omitted
                    )

                    let details: String

                    if isToday {
                        details = doses > 1
                            ? "Auto-decreased by today’s scheduled \(doses) doses."
                            : "Auto-decreased by today’s scheduled dose."
                    } else {
                        details = doses > 1
                            ? "Backfilled \(doses) scheduled doses for \(formattedDay)."
                            : "Backfilled scheduled dose for \(formattedDay)."
                    }

                    modelContext.insert(
                        LunixiaMedHistoryEntry(
                            type: .taken,
                            amountText: "\(previousAmount) → \(newAmount)",
                            details: details,
                            effectiveDayKey: processedDayKey,
                            automationKey: autoDecreaseAutomationKey(
                                for: medication,
                                effectiveDayKey: processedDayKey
                            ),
                            medication: medication
                        )
                    )
                }

                medication.lastAutoDecreaseDayKey = processedDayKey
                medication.updatedAt = now

                guard let nextDay = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: dayToProcess
                ) else {
                    break
                }

                dayToProcess = nextDay
            }
        }
    }

    // MARK: - Schedule Helpers

    private static func date(fromDayKey dayKey: String) -> Date? {
        let calendar = Calendar.current

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let parsedDate = formatter.date(from: dayKey) else {
            return nil
        }

        return calendar.startOfDay(for: parsedDate)
    }

    private static func automationTime(
        for medication: LunixiaMedication,
        on day: Date
    ) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)

        let hour = min(max(medication.autoDecreaseHour, 0), 23)
        let minute = min(max(medication.autoDecreaseMinute, 0), 59)

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: dayStart
        ) ?? dayStart
    }

    private static func scheduledDoseCount(
        for medication: LunixiaMedication,
        on day: Date
    ) -> Int {
        let weekday = Calendar.current.component(.weekday, from: day)

        switch medication.scheduleFrequency {
        case .daily:
            let amount = medication.doseScheduleOverrides[weekday]
                ?? medication.timesPerDay

            return max(0, amount)

        case .weekly:
            guard weekday == medication.weeklyWeekday else {
                return 0
            }

            return max(0, medication.timesPerDay)
        }
    }

    // MARK: - History Repair and Idempotency

    private static func repairMedicationHistory(
        medications: [LunixiaMedication],
        modelContext: ModelContext,
        now: Date,
        shouldRepairRefills: Bool
    ) {
        for medication in medications where medication.isActive {
            let entries = medication.historyEntries ?? []

            for entry in entries {
                let effectiveDayKey = normalizedEffectiveDayKey(for: entry)
                if entry.effectiveDayKey != effectiveDayKey {
                    entry.effectiveDayKey = effectiveDayKey
                }

                let automationKey = normalizedAutomationKey(
                    for: entry,
                    medication: medication,
                    effectiveDayKey: effectiveDayKey
                )

                if entry.automationKey != automationKey {
                    entry.automationKey = automationKey
                }
            }

            removeDuplicateAutomatedTakenEntries(
                for: medication,
                entries: entries,
                modelContext: modelContext,
                now: now
            )

            if shouldRepairRefills {
                removeDuplicateAutomatedRefillEntries(
                    entries: entries,
                    modelContext: modelContext
                )

                removeImpossibleAutomatedRefills(
                    for: medication,
                    entries: entries,
                    modelContext: modelContext,
                    now: now
                )

                reconcileInventoryFromLatestAutomatedRefill(
                    for: medication,
                    entries: medication.historyEntries ?? entries,
                    now: now
                )
            }

            advanceAutoDecreaseDayKeyFromHistory(
                for: medication,
                now: now
            )
        }
    }

    private static func removeDuplicateAutomatedTakenEntries(
        for medication: LunixiaMedication,
        entries: [LunixiaMedHistoryEntry],
        modelContext: ModelContext,
        now: Date
    ) {
        let automatedTakenEntries = entries.filter {
            isAutomatedTakenEntry($0) && !$0.effectiveDayKey.isEmpty
        }
        let groupedByDay = Dictionary(
            grouping: automatedTakenEntries,
            by: \.effectiveDayKey
        )

        for (_, dayEntries) in groupedByDay where dayEntries.count > 1 {
            let sortedEntries = dayEntries.sorted { lhs, rhs in
                let lhsRank = duplicateKeepRank(for: lhs)
                let rhsRank = duplicateKeepRank(for: rhs)

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                return lhs.createdAt < rhs.createdAt
            }

            for duplicate in sortedEntries.dropFirst() {
                if shouldRestoreInventory(
                    for: duplicate,
                    among: entries
                ) {
                    let restoredAmount = medication.currentAmount + amountDecrement(
                        from: duplicate.amountText
                    )

                    medication.currentAmount = medication.supplyAmount > 0
                        ? min(medication.supplyAmount, restoredAmount)
                        : restoredAmount
                    medication.updatedAt = now
                }

                modelContext.delete(duplicate)
            }
        }
    }

    private static func removeDuplicateAutomatedRefillEntries(
        entries: [LunixiaMedHistoryEntry],
        modelContext: ModelContext
    ) {
        let automatedRefillEntries = entries.filter {
            isAutomatedRefillEntry($0) && !$0.effectiveDayKey.isEmpty
        }
        let groupedByDay = Dictionary(
            grouping: automatedRefillEntries,
            by: \.effectiveDayKey
        )

        for (_, dayEntries) in groupedByDay where dayEntries.count > 1 {
            let sortedEntries = dayEntries.sorted { $0.createdAt < $1.createdAt }

            for duplicate in sortedEntries.dropFirst() {
                modelContext.delete(duplicate)
            }
        }
    }

    private static func removeImpossibleAutomatedRefills(
        for medication: LunixiaMedication,
        entries: [LunixiaMedHistoryEntry],
        modelContext: ModelContext,
        now: Date
    ) {
        guard medication.daysSupply > 0 else {
            return
        }

        let calendar = Calendar.current
        let automatedRefillEntries = entries
            .filter { isAutomatedRefillEntry($0) && !$0.effectiveDayKey.isEmpty }
            .sorted { lhs, rhs in
                if lhs.effectiveDayKey != rhs.effectiveDayKey {
                    return lhs.effectiveDayKey < rhs.effectiveDayKey
                }

                return lhs.createdAt < rhs.createdAt
            }

        var lastAcceptedRefillDay: Date?
        var lastAcceptedRefillEntry: LunixiaMedHistoryEntry?

        for entry in automatedRefillEntries {
            guard let refillDay = date(fromDayKey: entry.effectiveDayKey) else {
                continue
            }

            if let previousRefillDay = lastAcceptedRefillDay,
               let nextValidRefillDay = calendar.date(
                byAdding: .day,
                value: medication.daysSupply,
                to: previousRefillDay
               ),
               refillDay < nextValidRefillDay {
                if let previousRefillEntry = lastAcceptedRefillEntry {
                    restoreInventoryForImpossibleRefillIfSafe(
                        entry,
                        previousRefillEntry: previousRefillEntry,
                        previousRefillDay: previousRefillDay,
                        medication: medication,
                        entries: entries,
                        now: now
                    )
                }

                modelContext.delete(entry)
                continue
            }

            lastAcceptedRefillDay = refillDay
            lastAcceptedRefillEntry = entry
        }
    }

    private static func restoreInventoryForImpossibleRefillIfSafe(
        _ impossibleRefill: LunixiaMedHistoryEntry,
        previousRefillEntry: LunixiaMedHistoryEntry,
        previousRefillDay: Date,
        medication: LunixiaMedication,
        entries: [LunixiaMedHistoryEntry],
        now: Date
    ) {
        guard !hasManualInventoryChange(
            among: entries,
            after: previousRefillEntry.createdAt,
            before: impossibleRefill.createdAt
        ),
        !hasManualInventoryChange(
            among: entries,
            after: impossibleRefill.createdAt
        ),
        let impossibleRefillDay = date(fromDayKey: impossibleRefill.effectiveDayKey),
        let amountAfterImpossibleRefill = amountAfterChange(from: impossibleRefill.amountText)
        else {
            return
        }

        let previousRefillAmount = amountAfterChange(
            from: previousRefillEntry.amountText
        ) ?? medication.supplyAmount
        let expectedAmount = expectedAmountAfterScheduledDoses(
            startingAmount: previousRefillAmount,
            from: previousRefillDay,
            through: impossibleRefillDay,
            medication: medication
        )
        let excess = max(0, amountAfterImpossibleRefill - expectedAmount)

        guard excess > 0 else {
            return
        }

        medication.currentAmount = max(0, medication.currentAmount - excess)
        medication.updatedAt = now
    }

    private static func hasManualInventoryChange(
        among entries: [LunixiaMedHistoryEntry],
        after startDate: Date,
        before endDate: Date? = nil
    ) -> Bool {
        entries.contains { entry in
            guard entry.type == .edited,
                  entry.createdAt > startDate else {
                return false
            }

            if let endDate {
                return entry.createdAt < endDate
            }

            return true
        }
    }

    private static func expectedAmountAfterScheduledDoses(
        startingAmount: Int,
        from startDay: Date,
        through endDay: Date,
        medication: LunixiaMedication
    ) -> Int {
        let calendar = Calendar.current
        var amount = max(0, startingAmount)
        var day = calendar.startOfDay(for: startDay)
        let end = calendar.startOfDay(for: endDay)

        while day <= end {
            amount = max(
                0,
                amount - scheduledDoseCount(
                    for: medication,
                    on: day
                )
            )

            guard let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: day
            ) else {
                break
            }

            day = nextDay
        }

        return amount
    }

    private static func advanceAutoDecreaseDayKeyFromHistory(
        for medication: LunixiaMedication,
        now: Date
    ) {
        guard medication.autoDecreaseEnabled else {
            return
        }

        let todayKey = dayKey(for: now)
        let latestTakenDayKey = (medication.historyEntries ?? [])
            .filter { $0.type == .taken }
            .map { normalizedEffectiveDayKey(for: $0) }
            .filter { !$0.isEmpty && $0 <= todayKey }
            .max()

        guard let latestTakenDayKey else {
            return
        }

        if medication.lastAutoDecreaseDayKey.isEmpty ||
            latestTakenDayKey > medication.lastAutoDecreaseDayKey {
            medication.lastAutoDecreaseDayKey = latestTakenDayKey
            medication.updatedAt = now
        }
    }

    private static func hasTakenEntry(
        for medication: LunixiaMedication,
        effectiveDayKey: String
    ) -> Bool {
        (medication.historyEntries ?? []).contains { entry in
            entry.type == .taken &&
            normalizedEffectiveDayKey(for: entry) == effectiveDayKey
        }
    }

    private static func automatedRefillEntry(
        for medication: LunixiaMedication,
        effectiveDayKey: String
    ) -> LunixiaMedHistoryEntry? {
        let key = autoRefillAutomationKey(
            for: medication,
            effectiveDayKey: effectiveDayKey
        )

        return (medication.historyEntries ?? [])
            .filter { entry in
                isAutomatedRefillEntry(entry) &&
                (
                    entry.automationKey == key ||
                    normalizedEffectiveDayKey(for: entry) == effectiveDayKey
                )
            }
            .sorted { $0.createdAt < $1.createdAt }
            .first
    }

    private static func reconcileInventoryFromLatestAutomatedRefill(
        for medication: LunixiaMedication,
        entries: [LunixiaMedHistoryEntry],
        now: Date
    ) {
        let todayKey = dayKey(for: now)
        guard let latestRefill = entries
            .filter({
                isAutomatedRefillEntry($0) &&
                normalizedEffectiveDayKey(for: $0) <= todayKey
            })
            .sorted(by: {
                let lhsDay = normalizedEffectiveDayKey(for: $0)
                let rhsDay = normalizedEffectiveDayKey(for: $1)

                if lhsDay != rhsDay {
                    return lhsDay < rhsDay
                }

                return $0.createdAt < $1.createdAt
            })
            .last else {
            return
        }

        reconcileInventoryFromAutomatedRefill(
            latestRefill,
            medication: medication,
            entries: entries,
            throughDayKey: todayKey,
            now: now
        )
    }

    private static func reconcileInventoryFromAutomatedRefill(
        _ refillEntry: LunixiaMedHistoryEntry,
        medication: LunixiaMedication,
        entries: [LunixiaMedHistoryEntry],
        throughDayKey: String,
        now: Date
    ) {
        let refillDayKey = normalizedEffectiveDayKey(for: refillEntry)
        guard !refillDayKey.isEmpty else {
            return
        }

        guard !hasManualInventoryChange(
            among: entries,
            after: refillEntry.createdAt
        ) else {
            return
        }

        let refilledAmount = amountAfterChange(from: refillEntry.amountText)
            ?? max(0, medication.supplyAmount)
        let takenAmount = entries.reduce(0) { partial, entry in
            guard entry.type == .taken else {
                return partial
            }

            let entryDayKey = normalizedEffectiveDayKey(for: entry)
            guard entryDayKey >= refillDayKey,
                  entryDayKey <= throughDayKey else {
                return partial
            }

            if entry.id == refillEntry.id {
                return partial
            }

            let recordedDecrease = amountDecrement(from: entry.amountText)
            if recordedDecrease > 0 {
                return partial + recordedDecrease
            }

            guard let entryDay = date(fromDayKey: entryDayKey) else {
                return partial
            }

            return partial + scheduledDoseCount(
                for: medication,
                on: entryDay
            )
        }

        let reconciledAmount = max(0, refilledAmount - takenAmount)

        if medication.currentAmount != reconciledAmount {
            medication.currentAmount = reconciledAmount
            medication.updatedAt = now
        }
    }

    private static func normalizedAutomationKey(
        for entry: LunixiaMedHistoryEntry,
        medication: LunixiaMedication,
        effectiveDayKey: String
    ) -> String {
        guard !effectiveDayKey.isEmpty else {
            return ""
        }

        if isAutomatedTakenEntry(entry) {
            return autoDecreaseAutomationKey(
                for: medication,
                effectiveDayKey: effectiveDayKey
            )
        }

        if isAutomatedRefillEntry(entry) {
            return autoRefillAutomationKey(
                for: medication,
                effectiveDayKey: effectiveDayKey
            )
        }

        return entry.automationKey
    }

    private static func normalizedEffectiveDayKey(
        for entry: LunixiaMedHistoryEntry
    ) -> String {
        if !entry.effectiveDayKey.isEmpty {
            return entry.effectiveDayKey
        }

        if isBackfilledTakenEntry(entry),
           let day = backfilledDay(from: entry.details) {
            return dayKey(for: day)
        }

        return dayKey(for: entry.createdAt)
    }

    private static func isAutomatedTakenEntry(
        _ entry: LunixiaMedHistoryEntry
    ) -> Bool {
        entry.type == .taken &&
        (
            entry.details.hasPrefix("Auto-decreased") ||
            isBackfilledTakenEntry(entry)
        )
    }

    private static func isBackfilledTakenEntry(
        _ entry: LunixiaMedHistoryEntry
    ) -> Bool {
        entry.type == .taken &&
        entry.details.hasPrefix("Backfilled")
    }

    private static func isAutomatedRefillEntry(
        _ entry: LunixiaMedHistoryEntry
    ) -> Bool {
        entry.type == .refilled &&
        entry.details.hasPrefix("Auto-refilled")
    }

    private static func duplicateKeepRank(
        for entry: LunixiaMedHistoryEntry
    ) -> Int {
        isBackfilledTakenEntry(entry) ? 1 : 0
    }

    private static func shouldRestoreInventory(
        for duplicate: LunixiaMedHistoryEntry,
        among entries: [LunixiaMedHistoryEntry]
    ) -> Bool {
        !entries.contains { entry in
            entry.createdAt > duplicate.createdAt &&
            (entry.type == .refilled || entry.type == .edited)
        }
    }

    private static func amountDecrement(from amountText: String) -> Int {
        let separator = amountText.contains("→") ? "→" : "->"
        let parts = amountText.components(separatedBy: separator)

        guard parts.count == 2,
              let previous = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let current = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return 0
        }

        return max(0, previous - current)
    }

    private static func amountAfterChange(from amountText: String) -> Int? {
        let separator = amountText.contains("→") ? "→" : "->"
        let parts = amountText.components(separatedBy: separator)

        guard parts.count == 2 else {
            return nil
        }

        return Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func backfilledDay(from details: String) -> Date? {
        guard let range = details.range(of: " for ") else {
            return nil
        }

        let rawDate = details[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = Calendar.current.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"

        return formatter.date(from: rawDate)
    }

    private static func nextRefillDate(
        after refillDay: Date,
        daysSupply: Int,
        today: Date
    ) -> Date? {
        guard daysSupply > 0 else {
            return nil
        }

        let calendar = Calendar.current
        var nextRefill = refillDay

        repeat {
            guard let advanced = calendar.date(
                byAdding: .day,
                value: daysSupply,
                to: nextRefill
            ) else {
                return nil
            }

            nextRefill = advanced
        } while nextRefill <= today

        return nextRefill
    }

    private static func autoDecreaseAutomationKey(
        for medication: LunixiaMedication,
        effectiveDayKey: String
    ) -> String {
        "medication:autoDecrease:\(medication.id.uuidString):\(effectiveDayKey)"
    }

    private static func autoRefillAutomationKey(
        for medication: LunixiaMedication,
        effectiveDayKey: String
    ) -> String {
        "medication:autoRefill:\(medication.id.uuidString):\(effectiveDayKey)"
    }
}
