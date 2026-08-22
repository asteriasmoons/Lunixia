//
// JournalAnalysisService.swift
// Lystaria
//

import Foundation

struct JournalAnalysisResponse: Decodable {
    let themes: [String]
    let mood: String
    let reflection: String
    let dateKey: String
    let cached: Bool
}

private struct JournalAnalysisRequest: Encodable {
    struct EntryPayload: Encodable {
        let title: String
        let body: String
    }
    let userId: String
    let bookId: String
    let dateKey: String
    let entries: [EntryPayload]
    let tags: [String]
    let mindfulMinutes: Int
    let entryCount: Int
}

// MARK: - Theme Insights Response Models

struct ThemeInsightOverview: Decodable {
    let totalEntries: Int
    let totalMindfulMinutes: Int
    let uniqueThemes: Int
    let uniqueTags: Int
}

struct ThemeInsightItem: Decodable, Identifiable, Hashable {
    let name: String
    let entryCount: Int
    let mindfulMinutes: Int
    let percentage: Int
    let firstUsedDate: String
    let lastUsedDate: String
    let currentPeriodCount: Int
    let previousPeriodCount: Int
    let changeAmount: Int
    let trend: String
    let relatedThemes: [String]

    var id: String { name }

    func hash(into hasher: inout Hasher) { hasher.combine(name) }
    static func == (lhs: ThemeInsightItem, rhs: ThemeInsightItem) -> Bool { lhs.name == rhs.name }
}

struct ThemeCategoryInsights: Decodable {
    let mostCommon: [ThemeInsightItem]
    let emerging: [ThemeInsightItem]
    let new: [ThemeInsightItem]
    let declining: [ThemeInsightItem]

    private enum CodingKeys: String, CodingKey {
        case mostCommon, emerging, declining
        case new = "new"
    }
}

struct TagCategoryInsights: Decodable {
    let mostCommon: [ThemeInsightItem]
}

struct ThemeInsightsResponse: Decodable {
    let period: String
    let totalEntries: Int
    let overview: ThemeInsightOverview
    let themes: ThemeCategoryInsights
    let tags: TagCategoryInsights
}

struct RelatedThemeItem: Decodable {
    let name: String
    let coOccurrences: Int
    let percentage: Int
}

struct UsageDay: Decodable {
    let day: String
    let count: Int
}

struct ThemeEntrySummary: Decodable {
    let dateKey: String
    let bookId: String
    let mood: String
    let themes: [String]
    let mindfulMinutes: Int
}

struct ThemeDetailResponse: Decodable {
    let name: String
    let entryCount: Int
    let totalEntries: Int
    let percentage: Int
    let mindfulMinutes: Int
    let firstUsedDate: String?
    let lastUsedDate: String?
    let usageByDay: [UsageDay]
    let relatedThemes: [RelatedThemeItem]
    let entries: [ThemeEntrySummary]
}

struct ThemeExtractionResponse: Decodable {
    let themes: [String]
    let suggestedTags: [String]
}

final class JournalAnalysisService {

    static let shared = JournalAnalysisService()
    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink"

    func fetchAnalysis(userId: String, bookId: String, dateKey: String) async throws -> JournalAnalysisResponse? {
        guard var components = URLComponents(string: "\(baseURL)/api/journal/analyze") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "bookId", value: bookId),
            URLQueryItem(name: "dateKey", value: dateKey)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        print("JournalAnalysis URL:", request.url?.absoluteString ?? "nil")
        print("JournalAnalysis status:", (response as? HTTPURLResponse)?.statusCode ?? -1)
        print("JournalAnalysis body:", String(data: data, encoding: .utf8) ?? "nil")

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalAnalysisService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let exists = raw?["exists"] as? Bool, exists else {
            return nil
        }

