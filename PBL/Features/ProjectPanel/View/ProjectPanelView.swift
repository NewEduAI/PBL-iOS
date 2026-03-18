//
//  ProjectPanelView.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import SwiftUI

struct ProjectPanelViewiOS: View {
    @Environment(AppState.self) private var appState
    @State private var assignments: [StudentAssignment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var showJoinByCode = false
    @State private var showJoinOpen = false
    @State private var showCreateProject = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                } else if appState.isTeacher {
                    Text("Teacher view - TODO")
                } else {
                    List(assignments) { assignment in
                        ProjectCardStudent(assignment: assignment)
                    }
                }
            }
            .navigationTitle("项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showJoinByCode = true
                        } label: {
                            Label("课程码", systemImage: "ticket")
                        }

                        Button {
                            showJoinOpen = true
                        } label: {
                            Label("加入经典项目", systemImage: "globe")
                        }

                        if appState.isTeacher {
                            Button {
                                showCreateProject = true
                            } label: {
                                Label("创建项目", systemImage: "plus.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showJoinByCode) {
                // Join by code view
                Text("Join by invitation code")
            }
            .sheet(isPresented: $showJoinOpen) {
                // Join open project view
                Text("Join open project")
            }
            .sheet(isPresented: $showCreateProject) {
                // Create project view
                Text("Create project")
            }
            .task {
                await loadAssignments()
            }
        }
    }

    func loadAssignments() async {
        guard !appState.isTeacher, !appState.userId.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let projectAPI = StudentProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
            assignments = try await projectAPI.getStudentAssignments()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
