//
//  HealthHistoryManager.swift
//  Lunixia
//

import Foundation
import SwiftData

@MainActor
enum HealthHistoryManager {
    @discardableResult
    static func recordWaterCleared(
        in modelContext: ModelContext,
        amountOz: Double,
        previousTotalOz: Double,
        currentTotalOz: Double,
        goalOz: Double,
        at date: Date = Date()
    ) -> Bool {
        guard amountOz > 0 else { return false }

        let dayKey = dayKey(from: date)
        let milliseconds = Int(date.timeIntervalSince1970 * 1000)
        let eventKey = "water:cleared:\(dayKey):\(milliseconds)"

        return insertIfMissing(
            HealthMetricHistoryEntry(
                metric: .water,
                event: .cleared,
                dayKey: dayKey,
                eventKey: eventKey,
                timestamp: date,
                amount: amountOz,
                previousValue: previousTotalOz,
                currentValue: max(0, currentTotalOz),
                goalValue: goalOz,
                details: "Cleared \(Int(amountOz)) oz from today’s total."
            ),
            in: modelContext
        )
    }

    @discardableResult
    static func recordWaterCompletionIfNeeded(
        in modelContext: ModelContext,
        totalOz: Double,
        goalOz: Double,
        at date: Date = Date()
    ) -> Bool {
        guard goalOz > 0, totalOz >= goalOz else { return false }

        let dayKey = dayKey(from: date)
        let eventKey = "water:completed:\(dayKey)"

        return insertIfMissing(
            HealthMetricHistoryEntry(
                metric: .water,
                event: .completed,
                dayKey: dayKey,
                eventKey: eventKey,
                timestamp: date,
                amount: totalOz,
                currentValue: totalOz,
                goalValue: goalOz,
                details: "Daily water goal completed."
            ),
            in: modelContext
        )
    }

    @discardableResult
    static func recordStepSamples(
        _ samples: [HealthKitStepSample],
        in modelContext: ModelContext,
        totalSteps: Int,
        goalSteps: Int
    ) -> Bool {
        let dayKey = dayKey(from: Date())
        let sortedSamples = samples.sorted { lhs, rhs in
            if lhs.endDate != rhs.endDate {
                return lhs.endDate < rhs.endDate
            }

            return lhs.id < rhs.id
        }

        var runningTotal = 0
        let cappedTotal = max(0, totalSteps)
        var expectedEntries: [HealthMetricHistoryEntry] = []

        for sample in sortedSamples {
            guard runningTotal < cappedTotal else { break }

            let amount = min(sample.steps, cappedTotal - runningTotal)
            guard amount > 0 else { continue }

            let previousTotal = runningTotal
            runningTotal += amount

            let sampleDayKey = Self.dayKey(from: sample.endDate)
            let eventKey = "steps:sample:\(sample.id)"
            expectedEntries.append(
                HealthMetricHistoryEntry(
                    metric: .steps,
                    event: .sample,
                    dayKey: sampleDayKey,
                    eventKey: eventKey,
                    timestamp: sample.endDate,
                    amount: Double(amount),
                    previousValue: Double(previousTotal),
                    currentValue: Double(runningTotal),
                    goalValue: Double(goalSteps),
                    details: "HealthKit step sample captured."
                )
            )
        }

        return replaceTodayStepSamples(
            with: expectedEntries,
            dayKey: dayKey,
            totalSteps: cappedTotal,
            in: modelContext
        )
    }

    @discardableResult
    private static func replaceTodayStepSamples(
        with expectedEntries: [HealthMetricHistoryEntry],
        dayKey: String,
        totalSteps: Int,
        in modelContext: ModelContext
    ) -> Bool {
        let existingEntries = fetchEntries(
            in: modelContext,
            metric: .steps,
            event: .sample,
            dayKey: dayKey
        )
        let expectedKeys = Set(expectedEntries.map(\.eventKey))
        var existingByKey: [String: HealthMetricHistoryEntry] = [:]
        var changed = false

        for existing in existingEntries {
            if !expectedKeys.contains(existing.eventKey) ||
                existing.currentValue > Double(totalSteps) ||
                existingByKey[existing.eventKey] != nil {
                modelContext.delete(existing)
                changed = true
            } else {
                existingByKey[existing.eventKey] = existing
            }
        }

        for expected in expectedEntries {
            if let existing = existingByKey[expected.eventKey] {
                changed = updateIfNeeded(existing, from: expected) || changed
            } else {
                modelContext.insert(expected)
                changed = true
            }
        }

        if changed {
            try? modelContext.save()
        }

        return changed
    }

