//
//  LunixiaShortcutsProvider.swift
//  Lunixia
//

import AppIntents

struct LunixiaShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMoodShortcutIntent(),
            phrases: [
                "Log my mood in \(.applicationName)",
                "Add a mood to \(.applicationName)",
                "Log how I'm feeling in \(.applicationName)"
            ],
            shortTitle: "Log Mood",
            systemImageName: "face.smiling"
        )
        AppShortcut(
            intent: LogVitalsShortcutIntent(),
            phrases: [
                "Log my vitals in \(.applicationName)",
                "Add vitals to \(.applicationName)"
            ],
            shortTitle: "Log Vitals",
            systemImageName: "heart.text.square"
        )
        AppShortcut(
            intent: LogWaterShortcutIntent(),
            phrases: [
                "Log my water in \(.applicationName)",
                "Add water to \(.applicationName)",
                "Log water intake in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: LogExerciseShortcutIntent(),
            phrases: [
                "Log my exercise in \(.applicationName)",
                "Add a workout to \(.applicationName)",
                "Log a workout in \(.applicationName)"
            ],
            shortTitle: "Log Exercise",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: LogDailyIntentionShortcutIntent(),
            phrases: [
                "Set my daily intention in \(.applicationName)",
                "Set today's intention in \(.applicationName)",
                "Log my intention in \(.applicationName)"
            ],
            shortTitle: "Set Daily Intention",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: AddJournalEntryShortcutIntent(),
            phrases: [
                "Add a journal entry in \(.applicationName)",
                "Write in my journal in \(.applicationName)",
                "Create a journal entry in \(.applicationName)"
            ],
            shortTitle: "Add Journal Entry",
            systemImageName: "book.closed.fill"
        )
    }
}
