//
//  MoodStatsContextService.swift
//  Lunixia
//

import Foundation

struct MoodStatsContextRequest: Encodable {
    struct MoodSummary: Encodable {
        let averageMoodPercent: Int
        let checkInCount: Int
        let bestDay: String
        let hardestDay: String
    }

    struct PhoneBehavior: Encodable {
        let screenTimeMinutes: Double
        let socialAppMinutes: Double
        let nighttimePhoneMinutes: Double
        let pickupCount: Int
        let notificationCount: Int
    }

    struct RecentSnapshot: Encodable {
        let date: String
        let averageMoodPercent: Int
        let checkInCount: Int
        let screenTimeMinutes: Double
        let socialAppMinutes: Double
        let nighttimePhoneMinutes: Double
        let pickupCount: Int
        let notificationCount: Int
    }

    let userId: String?
    let date: String
    let moodSummary: MoodSummary
    let phoneBehavior: PhoneBehavior
    let recentSnapshots: [RecentSnapshot]
}

struct MoodStatsContextResponse: Codable {
    struct Behavior: Codable {
        let key: String
        let insight: String
    }

    let summary: String
    let behaviors: [Behavior]
    let generatedAt: String
}

final class MoodStatsContextService {
    static let shared = MoodStatsContextService()
    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink"

    func generateContext(_ payload: MoodStatsContextRequest) async throws -> MoodStatsContextResponse {
        guard let url = URL(string: "\(baseURL)/api/mood/stats/context") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "MoodStatsContextService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        return try JSONDecoder().decode(MoodStatsContextResponse.self, from: data)
    }
}
