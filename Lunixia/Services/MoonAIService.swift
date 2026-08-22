//
//  MoonAIService.swift
//  Lunixia
//

import Foundation

struct MoonAIRequest: Encodable {
    let phaseName: String
    let signName: String
    let details: String
}

struct MoonAIResponse: Decodable {
    let title: String
    let keywords: [String]
    let message: String
}

private struct MoonAIErrorResponse: Decodable {
    let error: String
}

final class MoonAIService {
    static let shared = MoonAIService()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func generateMoonInterpretation(
        phaseName: String,
        signName: String,
        details: String
    ) async throws -> MoonAIResponse {
        let requestBody = MoonAIRequest(
            phaseName: phaseName.trimmingCharacters(in: .whitespacesAndNewlines),
            signName: signName.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard !requestBody.phaseName.isEmpty else {
            throw MoonAIServiceError.invalidPhaseName
        }

        guard !requestBody.signName.isEmpty else {
            throw MoonAIServiceError.invalidSignName
        }

        guard !requestBody.details.isEmpty else {
            throw MoonAIServiceError.invalidDetails
        }

        guard let url = URL(
            string: "https://appapi.voxiverse.ink/api/moon"
        ) else {
            throw MoonAIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        do {
            request.httpBody = try encoder.encode(requestBody)
        } catch {
            throw MoonAIServiceError.encodingFailed
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                throw MoonAIServiceError.noInternetConnection
            case .timedOut:
                throw MoonAIServiceError.requestTimedOut
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw MoonAIServiceError.backendUnavailable
            default:
                throw MoonAIServiceError.networkFailed
            }
        } catch {
            throw MoonAIServiceError.networkFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MoonAIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let backendError = try? decoder.decode(MoonAIErrorResponse.self, from: data),
               !backendError.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw MoonAIServiceError.serverError(backendError.error)
            }

            throw MoonAIServiceError.serverError(
                "The moon interpretation could not be generated."
            )
        }

        do {
            let result = try decoder.decode(MoonAIResponse.self, from: data)

            let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = result.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let keywords = result.keywords
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !title.isEmpty else {
                throw MoonAIServiceError.emptyTitle
            }

            guard !message.isEmpty else {
                throw MoonAIServiceError.emptyMessage
            }

            guard !keywords.isEmpty else {
                throw MoonAIServiceError.emptyKeywords
            }

            return MoonAIResponse(
                title: title,
                keywords: keywords,
                message: message
            )
        } catch let error as MoonAIServiceError {
            throw error
        } catch {
            throw MoonAIServiceError.decodingFailed
        }
    }
}

enum MoonAIServiceError: LocalizedError {
    case invalidPhaseName
    case invalidSignName
    case invalidDetails
    case invalidURL
    case invalidResponse
    case encodingFailed
    case decodingFailed
    case networkFailed
    case noInternetConnection
    case requestTimedOut
    case backendUnavailable
    case serverError(String)
    case emptyTitle
    case emptyKeywords
    case emptyMessage

    var errorDescription: String? {
        switch self {
        case .invalidPhaseName:
            return "The moon phase name is missing."
        case .invalidSignName:
            return "The moon sign name is missing."
        case .invalidDetails:
            return "The moon details are missing."
        case .invalidURL:
            return "The moon service URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .encodingFailed:
            return "The moon details could not be prepared for the request."
        case .decodingFailed:
            return "The moon interpretation could not be understood."
        case .networkFailed:
            return "The moon interpretation request failed."
        case .noInternetConnection:
            return "An internet connection is required to create this moon interpretation."
        case .requestTimedOut:
            return "The moon interpretation took too long to generate. Please try again."
        case .backendUnavailable:
            return "The moon interpretation service is currently unavailable."
        case let .serverError(message):
            return message
        case .emptyTitle:
            return "The moon interpretation did not include a title."
        case .emptyKeywords:
            return "The moon interpretation did not include any keywords."
        case .emptyMessage:
            return "The moon interpretation did not include a message."
        }
    }
}
