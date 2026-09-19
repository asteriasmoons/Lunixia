//
//  LogDailyIntentionShortcutIntent.swift
//  Lunixia
//

import AppIntents
import Foundation
import SwiftData

struct LogDailyIntentionShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Daily Intention"
    static var description = IntentDescription("Set today's daily intention in Lunixia.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Intention",
        inputOptions: String.IntentInputOptions(
            capitalizationType: .sentences,
            multiline: true,
            autocorrect: true,
            smartQuotes: true,
            smartDashes: true
        ),
        requestValueDialog: IntentDialog("What's your intention for today?")
    )
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Set today's intention to \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .result(dialog: IntentDialog("Please enter an intention."))
        }

        // Uses the exact same writer the in-app editor uses
        // (DailyIntentionWriter.setTodayIntention), which fetch-or-creates today's
        // record, saves the text, and awards the daily-intention points.
        try await MainActor.run {
            let context = ModelContext(LunixiaApp.sharedModelContainer)
            try DailyIntentionWriter.setTodayIntention(trimmed, modelContext: context)
        }

        return .result(dialog: IntentDialog("Today's intention is set."))
    }
}
