//
//  LogExerciseShortcutIntent.swift
//  Lunixia

import AppIntents
import SwiftData

struct LogExerciseShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Exercise"
    static var description = IntentDescription("Log an exercise entry in Lunixia.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Exercise Name",
        requestValueDialog: IntentDialog("What exercise did you do?")
    )
    var name: String

    @Parameter(
        title: "Duration (minutes)",
        requestValueDialog: IntentDialog("How many minutes did you exercise?")
    )
    var durationMinutes: Int

    @Parameter(
        title: "Reps",
        requestValueDialog: IntentDialog("How many reps? Enter 0 to skip.")
    )
    var reps: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$name) for \(\.$durationMinutes) min") {
            \.$reps
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            return .result(dialog: IntentDialog("Please enter an exercise name."))
        }

        guard durationMinutes > 0 else {
            return .result(dialog: IntentDialog("Please enter a duration greater than 0."))
        }

        try await saveAndSyncExercise(
            name: trimmedName,
            durationMinutes: durationMinutes,
            reps: reps ?? 0
        )

        return .result(dialog: IntentDialog("Logged \(trimmedName) for \(durationMinutes) min."))
    }

    // Saves the entry and mirrors the in-app handleExerciseSave HealthKit behavior:
    // syncExerciseDayToHealthKit -> HealthKitWriteManager.syncExerciseDay for all of
    // that day's entries. Runs on the main actor so the real, id-bearing entries
    // (syncExerciseDay keys HealthKit workouts by entry.id) never cross an actor
    // boundary. (The in-app path's flash() is view-only UI and doesn't apply here.)
    @MainActor
    private func saveAndSyncExercise(
        name: String,
        durationMinutes: Int,
        reps: Int
    ) async throws {
        let context = ModelContext(LunixiaApp.sharedModelContainer)

        let entry = ExerciseEntry(
            name: name,
            durationMinutes: durationMinutes,
            reps: reps
        )

        context.insert(entry)

        _ = try? LunixiaPointsManager.awardExerciseLog(
            in: context,
            id: entry.id.uuidString,
            at: entry.timestamp
        )

        try context.save()

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: entry.timestamp)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let sameDayEntries = try context.fetch(
            FetchDescriptor<ExerciseEntry>(
                predicate: #Predicate { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
            )
        )

        _ = await HealthKitWriteManager.shared.syncExerciseDay(entries: sameDayEntries)
    }
}
