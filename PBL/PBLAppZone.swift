//
//  PBLAppZone.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI
import UserNotifications
import Sparkle

@main
struct PBLAppZone: App {
    @State private var appState = AppState()
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

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
        // Main window — login or project panel
        WindowGroup {
            Group {
                if appState.token != "" {
                    MainTabViewMacOS()
                        .environment(appState)
                        .frame(minWidth: 1200, minHeight: 680)
                } else if appState.isAutoLoggingIn {
                    ProgressView("登录中…")
                        .frame(width: 1200, height: 680)
                } else {
                    LoginViewMacOS()
                        .environment(appState)
                        .frame(width: 1200, height: 680)
                }
            }
            .task {
                await autoLogin()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }

        // Project workspace windows — opened via openWindow(id: "project-view", value: "projectId|groupId")
        WindowGroup(id: "project-view", for: String.self) { $windowKey in
            ProjectViewMacOS(windowKey: windowKey ?? "")
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Teacher project edit windows — opened via openWindow(id: "project-edit", value: projectId)
        WindowGroup(id: "project-edit", for: String.self) { $projectId in
            ProjectEditViewMacOS(projectId: projectId ?? "")
                .environment(appState)
                .frame(minWidth: 1350, minHeight: 660)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
