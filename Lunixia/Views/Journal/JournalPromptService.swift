//
//  JournalPromptService.swift
//  Lunixia
//

import Foundation
import SwiftData

struct JournalPromptResponse: Decodable {
    let prompt: String
    let remaining: Int
    let dateKey: String
}

private struct JournalPromptRequest: Encodable {
    let userId: String
}

final class JournalPromptService {

    static let shared = JournalPromptService()

    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink"

    func generatePrompt(userId: String, modelContext: ModelContext) async throws -> JournalPromptResponse {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let todayDateKey = formatter.string(from: Date())

        let descriptor = FetchDescriptor<JournalPromptUsage>(
            predicate: #Predicate { usage in
                usage.userId == userId && usage.dateKey == todayDateKey
            }
        )

        let usageRecord: JournalPromptUsage
        if let existing = try modelContext.fetch(descriptor).first {
            usageRecord = existing
        } else {
            let newRecord = JournalPromptUsage(userId: userId, dateKey: todayDateKey)
            modelContext.insert(newRecord)
            usageRecord = newRecord
        }

        guard usageRecord.usedCount < 3 else {
            throw NSError(
                domain: "JournalPromptService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "You’ve already used your 3 journal prompts for today."]
            )
        }

        guard let url = URL(string: "\(baseURL)/api/journal/prompt") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(JournalPromptRequest(userId: userId))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalPromptService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        let decoded = try JSONDecoder().decode(JournalPromptResponse.self, from: data)
        let prompt = decoded.prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prompt.isEmpty else {
            throw NSError(
                domain: "JournalPromptService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Groq returned an empty prompt."]
            )
        }

        usageRecord.usedCount += 1
        usageRecord.updatedAt = Date()
        try modelContext.save()

        return JournalPromptResponse(
            prompt: prompt,
            remaining: decoded.remaining,
            dateKey: decoded.dateKey
        )
    }
}
