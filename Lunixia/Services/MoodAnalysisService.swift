//
//  MoodAnalysisService.swift
//  Lunixia
//

import Foundation

// MARK: - Response Models

struct MoodAnalysisResponse: Decodable, Identifiable {
    let id: String
    let mindset: String
    let emotionalBalance: String
    let influences: String
    let reflection: String
    let themes: [String]
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id, mindset, emotionalBalance, influences, reflection, themes, createdAt
    }
}

struct MoodAnalysisHistoryItem: Decodable, Identifiable {
    let id: String
    let moodEntryId: String
    let timestamp: String
    let mindset: String
    let emotionalBalance: String
    let influences: String
    let reflection: String
    let themes: [String]
    let emotions: [String]
    let activities: [String]
    let createdAt: String
}

struct MoodAnalysisHistoryResponse: Decodable {
    let analyses: [MoodAnalysisHistoryItem]
}

// MARK: - Request Models

private struct MoodEmotionPayload: Encodable {
    let name: String
    let category: String
}

private struct MoodAnalyzeRequest: Encodable {
    let userId: String
    let moodEntryId: String
    let emotions: [MoodEmotionPayload]
    let activities: [String]
    let sleepHours: Double
    let exerciseMinutes: Int
    let steps: Int
    let meditationMinutes: Int
    let waterOz: Double
    let note: String
    let timestamp: String
}

// MARK: - Service

final class MoodAnalysisService {
    static let shared = MoodAnalysisService()
    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink"

    func analyze(userId: String, entry: MoodEntry) async throws -> MoodAnalysisResponse {
        guard let url = URL(string: "\(baseURL)/api/mood/analyze") else {
            throw URLError(.badURL)
        }

        let emotionPayloads = entry.resolvedEmotions.map { emotion in
            MoodEmotionPayload(name: emotion.name, category: emotion.category.rawValue)
        }

        let request = MoodAnalyzeRequest(
            userId: userId,
            moodEntryId: entry.id.uuidString,
            emotions: emotionPayloads,
            activities: entry.activityNames,
            sleepHours: entry.sleepHours,
            exerciseMinutes: entry.exerciseMinutes,
            steps: entry.steps,
            meditationMinutes: entry.meditationMinutes,
            waterOz: entry.waterOz,
            note: entry.note,
            timestamp: ISO8601DateFormatter().string(from: entry.timestamp)
        )

        var urlRequest = URLRequest(url: url, timeoutInterval: 45)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "MoodAnalysisService",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        return try JSONDecoder().decode(MoodAnalysisResponse.self, from: data)
    }

    func fetchHistory(userId: String, moodEntryId: String? = nil) async throws -> [MoodAnalysisHistoryItem] {
        guard var components = URLComponents(string: "\(baseURL)/api/mood/analyze/history") else {
            throw URLError(.badURL)
        }

        var queryItems = [URLQueryItem(name: "userId", value: userId)]
        if let entryId = moodEntryId {
            queryItems.append(URLQueryItem(name: "moodEntryId", value: entryId))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "MoodAnalysisService",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        return try JSONDecoder().decode(MoodAnalysisHistoryResponse.self, from: data).analyses
    }
}
