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
    private let token: String

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
        }
        return req
    }

    func request<T: Codable>(
        path: String,
        method: HTTPMethod,
        body: Codable? = nil
    ) async throws -> T {
        let urlRequest = try buildRequest(path: path, method: method, body: body)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let rawJSON = String(data: data, encoding: .utf8) {
            print("API Response [\(path)]: \(rawJSON)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)

        guard apiResponse.isSuccess else {
            throw APIError(message: apiResponse.message, statusCode: httpResponse.statusCode)
        }

        guard let responseData = apiResponse.data else {
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
        let urlRequest = try buildRequest(path: path, method: method, body: body)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)

        guard apiResponse.isSuccess else {
            throw APIError(message: apiResponse.message, statusCode: httpResponse.statusCode)
        }

        return apiResponse.data  // nil when the server returns null — caller treats as "none"
    }

    /// For endpoints that return no data (void), only checks `is_success`.
    func requestEmpty(
        path: String,
        method: HTTPMethod,
        body: Codable? = nil
    ) async throws {
        let urlRequest = try buildRequest(path: path, method: method, body: body)
        let (data, _) = try await URLSession.shared.data(for: urlRequest)

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
