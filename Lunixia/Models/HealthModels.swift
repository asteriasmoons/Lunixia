//
//  HealthModels.swift
//  Lunixia
//

import Foundation
import SwiftData

// MARK: - Vitals Entry

@Model
final class VitalsEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var bloodOxygen: Double = 0.0       // %
    var bpm: Double = 0.0               // beats per minute
    var systolic: Double = 0.0          // mmHg
    var diastolic: Double = 0.0         // mmHg
    var bodyTemp: Double = 0.0          // °F
    var weight: Double = 0.0            // lbs

    init(
        bloodOxygen: Double,
        bpm: Double = 0.0,
        systolic: Double,
        diastolic: Double,
        bodyTemp: Double,
        weight: Double,
        timestamp: Date = .now
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.bloodOxygen = bloodOxygen
        self.bpm = bpm
        self.systolic = systolic
        self.diastolic = diastolic
        self.bodyTemp = bodyTemp
        self.weight = weight
    }
}

// MARK: - Exercise Entry

@Model
final class ExerciseEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var name: String = ""
    var durationMinutes: Int = 0
    var reps: Int = 0

    init(name: String, durationMinutes: Int, reps: Int, timestamp: Date = .now) {
        self.id = UUID()
        self.timestamp = timestamp
        self.name = name
        self.durationMinutes = durationMinutes
        self.reps = reps
    }
}

// MARK: - Water Log Entry

@Model
final class WaterEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var oz: Double = 0.0

    init(oz: Double, timestamp: Date = .now) {
        self.id = UUID()
        self.timestamp = timestamp
        self.oz = oz
    }
}

// MARK: - Health Metric History

@Model
final class HealthMetricHistoryEntry {
    var id: UUID = UUID()
    var metricRaw: String = "water"
    var eventRaw: String = "logged"
    var dayKey: String = ""
    var eventKey: String = ""
    var timestamp: Date = Date.now
    var amount: Double = 0
    var previousValue: Double = 0
    var currentValue: Double = 0
    var goalValue: Double = 0
    var details: String = ""

    enum Metric: String, Codable {
        case water
        case steps
    }

    enum EventType: String, Codable {
        case logged
        case cleared
        case sample
        case snapshot
        case completed
    }

    var metric: Metric {
        get { Metric(rawValue: metricRaw) ?? .water }
        set { metricRaw = newValue.rawValue }
    }

    var event: EventType {
        get { EventType(rawValue: eventRaw) ?? .logged }
        set { eventRaw = newValue.rawValue }
    }

    init(
        metric: Metric,
        event: EventType,
        dayKey: String,
        eventKey: String,
        timestamp: Date = .now,
        amount: Double = 0,
        previousValue: Double = 0,
        currentValue: Double = 0,
        goalValue: Double = 0,
        details: String = ""
    ) {
        self.id = UUID()
        self.metricRaw = metric.rawValue
        self.eventRaw = event.rawValue
        self.dayKey = dayKey
        self.eventKey = eventKey
        self.timestamp = timestamp
        self.amount = amount
        self.previousValue = previousValue
        self.currentValue = currentValue
        self.goalValue = goalValue
        self.details = details
    }
}

// MARK: - Health Goals

@Model
final class HealthGoals {
    var id: UUID = UUID()
    var dailyWaterOz: Double = 64.0
    var dailySteps: Int = 10000
    var sleepGoalHours: Double = 8.0

    init(
        dailyWaterOz: Double = 64.0,
        dailySteps: Int = 10000,
        sleepGoalHours: Double = 8.0
    ) {
        self.id = UUID()
        self.dailyWaterOz = dailyWaterOz
        self.dailySteps = dailySteps
        self.sleepGoalHours = sleepGoalHours
    }
}
