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
    
    var body: some Scene {
        WindowGroup {
            if appState.token != "" {
                MainTabViewiOS()
                    .environment(appState)
            } else {
                LoginViewiOS()
                    .environment(appState)
            }
        }
    }
}