    static func recordStepCompletionIfNeeded(
        in modelContext: ModelContext,
        steps: Int,
        goalSteps: Int,
        at date: Date = Date()
    ) -> Bool {
        let dayKey = dayKey(from: date)
        let existingEntries = fetchEntries(
            in: modelContext,
            metric: .steps,
            event: .completed,
            dayKey: dayKey
        )

        guard goalSteps > 0, steps >= goalSteps else {
            var removedAny = false
            for entry in existingEntries {
                modelContext.delete(entry)
                removedAny = true
            }
            if removedAny {
                try? modelContext.save()
            }
            return removedAny
        }

        let eventKey = "steps:completed:\(dayKey)"

        return insertIfMissing(
            HealthMetricHistoryEntry(
                metric: .steps,
                event: .completed,
                dayKey: dayKey,
                eventKey: eventKey,
                timestamp: date,
                amount: Double(steps),
                currentValue: Double(steps),
                goalValue: Double(goalSteps),
                details: "Daily step goal completed."
            ),
            in: modelContext
        )
    }

    private static func insertIfMissing(
        _ entry: HealthMetricHistoryEntry,
        in modelContext: ModelContext
    ) -> Bool {
        guard !hasEntry(in: modelContext, eventKey: entry.eventKey) else {
            return false
        }

        modelContext.insert(entry)
        try? modelContext.save()
        return true
    }

    private static func hasEntry(
        in modelContext: ModelContext,
        eventKey: String
    ) -> Bool {
        let descriptor = FetchDescriptor<HealthMetricHistoryEntry>(
            predicate: #Predicate { $0.eventKey == eventKey }
        )

        return ((try? modelContext.fetch(descriptor)) ?? []).isEmpty == false
    }

    private static func latestEntry(
        in modelContext: ModelContext,
        metric: HealthMetricHistoryEntry.Metric,
        event: HealthMetricHistoryEntry.EventType,
        dayKey: String
    ) -> HealthMetricHistoryEntry? {
        let metricRaw = metric.rawValue
        let eventRaw = event.rawValue
        var descriptor = FetchDescriptor<HealthMetricHistoryEntry>(
            predicate: #Predicate {
                $0.metricRaw == metricRaw &&
                $0.eventRaw == eventRaw &&
                $0.dayKey == dayKey
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try? modelContext.fetch(descriptor).first
    }

    private static func fetchEntries(
        in modelContext: ModelContext,
        metric: HealthMetricHistoryEntry.Metric,
        event: HealthMetricHistoryEntry.EventType,
        dayKey: String
    ) -> [HealthMetricHistoryEntry] {
        let metricRaw = metric.rawValue
        let eventRaw = event.rawValue
        let descriptor = FetchDescriptor<HealthMetricHistoryEntry>(
            predicate: #Predicate {
                $0.metricRaw == metricRaw &&
                $0.eventRaw == eventRaw &&
                $0.dayKey == dayKey
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func updateIfNeeded(
        _ existing: HealthMetricHistoryEntry,
        from expected: HealthMetricHistoryEntry
    ) -> Bool {
        var changed = false

        if existing.timestamp != expected.timestamp {
            existing.timestamp = expected.timestamp
            changed = true
        }
        if existing.amount != expected.amount {
            existing.amount = expected.amount
            changed = true
        }
        if existing.previousValue != expected.previousValue {
            existing.previousValue = expected.previousValue
            changed = true
        }
        if existing.currentValue != expected.currentValue {
            existing.currentValue = expected.currentValue
            changed = true
        }
        if existing.goalValue != expected.goalValue {
            existing.goalValue = expected.goalValue
            changed = true
        }
        if existing.details != expected.details {
            existing.details = expected.details
            changed = true
        }

        return changed
    }

    private static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
