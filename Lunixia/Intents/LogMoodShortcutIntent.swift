//
//  LogMoodShortcutIntent.swift
//  Lunixia
//

import AppIntents
import Foundation
import SwiftData

// MARK: - Options Providers (tappable pick lists in Shortcuts)

struct MoodEmotionOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        MoodEmotion.all.map(\.name)
    }
}

struct MoodActivityOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        MoodActivity.all.map(\.name)
    }
}

// MARK: - Log Mood Intent

struct LogMoodShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mood"
    static var description = IntentDescription("Log a mood entry in Lunixia with emotions, activities, a note, and a date.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Moods",
        optionsProvider: MoodEmotionOptionsProvider()
    )
    var emotions: [String]

    @Parameter(
        title: "Activities",
        optionsProvider: MoodActivityOptionsProvider()
    )
    var activities: [String]?

    @Parameter(
        title: "Note",
        default: "",
        inputOptions: String.IntentInputOptions(
            capitalizationType: .sentences,
            multiline: true,
            autocorrect: true,
            smartQuotes: true,
            smartDashes: true
        )
    )
    var note: String

    @Parameter(title: "Date & Time")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Log mood \(\.$emotions)") {
            \.$activities
            \.$note
            \.$date
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !emotions.isEmpty else {
            return .result(dialog: IntentDialog("Please choose at least one mood."))
        }

        let resolvedEmotions = emotions.compactMap { name in
            MoodEmotion.all.first { $0.name == name }
        }
        let resolvedActivities = (activities ?? []).compactMap { name in
            MoodActivity.all.first { $0.name == name }
        }
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let timestamp = date ?? Date()

        // Populate the same HealthKit snapshot the in-app mood sheet records.
        let hk = HealthKitManager.shared
        await hk.requestAuthorization()
        await hk.fetchAll()
        let sleepHours = hk.sleepHours
        let exerciseMinutes = hk.exerciseMinutes
        let steps = hk.steps
        let meditationMinutes = hk.meditationMinutes
        let waterOz = hk.waterOz

        try await MainActor.run {
            let context = ModelContext(LunixiaApp.sharedModelContainer)

            let entry = MoodEntry(
                emotions: resolvedEmotions,
                activities: resolvedActivities,
                note: cleanedNote,
                timestamp: timestamp
            )

            entry.sleepHours = sleepHours
            entry.exerciseMinutes = exerciseMinutes
            entry.steps = steps
            entry.meditationMinutes = meditationMinutes
            entry.waterOz = waterOz

            context.insert(entry)
            try context.save()

            _ = try? LunixiaPointsManager.awardMoodLog(
                in: context,
                id: entry.id.uuidString,
                at: entry.timestamp
            )

            let allEntries = try context.fetch(FetchDescriptor<MoodEntry>())
            LunixiaMoodWidgetWriter.write(allEntries: allEntries)
        }

        let moodList = resolvedEmotions.map(\.name).joined(separator: ", ")
        return .result(dialog: IntentDialog("Logged your mood: \(moodList)."))
    }
}
