//
//  SpiritualService.swift
//  Lunixia
//

import Foundation

enum SpiritualServiceError: Error {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case decodingError(Error)
}

struct SpiritualCardResponse: Decodable {
    let title: String
    let keywords: [String]
    let message: String
}

final class SpiritualService {
    static let shared = SpiritualService()
    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink/api/spiritual"

    // MARK: - Tarot

    func fetchTarotInterpretation(cardName: String) async throws -> SpiritualCardResponse {
        return try await fetch(endpoint: "tarot", cardName: cardName)
    }

    // MARK: - Lenormand

    func fetchLenormandInterpretation(cardName: String) async throws -> SpiritualCardResponse {
        return try await fetch(endpoint: "lenormand", cardName: cardName)
    }

    // MARK: - Shared fetch

    private func fetch(endpoint: String, cardName: String) async throws -> SpiritualCardResponse {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw SpiritualServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["cardName": cardName])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SpiritualServiceError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SpiritualServiceError.serverError(text)
        }

        do {
            return try JSONDecoder().decode(SpiritualCardResponse.self, from: data)
        } catch {
            throw SpiritualServiceError.decodingError(error)
        }
    }
}
