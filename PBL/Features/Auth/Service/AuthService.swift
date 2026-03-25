//
//  AuthService.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import Foundation

func tryLogin(
    appState: AppState,
    email: String,
    password: String,
    emailDomain: String
) async throws -> Bool {
    guard let institution = InstitutionList.fromEmailDomain(emailDomain) else {
        return false
    }
    let userAPI = UserAPI(baseURL: institution.baseUrl)
    let authResponse = try await userAPI.login(email: email, password: password)
    let authedAPI = UserAPI(baseURL: institution.baseUrl, token: authResponse.token)
    let userInfo = try await authedAPI.getUserInfo()
    appState.saveLoginResult(
        userId: authResponse.userId,
        token: authResponse.token,
        username: userInfo.name,
        email: email,
        password: password,
        isTeacher: userInfo.is_teacher,
        organization: institution.name,
        organizationBaseUrl: institution.baseUrl
    )
    return true
}

func tryRegister(
    appState: AppState,
    name: String,
    email: String,
    password: String,
    isTeacher: Bool,
    emailDomain: String
) async throws -> Bool {
    let institution = InstitutionList.fromEmailDomain(emailDomain) ?? InstitutionList.defaultInstitution
    let userAPI = UserAPI(baseURL: institution.baseUrl)
    let authResponse = try await userAPI.register(
        name: name,
        email: email,
        password: password,
        isTeacher: isTeacher
    )
    appState.saveLoginResult(
        userId: authResponse.userId,
        token: authResponse.token,
        username: name,
        email: email,
        password: password,
        isTeacher: isTeacher,
        organization: institution.name,
        organizationBaseUrl: institution.baseUrl
    )
    return true
}
