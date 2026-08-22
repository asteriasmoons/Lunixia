//
//  MedicationModels.swift
//  Lunixia
//

import Foundation
import SwiftData

// MARK: - Dose Notify Time

struct DoseNotifyTime: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var hour: Int   // 0–23
    var minute: Int // 0–59

    var displayString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let m = String(format: "%02d", minute)
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(ampm)"
    }
}

// MARK: - Medication

@Model
final class LunixiaMedication {

    // MARK: Core
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""

    // MARK: Supply
    var currentAmount: Int = 0
    var supplyAmount: Int = 0
    var daysSupply: Int = 0

    // MARK: Refill
    var refillDate: Date? = nil
    var lastAutoRefillDayKey: String = ""

    // MARK: Dose Schedule
    /// daily or weekly — stored as String for SwiftData/CloudKit safety.
    var scheduleFrequencyRaw: String = LunixiaMedicationScheduleFrequency.daily.rawValue
    /// Calendar weekday value, where Sunday = 1 and Saturday = 7. Used for weekly medications.
    var weeklyWeekday: Int = 1
    var timesPerDay: Int = 1
    var doseScheduleJSON: String = ""
    var lastTakenAt: Date? = nil

    // MARK: Auto Decrease
    var autoDecreaseEnabled: Bool = false
    var autoDecreaseHour: Int = 9
    var autoDecreaseMinute: Int = 0
    var lastAutoDecreaseDayKey: String = ""

    // MARK: Dose Notifications
    var notifyDose: Bool = false
    /// Legacy single-time fields — retained for CloudKit compatibility, not used in UI.
    var doseNotifyHour: Int = 9
    var doseNotifyMinute: Int = 0
    /// JSON-encoded [DoseNotifyTime] — the authoritative list of reminder times.
    var doseNotifyTimesJSON: String = ""

    // MARK: Refill Notifications
    var notifyRefill: Bool = false
    var daysBeforeRefillNotify: Int = 3

    // MARK: State
    var isActive: Bool = true

    // MARK: Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \LunixiaMedHistoryEntry.medication)
    var historyEntries: [LunixiaMedHistoryEntry]? = []

    // MARK: - Computed: schedule frequency

    enum LunixiaMedicationScheduleFrequency: String, Codable, CaseIterable {
        case daily
        case weekly
    }

    var scheduleFrequency: LunixiaMedicationScheduleFrequency {
        get { LunixiaMedicationScheduleFrequency(rawValue: scheduleFrequencyRaw) ?? .daily }
        set { scheduleFrequencyRaw = newValue.rawValue }
    }

    var isWeekly: Bool {
        scheduleFrequency == .weekly
    }

    // MARK: - Computed: dose schedule overrides

