//
//  ThemeInsightsBackfillManager.swift
//  Lunixia
//

import Foundation
import SwiftData

/// One-time backfill that sends existing journal entry tags and estimated
/// mindful minutes to the backend, and creates local MindfulSession records
/// for past entries. Guarded by a UserDefaults flag so it only runs once.
enum ThemeInsightsBackfillManager {

    private static let backfillKey = "lunixia_theme_insights_backfilled_v5"
    private static let baseURL = "https://appapi.voxiverse.ink"

    static var hasBackfilled: Bool {
        UserDefaults.standard.bool(forKey: backfillKey)
    }

    /// Run the backfill if it hasn't been done yet.
    @MainActor
    static func backfillIfNeeded(modelContext: ModelContext, userId: String) {
        guard !hasBackfilled else { return }
        guard !userId.isEmpty else { return }

        Task {
            await runBackfill(modelContext: modelContext, userId: userId)
        }
    }

    @MainActor
    private static func runBackfill(modelContext: ModelContext, userId: String) async {
        print("[ThemeBackfill] Starting backfill for user: \(userId)")

        // 1. Fetch all non-deleted entries
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        guard let entries = try? modelContext.fetch(descriptor), !entries.isEmpty else {
            print("[ThemeBackfill] No entries found, marking complete")
            UserDefaults.standard.set(true, forKey: backfillKey)
            return
        }

        print("[ThemeBackfill] Found \(entries.count) entries to process")

        // 2. Group entries by (bookId, dateKey)
        struct GroupKey: Hashable {
            let bookId: String
            let dateKey: String
        }

        var groups: [GroupKey: [JournalEntry]] = [:]

        for entry in entries {
            guard let book = entry.book else { continue }
            let bookId = book.uuid.uuidString
            let dateKey = MindfulSession.chicagoDateKey(from: entry.createdAt)
            let key = GroupKey(bookId: bookId, dateKey: dateKey)
            groups[key, default: []].append(entry)
        }

        // 3. Build backend backfill records + local MindfulSession records
        var backfillRecords: [BackfillRecord] = []

        // Check which entries already have MindfulSession records
        let existingSessions = (try? modelContext.fetch(FetchDescriptor<MindfulSession>())) ?? []
        let existingEntryIDs = Set(existingSessions.map(\.entryPersistentID))

        var localSessionsCreated = 0

        for (key, groupEntries) in groups {
            // Collect all unique tags across entries in this group
            var allTags: [String] = []
            var totalEstimatedMinutes = 0

            for entry in groupEntries {
                allTags.append(contentsOf: entry.tags)

                // Estimate mindful minutes from content length:
                // ~200 chars/min writing speed, minimum 1 minute per entry
                let bodyLength = entry.blockPreviewText.count
                let estimatedMinutes = max(1, Int(round(Double(bodyLength) / 200.0)))
                totalEstimatedMinutes += estimatedMinutes

                // Create local MindfulSession if one doesn't exist for this entry
                let entryId = String(entry.persistentModelID.hashValue)
                if !existingEntryIDs.contains(entryId) {
                    let session = MindfulSession(
                        entryPersistentID: entryId,
                        bookPersistentID: key.bookId,
                        minutes: estimatedMinutes,
                        tags: entry.tags,
                        date: entry.createdAt,
                        dateKey: key.dateKey
                    )
                    modelContext.insert(session)
                    localSessionsCreated += 1
                }
            }

            // Deduplicate tags (simple case-insensitive)
            let uniqueTags = Array(Set(allTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
                .filter { !$0.isEmpty }

            backfillRecords.append(BackfillRecord(
                dateKey: key.dateKey,
                bookId: key.bookId,
                tags: uniqueTags,
                mindfulMinutes: totalEstimatedMinutes,
                entryCount: groupEntries.count
            ))
        }

        // Save local MindfulSession records
        try? modelContext.save()
        print("[ThemeBackfill] Created \(localSessionsCreated) local MindfulSession records")

        // 4. Wake the server with a lightweight ping before batching
        print("[ThemeBackfill] Warming up server...")
        if let pingURL = URL(string: baseURL) {
            _ = try? await URLSession.shared.data(from: pingURL)
        }

        // 5. Send to backend in small batches with retries
        let batchSize = 10
        var totalUpdated = 0

        for batchStart in stride(from: 0, to: backfillRecords.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, backfillRecords.count)
            let batch = Array(backfillRecords[batchStart..<batchEnd])
            let batchNum = batchStart / batchSize + 1

            var succeeded = false
            for attempt in 1...3 {
                do {
                    let updated = try await sendBackfillBatch(userId: userId, records: batch)
                    totalUpdated += updated
                    print("[ThemeBackfill] Batch \(batchNum): updated \(updated) records")
                    succeeded = true
                    break
                } catch {
                    print("[ThemeBackfill] Batch \(batchNum) attempt \(attempt) failed: \(error.localizedDescription)")
                    if attempt < 3 {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 3_000_000_000) // 3s, 6s backoff
                    }
                }
            }

            if !succeeded {
                print("[ThemeBackfill] Batch \(batchNum) failed after 3 attempts, continuing")
            }
        }

        print("[ThemeBackfill] Complete: \(totalUpdated) backend records updated, \(localSessionsCreated) local sessions created")

        // 6. Re-normalize all stored themes/tags in MongoDB
        print("[ThemeBackfill] Running theme normalization...")
        do {
            let normalized = try await JournalAnalysisService.shared.normalizeThemes(userId: userId)
            print("[ThemeBackfill] Normalized \(normalized) documents")
        } catch {
            print("[ThemeBackfill] Normalization failed: \(error.localizedDescription)")
        }

        UserDefaults.standard.set(true, forKey: backfillKey)
    }

    private struct BackfillRecord: Encodable {
        let dateKey: String
        let bookId: String
        let tags: [String]
        let mindfulMinutes: Int
        let entryCount: Int
    }

    private struct BackfillRequest: Encodable {
        let userId: String
        let records: [BackfillRecord]
    }

    private struct BackfillResponse: Decodable {
        let updated: Int
        let total: Int
    }

    private static func sendBackfillBatch(userId: String, records: [BackfillRecord]) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/api/journal/insights/backfill") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(BackfillRequest(userId: userId, records: records))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ThemeBackfill",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        return try JSONDecoder().decode(BackfillResponse.self, from: data).updated
    }
}
