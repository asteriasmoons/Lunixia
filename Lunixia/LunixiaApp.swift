//
//  LunixiaApp.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import Combine

@main
struct LunixiaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var appState = AppState()
    @StateObject private var storeManager = LunixiaStoreManager()

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            NapEntry.self,
            MoodEntry.self,
            VitalsEntry.self,
            ExerciseEntry.self,
            WaterEntry.self,
            HealthMetricHistoryEntry.self,
            HealthGoals.self,
            DailyHoroscopeRecord.self,
            DailyTarotRecord.self,
            DailyLenormandRecord.self,
            TarotPullRecord.self,
            LenormandPullRecord.self,
            AuthUser.self,
            Note.self,
            NotesTab.self,
            DailyIntention.self,
            JournalBlock.self,
            JournalBook.self,
            JournalEntry.self,
            JournalPrompt.self,
            JournalPromptUsage.self,
            JournalStats.self,
            JournalInlineStyle.self,
            UserSettings.self,
            LunixiaMedication.self,
            LunixiaMedHistoryEntry.self,
            LunixiaSymptomLog.self,
            LunixiaPointEntry.self,
            LunixiaPointsProfile.self,
            LunixiaPointsResetLog.self,
            MoodChatSession.self,
            MoodPhoneStatsSnapshot.self,
            MindfulSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(storeManager)
                .task {
                    await MainActor.run {
                        LunixiaPointsManager.scheduleWeeklyReset(
                            modelContainer: LunixiaApp.sharedModelContainer
                        )

                        LunixiaPointsManager.patchFaultyMidWeekReset(
                            modelContainer: LunixiaApp.sharedModelContainer
                        )

                        MedicationAutomationManager.run(
                            in: LunixiaApp.sharedModelContainer.mainContext
                        )
                    }

                    LunixiaMoonPhaseWidgetWriter.write()
                    await MainActor.run {
                        LunixiaStickyNoteWidgetWriter.write(
                            in: LunixiaApp.sharedModelContainer.mainContext
                        )
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else {
                        return
                    }

                    Task { @MainActor in
                        MedicationAutomationManager.run(
                            in: LunixiaApp.sharedModelContainer.mainContext
                        )
                        LunixiaStickyNoteWidgetWriter.write(
                            in: LunixiaApp.sharedModelContainer.mainContext
                        )
                    }
                }
                .onReceive(
                    Timer.publish(
                        every: 300,
                        on: .main,
                        in: .common
                    )
                    .autoconnect()
                ) { _ in
                    guard scenePhase == .active else {
                        return
                    }

                    MedicationAutomationManager.run(
                        in: LunixiaApp.sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(LunixiaApp.sharedModelContainer)
    }
}
