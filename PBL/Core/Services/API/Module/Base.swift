//
//  Base.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

struct APIResponse<T: Codable>: Codable {
    let isSuccess: Bool
    let message: String
    let data: T?

    enum CodingKeys: String, CodingKey {
        case isSuccess = "is_success"
        case message
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSuccess = try container.decode(Bool.self, forKey: .isSuccess)
        message = try container.decode(String.self, forKey: .message)
        data = try? container.decode(T.self, forKey: .data)
    }
}

struct APIError: Error {
    let message: String
    let statusCode: Int
}

class BaseAPI {
    private let baseURL: String
    private var token: String

    /// Global callback: called on HTTP 401 to silently re-login. Returns the new token or nil.
    static var tokenRefresher: (() async -> String?)?

    init(baseURL: String, token: String = "") {
        self.baseURL = baseURL
        self.token = token
    }

    private func buildRequest(path: String, method: HTTPMethod, body: Codable?) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        } else if method == .post {
            // FastAPI requires a JSON body on POST even if no fields are needed.
            req.httpBody = "{}".data(using: .utf8)
        }
        return req
    }

    /// If a 401 is received, attempt a silent re-login and retry the request once.
    private func refreshAndRetry(path: String, method: HTTPMethod, body: Codable?) async -> Bool {
        guard let refresher = Self.tokenRefresher,
              let newToken = await refresher() else { return false }
        token = newToken
        return true
    }

    func request<T: Codable>(
        path: String,
        method: HTTPMethod,
        body: Codable? = nil
    ) async throws -> T {
        var urlRequest = try buildRequest(path: path, method: method, body: body)
        var (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let rawJSON = String(data: data, encoding: .utf8) {
            print("API Response [\(path)]: \(rawJSON)")
        }

        guard var httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Silent token refresh on 401
        if httpResponse.statusCode == 401,
           await refreshAndRetry(path: path, method: method, body: body) {
            urlRequest = try buildRequest(path: path, method: method, body: body)
            (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let retryResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            httpResponse = retryResponse
        }

        let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)

        guard apiResponse.isSuccess else {
            print("API Error [\(path)]: \(apiResponse.message) (HTTP \(httpResponse.statusCode))")
            throw APIError(message: apiResponse.message, statusCode: httpResponse.statusCode)
        }

        guard let responseData = apiResponse.data else {
            print("API Error [\(path)]: data is nil despite is_success=true. Raw: \(String(data: data, encoding: .utf8) ?? "?")")
            throw APIError(message: "未知网络错误", statusCode: -1)
        }

        return responseData
    }

    /// For endpoints that may return null data (e.g. "not found" → nil without error).
    func requestOptional<T: Codable>(
        path: String,
        method: HTTPMethod,
        body: Codable? = nil
    ) async throws -> T? {
        var urlRequest = try buildRequest(path: path, method: method, body: body)
        var (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard var httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401,
           await refreshAndRetry(path: path, method: method, body: body) {
            urlRequest = try buildRequest(path: path, method: method, body: body)
            (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let retryResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            httpResponse = retryResponse
        }

        let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)

        guard apiResponse.isSuccess else {
            throw APIError(message: apiResponse.message, statusCode: httpResponse.statusCode)
        }

        return apiResponse.data
    }

    /// For endpoints that return no data (void), only checks `is_success`.
    func requestEmpty(
        path: String,
        method: HTTPMethod,
        body: Codable? = nil
    ) async throws {
        var urlRequest = try buildRequest(path: path, method: method, body: body)
        var (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401,
           await refreshAndRetry(path: path, method: method, body: body) {
            urlRequest = try buildRequest(path: path, method: method, body: body)
            (data, _) = try await URLSession.shared.data(for: urlRequest)
        }

        struct Bare: Codable {
            let isSuccess: Bool
            let message: String
            enum CodingKeys: String, CodingKey {
                case isSuccess = "is_success"
                case message
            }
        }
        let bare = try JSONDecoder().decode(Bare.self, from: data)
        guard bare.isSuccess else {
            throw APIError(message: bare.message, statusCode: 0)
        }
    }
}
