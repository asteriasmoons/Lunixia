//
//  ContentView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch appState.status {
            case .checking:
                ZStack {
                    LunixiaBackground()
                        .ignoresSafeArea()
                }
                .task {
                    appState.bootstrap(modelContext: modelContext)
                }

            case .signedOut:
                SignInView()

            case .signedIn:
                MainTabView()
            }
        }
        .onOpenURL { url in
            appState.handleReportConversationURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: LunixiaReportConversationNotificationManager.conversationNotificationOpened
        )) { notification in
            guard let reportID = notification.object as? String else { return }
            appState.handleReportConversationID(reportID)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await LunixiaReportConversationNotificationManager.scanForNewMessages() }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
