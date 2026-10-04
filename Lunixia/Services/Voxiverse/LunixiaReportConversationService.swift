//
//  LunixiaReportConversationService.swift
//  Lunixia
//

import CloudKit
import Combine
import Foundation
import SwiftData

@MainActor
final class LunixiaReportConversationService: ObservableObject {
    @Published private(set) var snapshot: LunixiaReportConversationSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var localOutgoingMessages: [LunixiaReportConversationMessage] = []
    @Published private(set) var isUpdatingInvitation = false
    @Published var errorMessage: String?

    private let container: CKContainer
    private var pendingPayloads: [String: PendingOutgoingPayload] = [:]
    private var activeMessageIDs: Set<String> = []

    private struct PendingOutgoingPayload: Codable {
        let text: String
        let attachments: [LunixiaConversationAttachment]
        let createdAt: Date
        let conversationID: String
    }

    init(container: CKContainer = CKContainer(identifier: LunixiaReportConversationCloudKitSchema.containerIdentifier)) {
        self.container = container
    }

    func load(report: SubmittedReport, modelContext: ModelContext, markRead: Bool = false) async {
        isLoading = true
        errorMessage = nil
        restorePendingPayloads(for: report.reportID)
        do {
            let loaded = try await fetchSnapshot(for: report, modelContext: modelContext, markRead: markRead)
            snapshot = loaded
            reconcileLocalMessages(with: loaded)
        } catch {
            snapshot = snapshot ?? cachedSnapshot(for: report)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func accept(report: SubmittedReport, modelContext: ModelContext) async {
        isUpdatingInvitation = true
        errorMessage = nil
        do {
            let current = try await currentSnapshot(for: report, modelContext: modelContext)
            guard let recordID = current.recordID else { throw ConversationError.missingSharedConversation }
            let database = conversationDatabase(for: recordID)
            let root = try await fetchRecord(recordID, in: database)
            let now = Date()
            root[LunixiaReportConversationCloudKitSchema.ConversationField.invitationState] = LunixiaReportConversationState.accepted.rawValue as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.acceptedAt] = now as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.updatedAt] = now as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.reporterUnreadCount] = 0 as CKRecordValue
            _ = try await database.modifyRecords(saving: [root], deleting: [], savePolicy: .changedKeys, atomically: true)
            try? await updatePublicReportConversationState(for: report, state: .accepted, timestamp: now)

            snapshot = try await fetchSnapshot(for: report, modelContext: modelContext, markRead: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdatingInvitation = false
    }

    func decline(report: SubmittedReport, modelContext: ModelContext) async {
        isUpdatingInvitation = true
        errorMessage = nil
        do {
            let current = try await currentSnapshot(for: report, modelContext: modelContext)
            guard let recordID = current.recordID else { throw ConversationError.missingSharedConversation }
            let database = conversationDatabase(for: recordID)
            let root = try await fetchRecord(recordID, in: database)
            let now = Date()
            root[LunixiaReportConversationCloudKitSchema.ConversationField.invitationState] = LunixiaReportConversationState.declined.rawValue as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.declinedAt] = now as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.updatedAt] = now as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.reporterUnreadCount] = 0 as CKRecordValue
            _ = try await database.modifyRecords(saving: [root], deleting: [], savePolicy: .changedKeys, atomically: true)
            try? await updatePublicReportConversationState(for: report, state: .declined, timestamp: now)

            snapshot = try await fetchSnapshot(for: report, modelContext: modelContext, markRead: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdatingInvitation = false
    }

    func sendReporterMessage(
        _ rawText: String,
        attachments: [LunixiaConversationAttachment] = [],
        report: SubmittedReport,
        modelContext: ModelContext
    ) -> Bool {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachments.isEmpty else { return false }
        guard let current = snapshot, current.state == .accepted, current.acceptsReplies else { return false }

        let messageID = UUID().uuidString
        let now = Date()
        pendingPayloads[messageID] = PendingOutgoingPayload(text: text, attachments: attachments, createdAt: now, conversationID: report.reportID)
        localOutgoingMessages.append(LunixiaReportConversationMessage(
            id: messageID, senderRole: .reporter, body: text, createdAt: now,
            creatorRecordName: "", attachments: attachments, deliveryState: .sending
        ))
        updateSendingState()
        errorMessage = nil
        Task { await processOutgoingMessage(messageID, report: report, modelContext: modelContext) }
        return true
    }

