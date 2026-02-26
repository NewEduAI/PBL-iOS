//
//  ProjectViewMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI

// MARK: - Tab definition

enum ProjectTab: String, CaseIterable {
    case chat, issues, git

    var icon: String {
        switch self {
        case .chat:   return "bubble.left.and.bubble.right"
        case .issues: return "checklist"
        case .git:    return "externaldrive.badge.timemachine"
        }
    }

    var label: String {
        switch self {
        case .chat:   return "聊天"
        case .issues: return "任务板"
        case .git:    return "代码库"
        }
    }
}

// MARK: - Main view

struct ProjectViewMacOS: View {
    /// Format: "projectId|groupId" (groupId may be empty for teachers)
    let windowKey: String

    @Environment(AppState.self) private var appState

    // Parsed IDs
    var projectId: String { windowKey.components(separatedBy: "|").first ?? windowKey }
    var groupId: String {
        let parts = windowKey.components(separatedBy: "|")
        return parts.count > 1 ? parts[1] : ""
    }

    // Data
    @State private var project: Project? = nil
    @State private var issues: [Issue] = []
    @State private var members: [GroupMember] = []
    @State private var userRole: GroupMember? = nil
    @State private var activationStatus: [String: Bool] = [:]
    /// Maps userId → online status string (e.g. "online", "offline")
    @State private var memberOnlineStatus: [String: String] = [:]
    @State private var isLoading = true
    @State private var error: String? = nil

    // UI
    @State private var selectedTab: ProjectTab = .chat
    @State private var needsRoleSelection = false
    @State private var sidebarVisible = true
    @State private var isMarkingDone = false

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

    /// Deepest undone leaf issue — recurses into children first.
    /// A parent only surfaces as current when all its children are done.
    var currentIssue: Issue? { findLeafCurrentIssue(issues) }

    func findLeafCurrentIssue(_ list: [Issue]) -> Issue? {
        for issue in list {
            guard !issue.isDone else { continue }
            if let children = issue.children, !children.isEmpty,
               let leaf = findLeafCurrentIssue(children) {
                return leaf
            }
            return issue
        }
        return nil
    }

    var body: some View {
        Group {
            if needsRoleSelection {
                RoleSelectionMacOS(groupId: groupId) {
                    needsRoleSelection = false
                    Task { await loadAll() }
                }
                .environment(appState)
            } else {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        if sidebarVisible {
                            sidebar
                                .frame(width: 260)
                                .background(Color(NSColor.controlBackgroundColor))
                                .transition(.move(edge: .leading))

                            Divider()
                        }

                        contentPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Sidebar toggle — anchored to the window's top-left corner
                    if !sidebarVisible {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { sidebarVisible = true }
                        } label: {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 44)
                        .padding(.leading, 10)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: sidebarVisible)
            }
        }
        .ignoresSafeArea()
        .task { await loadAll() }
    }

    // MARK: - Sidebar

    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MAIC-PBL branding + collapse button
            HStack {
                Text("MAIC-PBL")
                    .font(.system(size: 13, weight: .bold))
                    .italic()
                    .foregroundStyle(brandGradient)
//                Spacer()
//                Button {
//                    withAnimation(.easeInOut(duration: 0.2)) { sidebarVisible = false }
//                } label: {
//                    Image(systemName: "sidebar.left")
//                        .font(.system(size: 13))
//                        .foregroundStyle(.secondary)
//                }
//                .buttonStyle(.plain)
//                .help("隐藏侧边栏")
            }
            .padding(.horizontal, 16)
            .padding(.top, 40)
            .padding(.bottom, 4)

            Divider()

            // Project header
            if let project = project {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        projectMonogram(title: project.title, size: 48)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.title)
                                .font(.headline)
                                .lineLimit(2)