        return try JSONDecoder().decode(JournalAnalysisResponse.self, from: data)
    }

    func fetchAnalysisDates(userId: String, bookId: String) async throws -> [String] {
        guard var components = URLComponents(string: "\(baseURL)/api/journal/analyze/dates") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "bookId", value: bookId)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        print("JournalAnalysis URL:", request.url?.absoluteString ?? "nil")
        print("JournalAnalysis status:", (response as? HTTPURLResponse)?.statusCode ?? -1)
        print("JournalAnalysis body:", String(data: data, encoding: .utf8) ?? "nil")

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalAnalysisService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        struct DatesResponse: Decodable { let dates: [String] }
        let decoded = try JSONDecoder().decode(DatesResponse.self, from: data)
        return decoded.dates
    }

    func fetchTodayAnalysis(userId: String) async throws -> JournalAnalysisResponse? {
        guard var components = URLComponents(string: "\(baseURL)/api/journal/analyze") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "userId", value: userId)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        print("JournalAnalysis URL:", request.url?.absoluteString ?? "nil")
        print("JournalAnalysis status:", (response as? HTTPURLResponse)?.statusCode ?? -1)
        print("JournalAnalysis body:", String(data: data, encoding: .utf8) ?? "nil")

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalAnalysisService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let exists = raw?["exists"] as? Bool, exists else {
            return nil
        }

        return try JSONDecoder().decode(JournalAnalysisResponse.self, from: data)
    }

    func analyze(
        userId: String,
        bookId: String,
        dateKey: String,
        entries: [JournalEntry],
        tags: [String] = [],
        mindfulMinutes: Int = 0
    ) async throws -> JournalAnalysisResponse {
        guard !entries.isEmpty else {
            throw NSError(
                domain: "JournalAnalysisService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No entries to analyze for today."]
            )
        }

        guard let url = URL(string: "\(baseURL)/api/journal/analyze") else {
            throw URLError(.badURL)
        }

        let payloads = entries.map { entry -> JournalAnalysisRequest.EntryPayload in
            let blockText = entry.sortedBlocks
                .compactMap { block -> String? in
                    let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }
                .joined(separator: "\n")
            let body = blockText.isEmpty ? entry.body : blockText
            return JournalAnalysisRequest.EntryPayload(
                title: entry.title.isEmpty ? "Untitled" : entry.title,
                body: body
            )
        }

        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            JournalAnalysisRequest(
                userId: userId,
                bookId: bookId,
                dateKey: dateKey,
                entries: payloads,
                tags: tags,
                mindfulMinutes: mindfulMinutes,
                entryCount: entries.count
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        print("JournalAnalysis URL:", request.url?.absoluteString ?? "nil")
        print("JournalAnalysis status:", (response as? HTTPURLResponse)?.statusCode ?? -1)
        print("JournalAnalysis body:", String(data: data, encoding: .utf8) ?? "nil")

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            // Prefer the server's own error message; fall back to the raw body
            let body = String(data: data, encoding: .utf8) ?? ""
            let serverMessage: String = {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = json["error"] as? String ?? json["message"] as? String,
                   !msg.isEmpty {
                    return msg
                }
                return body.isEmpty ? "Server returned status \(http.statusCode)" : body
            }()
            throw NSError(
                domain: "JournalAnalysisService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: serverMessage]
            )
        }

        return try JSONDecoder().decode(JournalAnalysisResponse.self, from: data)
    }

    // MARK: - Theme Insights

    func fetchInsights(userId: String, period: String = "month") async throws -> ThemeInsightsResponse {
        guard var components = URLComponents(string: "\(baseURL)/api/journal/insights") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "period", value: period),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalAnalysisService",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        return try JSONDecoder().decode(ThemeInsightsResponse.self, from: data)
    }

    func fetchThemeDetail(userId: String, theme: String) async throws -> ThemeDetailResponse {
        let encoded = theme.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? theme
        guard var components = URLComponents(string: "\(baseURL)/api/journal/insights/\(encoded)") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalAnalysisService",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        return try JSONDecoder().decode(ThemeDetailResponse.self, from: data)
    }

    /// Ask the backend to re-normalize all stored themes/tags for this user.
    func normalizeThemes(userId: String) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/api/journal/insights/normalize") else {
            throw URLError(.badURL)
        }

        struct NormalizeRequest: Encodable { let userId: String }
        struct NormalizeResponse: Decodable { let updated: Int; let total: Int }

        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(NormalizeRequest(userId: userId))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalAnalysisService",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        let result = try JSONDecoder().decode(NormalizeResponse.self, from: data)
        print("[Normalize] Updated \(result.updated)/\(result.total) documents")
        return result.updated
    }

    func extractThemes(entries: [JournalEntry]) async throws -> ThemeExtractionResponse {
        guard let url = URL(string: "\(baseURL)/api/journal/insights/extract-themes") else {
            throw URLError(.badURL)
        }

        struct ExtractRequest: Encodable {
            struct Entry: Encodable {
                let title: String
                let body: String
                let tags: [String]
            }
            let entries: [Entry]
        }

        let payloads = entries.map { entry -> ExtractRequest.Entry in
            let blockText = entry.sortedBlocks
                .compactMap { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: "\n")
            return ExtractRequest.Entry(
                title: entry.title.isEmpty ? "Untitled" : entry.title,
                body: blockText.isEmpty ? entry.body : blockText,
                tags: entry.tags
            )
        }

        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ExtractRequest(entries: payloads))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "JournalAnalysisService",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        return try JSONDecoder().decode(ThemeExtractionResponse.self, from: data)
    }
}
