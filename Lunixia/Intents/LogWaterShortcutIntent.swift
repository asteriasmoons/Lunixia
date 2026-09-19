//
//  LogWaterShortcutIntent.swift
//  Lunixia

import AppIntents
import SwiftData

struct LogWaterShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Log a water entry in Lunixia.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Amount (oz)",
        requestValueDialog: IntentDialog("How many ounces did you drink?")
    )
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) oz of water")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: IntentDialog("Please enter an amount greater than 0."))
        }

        try await MainActor.run {
            let context = ModelContext(LunixiaApp.sharedModelContainer)
            let today = Calendar.current.startOfDay(for: Date())
            let goals = try context.fetch(FetchDescriptor<HealthGoals>())
            let waterGoal = goals.first?.dailyWaterOz ?? 64
            let existingWaterEntries = try context.fetch(
                FetchDescriptor<WaterEntry>(
                    predicate: #Predicate { $0.timestamp >= today }
                )
            )
            let existingWaterOz = existingWaterEntries.reduce(0) { $0 + $1.oz }

            let entry = WaterEntry(oz: amount)

            context.insert(entry)

            HealthHistoryManager.recordWaterCompletionIfNeeded(
                in: context,
                totalOz: existingWaterOz + amount,
                goalOz: waterGoal,
                at: entry.timestamp
            )

            _ = try? LunixiaPointsManager.awardWaterLog(
                in: context,
                entryId: entry.id.uuidString,
                at: entry.timestamp
            )

            try context.save()
        }

        // Write the water into the Health app and refresh the health widget, exactly
        // as the in-app logger does: writeWaterToHealthKit -> HealthKitWriteManager
        // .writeWater, then refreshHealthKitTotalsSoon, whose widget update is
        // fetchAll()'s saveHealthWidgetSnapshot + WidgetCenter reload. (The in-app
        // path's celebration/flash are view-only UI feedback and don't apply here.)
        await HealthKitWriteManager.shared.writeWater(oz: amount)
        await HealthKitManager.shared.fetchAll()

        return .result(dialog: IntentDialog("Logged \(Int(amount)) oz of water."))
    }
}
