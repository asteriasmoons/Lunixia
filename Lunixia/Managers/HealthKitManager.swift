//
//  HealthKitManager.swift
//  Lunixia
//

import Foundation
import HealthKit
import SwiftData
import WidgetKit

struct LunixiaHealthWidgetSnapshot: Codable {
    var steps: Int
    var stepGoal: Int
    var waterOz: Double
    var waterGoalOz: Double
    var hrvSDNN: Double
    var lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case steps
        case stepGoal
        case waterOz
        case waterGoalOz
        case hrvSDNN
        case lastUpdated
    }

    init(
        steps: Int,
        stepGoal: Int,
        waterOz: Double,
        waterGoalOz: Double,
        hrvSDNN: Double = 0,
        lastUpdated: Date
    ) {
        self.steps = steps
        self.stepGoal = stepGoal
        self.waterOz = waterOz
        self.waterGoalOz = waterGoalOz
        self.hrvSDNN = hrvSDNN
        self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        steps = try container.decode(Int.self, forKey: .steps)
        stepGoal = try container.decode(Int.self, forKey: .stepGoal)
        waterOz = try container.decode(Double.self, forKey: .waterOz)
        waterGoalOz = try container.decode(Double.self, forKey: .waterGoalOz)
        hrvSDNN = try container.decodeIfPresent(Double.self, forKey: .hrvSDNN) ?? 0
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }
}

// Mirrors LunixiaVitalsWidgetSnapshot in LunixiaHealthWidget.swift (widget target).
// Identical Codable layout — both sides encode/decode the same App Group UserDefaults key.
struct LunixiaVitalsWidgetSnapshot: Codable {
    var bloodOxygen: Double
    var bpm: Double
    var systolic: Double
    var diastolic: Double
    var bodyTemp: Double
    var weight: Double
    var lastUpdated: Date
}

struct HealthKitStepSample: Identifiable, Sendable {
    let id: String
    let startDate: Date
    let endDate: Date
    let steps: Int
}

