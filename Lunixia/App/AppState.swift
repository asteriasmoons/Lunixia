//
//  AppState.swift
//  Lunixia
//

import Foundation
import Combine
import SwiftData

@MainActor
final class AppState: ObservableObject {
    
    enum SessionStatus {
        case checking
        case signedOut
        case signedIn(AuthUser)
    }
    
    @Published private(set) var status: SessionStatus = .checking
    @Published var isPopupPresented: Bool = false
    @Published var pendingReportConversationID: String?
    
    var currentUser: AuthUser? {
        if case .signedIn(let user) = status {
            return user
        }
        return nil
    }

    var currentAppleUserId: String? {
        currentUser?.appleUserId
    }

    // MARK: - Report conversation deep links / notification routing

    func handleReportConversationURL(_ url: URL) {
        guard url.scheme?.lowercased() == "lunixia" else { return }
        let host = url.host?.lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        guard host == "report-conversation" || path == "report-conversation" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let reportID = components?.queryItems?.first(where: { $0.name == "reportID" || $0.name == "reportId" })?.value
        if let reportID, !reportID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handleReportConversationID(reportID)
        }
    }

    func handleReportConversationID(_ reportID: String) {
        let trimmed = reportID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingReportConversationID = trimmed
    }

    func consumePendingReportConversationID() -> String? {
        let value = pendingReportConversationID
        pendingReportConversationID = nil
        return value
    }
    
    private var bootstrapTask: Task<Void, Never>?
    private var hasBootstrapped = false
    
    func bootstrap(modelContext: ModelContext, force: Bool = false) {
        if hasBootstrapped && !force { return }

        bootstrapTask?.cancel()
        status = .checking
        hasBootstrapped = true

        bootstrapTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                try await AuthService.shared.validateStoredAppleSession()
                let user = try await AuthService.shared.fetchMeWithAutoRefresh(modelContext: modelContext)
                guard !Task.isCancelled else { return }
                self.status = .signedIn(user)
            } catch {
                guard !Task.isCancelled else { return }
                print("[AppState] bootstrap failed:", error)
                self.status = .signedOut
            }
        }
    }

    func setSignedIn(_ user: AuthUser) {
        bootstrapTask?.cancel()
        hasBootstrapped = true
        status = .signedIn(user)
    }

    func updateCurrentUserDisplayName(_ newName: String) {
        guard case .signedIn(let user) = status else { return }
        user.displayName = newName
        objectWillChange.send()
    }

    func signOut() {
        print("[AppState] signOut() called")
        bootstrapTask?.cancel()
        AuthService.shared.signOutLocal()
        hasBootstrapped = true
        status = .signedOut
        print("[AppState] status is now .signedOut")
    }

    /// Call this after mutating currentUser properties (e.g. displayName)
    /// so SwiftUI views that depend on currentUser re-render immediately.
    func userDidChange() {
        objectWillChange.send()
    }
}
