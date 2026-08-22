//
//  HoroscopeService.swift
//  Lunixia
//

import Foundation

enum HoroscopeServiceError: Error {
    case invalidURL
    case invalidResponse
    case serverError(String)
}

final class HoroscopeService {
    static let shared = HoroscopeService()

    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink"

    private struct HoroscopeRequest: Codable {
        let sign: String
    }

    private struct HoroscopeResponse: Codable {
        let sign: String
        let message: String
        let date: String?
    }

    func fetchHoroscope(for sign: String) async throws -> DailyHoroscope {
        guard let url = URL(string: "\(baseURL)/api/astrology/horoscope") else {
            throw HoroscopeServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(HoroscopeRequest(sign: sign.lowercased()))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HoroscopeServiceError.invalidResponse
        }

        let rawText = String(data: data, encoding: .utf8) ?? "Unable to decode response body"
        print("[Horoscope] Status Code:", httpResponse.statusCode)
        print("[Horoscope] Raw Response:", rawText)

        guard 200..<300 ~= httpResponse.statusCode else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw HoroscopeServiceError.serverError(text)
        }

        do {
            let decoded = try JSONDecoder().decode(HoroscopeResponse.self, from: data)

            return DailyHoroscope(
                sign: decoded.sign.capitalized,
                message: decoded.message
            )
        } catch {
            print("[Horoscope] Decoding Error:", error)
            throw error
        }
    }
}
