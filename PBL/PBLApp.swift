//
//  PBLApp.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import SwiftUI

@main
struct PBLApp: App {
    @State private var appState = AppState()

    func autoLogin() async {
        guard appState.token.isEmpty,
              let creds = AppState.loadSavedCredentials() else { return }
        let domain = creds.email.components(separatedBy: "@").last ?? ""
        appState.isAutoLoggingIn = true
        let success = (try? await tryLogin(
            appState: appState,
            email: creds.email,
            password: creds.password,
            emailDomain: domain
        )) ?? false
        if !success {
            appState.isAutoLoggingIn = false
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.token != "" {
                    MainTabViewiOS()
                        .environment(appState)
                } else if appState.isAutoLoggingIn {
                    ProgressView("登录中…")
                } else {
                    LoginViewiOS()
                        .environment(appState)
                }
            }
            .task {
                await autoLogin()
            }
        }
    }
}
