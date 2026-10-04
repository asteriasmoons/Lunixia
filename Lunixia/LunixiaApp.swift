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
    @UIApplicationDelegateAdaptor(LunixiaNotificationDelegate.self) private var notificationDelegate

    @StateObject private var appState = AppState()
    @StateObject private var storeManager = LunixiaStoreManager()
    @StateObject private var syncIntegrityManager = LunixiaSyncIntegrityManager.shared

    static var sharedModelContainer: ModelContainer = {
        LunixiaSyncIntegrityManager.shared.beginObservingCloudKitEvents()

        let allModels: [any PersistentModel.Type] = [
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
            SubmittedReport.self,
            SubmittedReportAttachment.self,
            StreakConfiguration.self,
        ]

        let schema = Schema(allModels)

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.im.lystaria.Lurelia")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private var rootContent: AnyView {
        if syncIntegrityManager.isReadyForContent {
            return AnyView(ContentView())
        }
        return AnyView(LunixiaSyncWaitingView())
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environmentObject(appState)
                .environmentObject(storeManager)
                .task {
                    await MainActor.run {
                        LunixiaSyncIntegrityManager.shared.start(
                            container: LunixiaApp.sharedModelContainer
                        )
                    }

                    LunixiaMoonPhaseWidgetWriter.write()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else {
                        return
                    }

                    Task { @MainActor in
                        LunixiaSyncIntegrityManager.shared.applicationBecameActive(
                            container: LunixiaApp.sharedModelContainer
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

                    LunixiaSyncIntegrityManager.shared.runPeriodicAutomationsIfSafe(
                        container: LunixiaApp.sharedModelContainer
                    )
                }
        }
        .modelContainer(LunixiaApp.sharedModelContainer)
    }
}
