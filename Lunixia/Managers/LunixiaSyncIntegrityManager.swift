//
//  LunixiaSyncIntegrityManager.swift
//  Lunixia
//

import CoreData
import Combine
import Foundation
import SwiftData

@MainActor
final class LunixiaSyncIntegrityManager: ObservableObject {
    static let shared = LunixiaSyncIntegrityManager()

    @Published private(set) var isReadyForContent = false

    private var cloudKitObserver: NSObjectProtocol?
    private var activeImportIDs = Set<UUID>()
    private var lastCloudKitEventAt = Date()
    private var initialReconciliationTask: Task<Void, Never>?
    private var importReconciliationTask: Task<Void, Never>?
    private var modelContainer: ModelContainer?
    private var hasCompletedInitialGate = false

    private init() {}

    /// Start observing before the model container is created so the app cannot
    /// miss the initial CloudKit import event on a newly installed device.
    func beginObservingCloudKitEvents() {
        guard cloudKitObserver == nil else { return }

        lastCloudKitEventAt = Date()
        cloudKitObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else {
                return
            }

            Task { @MainActor [weak self] in
                self?.receive(event)
            }
        }
    }

    func start(container: ModelContainer) {
        beginObservingCloudKitEvents()
        modelContainer = container
        guard initialReconciliationTask == nil else { return }

        initialReconciliationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let hasLocalIdentity = ((try? container.mainContext.fetch(
                FetchDescriptor<AuthUser>()
            )) ?? []).isEmpty == false

            // A fresh device needs a longer window for its first import to
            // begin. An established local store only needs the quiet window.
            try? await Task.sleep(for: hasLocalIdentity ? .seconds(2) : .seconds(8))
            let didSettle = await waitForImportToSettle(
                maximumWait: hasLocalIdentity ? .seconds(8) : .seconds(30)
            )
            guard !Task.isCancelled else { return }

            hasCompletedInitialGate = true
            isReadyForContent = true

            if didSettle {
                reconcileAndRunAutomations(in: container)
            } else {
                // CloudKit can leave a started import event without a matching
                // terminal event. Keep reconciliation deferred, but never trap
                // the entire app behind the startup screen indefinitely.
                scheduleReconciliation(in: container, after: .seconds(10))
            }
        }
    }

    func applicationBecameActive(container: ModelContainer) {
        guard hasCompletedInitialGate else { return }
        scheduleReconciliation(in: container, after: .seconds(3))
    }

    func runPeriodicAutomationsIfSafe(container: ModelContainer) {
        guard hasCompletedInitialGate,
              activeImportIDs.isEmpty,
              Date().timeIntervalSince(lastCloudKitEventAt) >= 2 else {
            if hasCompletedInitialGate {
                scheduleReconciliation(in: container, after: .seconds(3))
            }
            return
        }

        MedicationAutomationManager.run(in: container.mainContext)
    }

    func runWeeklyResetIfSafe(container: ModelContainer) {
        guard hasCompletedInitialGate,
              activeImportIDs.isEmpty,
              Date().timeIntervalSince(lastCloudKitEventAt) >= 2 else {
            if hasCompletedInitialGate {
                scheduleReconciliation(in: container, after: .seconds(3))
            }
            return
        }

        LunixiaPointsManager.performDueWeeklyResetIfNeeded(modelContainer: container)
    }

    private func receive(_ event: NSPersistentCloudKitContainer.Event) {
        lastCloudKitEventAt = Date()

        guard event.type == .import else { return }

        if event.endDate == nil {
            activeImportIDs.insert(event.identifier)
            importReconciliationTask?.cancel()
        } else {
            activeImportIDs.remove(event.identifier)

            if hasCompletedInitialGate, let container = modelContainer {
                scheduleReconciliation(in: container, after: .seconds(2))
            }
        }
    }

    private func scheduleReconciliation(
        in container: ModelContainer,
        after delay: Duration
    ) {
        importReconciliationTask?.cancel()
        importReconciliationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            let didSettle = await waitForImportToSettle(maximumWait: .seconds(90))
            guard !Task.isCancelled else { return }
            guard didSettle else {
                scheduleReconciliation(in: container, after: .seconds(10))
                return
            }
            hasCompletedInitialGate = true
            reconcileAndRunAutomations(in: container)
            isReadyForContent = true
        }
    }

    private func waitForImportToSettle(maximumWait: Duration) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: maximumWait)

        while clock.now < deadline {
            let hasQuietWindow = Date().timeIntervalSince(lastCloudKitEventAt) >= 2
            if activeImportIDs.isEmpty && hasQuietWindow {
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

        return false
    }

    private func reconcileAndRunAutomations(in container: ModelContainer) {
        let context = container.mainContext

        LunixiaPointsManager.reconcileSyncedData(in: context)
        LunixiaPointsManager.performDueWeeklyResetIfNeeded(modelContainer: container)
        LunixiaPointsManager.scheduleWeeklyReset(
            modelContainer: container,
            performImmediately: false
        )
        MedicationAutomationManager.run(
            in: context,
            shouldReconcileSyncedInventory: true
        )
        LunixiaStickyNoteWidgetWriter.write(in: context)
    }
}
