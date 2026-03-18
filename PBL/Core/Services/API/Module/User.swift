//
//  User.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import Foundation

// MARK: - Login

struct LoginRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Register

struct RegisterRequest: Codable {
    let name: String
    let email: String
    let password: String
    let is_teacher: Bool
}

// MARK: - Auth Response
// Handles both new format { user_id, token } and legacy format (plain userId string).

struct AuthResponse: Codable {
    let userId: String
    let token: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
    }

    init(from decoder: Decoder) throws {
        // Try new keyed format first: { "user_id": "...", "token": "..." }
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let uid = try? container.decode(String.self, forKey: .userId),
           let tok = try? container.decode(String.self, forKey: .token) {
            self.userId = uid
            self.token = tok
        } else {
            // Legacy: data is just a plain userId string (token = userId for now)
            let container = try decoder.singleValueContainer()
            let uid = try container.decode(String.self)
            self.userId = uid
            self.token = uid
        }
    }
}

// MARK: - User Info

struct UserInfoResponse: Codable {
    let name: String
    let email: String
    let is_teacher: Bool
}

// MARK: - Access Tokens

struct AccessToken: Codable, Identifiable {
    let id: String
    let name: String
    let createdAt: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case createdAt = "created_at"
        case isActive = "is_active"
    }
}

struct CreateTokenResponse: Codable {
    let tokenId: String
    let token: String

    enum CodingKeys: String, CodingKey {
        case tokenId = "token_id"
        case token
    }
}

// MARK: - API

class UserAPI: BaseAPI {
    let prefix = "/user"

    func login(email: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await self.request(
            path: self.prefix + "/login",
            method: .post,
            body: LoginRequest(email: email, password: password)
        )
        print("Login successful, user_id: \(response.userId)")
        return response
    }

    func register(name: String, email: String, password: String, isTeacher: Bool) async throws -> AuthResponse {
        let response: AuthResponse = try await self.request(
            path: self.prefix + "/register",
            method: .post,
            body: RegisterRequest(name: name, email: email, password: password, is_teacher: isTeacher)
        )
        print("Register successful, user_id: \(response.userId)")
        return response
    }

    func getUserInfo() async throws -> UserInfoResponse {
        let response: UserInfoResponse = try await self.request(
            path: self.prefix + "/info",
            method: .post
        )
        return response
    }

    // MARK: Access Tokens

    func createAccessToken(name: String) async throws -> CreateTokenResponse {
        struct Body: Codable { let name: String }
        return try await request(
            path: prefix + "/access_tokens",
            method: .post,
            body: Body(name: name)
        )
    }

    func listAccessTokens() async throws -> [AccessToken] {
        try await request(
            path: prefix + "/access_tokens",
            method: .get
        )
    }

    func revokeAccessToken(tokenId: String) async throws {
        try await requestEmpty(
            path: prefix + "/access_tokens/\(tokenId)",
            method: .delete
        )
    }
}
