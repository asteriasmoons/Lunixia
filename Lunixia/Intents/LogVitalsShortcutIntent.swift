//
//  LogVitalsShortcutIntent.swift
//  Lunixia
//

import AppIntents
import SwiftData

struct LogVitalsShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Vitals"
    static var description = IntentDescription("Log vitals in Lunixia.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Blood Oxygen (%)")
    var bloodOxygen: Double?

    @Parameter(title: "Systolic")
    var systolic: Int?

    @Parameter(title: "Diastolic")
    var diastolic: Int?

    @Parameter(title: "BPM")
    var bpm: Int?

    @Parameter(title: "Body Temperature (°F)")
    var bodyTemp: Double?

    @Parameter(title: "Weight (lb)")
    var weight: Double?

    @Parameter(
        title: "Date & Time",
        requestValueDialog: IntentDialog("What date and time should these vitals use?")
    )
    var date: Date

    static var parameterSummary: some ParameterSummary {
        Summary("Log vitals") {
            \.$bloodOxygen
            \.$systolic
            \.$diastolic
            \.$bpm
            \.$bodyTemp
            \.$weight
            \.$date
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let finalBloodOxygen = bloodOxygen ?? 0
        let finalSystolic = systolic ?? 0
        let finalDiastolic = diastolic ?? 0
        let finalBpm = bpm ?? 0
        let finalBodyTemp = bodyTemp ?? 0
        let finalWeight = weight ?? 0
        let finalDate = date

        let hasAtLeastOneMetric =
            finalBloodOxygen > 0 ||
            finalSystolic > 0 ||
            finalDiastolic > 0 ||
            finalBpm > 0 ||
            finalBodyTemp > 0 ||
            finalWeight > 0

        guard hasAtLeastOneMetric else {
            return .result(dialog: IntentDialog("Enter at least one vital."))
        }

        try await MainActor.run {
            let context = ModelContext(LunixiaApp.sharedModelContainer)

            let entry = VitalsEntry(
                bloodOxygen: finalBloodOxygen,
                bpm: Double(finalBpm),
                systolic: Double(finalSystolic),
                diastolic: Double(finalDiastolic),
                bodyTemp: finalBodyTemp,
                weight: finalWeight,
                timestamp: finalDate
            )

            context.insert(entry)

            _ = try? LunixiaPointsManager.awardVitalsLog(
                in: context,
                id: entry.id.uuidString,
                at: entry.timestamp
            )

            try context.save()
        }

        // Write these vitals into the Health app using the exact same method the
        // in-app logger uses (HealthKitWriteManager.writeVitals, which requests
        // write authorization internally). VitalsEntry is a SwiftData @Model and
        // therefore non-Sendable, so it can't be returned out of the MainActor
        // block above; writeVitals reads only the scalar fields and timestamp, so
        // a value carrying the same inputs produces identical HealthKit samples.
        let healthKitEntry = VitalsEntry(
            bloodOxygen: finalBloodOxygen,
            bpm: Double(finalBpm),
            systolic: Double(finalSystolic),
            diastolic: Double(finalDiastolic),
            bodyTemp: finalBodyTemp,
            weight: finalWeight,
            timestamp: finalDate
        )
        await HealthKitWriteManager.shared.writeVitals(entry: healthKitEntry)

        // Update the vitals widget snapshot, matching the in-app logger exactly.
        HealthKitManager.shared.saveVitalsWidgetSnapshot(from: healthKitEntry)

        return .result(dialog: IntentDialog("Vitals logged."))
    }
}