@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let widgetDefaults = UserDefaults(suiteName: "group.com.asteriasmoons.Lunixia")
    private let healthWidgetSnapshotKey = "lunixiaHealthWidgetSnapshot"
    private var stepObserverQuery: HKObserverQuery?

    var isAuthorized = false
    private(set) var hasFetchedToday = false

    var sleepHours: Double = 0
    var exerciseMinutes: Int = 0
    var steps: Int = 0
    var meditationMinutes: Int = 0
    var cycleNote: String = ""
    var waterOz: Double = 0
    var caffeineMg: Double = 0
    var bpm: Double = 0
    var hrvSDNN: Double = 0

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let shareTypes: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]

        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
            HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCaffeine)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        ]

        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
        } catch {
            print("HealthKit auth error: \(error)")
            isAuthorized = false
        }
    }

    @MainActor
    func requestAuthorizationIfNeeded(settings: UserSettings) async {
        guard !settings.didRequestHealthKitAuthorization else { return }
        
        await requestAuthorization()
        settings.didRequestHealthKitAuthorization = true
        settings.updatedAt = Date()
    }

    // MARK: - Fetch All

    func fetchAll() async {
        if !isAuthorized {
            await requestAuthorization()
        }

        let todayStart = Calendar.current.startOfDay(for: Date())
        let now = Date()
        let todayPredicate = HKQuery.predicateForSamples(withStart: todayStart, end: now)

        async let s  = fetchSleep(todayStart: todayStart, now: now)
        async let e  = fetchExercise(predicate: todayPredicate)
        async let st = fetchSteps(predicate: todayPredicate)
        async let m  = fetchMeditation(predicate: todayPredicate)
        async let c  = fetchCycle(predicate: todayPredicate)
        async let w  = fetchWater(predicate: todayPredicate)
        async let ca = fetchCaffeine(predicate: todayPredicate)
        async let hr = fetchHeartRate(predicate: todayPredicate)
        async let hrv = fetchHRV(predicate: todayPredicate)

        let (sleep, exercise, stepsVal, meditation, cycle, water, caffeine, heartRate, hrvValue) =
            await (s, e, st, m, c, w, ca, hr, hrv)

        await MainActor.run {
            self.sleepHours        = sleep
            self.exerciseMinutes   = exercise
            self.steps             = stepsVal
            self.meditationMinutes = meditation
            self.cycleNote         = cycle
            self.waterOz           = water
            self.caffeineMg        = caffeine
            self.bpm               = heartRate
            self.hrvSDNN           = hrvValue
            self.hasFetchedToday   = true
        }

        saveHealthWidgetSnapshot(
            steps: stepsVal,
            stepGoal: nil,
            waterOz: water,
            waterGoalOz: nil,
            hrvSDNN: hrvValue
        )
    }

    // MARK: - Write Mindful Minutes

    func addMindfulMinutesForJournalEntry(minutes: Int = 1, at date: Date = Date()) async {
        print("[HealthKit] addMindfulMinutes start minutes=\(minutes)")
        guard HKHealthStore.isHealthDataAvailable() else { print("[HealthKit] HealthData not available"); return }
        guard minutes > 0 else { return }
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        if !isAuthorized {
            print("[HealthKit] not authorized, requesting")
            await requestAuthorization()
        }

        let endDate = date
        let startDate = Calendar.current.date(byAdding: .minute, value: -minutes, to: endDate) ?? endDate.addingTimeInterval(Double(-minutes * 60))

        let sample = HKCategorySample(
            type: type,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate
        )

        do {
            print("[HealthKit] saving mindful sample")
            try await store.save(sample)
            print("[HealthKit] mindful sample saved")
            await MainActor.run {
                self.hasFetchedToday = false
            }
        } catch {
            print("[HealthKit] mindful journal save error: \(error)")
        }
        print("[HealthKit] addMindfulMinutes done")
    }

    // MARK: - Sleep
    // Previous noon → current noon to capture a full night within "today"

    private func fetchSleep(todayStart: Date, now: Date) async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let calendar = Calendar.current
        let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let yesterdayNoon = calendar.date(byAdding: .day, value: -1, to: todayNoon) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: yesterdayNoon, end: now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0); return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let total = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: total / 3600)
            }
            store.execute(query)
        }
    }

    // MARK: - Exercise

    private func fetchExercise(predicate: NSPredicate) async -> Int {
        var exerciseRingMinutes = 0

        if let type = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            exerciseRingMinutes = Int(await fetchSum(type: type, unit: .minute(), predicate: predicate))
        }

        let workoutMinutes = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    print("HealthKit workout fetch error: \(error)")
                    continuation.resume(returning: 0)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: 0)
                    return
                }

                let total = workouts.reduce(0.0) { $0 + $1.duration }
                continuation.resume(returning: Int(total / 60))
            }
            store.execute(query)
        }

        return max(exerciseRingMinutes, workoutMinutes)
    }

    // MARK: - Steps

    private func fetchSteps(predicate: NSPredicate) async -> Int {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return Int(await fetchSum(type: type, unit: .count(), predicate: predicate))
    }

    // MARK: - Meditation

    private func fetchMeditation(predicate: NSPredicate) async -> Int {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return 0 }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0); return
                }
                let total = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: Int(total / 60))
            }
            store.execute(query)
        }
    }

    // MARK: - Cycle

    private func fetchCycle(predicate: NSPredicate) async -> String {
        guard let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return "" }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKCategorySample else {
                    continuation.resume(returning: ""); return
                }
                let flow: String
                switch HKCategoryValueMenstrualFlow(rawValue: sample.value) {
                case .none:        flow = "no flow"
                case .unspecified: flow = "spotting"
                case .light:       flow = "light"
                case .medium:      flow = "medium"
                case .heavy:       flow = "heavy"
                @unknown default:  flow = "logged"
                }
                continuation.resume(returning: flow)
            }
            store.execute(query)
        }
    }

    // MARK: - Water

    private func fetchWater(predicate: NSPredicate) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return 0 }
        return await fetchSum(type: type, unit: .fluidOunceUS(), predicate: predicate)
    }

    // MARK: - Caffeine

    private func fetchCaffeine(predicate: NSPredicate) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .dietaryCaffeine) else { return 0 }
        return await fetchSum(type: type, unit: .gramUnit(with: .milli), predicate: predicate)
    }

    // MARK: - Heart Rate

    private func fetchHeartRate(predicate: NSPredicate) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return 0 }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    print("HealthKit heart rate error: \(error)")
                    continuation.resume(returning: 0)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }

            store.execute(query)
        }
    }

    // MARK: - Heart Rate Variability

    private func fetchHRV(predicate: NSPredicate) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return 0 }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    print("HealthKit HRV error: \(error)")
                    continuation.resume(returning: 0)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }

                continuation.resume(returning: sample.quantity.doubleValue(for: .secondUnit(with: .milli)))
            }

            store.execute(query)
        }
    }

    // MARK: - Helper

    private func fetchSum(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func fetchSampleSum(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    print("HealthKit sample sum error for \(type.identifier): \(error)")
                    continuation.resume(returning: 0)
                    return
                }

                let quantitySamples = samples as? [HKQuantitySample] ?? []
                let total = quantitySamples.reduce(0.0) { partialResult, sample in
                    partialResult + sample.quantity.doubleValue(for: unit)
                }

                continuation.resume(returning: total)
            }

            store.execute(query)
        }
    }

    // MARK: - Public standalone sleep fetch for Health tab

    func fetchSleepLastNight() async -> Double {
        if !isAuthorized {
            await requestAuthorization()
        }

        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        let sleep = await fetchSleep(todayStart: todayStart, now: now)

        await MainActor.run {
            self.sleepHours = sleep
        }

        return sleep
    }

    // MARK: - Public standalone steps fetch for Health tab

    func startStepUpdates(onUpdate: @escaping () -> Void) async {
        if !isAuthorized {
            await requestAuthorization()
        }

        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        if let stepObserverQuery {
            store.stop(stepObserverQuery)
        }

        let query = HKObserverQuery(
            sampleType: type,
            predicate: nil
        ) { _, completionHandler, error in
            if let error {
                print("HealthKit step observer error: \(error)")
                completionHandler()
                return
            }

            onUpdate()
            completionHandler()
        }

        stepObserverQuery = query
        store.execute(query)
        try? await store.enableBackgroundDelivery(for: type, frequency: .immediate)
    }

    func fetchStepsToday() async -> Int {
        if !isAuthorized {
            await requestAuthorization()
        }

        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let total = Int(await fetchSum(type: type, unit: .count(), predicate: predicate))

        await MainActor.run {
            self.steps = total
        }

        saveHealthWidgetSnapshot(
            steps: total,
            stepGoal: nil,
            waterOz: self.waterOz,
            waterGoalOz: nil,
            hrvSDNN: self.hrvSDNN
        )

        return total
    }

    func fetchStepSamplesToday() async -> [HealthKitStepSample] {
        if !isAuthorized {
            await requestAuthorization()
        }

        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return []
        }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: Date(),
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: DateComponents(minute: 1)
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    print("HealthKit step sample fetch error: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                let unit = HKUnit.count()
                var stepSamples: [HealthKitStepSample] = []

                collection?.enumerateStatistics(from: start, to: Date()) { statistics, _ in
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: unit) ?? 0)
                    guard steps > 0 else { return }

                    let startMilliseconds = Int(statistics.startDate.timeIntervalSince1970 * 1000)
                    let endMilliseconds = Int(statistics.endDate.timeIntervalSince1970 * 1000)
                    stepSamples.append(
                        HealthKitStepSample(
                            id: "\(startMilliseconds)-\(endMilliseconds)-\(steps)",
                            startDate: statistics.startDate,
                            endDate: statistics.endDate,
                            steps: steps
                        )
                    )
                }

                continuation.resume(returning: stepSamples)
            }

            store.execute(query)
        }
    }

    func fetchWaterToday() async -> Double {
        if !isAuthorized {
            await requestAuthorization()
        }

        guard let type = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let total = await fetchSum(type: type, unit: .fluidOunceUS(), predicate: predicate)

        await MainActor.run {
            self.waterOz = total
        }

        saveHealthWidgetSnapshot(
            steps: self.steps,
            stepGoal: nil,
            waterOz: total,
            waterGoalOz: nil,
            hrvSDNN: self.hrvSDNN
        )

        return total
    }

    func fetchHeartRateToday() async -> Double {

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let heartRate = await fetchHeartRate(predicate: predicate)

        await MainActor.run {
            self.bpm = heartRate
        }

        return heartRate
    }

    func fetchHRVToday() async -> Double {
        if !isAuthorized {
            await requestAuthorization()
        }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let hrv = await fetchHRV(predicate: predicate)

        await MainActor.run {
            self.hrvSDNN = hrv
        }

        saveHealthWidgetSnapshot(
            steps: self.steps,
            stepGoal: nil,
            waterOz: self.waterOz,
            waterGoalOz: nil,
            hrvSDNN: hrv
        )

        return hrv
    }

    // MARK: - Widget Snapshot

    func saveHealthWidgetSnapshot(
        steps: Int? = nil,
        stepGoal: Int? = nil,
        waterOz: Double? = nil,
        waterGoalOz: Double? = nil,
        hrvSDNN: Double? = nil
    ) {
        let existingSnapshot = loadHealthWidgetSnapshot()

        let snapshot = LunixiaHealthWidgetSnapshot(
            steps: steps ?? existingSnapshot?.steps ?? self.steps,
            stepGoal: stepGoal ?? existingSnapshot?.stepGoal ?? 10_000,
            waterOz: waterOz ?? existingSnapshot?.waterOz ?? self.waterOz,
            waterGoalOz: waterGoalOz ?? existingSnapshot?.waterGoalOz ?? 64,
            hrvSDNN: hrvSDNN ?? existingSnapshot?.hrvSDNN ?? self.hrvSDNN,
            lastUpdated: Date()
        )

        do {
            let data = try JSONEncoder().encode(snapshot)
            widgetDefaults?.set(data, forKey: healthWidgetSnapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Health widget snapshot save error: \(error)")
        }
    }

    func saveHealthWidgetGoals(stepGoal: Int, waterGoalOz: Double) {
        saveHealthWidgetSnapshot(
            steps: self.steps,
            stepGoal: stepGoal,
            waterOz: self.waterOz,
            waterGoalOz: waterGoalOz,
            hrvSDNN: self.hrvSDNN
        )
    }

    func loadHealthWidgetSnapshot() -> LunixiaHealthWidgetSnapshot? {
        guard let data = widgetDefaults?.data(forKey: healthWidgetSnapshotKey) else { return nil }

        do {
            return try JSONDecoder().decode(LunixiaHealthWidgetSnapshot.self, from: data)
        } catch {
            print("Health widget snapshot load error: \(error)")
            return nil
        }
    }

    // MARK: - Vitals Widget Snapshot

    private let vitalsWidgetSnapshotKey = "lunixiaVitalsWidgetSnapshot"

    func saveVitalsWidgetSnapshot(from entry: VitalsEntry) {
        let snapshot = LunixiaVitalsWidgetSnapshot(
            bloodOxygen: entry.bloodOxygen,
            bpm:         entry.bpm,
            systolic:    entry.systolic,
            diastolic:   entry.diastolic,
            bodyTemp:    entry.bodyTemp,
            weight:      entry.weight,
            lastUpdated: Date()
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            widgetDefaults?.set(data, forKey: vitalsWidgetSnapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Vitals widget snapshot save error: \(error)")
        }
    }
}
