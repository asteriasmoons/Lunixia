//
//  MedicationAutomationManager.swift
//  Lunixia
//

import Foundation
import SwiftData

@MainActor
enum MedicationAutomationManager {

    private struct InventoryAuditResult {
        let amount: Int
        let sourceEntry: LunixiaMedHistoryEntry
        let firstGap: (expected: Int, recorded: Int)?
    }

    // MARK: - Public API

    static func run(
        in modelContext: ModelContext,
        now: Date = Date(),
        shouldProcessRefills: Bool = true,
        shouldProcessAutoDecreases: Bool = true,
        shouldReconcileSyncedInventory: Bool = false
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

            if shouldReconcileSyncedInventory {
                reconcileSyncedInventoryAmounts(
                    medications: medications,
                    modelContext: modelContext,
                    now: now
                )
            }

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

            if automatedRefillEntry(
                for: medication,
                effectiveDayKey: refillDayKey
            ) != nil {
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
                entries: entries,
                modelContext: modelContext
            )

            if shouldRepairRefills {
                removeDuplicateAutomatedRefillEntries(
                    entries: entries,
                    modelContext: modelContext
                )

            }

            advanceAutoDecreaseDayKeyFromHistory(
                for: medication,
                now: now
            )
        }
    }

    private static func removeDuplicateAutomatedTakenEntries(
        entries: [LunixiaMedHistoryEntry],
        modelContext: ModelContext
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

    private static func reconcileSyncedInventoryAmounts(
        medications: [LunixiaMedication],
        modelContext: ModelContext,
        now: Date
    ) {
        for medication in medications {
            guard let audit = auditedInventoryResult(for: medication),
                  medication.currentAmount != audit.amount,
                  audit.firstGap != nil ||
                    audit.sourceEntry.createdAt >= medication.updatedAt else {
                continue
            }

            let previousAmount = medication.currentAmount
            let historyEntries = medication.historyEntries ?? []
            let previousSyncAudit = historyEntries
                .filter {
                    isSyncInventoryAuditEntry($0) &&
                    $0.createdAt >= audit.sourceEntry.createdAt
                }
                .max { $0.createdAt < $1.createdAt }
            let displayedPreviousAmount = previousSyncAudit
                .flatMap { amountChange(from: $0.amountText)?.previous }
                ?? previousAmount
            let auditKey = syncInventoryAuditKey(
                for: medication,
                sourceEntry: audit.sourceEntry,
                previousAmount: displayedPreviousAmount,
                correctedAmount: audit.amount
            )

            medication.currentAmount = audit.amount
            medication.updatedAt = now

            let details: String
            if let gap = audit.firstGap {
                details = "Corrected inventory after CloudKit sync found an unaudited \(gap.expected) → \(gap.recorded) gap."
            } else {
                details = "Restored inventory to the latest audited value after CloudKit sync."
            }

            if let previousSyncAudit {
                previousSyncAudit.amountText = "\(displayedPreviousAmount) → \(audit.amount)"
                previousSyncAudit.details = details
                previousSyncAudit.automationKey = auditKey
                continue
            }

            let alreadyRecorded = historyEntries.contains {
                $0.automationKey == auditKey
            }

            guard !alreadyRecorded else {
                continue
            }

            modelContext.insert(
                LunixiaMedHistoryEntry(
                    type: .edited,
                    amountText: "\(previousAmount) → \(audit.amount)",
                    details: details,
                    effectiveDayKey: dayKey(for: now),
                    automationKey: auditKey,
                    createdAt: now,
                    medication: medication
                )
            )
        }
    }

    private static func auditedInventoryResult(
        for medication: LunixiaMedication
    ) -> InventoryAuditResult? {
        let entries = canonicalInventoryEntries(
            medication.historyEntries ?? []
        ).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        var auditedAmount: Int?
        var sourceEntry: LunixiaMedHistoryEntry?
        var unresolvedGap: (expected: Int, recorded: Int)?
        let latestScheduleChangeDayKey = entries
            .filter {
                $0.type == .edited &&
                $0.details.localizedCaseInsensitiveContains("dose schedule")
            }
            .max { $0.createdAt < $1.createdAt }
            .map { normalizedEffectiveDayKey(for: $0) }

        for entry in entries {
            guard !isSyncInventoryAuditEntry(entry) else {
                continue
            }

            guard let change = amountChange(from: entry.amountText) else {
                continue
            }

            if change.previous == change.current {
                continue
            }

            if auditedAmount == nil {
                auditedAmount = change.previous
            }

            guard let expectedBeforeChange = auditedAmount else {
                continue
            }

            switch entry.type {
            case .taken:
                updateUnresolvedGap(
                    &unresolvedGap,
                    expected: expectedBeforeChange,
                    recorded: change.previous
                )

                let delta: Int
                let entryDayKey = normalizedEffectiveDayKey(for: entry)
                if let latestScheduleChangeDayKey,
                   entryDayKey >= latestScheduleChangeDayKey,
                   let entryDay = date(fromDayKey: entryDayKey) {
                    delta = -scheduledDoseCount(
                        for: medication,
                        on: entryDay
                    )
                } else {
                    delta = change.current - change.previous
                }

                auditedAmount = max(0, expectedBeforeChange + delta)

            case .refilled:
                auditedAmount = max(0, change.current)
                unresolvedGap = nil

            case .edited:
                if entry.details == "Manual inventory increase" ||
                    entry.details == "Manual inventory decrease" {
                    updateUnresolvedGap(
                        &unresolvedGap,
                        expected: expectedBeforeChange,
                        recorded: change.previous
                    )

                    let delta = change.current - change.previous
                    auditedAmount = max(0, expectedBeforeChange + delta)
                } else {
                    auditedAmount = max(0, change.current)
                    unresolvedGap = nil
                }
            }

            sourceEntry = entry
        }

        guard let auditedAmount, let sourceEntry else {
            return nil
        }

        return InventoryAuditResult(
            amount: auditedAmount,
            sourceEntry: sourceEntry,
            firstGap: unresolvedGap
        )
    }

    private static func updateUnresolvedGap(
        _ gap: inout (expected: Int, recorded: Int)?,
        expected: Int,
        recorded: Int
    ) {
        if expected == recorded {
            gap = nil
        } else if gap == nil ||
                    gap.map({ $0.recorded - $0.expected }) != recorded - expected {
            gap = (expected: expected, recorded: recorded)
        }
    }

    private static func canonicalInventoryEntries(
        _ entries: [LunixiaMedHistoryEntry]
    ) -> [LunixiaMedHistoryEntry] {
        let automatedTakenEntries = entries.filter { isAutomatedTakenEntry($0) }
        let takenByDay = Dictionary(
            grouping: automatedTakenEntries,
            by: { normalizedEffectiveDayKey(for: $0) }
        )
        let keptTakenIDs = Set(takenByDay.values.compactMap { entriesForDay in
            entriesForDay.sorted { lhs, rhs in
                let lhsRank = duplicateKeepRank(for: lhs)
                let rhsRank = duplicateKeepRank(for: rhs)

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                return lhs.createdAt < rhs.createdAt
            }.first?.id
        })

        let automatedRefillEntries = entries.filter { isAutomatedRefillEntry($0) }
        let refillByDay = Dictionary(
            grouping: automatedRefillEntries,
            by: { normalizedEffectiveDayKey(for: $0) }
        )
        let keptRefillIDs = Set(refillByDay.values.compactMap { entriesForDay in
            entriesForDay.min { $0.createdAt < $1.createdAt }?.id
        })

        return entries.filter { entry in
            if isAutomatedTakenEntry(entry) {
                return keptTakenIDs.contains(entry.id)
            }

            if isAutomatedRefillEntry(entry) {
                return keptRefillIDs.contains(entry.id)
            }

            return true
        }
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

    private static func isSyncInventoryAuditEntry(
        _ entry: LunixiaMedHistoryEntry
    ) -> Bool {
        entry.automationKey.hasPrefix("medication:syncInventoryAudit:")
    }

    private static func duplicateKeepRank(
        for entry: LunixiaMedHistoryEntry
    ) -> Int {
        isBackfilledTakenEntry(entry) ? 1 : 0
    }

    private static func amountChange(
        from amountText: String
    ) -> (previous: Int, current: Int)? {
        let separator = amountText.contains("→") ? "→" : "->"
        let parts = amountText.components(separatedBy: separator)

        guard parts.count == 2,
              let previous = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let current = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return (previous, current)
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

    private static func syncInventoryAuditKey(
        for medication: LunixiaMedication,
        sourceEntry: LunixiaMedHistoryEntry,
        previousAmount: Int,
        correctedAmount: Int
    ) -> String {
        "medication:syncInventoryAudit:\(medication.id.uuidString):\(sourceEntry.id.uuidString):\(previousAmount):\(correctedAmount)"
    }
}
