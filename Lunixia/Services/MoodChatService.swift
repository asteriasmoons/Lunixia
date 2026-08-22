//
//  MoodChatService.swift
//  Lunixia
//

import Foundation

// MARK: - Message model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String   // "user" | "model"
    var text: String

    /// Serialised format the backend expects
    func toPayload() -> [String: Any] {
        ["role": role, "parts": [["text": text]]]
    }
}

// MARK: - Service

final class MoodChatService {

    // Replace with your deployed lystaria-api base URL
    private let baseURL = "https://appapi.voxiverse.ink/api/mood/chat"

    func send(messages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw MoodChatError.badURL
        }

        let body: [String: Any] = [
            "messages": messages.map { $0.toPayload() }
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw MoodChatError.badResponse
        }
        guard http.statusCode == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? "unknown"
            throw MoodChatError.httpError(http.statusCode, raw)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let reply = json["reply"] as? String
        else {
            throw MoodChatError.malformedResponse
        }

        return reply
    }
}

// MARK: - Errors

enum MoodChatError: LocalizedError {
    case badURL
    case badResponse
    case httpError(Int, String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .badURL:                    return "Invalid API URL."
        case .badResponse:               return "Invalid response from server."
        case .httpError(let c, let m):   return "HTTP \(c): \(m)"
        case .malformedResponse:         return "Unexpected response format."
        }
    }
}
