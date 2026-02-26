//
//  UserProfile.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import SwiftUI

struct UserProfileView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("信息") {
                    HStack {
                        Text("姓名")
                        Spacer()
                        Text(appState.username)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("用户ID")
                        Spacer()
                        Text(appState.userId)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("身份")
                        Spacer()
                        Text(appState.isTeacher ? "教师" : "学生")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("机构")
                        Spacer()
                        Text(appState.organization)
                            .foregroundStyle(.secondary)
                    }
                }
                
//                Section("设置")

                Section {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("\(appState.username) \(appState.isTeacher ? "老师" : "同学" )您好")
        }
    }
}