    var doseScheduleOverrides: [Int: Int] {
        get {
            guard !doseScheduleJSON.isEmpty,
                  let data = doseScheduleJSON.data(using: .utf8),
                  let raw = try? JSONDecoder().decode([String: Int].self, from: data)
            else { return [:] }
            return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in
                guard let intKey = Int(k) else { return nil }
                return (intKey, v)
            })
        }
        set {
            let stringKeyed = Dictionary(uniqueKeysWithValues: newValue.map { ("\($0.key)", $0.value) })
            if let data = try? JSONEncoder().encode(stringKeyed),
               let str = String(data: data, encoding: .utf8) {
                doseScheduleJSON = str
            } else {
                doseScheduleJSON = ""
            }
        }
    }

    func doses(forWeekday weekday: Int) -> Int {
        let cleanWeekday = min(max(weekday, 1), 7)
        let overrides = doseScheduleOverrides

        switch scheduleFrequency {
        case .daily:
            return max(0, overrides[cleanWeekday] ?? timesPerDay)
        case .weekly:
            guard cleanWeekday == weeklyWeekday else { return 0 }
            return max(0, overrides[cleanWeekday] ?? timesPerDay)
        }
    }

    var dosesToday: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return doses(forWeekday: weekday)
    }
    
    // MARK: - Computed: auto decrease time

    var autoDecreaseTimeDisplayString: String {
        let cleanHour = min(max(autoDecreaseHour, 0), 23)
        let cleanMinute = min(max(autoDecreaseMinute, 0), 59)

        let hour = cleanHour % 12 == 0 ? 12 : cleanHour % 12
        let minute = String(format: "%02d", cleanMinute)
        let period = cleanHour < 12 ? "AM" : "PM"

        return "\(hour):\(minute) \(period)"
    }

    // MARK: - Computed: dose notify times

    var doseNotifyTimes: [DoseNotifyTime] {
        get {
            guard !doseNotifyTimesJSON.isEmpty,
                  let data = doseNotifyTimesJSON.data(using: .utf8),
                  let times = try? JSONDecoder().decode([DoseNotifyTime].self, from: data)
            else {
                // Fall back to legacy single time if JSON is empty
                return [DoseNotifyTime(hour: doseNotifyHour, minute: doseNotifyMinute)]
            }
            return times.isEmpty ? [DoseNotifyTime(hour: doseNotifyHour, minute: doseNotifyMinute)] : times
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                doseNotifyTimesJSON = str
            } else {
                doseNotifyTimesJSON = ""
            }
        }
    }

    // MARK: - Init

    init(
        name: String,
        notes: String = "",
        currentAmount: Int,
        supplyAmount: Int,
        daysSupply: Int = 0,
        refillDate: Date? = nil,
        scheduleFrequency: LunixiaMedicationScheduleFrequency = .daily,
        weeklyWeekday: Int = 1,
        timesPerDay: Int = 1,
        doseScheduleOverrides: [Int: Int] = [:],
        autoDecreaseEnabled: Bool = false,
        autoDecreaseHour: Int = 9,
        autoDecreaseMinute: Int = 0,
        notifyDose: Bool = false,
        doseNotifyTimes: [DoseNotifyTime] = [DoseNotifyTime(hour: 9, minute: 0)],
        notifyRefill: Bool = false,
        daysBeforeRefillNotify: Int = 3
    ) {
        self.id = UUID()
        self.name = name
        self.notes = notes
        self.currentAmount = currentAmount
        self.supplyAmount = supplyAmount
        self.daysSupply = daysSupply
        self.refillDate = refillDate
        self.lastAutoRefillDayKey = ""
        self.scheduleFrequencyRaw = scheduleFrequency.rawValue
        self.weeklyWeekday = min(max(weeklyWeekday, 1), 7)
        self.timesPerDay = timesPerDay
        self.lastTakenAt = nil
        self.autoDecreaseEnabled = autoDecreaseEnabled
        self.autoDecreaseHour = min(max(autoDecreaseHour, 0), 23)
        self.autoDecreaseMinute = min(max(autoDecreaseMinute, 0), 59)
        self.lastAutoDecreaseDayKey = ""
        self.notifyDose = notifyDose
        self.doseNotifyHour = doseNotifyTimes.first?.hour ?? 9
        self.doseNotifyMinute = doseNotifyTimes.first?.minute ?? 0
        self.notifyRefill = notifyRefill
        self.daysBeforeRefillNotify = daysBeforeRefillNotify
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
        let stringKeyed = Dictionary(uniqueKeysWithValues: doseScheduleOverrides.map { ("\($0.key)", $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed),
           let str = String(data: data, encoding: .utf8) {
            self.doseScheduleJSON = str
        } else {
            self.doseScheduleJSON = ""
        }
        if let data = try? JSONEncoder().encode(doseNotifyTimes),
           let str = String(data: data, encoding: .utf8) {
            self.doseNotifyTimesJSON = str
        } else {
            self.doseNotifyTimesJSON = ""
        }
    }
}

// MARK: - History Entry

@Model
final class LunixiaMedHistoryEntry {
    var id: UUID = UUID()
    var typeRaw: String = "taken"
    var amountText: String = ""
    var details: String = ""
    var effectiveDayKey: String = ""
    var automationKey: String = ""
    var createdAt: Date = Date()
    var medication: LunixiaMedication?

    enum EntryType: String, Codable {
        case taken    = "taken"
        case refilled = "refilled"
        case edited   = "edited"
    }

    var type: EntryType {
        get { EntryType(rawValue: typeRaw) ?? .taken }
        set { typeRaw = newValue.rawValue }
    }

    init(
        type: EntryType,
        amountText: String,
        details: String,
        effectiveDayKey: String = "",
        automationKey: String = "",
        createdAt: Date = Date(),
        medication: LunixiaMedication? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.amountText = amountText
        self.details = details
        self.effectiveDayKey = effectiveDayKey
        self.automationKey = automationKey
        self.createdAt = createdAt
        self.medication = medication
    }
}
