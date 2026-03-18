//
//  ProjectEditViewMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/26.
//

import SwiftUI

// MARK: - Tab definition

enum EditTab: String, CaseIterable {
    case agents, issues, gitlab

    var icon: String {
        switch self {
        case .agents:  return "person.2"
        case .issues:  return "checklist"
        case .gitlab:  return "externaldrive.badge.timemachine"
        }
    }

    var label: String {
        switch self {
        case .agents:  return "智能体"
        case .issues:  return "任务模板"
        case .gitlab:  return "课程材料"
        }
    }
}

// MARK: - Main view

struct ProjectEditViewMacOS: View {
    let projectId: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var project: Project? = nil
    @State private var isLoading = true
    @State private var error: String? = nil
    @State private var selectedTab: EditTab = .agents
    @State private var isPublishing = false
    @State private var publishError: String? = nil

    @State private var taService = TAAgentWebSocketService()

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 98/255, green: 83/255, blue: 225/255),
                Color(red: 4/255, green: 190/255, blue: 254/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 240)
                        .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    contentPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    TAAgentPanelMacOS(projectId: projectId, service: taService)
                        .frame(width: 400)
                        .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
        .ignoresSafeArea()
        .task {
            if appState.token.isEmpty { dismiss(); return }
            await loadProject()
        }
        .onDisappear { taService.disconnect() }
        .onChange(of: taService.lastAction) { _, action in
            handleTAAction(action)
        }
        .onChange(of: appState.token) { _, token in
            if token.isEmpty { dismiss() }
        }
    }

    // MARK: - Sidebar

    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Branding
            BrandingText(fontSize: 13)
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .padding(.bottom, 12)

            Divider()

            // Project header
            if let project {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        projectMonogram(title: project.title, size: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.title)
                                .font(.headline)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Status badge
                    HStack {
                        let isPublished = project.isPublished == true
                        Label(isPublished ? "已发布" : "草稿",
                              systemImage: isPublished ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.caption)
                            .foregroundStyle(isPublished ? .green : .secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }

                Divider()
                    .padding(.vertical, 6)
            }

            // Tab navigation
            VStack(spacing: 2) {
                ForEach(EditTab.allCases, id: \.self) { tab in
                    SidebarEditTabRow(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        isDisabled: taService.isProcessing,
                        gradient: brandGradient
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            Divider()

            // Publish button
            if let project {
                VStack(spacing: 6) {
                    if let err = publishError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        Task { await publishProject() }
                    } label: {
                        HStack {
                            if isPublishing {
                                ProgressView().scaleEffect(0.7)
                            }
                            Text(isPublishing ? "发布中…" : (project.isPublished == true ? "更新发布" : "发布项目"))
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 9)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isPublishing
                                  ? AnyShapeStyle(Color.secondary.opacity(0.3))
                                  : AnyShapeStyle(brandGradient))
                    )
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .disabled(isPublishing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Content panel

    @ViewBuilder
    var contentPanel: some View {
        let isLocked = taService.isProcessing
        switch selectedTab {
        case .agents:
            AgentsPanelMacOS(projectId: projectId, isLocked: isLocked, refreshTrigger: taService.agentRefreshTrigger)
                .environment(appState)
        case .issues:
            IssuesPanelMacOS(projectId: projectId, isLocked: isLocked, refreshTrigger: taService.issueboardRefreshTrigger)
                .environment(appState)
        case .gitlab:
            GitLabPanelMacOS(
                projectId: projectId,
                isLocked: isLocked,
                gitlabActionType: taService.gitlabActionType,
                gitlabActionFilePath: taService.gitlabActionFilePath
            )
            .environment(appState)
        }
    }

    func handleTAAction(_ action: String) {
        // Only force-switch panels when the TA explicitly sets its mode.
        // Individual action messages (issueboard_*, gitlab_*, agent_*) update data
        // but do not drive tab navigation — matching web version behaviour.
        guard action == "mode_ta_set_mode" else { return }
        withAnimation {
            switch taService.lastActionMode {
            case "issueboard": selectedTab = .issues
            case "gitlab":     selectedTab = .gitlab
            case "agent":      selectedTab = .agents
            default: break
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    func projectMonogram(title: String, size: CGFloat) -> some View {
        ProjectMonogramView(title: title, size: size)
    }

    // MARK: - Actions

    func loadProject() async {
        isLoading = true
        error = nil
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            project = try await api.getProject(projectId: projectId)
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func publishProject() async {
        guard let project else { return }
        isPublishing = true
        publishError = nil
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            try await api.publishProject(
                projectId: project.projectId,
                userId: appState.userId,
                userName: appState.username,
                userEmail: appState.email
            )
            self.project = Project(
                projectId: project.projectId,
                title: project.title,
                description: project.description,
                isPublished: true
            )
        } catch let err as APIError {
            publishError = err.message
        } catch {
            publishError = error.localizedDescription
        }
        isPublishing = false
    }
}

// MARK: - Sidebar tab row

private struct SidebarEditTabRow: View {
    let tab: EditTab
    let isSelected: Bool
    var isDisabled: Bool = false
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .frame(width: 20, alignment: .center)
                Text(tab.label)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected
                          ? AnyShapeStyle(gradient.opacity(0.15))
                          : AnyShapeStyle(Color.clear))
            )
            .foregroundStyle(
                isDisabled && !isSelected
                    ? AnyShapeStyle(Color.primary.opacity(0.3))
                    : isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(Color.primary.opacity(0.75))
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
