//
//  PBLAppZone.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI
import UserNotifications

@main
struct PBLAppZone: App {
    @State private var appState = AppState()

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        // Main window — login or project panel
        WindowGroup {
            Group {
                if appState.token != "" {
                    MainTabViewMacOS()
                        .environment(appState)
                        .frame(minWidth: 1200, minHeight: 680)
                } else {
                    LoginViewMacOS()
                        .environment(appState)
                        .frame(width: 1200, height: 680)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Project workspace windows — opened via openWindow(id: "project-view", value: "projectId|groupId")
        WindowGroup(id: "project-view", for: String.self) { $windowKey in
            ProjectViewMacOS(windowKey: windowKey ?? "")
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
