//
//  DailyIntentionAIService.swift
//  Lunixia
//

import Foundation

struct DailyIntentionAIResponse: Decodable {
    let intention: String
}

private struct DailyIntentionAIRequest: Encodable {
    let context: String
}

final class DailyIntentionAIService {
    static let shared = DailyIntentionAIService()
    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink"

    func generateIntention(context: String) async throws -> DailyIntentionAIResponse {
        let cleanedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedContext.isEmpty else {
            throw NSError(
                domain: "DailyIntentionAIService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Type context before getting an intention."]
            )
        }

        guard let url = URL(string: "\(baseURL)/api/journal/intention") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DailyIntentionAIRequest(context: cleanedContext))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "DailyIntentionAIService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        let decoded = try JSONDecoder().decode(DailyIntentionAIResponse.self, from: data)
        let intention = decoded.intention.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !intention.isEmpty else {
            throw NSError(
                domain: "DailyIntentionAIService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "The generated intention was empty."]
            )
        }

        return DailyIntentionAIResponse(intention: intention)
    }
}
