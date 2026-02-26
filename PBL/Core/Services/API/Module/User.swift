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

// MARK: - Auth Response (both login and register return a userId string)

struct AuthResponse: Codable {
    let userId: String
    let token: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.userId = try container.decode(String.self)
        self.token = self.userId
    }
}

// MARK: - User Info

struct GetUserInfoRequest: Codable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct UserInfoResponse: Codable {
    let name: String
    let email: String
    let is_teacher: Bool
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

    func getUserInfo(userId: String) async throws -> UserInfoResponse {
        let response: UserInfoResponse = try await self.request(
            path: self.prefix + "/info",
            method: .post,
            body: GetUserInfoRequest(userId: userId)
        )
        return response
    }
}