    func retryReporterMessage(_ messageID: String, report: SubmittedReport, modelContext: ModelContext) {
        guard pendingPayloads[messageID] != nil,
              let index = localOutgoingMessages.firstIndex(where: { $0.id == messageID }),
              localOutgoingMessages[index].deliveryState == .failed,
              snapshot?.state == .accepted, snapshot?.acceptsReplies == true else { return }
        localOutgoingMessages[index].deliveryState = .sending
        updateSendingState()
        Task { await processOutgoingMessage(messageID, report: report, modelContext: modelContext) }
    }

    var displayedMessages: [LunixiaReportConversationMessage] {
        let remote = snapshot?.messages ?? []
        let remoteIDs = Set(remote.map(\.id))
        return (remote + localOutgoingMessages.filter { !remoteIDs.contains($0.id) }).sorted { $0.createdAt < $1.createdAt }
    }

    private func processOutgoingMessage(_ messageID: String, report: SubmittedReport, modelContext: ModelContext) async {
        guard !activeMessageIDs.contains(messageID), let payload = pendingPayloads[messageID] else { return }
        activeMessageIDs.insert(messageID)
        defer { activeMessageIDs.remove(messageID); updateSendingState() }
        var finalError: Error?
        do {
            try persistPendingPayload(payload, messageID: messageID)
        } catch {
            setDeliveryState(.failed, for: messageID)
            errorMessage = error.localizedDescription
            return
        }
        for attempt in 0..<3 {
            do {
                try await persistReporterMessage(messageID: messageID, payload: payload, report: report, modelContext: modelContext)
                setDeliveryState(.sent, for: messageID)
                pendingPayloads.removeValue(forKey: messageID)
                removePersistedPayload(messageID: messageID)
                if let refreshed = try? await fetchSnapshot(for: report, modelContext: modelContext, markRead: true) {
                    snapshot = refreshed
                    reconcileLocalMessages(with: refreshed)
                }
                return
            } catch {
                finalError = error
                if attempt < 2 { try? await Task.sleep(for: .milliseconds(180)) }
            }
        }
        setDeliveryState(.failed, for: messageID)
        errorMessage = finalError?.localizedDescription
    }