//                            if project.isPublished == true {
//                                Label("已发布", systemImage: "checkmark.circle.fill")
//                                    .font(.caption.bold())
//                                    .foregroundStyle(.green)
//                            } else {
//                                Label("草稿", systemImage: "pencil.circle")
//                                    .font(.caption.bold())
//                                    .foregroundStyle(.orange)
//                            }
                            
                            Text(project.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("加载中…").font(.callout).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }

            sidebarDivider(label: "当前任务")

            // Current issue card
            if let issue = currentIssue {
                currentIssueCard(issue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else if !isLoading && !groupId.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("所有任务已完成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            sidebarDivider(label: "功能")

            // Tab navigation
            VStack(spacing: 2) {
                ForEach(ProjectTab.allCases, id: \.self) { tab in
                    SidebarTabRow(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.vertical, 4)

            Spacer()

            // User's role badge
            if let role = userRole {
                sidebarDivider(label: "我的角色")
                HStack(spacing: 8) {
                    Circle()
                        .fill(roleAccentColor(role.actorDescription))
                        .frame(width: 8, height: 8)
                    Text(role.actorDescription)
                        .font(.callout.bold())
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Members section (exclude the current user's role)
            let teammates = members.filter { $0.actorId != userRole?.actorId }
            if !teammates.isEmpty {
                sidebarDivider(label: "队友 (\(teammates.count))")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(teammates) { member in
                            memberAvatar(member)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Content panel

    @ViewBuilder
    var contentPanel: some View {
        if isLoading && project == nil {
            ProgressView("加载中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = error {
            ContentUnavailableView(
                "无法加载项目",
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else {
            switch selectedTab {
            case .chat:
                ChatPanelMacOS(
                    groupId: groupId,
                    projectId: projectId,
                    members: members,
                    currentActorId: userRole?.actorId
                )
                .environment(appState)
            case .issues:
                IssueBoardMacOS(groupId: groupId, initialIssues: issues, activationStatus: activationStatus) {
                    Task { await loadIssues() }
                }
                .environment(appState)
            case .git:
                GitPanelMacOS(projectId: projectId, groupId: groupId)
                    .environment(appState)
            }
        }
    }

    // MARK: - Sidebar sub-views

    @ViewBuilder
    func sidebarDivider(label: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    func currentIssueCard(_ issue: Issue) -> some View {
        let canMark = issue.personInCharge == appState.username
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    guard canMark else { return }
                    Task { await markIssueDone(issue) }
                } label: {
                    if isMarkingDone {
                        ProgressView().controlSize(.mini).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundStyle(canMark ? Color.orange : Color.orange.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canMark || isMarkingDone)
                .help(canMark ? "标记为完成" : "只有负责人可以标记完成")

                Text(issue.title)
                    .font(.callout.bold())
                    .lineLimit(2)
            }
            if let desc = issue.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let person = issue.personInCharge, !person.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(person)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    func projectMonogram(title: String, size: CGFloat) -> some View {
        let palette: [Color] = [.blue, .purple, .orange, .indigo, .teal, .pink, .red, .cyan]
        let color = palette[abs(title.hashValue) % palette.count]
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(color)
                .frame(width: size, height: size)
            Text(String(title.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    func memberAvatar(_ member: GroupMember) -> some View {
        let color = roleAccentColor(member.actorDescription)
        let status = memberOnlineStatus[member.userId ?? ""] ?? "offline"
        let isOnline = status == "online"
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
            Text(String(member.actorName.prefix(1)))
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
            Circle()
                .fill(isOnline ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color(NSColor.controlBackgroundColor), lineWidth: 1.5))
        }
        .help("\(member.actorName) · \(member.actorDescription) · \(isOnline ? "在线" : "离线")")
    }
    
    @ViewBuilder
    func userAvatar(_ userRole: GroupMember) -> some View {
        let color = roleAccentColor(userRole.actorDescription)
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
            Text(String(appState.username.prefix(1)))
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
        .help("\(appState.username) · \(userRole.actorDescription)")
    }

    func roleAccentColor(_ roleDescription: String) -> Color {
        if roleDescription.contains("开发") || roleDescription.contains("编程") { return .blue }
        if roleDescription.contains("设计") { return .purple }
        if roleDescription.contains("测试") { return .green }
        if roleDescription.contains("管理") { return .orange }
        let palette: [Color] = [.blue, .purple, .teal, .indigo]
        return palette[abs(roleDescription.hashValue) % palette.count]
    }

    // MARK: - Data loading

    func loadAll() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)

        do {
            project = try await api.getProject(projectId: projectId)
        } catch let err as APIError {
            error = err.message
            return
        } catch {
            self.error = error.localizedDescription
            return
        }

        guard !groupId.isEmpty else { return }

        // Check if user has selected a role (applies to both students and teachers testing a project)
        if let actor = try? await api.getCorrespondingActor(userId: appState.userId, projectId: projectId) {
            userRole = actor
        } else {
            needsRoleSelection = true
            return
        }

        // Load issues, members, and online statuses in parallel
        async let issuesLoad: Void = loadIssues()
        async let membersLoad: Void = {
            do {
                members = try await api.getGroupMembers(groupId: groupId)
            } catch {}
        }()
        async let statusLoad: Void = loadOnlineStatuses()
        _ = await (issuesLoad, membersLoad, statusLoad)
    }

    func loadOnlineStatuses() async {
        guard !groupId.isEmpty else { return }
        let chatAPI = ChatAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        guard let sessions = try? await chatAPI.getSessions(groupId: groupId, userId: appState.userId) else { return }
        var map: [String: String] = [:]
        for session in sessions {
            for member in session.members ?? [] {
                map[member.id] = member.status ?? "offline"
            }
        }
        memberOnlineStatus = map
    }

    func loadIssues() async {
        guard !groupId.isEmpty else { return }
        let issueAPI = IssueAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            issues = try await issueAPI.getIssues(groupId: groupId, userId: appState.userId)
            if let boardId = issues.first?.issueBoardId {
                activationStatus = (try? await issueAPI.getActivationStatus(issueBoardId: boardId)) ?? [:]
            }
        } catch {}
    }

    func markIssueDone(_ issue: Issue) async {
        guard issue.personInCharge == appState.username else { return }
        isMarkingDone = true
        let issueAPI = IssueAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            try await issueAPI.updateIssue(
                issueBoardId: issue.issueBoardId,
                groupId: groupId,
                issueId: issue.issueId,
                isDone: true
            )
            await loadIssues()
        } catch {}
        isMarkingDone = false
    }
}

// MARK: - Sidebar tab row

private struct SidebarTabRow: View {
    let tab: ProjectTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(tab.label)
                    .font(.callout)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected
                          ? AnyShapeStyle(LinearGradient(
                              colors: [
                                  Color(red: 98/255, green: 83/255, blue: 225/255),
                                  Color(red: 4/255, green: 190/255, blue: 254/255)
                              ],
                              startPoint: .leading,
                              endPoint: .trailing
                          ))
                          : AnyShapeStyle(isHovered
                                         ? Color.primary.opacity(0.06)
                                         : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { isHovered = $0 }
    }
}
