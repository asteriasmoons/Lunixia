//
//  HealthKitWriteManager.swift
//  Lunixia
//

import Foundation
import HealthKit

final class HealthKitWriteManager {
    static let shared = HealthKitWriteManager()
    private let store = HKHealthStore()
    private init() {}

    // MARK: - Authorization for writing

    func requestWriteAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        ]

        let readTypes: Set<HKObjectType> = writeTypes.compactMap { $0 as? HKObjectType }.reduce(into: Set<HKObjectType>()) { $0.insert($1) }

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        } catch {
            print("HealthKit write auth error: \(error)")
        }
    }

    // MARK: - Write Vitals

    @discardableResult
    func writeVitals(entry: VitalsEntry) async -> Bool {
        await requestWriteAuthorization()
        return await saveVitals(entry: entry)
    }

    private func saveVitals(entry: VitalsEntry) async -> Bool {
        let date = entry.timestamp
        var samples: [HKSample] = []

        // Blood Oxygen
        if entry.bloodOxygen > 0,
           let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            let qty = HKQuantity(unit: .percent(), doubleValue: entry.bloodOxygen / 100)
            samples.append(HKQuantitySample(type: type, quantity: qty, start: date, end: date))
        }

        // Heart Rate
        if entry.bpm > 0,
           let type = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let qty = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: entry.bpm)
            samples.append(HKQuantitySample(type: type, quantity: qty, start: date, end: date))
        }

        // Blood Pressure (systolic + diastolic must be written as a correlation)
        if entry.systolic > 0 && entry.diastolic > 0,
           let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
           let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic),
           let bpType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) {
            let systolicSample = HKQuantitySample(
                type: systolicType,
                quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: entry.systolic),
                start: date, end: date
            )
            let diastolicSample = HKQuantitySample(
                type: diastolicType,
                quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: entry.diastolic),
                start: date, end: date
            )
            let correlation = HKCorrelation(
                type: bpType,
                start: date,
                end: date,
                objects: [systolicSample, diastolicSample]
            )
            samples.append(correlation)
        }

        // Body Temperature
        if entry.bodyTemp > 0,
           let type = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
            let tempC = (entry.bodyTemp - 32) * 5 / 9
            let qty = HKQuantity(unit: .degreeCelsius(), doubleValue: tempC)
            samples.append(HKQuantitySample(type: type, quantity: qty, start: date, end: date))
        }

        // Weight
        if entry.weight > 0,
           let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            let qty = HKQuantity(unit: .pound(), doubleValue: entry.weight)
            samples.append(HKQuantitySample(type: type, quantity: qty, start: date, end: date))
        }

        guard !samples.isEmpty else { return false }

        do {
            try await store.save(samples)
            return true
        } catch {
            print("HealthKit vitals write error: \(error)")
            return false
        }
    }

    // MARK: - Backfill Vitals

    struct VitalsBackfillResult {
        let scanned: Int
        let written: Int
        let skippedExisting: Int
        let failed: Int
    }

    @MainActor
    func backfillVitals(entries: [VitalsEntry]) async -> VitalsBackfillResult {
        guard !entries.isEmpty else {
            return VitalsBackfillResult(scanned: 0, written: 0, skippedExisting: 0, failed: 0)
        }

        await requestWriteAuthorization()

        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        let start = sorted.first!.timestamp.addingTimeInterval(-2)
        let end = sorted.last!.timestamp.addingTimeInterval(2)
        let existingSystolic = await fetchExistingSystolicSamples(from: start, to: end)

        var written = 0
        var skipped = 0
        var failed = 0

        for entry in sorted {
            if entry.systolic > 0 && existingSystolic.contains(where: { sample in
                abs(sample.date.timeIntervalSince(entry.timestamp)) <= 1.0 &&
                abs(sample.value - entry.systolic) < 0.5
            }) {
                skipped += 1
                continue
            }

            if await saveVitals(entry: entry) {
                written += 1
            } else {
                failed += 1
            }
        }

        let result = VitalsBackfillResult(
            scanned: sorted.count,
            written: written,
            skippedExisting: skipped,
            failed: failed
        )
        print("[HealthKit] Vitals backfill scanned=\(result.scanned) written=\(result.written) skipped=\(result.skippedExisting) failed=\(result.failed)")
        return result
    }

    private func fetchExistingSystolicSamples(from start: Date, to end: Date) async -> [(date: Date, value: Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) else { return [] }
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate, .strictEndDate]
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    print("HealthKit systolic backfill query error: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                let values = (samples as? [HKQuantitySample] ?? []).map { sample in
                    (date: sample.startDate, value: sample.quantity.doubleValue(for: .millimeterOfMercury()))
                }
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }

    // MARK: - Write Exercise

    private let exerciseNameMetadataKey = "com.asteriasmoons.Lunixia.exerciseName"
    private let exerciseRepsMetadataKey = "com.asteriasmoons.Lunixia.reps"

    @discardableResult
    func writeExercise(entry: ExerciseEntry) async -> Bool {
        await requestWriteAuthorization()
        return await saveExercise(entry: entry, start: entry.timestamp)
    }

    private func saveExercise(entry: ExerciseEntry, start: Date) async -> Bool {
        let end = start.addingTimeInterval(Double(entry.durationMinutes) * 60)
        let syncIdentifier = "lunixia-exercise-\(entry.id.uuidString)"

        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: start,
            end: end,
            duration: Double(entry.durationMinutes) * 60,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "Lunixia",
                HKMetadataKeySyncIdentifier: syncIdentifier,
                HKMetadataKeySyncVersion: 2,
                exerciseNameMetadataKey: entry.name,
                exerciseRepsMetadataKey: entry.reps
            ]
        )

        do {
            try await store.save(workout)
            return true
        } catch {
            print("HealthKit exercise write error: \(error)")
            return false
        }
    }

    // MARK: - Backfill Exercise

    struct ExerciseBackfillResult {
        let scanned: Int
        let written: Int
        let skippedExisting: Int
        let failed: Int
    }

    @MainActor
    func backfillExercise(entries: [ExerciseEntry]) async -> ExerciseBackfillResult {
        guard !entries.isEmpty else {
            return ExerciseBackfillResult(scanned: 0, written: 0, skippedExisting: 0, failed: 0)
        }

        await requestWriteAuthorization()
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }

        var written = 0
        var failed = 0

        for dayEntries in grouped.values {
            let result = await syncExerciseDay(entries: dayEntries)
            written += result.written
            failed += result.failed
        }

        let result = ExerciseBackfillResult(
            scanned: entries.count,
            written: written,
            skippedExisting: 0,
            failed: failed
        )
        print("[HealthKit] Exercise backfill scanned=\(result.scanned) rewritten=\(result.written) failed=\(result.failed)")
        return result
    }

    @MainActor
    func syncExerciseDay(entries: [ExerciseEntry]) async -> ExerciseBackfillResult {
        guard !entries.isEmpty else {
            return ExerciseBackfillResult(scanned: 0, written: 0, skippedExisting: 0, failed: 0)
        }

        await requestWriteAuthorization()

        let calendar = Calendar.current
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        let dayStart = calendar.startOfDay(for: sorted[0].timestamp)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let existing = await fetchExistingWorkouts(from: dayStart, to: dayEnd)

        let lunixiaWorkouts = existing.filter { workout in
            sorted.contains { entry in
                matchesExercise(workout, entry: entry)
            }
        }

        if !lunixiaWorkouts.isEmpty {
            do {
                try await store.delete(lunixiaWorkouts)
            } catch {
                print("HealthKit exercise replacement delete error: \(error)")
                return ExerciseBackfillResult(scanned: sorted.count, written: 0, skippedExisting: 0, failed: sorted.count)
            }
        }

        let totalSeconds = sorted.reduce(0.0) { $0 + Double($1.durationMinutes) * 60 }
        let latestLoggedAt = sorted.last!.timestamp
        let latestAllowedEnd = dayEnd.addingTimeInterval(-1)
        var packedEnd = min(latestLoggedAt, latestAllowedEnd)
        let minimumEnd = dayStart.addingTimeInterval(totalSeconds)
        if packedEnd < minimumEnd {
            packedEnd = minimumEnd
        }

        var cursor = packedEnd.addingTimeInterval(-totalSeconds)
        var written = 0
        var failed = 0

        for entry in sorted {
            if await saveExercise(entry: entry, start: cursor) {
                written += 1
            } else {
                failed += 1
            }
            cursor = cursor.addingTimeInterval(Double(entry.durationMinutes) * 60)
        }

        let totalMinutes = sorted.reduce(0) { $0 + $1.durationMinutes }
        print("[HealthKit] Exercise day sync date=\(dayStart) entries=\(sorted.count) totalMinutes=\(totalMinutes) rewritten=\(written) failed=\(failed)")
        return ExerciseBackfillResult(scanned: sorted.count, written: written, skippedExisting: 0, failed: failed)
    }

    private func fetchExistingWorkouts(from start: Date, to end: Date) async -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate]
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    print("HealthKit exercise backfill query error: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            store.execute(query)
        }
    }

    private func matchesExercise(_ workout: HKWorkout, entry: ExerciseEntry) -> Bool {
        let metadata = workout.metadata ?? [:]
        let syncIdentifier = "lunixia-exercise-\(entry.id.uuidString)"
        if let existingSync = metadata[HKMetadataKeySyncIdentifier] as? String,
           existingSync == syncIdentifier {
            return true
        }

        let sameStart = abs(workout.startDate.timeIntervalSince(entry.timestamp)) <= 1.0
        let sameDuration = abs(workout.duration - Double(entry.durationMinutes) * 60) <= 1.0
        guard sameStart && sameDuration else { return false }

        let newName = metadata[exerciseNameMetadataKey] as? String
        let oldName = metadata[HKMetadataKeyWorkoutBrandName] as? String
        let nameMatches = newName == entry.name || oldName == entry.name

        let newReps = metadata[exerciseRepsMetadataKey] as? Int
        let oldReps = metadata["reps"] as? Int
        let repsMatches = newReps == entry.reps || oldReps == entry.reps

        return nameMatches && repsMatches
    }

    // MARK: - Write Water

    func writeWater(oz: Double) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let qty = HKQuantity(unit: .fluidOunceUS(), doubleValue: oz)
        let sample = HKQuantitySample(type: type, quantity: qty, start: Date(), end: Date())
        do {
            try await store.save(sample)
        } catch {
            print("HealthKit water write error: \(error)")
        }
    }
}