    private func persistReporterMessage(messageID: String, payload: PendingOutgoingPayload, report: SubmittedReport, modelContext: ModelContext) async throws {
            let current = try await currentSnapshot(for: report, modelContext: modelContext)
            guard current.state == .accepted else { throw ConversationError.notAccepted }
            guard let recordID = current.recordID else { throw ConversationError.missingSharedConversation }

            let database = conversationDatabase(for: recordID)
            let root = try await fetchRecord(recordID, in: database)
            guard LunixiaReportConversationState(rawValue: root.lunixiaString(LunixiaReportConversationCloudKitSchema.ConversationField.invitationState)) == .accepted else {
                throw ConversationError.notAccepted
            }
            guard (root[LunixiaReportConversationCloudKitSchema.ConversationField.acceptsReplies] as? NSNumber)?.boolValue ?? true else {
                throw ConversationError.readOnly
            }

            let now = payload.createdAt
            let messageRecordID = CKRecord.ID(recordName: "message-\(messageID)", zoneID: root.recordID.zoneID)
            if (try? await database.record(for: messageRecordID)) != nil { return }
            let message = CKRecord(recordType: LunixiaReportConversationCloudKitSchema.RecordType.message, recordID: messageRecordID)
            message.parent = CKRecord.Reference(recordID: root.recordID, action: .none)
            message[LunixiaReportConversationCloudKitSchema.MessageField.messageID] = messageID as CKRecordValue
            message[LunixiaReportConversationCloudKitSchema.MessageField.conversation] = CKRecord.Reference(recordID: root.recordID, action: .none)
            message[LunixiaReportConversationCloudKitSchema.MessageField.conversationRecordName] = root.recordID.recordName as CKRecordValue
            message[LunixiaReportConversationCloudKitSchema.MessageField.senderRole] = LunixiaReportConversationSenderRole.reporter.rawValue as CKRecordValue
            message[LunixiaReportConversationCloudKitSchema.MessageField.body] = payload.text as CKRecordValue
            message[LunixiaReportConversationCloudKitSchema.MessageField.createdAt] = now as CKRecordValue
            message[LunixiaReportConversationCloudKitSchema.MessageField.clientMessageID] = messageID as CKRecordValue
            let temporaryFiles = try writeAttachments(payload.attachments, to: message)
            defer { temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) } }

            var names = root[LunixiaReportConversationCloudKitSchema.ConversationField.messageRecordNames] as? [String] ?? []
            if !names.contains(messageRecordID.recordName) {
                names.append(messageRecordID.recordName)
            }
            root[LunixiaReportConversationCloudKitSchema.ConversationField.messageRecordNames] = names as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.lastMessageAt] = now as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.lastMessageSenderRole] = LunixiaReportConversationSenderRole.reporter.rawValue as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.updatedAt] = now as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.staffUnreadCount] = (root.lunixiaInt(LunixiaReportConversationCloudKitSchema.ConversationField.staffUnreadCount) + 1) as CKRecordValue

            let saveResult = try await database.modifyRecords(saving: [root, message], deleting: [], savePolicy: .changedKeys, atomically: true)
            for recordID in [root.recordID, message.recordID] {
                guard let result = saveResult.saveResults[recordID] else { throw ConversationError.recordNotFound }
                _ = try result.get()
            }
            try? await updatePublicReportConversationLastActivity(for: report, state: .accepted, timestamp: now)
    }

    private func setDeliveryState(_ state: LunixiaReportConversationDeliveryState, for messageID: String) {
        guard let index = localOutgoingMessages.firstIndex(where: { $0.id == messageID }) else { return }
        localOutgoingMessages[index].deliveryState = state
    }

    private func reconcileLocalMessages(with snapshot: LunixiaReportConversationSnapshot) {
        let remoteIDs = Set(snapshot.messages.map(\.id))
        for messageID in remoteIDs where pendingPayloads[messageID] != nil {
            pendingPayloads.removeValue(forKey: messageID)
            removePersistedPayload(messageID: messageID)
        }
        localOutgoingMessages.removeAll { remoteIDs.contains($0.id) }
    }

    private func restorePendingPayloads(for conversationID: String) {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: outboxDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
        let decoder = PropertyListDecoder()
        for url in urls where url.pathExtension == "plist" {
            guard let data = try? Data(contentsOf: url),
                  let payload = try? decoder.decode(PendingOutgoingPayload.self, from: data),
                  payload.conversationID == conversationID else { continue }
            let messageID = url.deletingPathExtension().lastPathComponent
            guard pendingPayloads[messageID] == nil else { continue }
            pendingPayloads[messageID] = payload
            localOutgoingMessages.append(LunixiaReportConversationMessage(
                id: messageID, senderRole: .reporter, body: payload.text, createdAt: payload.createdAt,
                creatorRecordName: "", attachments: payload.attachments, deliveryState: .failed
            ))
        }
    }

    private var outboxDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("LunixiaReportConversationOutbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func persistPendingPayload(_ payload: PendingOutgoingPayload, messageID: String) throws {
        let data = try PropertyListEncoder().encode(payload)
        try data.write(to: outboxDirectory.appendingPathComponent("\(messageID).plist"), options: .atomic)
    }

    private func removePersistedPayload(messageID: String) {
        try? FileManager.default.removeItem(at: outboxDirectory.appendingPathComponent("\(messageID).plist"))
    }

    private func updateSendingState() {
        isSending = localOutgoingMessages.contains { $0.deliveryState == .sending }
    }

    private func writeAttachments(_ attachments: [LunixiaConversationAttachment], to record: CKRecord) throws -> [URL] {
        var urls: [URL] = []
        do {
            for (offset, attachment) in attachments.prefix(3).enumerated() {
                let index = offset + 1
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try attachment.data.write(to: url, options: .atomic)
                urls.append(url)
                record[LunixiaReportConversationCloudKitSchema.MessageField.attachment(index)] = CKAsset(fileURL: url)
                record[LunixiaReportConversationCloudKitSchema.MessageField.attachmentName(index)] = attachment.name as CKRecordValue
                record[LunixiaReportConversationCloudKitSchema.MessageField.attachmentType(index)] = attachment.typeIdentifier as CKRecordValue
            }
            record[LunixiaReportConversationCloudKitSchema.MessageField.attachmentCount] = urls.count as CKRecordValue
            return urls
        } catch {
            urls.forEach { try? FileManager.default.removeItem(at: $0) }
            throw error
        }
    }

    private func readAttachments(from record: CKRecord) -> [LunixiaConversationAttachment] {
        (0..<min(3, record.lunixiaInt(LunixiaReportConversationCloudKitSchema.MessageField.attachmentCount))).compactMap { offset in
            let index = offset + 1
            guard let url = (record[LunixiaReportConversationCloudKitSchema.MessageField.attachment(index)] as? CKAsset)?.fileURL,
                  let data = try? Data(contentsOf: url) else { return nil }
            return LunixiaConversationAttachment(
                name: record.lunixiaString(LunixiaReportConversationCloudKitSchema.MessageField.attachmentName(index), fallback: "Attachment \(index)"),
                typeIdentifier: record.lunixiaString(LunixiaReportConversationCloudKitSchema.MessageField.attachmentType(index), fallback: "public.data"),
                data: data
            )
        }
    }

    func fetchSummary(for report: SubmittedReport, modelContext: ModelContext) async -> LunixiaReportConversationSnapshot {
        do {
            return try await fetchSnapshot(for: report, modelContext: modelContext)
        } catch {
            return cachedSnapshot(for: report)
        }
    }

    private func currentSnapshot(for report: SubmittedReport, modelContext: ModelContext) async throws -> LunixiaReportConversationSnapshot {
        if let snapshot {
            return snapshot
        }
        return try await fetchSnapshot(for: report, modelContext: modelContext)
    }

    private func fetchSnapshot(
        for report: SubmittedReport,
        modelContext: ModelContext,
        markRead: Bool = false
    ) async throws -> LunixiaReportConversationSnapshot {
        let publicRecord = try await fetchPublicReport(for: report)
        applyConversationPointer(from: publicRecord, to: report, modelContext: modelContext)

        guard let shareURL = URL(string: report.conversationShareURL), !report.conversationShareURL.isEmpty else {
            report.conversationState = .notStarted
            report.conversationUnreadCount = 0
            try? modelContext.save()
            return .notStarted(for: report)
        }

        let metadata = try await shareMetadata(for: shareURL)
        try await acceptShareIfNeeded(metadata)

        let resolvedConversation = try await fetchConversationRecord(
            metadata: metadata,
            report: report
        )
        let database = resolvedConversation.database
        let root = resolvedConversation.record
        if markRead {
            let now = Date()
            root[LunixiaReportConversationCloudKitSchema.ConversationField.reporterUnreadCount] = 0 as CKRecordValue
            root[LunixiaReportConversationCloudKitSchema.ConversationField.reporterLastReadAt] = now as CKRecordValue
            _ = try await database.modifyRecords(saving: [root], deleting: [], savePolicy: .changedKeys, atomically: true)
        }

        let messages = try await fetchMessages(from: root, in: database)
        let snapshot = makeSnapshot(from: root, shareURL: shareURL, messages: messages, fallbackReport: report)
        applySnapshot(snapshot, to: report, modelContext: modelContext)
        if markRead {
            await LunixiaReportConversationNotificationManager.clearReadConversationNotification(reportID: report.reportID)
        }
        try await LunixiaReportConversationNotificationManager.registerSharedConversationNotifications(
            database: database,
            conversationRecordID: root.recordID
        )
        return snapshot
    }

    private func fetchPublicReport(for report: SubmittedReport) async throws -> CKRecord {
        let database = container.publicCloudDatabase
        return try await fetchRecord(CKRecord.ID(recordName: report.reportID), in: database)
    }

    private func updatePublicReportConversationState(
        for report: SubmittedReport,
        state: LunixiaReportConversationState,
        timestamp: Date
    ) async throws {
        let record = try await fetchPublicReport(for: report)
        record[LunixiaReportConversationCloudKitSchema.PublicReportField.conversationState] = state.rawValue as CKRecordValue
        record[LunixiaReportConversationCloudKitSchema.PublicReportField.conversationUpdatedAt] = timestamp as CKRecordValue
        _ = try await container.publicCloudDatabase.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: true)
    }

    private func updatePublicReportConversationLastActivity(
        for report: SubmittedReport,
        state: LunixiaReportConversationState,
        timestamp: Date
    ) async throws {
        let record = try await fetchPublicReport(for: report)
        record[LunixiaReportConversationCloudKitSchema.PublicReportField.conversationState] = state.rawValue as CKRecordValue
        record[LunixiaReportConversationCloudKitSchema.PublicReportField.conversationUpdatedAt] = timestamp as CKRecordValue
        record[LunixiaReportConversationCloudKitSchema.PublicReportField.conversationLastMessageAt] = timestamp as CKRecordValue
        _ = try await container.publicCloudDatabase.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: true)
    }

    private func applyConversationPointer(from record: CKRecord, to report: SubmittedReport, modelContext: ModelContext) {
        report.conversationRecordName = record.lunixiaString(LunixiaReportConversationCloudKitSchema.PublicReportField.conversationRecordName)
        report.conversationZoneName = record.lunixiaString(LunixiaReportConversationCloudKitSchema.PublicReportField.conversationZoneName)
        report.conversationZoneOwnerName = record.lunixiaString(LunixiaReportConversationCloudKitSchema.PublicReportField.conversationZoneOwnerName)
        report.conversationShareURL = record.lunixiaString(LunixiaReportConversationCloudKitSchema.PublicReportField.conversationShareURL)
        report.conversationUpdatedAt = record.lunixiaDate(LunixiaReportConversationCloudKitSchema.PublicReportField.conversationUpdatedAt)
        report.conversationLastMessageAt = record.lunixiaDate(LunixiaReportConversationCloudKitSchema.PublicReportField.conversationLastMessageAt)
        if let state = LunixiaReportConversationState(rawValue: record.lunixiaString(LunixiaReportConversationCloudKitSchema.PublicReportField.conversationState)) {
            report.conversationState = state
        }
        try? modelContext.save()
    }

    private func applySnapshot(_ snapshot: LunixiaReportConversationSnapshot, to report: SubmittedReport, modelContext: ModelContext) {
        report.conversationRecordName = snapshot.recordID?.recordName ?? report.conversationRecordName
        report.conversationZoneName = snapshot.recordID?.zoneID.zoneName ?? report.conversationZoneName
        report.conversationZoneOwnerName = snapshot.recordID?.zoneID.ownerName ?? report.conversationZoneOwnerName
        report.conversationShareURL = snapshot.shareURL?.absoluteString ?? report.conversationShareURL
        report.conversationState = snapshot.state
        report.conversationUpdatedAt = snapshot.updatedAt
        report.conversationLastMessageAt = snapshot.messages.last?.createdAt
        report.conversationUnreadCount = snapshot.reporterUnreadCount
        if snapshot.reporterUnreadCount == 0 {
            report.conversationLastReadAt = Date()
        }
        try? modelContext.save()
    }

    private func cachedSnapshot(for report: SubmittedReport) -> LunixiaReportConversationSnapshot {
        let recordID: CKRecord.ID?
        if !report.conversationRecordName.isEmpty, !report.conversationZoneName.isEmpty {
            let ownerName = report.conversationZoneOwnerName.isEmpty
                ? CKCurrentUserDefaultName
                : report.conversationZoneOwnerName
            recordID = CKRecord.ID(
                recordName: report.conversationRecordName,
                zoneID: CKRecordZone.ID(
                    zoneName: report.conversationZoneName,
                    ownerName: ownerName
                )
            )
        } else {
            recordID = nil
        }

        return LunixiaReportConversationSnapshot(
            id: report.conversationRecordName.isEmpty ? report.reportID : report.conversationRecordName,
            reportID: report.reportID,
            sourceAppID: LunixiaReportConversationCloudKitSchema.sourceAppID,
            reportType: report.reportType,
            reportTitle: report.title,
            state: report.conversationState,
            acceptsReplies: true,
            recordID: recordID,
            shareURL: URL(string: report.conversationShareURL),
            createdAt: report.submittedAt,
            updatedAt: report.conversationUpdatedAt,
            invitedAt: report.conversationState == .invited ? report.conversationUpdatedAt : nil,
            acceptedAt: report.conversationState == .accepted ? report.conversationUpdatedAt : nil,
            declinedAt: report.conversationState == .declined ? report.conversationUpdatedAt : nil,
            reporterUnreadCount: report.conversationUnreadCount,
            staffUnreadCount: 0,
            messages: []
        )
    }

    private func shareMetadata(for url: URL) async throws -> CKShare.Metadata {
        let results = try await container.shareMetadatas(for: [url])
        guard let result = results[url] else { throw ConversationError.missingShareMetadata }
        return try result.get()
    }

    private func acceptShareIfNeeded(_ metadata: CKShare.Metadata) async throws {
        guard metadata.participantStatus != .accepted else { return }
        let results = try await container.accept([metadata])
        guard let result = results[metadata] else { throw ConversationError.shareAcceptanceFailed }
        _ = try result.get()
    }

    private func metadataRootRecordID(_ metadata: CKShare.Metadata) -> CKRecord.ID {
        let metadataRecordID: CKRecord.ID
        if #available(iOS 15.0, *) {
            if let recordID = metadata.hierarchicalRootRecordID {
                metadataRecordID = recordID
            } else {
                metadataRecordID = metadata.rootRecordID
            }
        } else {
            metadataRecordID = metadata.rootRecordID
        }
        return metadataRecordID
    }

    private func fetchConversationRecord(
        metadata: CKShare.Metadata,
        report: SubmittedReport
    ) async throws -> (record: CKRecord, database: CKDatabase) {
        let metadataRecordID = metadataRootRecordID(metadata)
        let recordName = report.conversationRecordName.isEmpty
            ? metadataRecordID.recordName
            : report.conversationRecordName
        let zoneName = report.conversationZoneName.isEmpty
            ? metadataRecordID.zoneID.zoneName
            : report.conversationZoneName

        if metadata.participantRole == .owner {
            let privateDatabase = container.privateCloudDatabase
            let privateRecordID = CKRecord.ID(
                recordName: recordName,
                zoneID: CKRecordZone.ID(
                    zoneName: zoneName,
                    ownerName: CKCurrentUserDefaultName
                )
            )
            return (try await fetchRecord(privateRecordID, in: privateDatabase), privateDatabase)
        }

        let sharedDatabase = container.sharedCloudDatabase
        let sharedZones = try await sharedDatabase.allRecordZones()
        let matchingZoneIDs = sharedZones
            .map(\.zoneID)
            .filter { $0.zoneName == zoneName }

        let candidateIDs = matchingZoneIDs.map {
            CKRecord.ID(recordName: recordName, zoneID: $0)
        }
        if !candidateIDs.isEmpty {
            let results = try await sharedDatabase.records(for: candidateIDs)

            for recordID in candidateIDs {
                guard let result = results[recordID] else { continue }
                if case .success(let record) = result {
                    return (record, sharedDatabase)
                }
            }
        }

        // When both apps are signed into the share owner's iCloud account,
        // CloudKit exposes the hierarchy in the private database rather than
        // creating a recipient zone in the shared database.
        let privateDatabase = container.privateCloudDatabase
        let privateRecordID = CKRecord.ID(
            recordName: recordName,
            zoneID: CKRecordZone.ID(
                zoneName: zoneName,
                ownerName: CKCurrentUserDefaultName
            )
        )
        do {
            return (try await fetchRecord(privateRecordID, in: privateDatabase), privateDatabase)
        } catch {
            if matchingZoneIDs.isEmpty {
                throw ConversationError.sharedZoneUnavailable
            }
            throw error
        }
    }

    private func conversationDatabase(for recordID: CKRecord.ID) -> CKDatabase {
        if recordID.zoneID.ownerName == CKCurrentUserDefaultName {
            return container.privateCloudDatabase
        }
        return container.sharedCloudDatabase
    }

    private func fetchRecord(_ recordID: CKRecord.ID, in database: CKDatabase) async throws -> CKRecord {
        let results = try await database.records(for: [recordID])
        guard let result = results[recordID] else { throw ConversationError.recordNotFound }
        return try result.get()
    }

    private func fetchMessages(from root: CKRecord, in database: CKDatabase) async throws -> [LunixiaReportConversationMessage] {
        let names = root[LunixiaReportConversationCloudKitSchema.ConversationField.messageRecordNames] as? [String] ?? []
        guard !names.isEmpty else { return [] }
        let ids = names.map { CKRecord.ID(recordName: $0, zoneID: root.recordID.zoneID) }
        let results = try await database.records(for: ids)
        return ids.compactMap { id in
            guard let result = results[id], let record = try? result.get() else { return nil }
            return LunixiaReportConversationMessage(
                id: record.lunixiaString(LunixiaReportConversationCloudKitSchema.MessageField.messageID, fallback: record.recordID.recordName),
                senderRole: LunixiaReportConversationSenderRole(rawValue: record.lunixiaString(LunixiaReportConversationCloudKitSchema.MessageField.senderRole)) ?? .unknown,
                body: record.lunixiaString(LunixiaReportConversationCloudKitSchema.MessageField.body),
                createdAt: record.lunixiaDate(LunixiaReportConversationCloudKitSchema.MessageField.createdAt) ?? record.creationDate ?? Date(),
                creatorRecordName: record.creatorUserRecordID?.recordName ?? "",
                attachments: readAttachments(from: record)
            )
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    private func makeSnapshot(
        from root: CKRecord,
        shareURL: URL,
        messages: [LunixiaReportConversationMessage],
        fallbackReport: SubmittedReport
    ) -> LunixiaReportConversationSnapshot {
        LunixiaReportConversationSnapshot(
            id: root.lunixiaString(LunixiaReportConversationCloudKitSchema.ConversationField.conversationID, fallback: root.recordID.recordName),
            reportID: root.lunixiaString(LunixiaReportConversationCloudKitSchema.ConversationField.reportID, fallback: fallbackReport.reportID),
            sourceAppID: root.lunixiaString(LunixiaReportConversationCloudKitSchema.ConversationField.sourceAppID, fallback: LunixiaReportConversationCloudKitSchema.sourceAppID),
            reportType: root.lunixiaString(LunixiaReportConversationCloudKitSchema.ConversationField.reportType, fallback: fallbackReport.reportType),
            reportTitle: root.lunixiaString(LunixiaReportConversationCloudKitSchema.ConversationField.reportTitle, fallback: fallbackReport.title),
            state: LunixiaReportConversationState(rawValue: root.lunixiaString(LunixiaReportConversationCloudKitSchema.ConversationField.invitationState)) ?? .notStarted,
            acceptsReplies: (root[LunixiaReportConversationCloudKitSchema.ConversationField.acceptsReplies] as? NSNumber)?.boolValue ?? true,
            recordID: root.recordID,
            shareURL: shareURL,
            createdAt: root.lunixiaDate(LunixiaReportConversationCloudKitSchema.ConversationField.createdAt) ?? root.creationDate,
            updatedAt: root.lunixiaDate(LunixiaReportConversationCloudKitSchema.ConversationField.updatedAt) ?? root.modificationDate,
            invitedAt: root.lunixiaDate(LunixiaReportConversationCloudKitSchema.ConversationField.invitedAt),
            acceptedAt: root.lunixiaDate(LunixiaReportConversationCloudKitSchema.ConversationField.acceptedAt),
            declinedAt: root.lunixiaDate(LunixiaReportConversationCloudKitSchema.ConversationField.declinedAt),
            reporterUnreadCount: root.lunixiaInt(LunixiaReportConversationCloudKitSchema.ConversationField.reporterUnreadCount),
            staffUnreadCount: root.lunixiaInt(LunixiaReportConversationCloudKitSchema.ConversationField.staffUnreadCount),
            messages: messages
        )
    }

    enum ConversationError: LocalizedError {
        case missingShareMetadata
        case sharedZoneUnavailable
        case shareAcceptanceFailed
        case missingSharedConversation
        case recordNotFound
        case notAccepted
        case readOnly

        var errorDescription: String? {
            switch self {
            case .missingShareMetadata:
                return "Lunixia could not load the private conversation invitation."
            case .sharedZoneUnavailable:
                return "The accepted private conversation is not available in Lunixia's shared CloudKit database yet."
            case .shareAcceptanceFailed:
                return "Lunixia could not prepare the private conversation share."
            case .missingSharedConversation:
                return "The private conversation is not available yet."
            case .recordNotFound:
                return "The private conversation record could not be found."
            case .notAccepted:
                return "Accept this invitation before sending a message."
            case .readOnly:
                return "This conversation is currently read only."
            }
        }
    }
}
