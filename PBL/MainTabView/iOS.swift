//
//  MainTabView.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import SwiftUI

struct MainTabViewiOS: View {
    var body: some View{
        TabView {
            NotificationView()
                .tabItem {
                    Label("消息", systemImage: "message")
                }
            ProjectPanelViewiOS()
                .tabItem {
                    Label("项目", systemImage: "folder")
                }
            UserProfileView()
                .tabItem{
                    Label("我的", systemImage: "person")
                }
        }
    }
}
