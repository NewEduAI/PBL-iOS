//
//  AppState.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import SwiftUI

@Observable
class AppState {
    var userId: String = ""
    var token: String = ""
    var username: String = "未登录"
    var email: String = ""
    var isTeacher: Bool = false
    var password: String = ""
    /// True while auto-login is in progress on app start (suppresses login screen flash).
    var isAutoLoggingIn: Bool = false

    var organization: String = "个人"
    var organizationBaseUrl: String = "https://assignment.maic.chat/api"

    var userAPI: UserAPI?

    // MARK: - Credential persistence (UserDefaults)

    private static let kEmail = "saved_email"
    private static let kPassword = "saved_password"

    /// Persist credentials so the app can auto-login on next launch.
    private func saveCredentials(email: String, password: String) {
        UserDefaults.standard.set(email, forKey: Self.kEmail)
        UserDefaults.standard.set(password, forKey: Self.kPassword)
    }

    /// Load persisted credentials. Returns (email, password) or nil.
    static func loadSavedCredentials() -> (email: String, password: String)? {
        guard let email = UserDefaults.standard.string(forKey: kEmail),
              let password = UserDefaults.standard.string(forKey: kPassword),
              !email.isEmpty, !password.isEmpty else { return nil }
        return (email, password)
    }

    private func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: Self.kEmail)
        UserDefaults.standard.removeObject(forKey: Self.kPassword)
    }

    // MARK: - Login / Logout

    func saveLoginResult(
        userId: String,
        token: String,
        username: String,
        email: String,
        password: String,
        isTeacher: Bool,
        organization: String,
        organizationBaseUrl: String
    ) {
        self.userId = userId
        self.token = token
        self.username = username
        self.email = email
        self.password = password
        self.isTeacher = isTeacher
        self.organization = organization
        self.organizationBaseUrl = organizationBaseUrl
        self.userAPI = UserAPI(baseURL: organizationBaseUrl)

        saveCredentials(email: email, password: password)

        // Register the global token refresher so any BaseAPI can silently re-auth on 401.
        BaseAPI.tokenRefresher = { [weak self] in
            guard let self, !self.email.isEmpty, !self.password.isEmpty else { return nil }
            let api = UserAPI(baseURL: self.organizationBaseUrl)
            guard let auth = try? await api.login(email: self.email, password: self.password) else { return nil }
            self.token = auth.token
            self.userId = auth.userId
            return auth.token
        }
    }

    func logout() {
        self.userId = ""
        self.token = ""
        self.username = "未登录"
        self.email = ""
        self.password = ""
        self.isTeacher = false
        self.organization = "个人"
        self.organizationBaseUrl = "https://assignment.maic.chat/api"
        self.userAPI = nil
        BaseAPI.tokenRefresher = nil
        clearCredentials()
    }
}
