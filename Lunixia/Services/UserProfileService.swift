//
//  UserProfileService.swift
//  Lunixia
//

import Foundation

final class UserProfileService {
    static let shared = UserProfileService()
    private init() {}

    private let baseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              !url.isEmpty else {
            return "https://appapi.voxiverse.ink"
        }
        return url
    }()

    private let session = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func setDisplayName(userId: String, displayName: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/user/display-name")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["userId": userId, "displayName": displayName])
        let (data, _) = try await session.data(for: request)
        let response = try decoder.decode(UserProfileResponse.self, from: data)
        if !response.success { throw UserProfileError.serverError }
    }

    func getDisplayName(userId: String) async throws -> String? {
        let url = URL(string: "\(baseURL)/api/user/display-name/\(userId)")!
        let (data, _) = try await session.data(for: URLRequest(url: url))
        let response = try decoder.decode(UserProfileDisplayNameResponse.self, from: data)
        return response.displayName
    }
}

enum UserProfileError: Error {
    case serverError
}

private struct UserProfileResponse: Decodable {
    let success: Bool
}

private struct UserProfileDisplayNameResponse: Decodable {
    let success: Bool
    let displayName: String?
}
