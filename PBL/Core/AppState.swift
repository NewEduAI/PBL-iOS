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
    var isTeacher: Bool = false

    var organization: String = "个人"
    var organizationBaseUrl: String = "https://assignment.maic.chat/api"

    var userAPI: UserAPI?

    func saveLoginResult(
        userId: String,
        token: String,
        username: String,
        isTeacher: Bool,
        organization: String,
        organizationBaseUrl: String
    ) {
        self.userId = userId
        self.token = token
        self.username = username
        self.isTeacher = isTeacher
        self.organization = organization
        self.organizationBaseUrl = organizationBaseUrl
        self.userAPI = UserAPI(baseURL: organizationBaseUrl)
    }

    func logout() {
        self.userId = ""
        self.token = ""
        self.username = "未登录"
        self.isTeacher = false
        self.organization = "个人"
        self.organizationBaseUrl = "https://assignment.maic.chat/api"
        self.userAPI = nil
    }
}
