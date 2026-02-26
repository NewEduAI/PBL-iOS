//
//  ProjectPanelViewMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI

// MARK: - Main view

struct ProjectPanelViewMacOS: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    // Student data
    @State private var activeAssignments: [StudentAssignment] = []
    @State private var availableProjects: [Project] = []

    // Teacher data
    @State private var teacherProjects: [Project] = []

    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedId: String? = nil

    // Sheet state
    @State private var showJoinByCode = false
    @State private var showJoinOpen = false
    @State private var showCreateProject = false
    @State private var pendingJoinProject: Project? = nil

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

    /// Project IDs the student is already enrolled in.
    private var activeProjectIdSet: Set<String> {
        Set(activeAssignments.map(\.projectId))
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarPanel
            Divider()
            mainPanel
        }
        .task { await loadData() }
        .sheet(isPresented: $showJoinByCode) {
            Text("通过课程码加入").padding(40)
        }
        .sheet(isPresented: $showJoinOpen) {
            JoinOpenProjectSheet(
                projects: availableProjects,
                activeProjectIds: activeProjectIdSet,
                isLoading: isLoading
            ) { project, groupId in
                showJoinOpen = false
                Task {
                    await loadData()
                    openWindow(id: "project-view", value: "\(project.projectId)|\(groupId)")
                }
            }
            .environment(appState)
        }
        .sheet(isPresented: $showCreateProject) {
            CreateProjectSheet { projectId in
                showCreateProject = false
                Task {
                    await loadData()
                    openWindow(id: "project-view", value: projectId)
                }
            }
            .environment(appState)
        }
        .sheet(item: $pendingJoinProject) { project in
            JoinProjectSheet(project: project) { groupId in
                pendingJoinProject = nil
                Task {
                    await loadData()
                    openWindow(id: "project-view", value: "\(project.projectId)|\(groupId)")
                }
            }
            .environment(appState)
        }
    }

    // MARK: - Sidebar

    var sidebarPanel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Branding + user greeting
            VStack(alignment: .leading, spacing: 6) {
                Text("MAIC-PBL")
                    .font(.system(size: 18, weight: .bold))
                    .italic()
                    .foregroundStyle(brandGradient)

                Text(appState.username)
                    .font(.callout.bold())
                    .lineLimit(1)

                Text(appState.organization)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Actions
            VStack(alignment: .leading, spacing: 2) {
                Text("操作")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                SidebarActionRow(icon: "ticket", label: "加入课程码") {
                    showJoinByCode = true
                }
                SidebarActionRow(icon: "globe", label: "加入开放项目") {
                    showJoinOpen = true
                }
                if appState.isTeacher {
                    SidebarActionRow(icon: "plus.circle", label: "创建项目") {
                        showCreateProject = true
                    }
                }
            }

            Spacer()

            Divider()

            // Bottom user row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(brandGradient)
                        .frame(width: 28, height: 28)
                    Text(String(appState.username.prefix(1)))
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(appState.username)
                        .font(.callout.bold())
                        .lineLimit(1)
                    Text(appState.isTeacher ? "教师" : "学生")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appState.logout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("退出登录")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Main panel

    var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text(appState.isTeacher ? "我的项目" : "项目")
                    .font(.title3.bold())

                Spacer()

                if isLoading {
                    ProgressView().controlSize(.small)
                }

                Button {
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
                .help("刷新")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            if let error = errorMessage {
                errorStateView(error)
            } else if appState.isTeacher {
                teacherProjectList
            } else {
                studentProjectList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Student list

    var studentProjectList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                if !activeAssignments.isEmpty {
                    Section {
                        ForEach(activeAssignments) { assignment in
                            ProjectRowView(
                                id: assignment.id,
                                title: assignment.title,
                                description: assignment.description,
                                date: String(assignment.time.prefix(10)),
                                status: .active,
                                selectedId: $selectedId,
                                onDoubleClick: {
                                    let key = "\(assignment.projectId)|\(assignment.groupId ?? "")"
                                    openWindow(id: "project-view", value: key)
                                },
                                onAbandon: {
                                    Task { await handleAbandon(projectId: assignment.projectId) }
                                }
                            )
                        }
                    } header: {
                        sectionHeader("进行中")
                    }
                }

                if activeAssignments.isEmpty && !isLoading {
                    emptyStateView
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Teacher list

    var teacherProjectList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                if !teacherProjects.isEmpty {
                    Section {
                        ForEach(teacherProjects) { project in
                            ProjectRowView(
                                id: project.id,
                                title: project.title,
                                description: project.description,
                                date: nil,
                                status: project.isPublished == true ? .published : .draft,
                                selectedId: $selectedId,
                                onDoubleClick: {
                                    openWindow(id: "project-view", value: project.projectId)
                                }
                            )
                        }
                    } header: {
                        sectionHeader("我的项目")
                    }
                } else if !isLoading {
                    emptyStateView
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helpers

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.top, 20)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.windowBackground)
    }

    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(appState.isTeacher ? "还没有项目，点击左侧「创建项目」开始" : "还没有项目")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    func errorStateView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") { Task { await loadData() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Data loading

    func loadData() async {
        guard !appState.userId.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)

        do {
            if appState.isTeacher {
                teacherProjects = try await api.getProjectsAsTeacher(userId: appState.userId)
            } else {
                async let assignmentsTask = api.getStudentAssignments(userId: appState.userId)
                async let projectsTask = api.getAllCollaborativeProjects(userId: appState.userId)
                (activeAssignments, availableProjects) = try await (assignmentsTask, projectsTask)
            }
        } catch let err as APIError {
            errorMessage = err.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleAbandon(projectId: String) async {
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            try await api.withdrawGroup(projectId: projectId, userId: appState.userId)
            await loadData()
        } catch let err as APIError {
            errorMessage = err.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Sidebar action row

private struct SidebarActionRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Project row status

private enum ProjectRowStatus {
    case active, available, draft, published

    var label: String {
        switch self {
        case .active: return "进行中"
        case .available: return "可加入"
        case .published: return "已发布"
        case .draft: return "草稿"
        }
    }

    var color: Color {
        switch self {
        case .active: return .blue
        case .available: return .green
        case .published: return .green
        case .draft: return .orange
        }
    }
}

// MARK: - Project row view

private struct ProjectRowView: View {
    let id: String
    let title: String
    let description: String
    let date: String?
    let status: ProjectRowStatus
    @Binding var selectedId: String?
    let onDoubleClick: () -> Void
    var onAbandon: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var showAbandonAlert = false

    var isSelected: Bool { selectedId == id }

    private static let iconPalette: [Color] = [.blue, .purple, .orange, .indigo, .teal, .pink, .red, .cyan]

    var iconColor: Color {
        Self.iconPalette[abs(title.hashValue) % Self.iconPalette.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            // Colored monogram icon
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconColor)
                    .frame(width: 44, height: 44)
                Text(String(title.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Title + description
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.bold())
                    .lineLimit(1)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status badge + date + optional abandon button
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(status.label)
                        .font(.caption2.bold())
                        .foregroundStyle(status.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(status.color.opacity(0.1))
                        .clipShape(Capsule())

                    if let date = date {
                        Text(date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }

                // Abandon button — only for student assignments, visible on hover
                if let abandon = onAbandon {
                    Button {
                        showAbandonAlert = true
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1 : 0)
                    .help("放弃进度")
                    .alert("放弃项目进度？", isPresented: $showAbandonAlert) {
                        Button("取消", role: .cancel) {}
                        Button("放弃进度", role: .destructive) { abandon() }
                    } message: {
                        Text("这将清除你在「\(title)」中的所有进度，无法撤销。")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleClick() }
        .onTapGesture(count: 1) { selectedId = id }
        .onHover { isHovered = $0 }
    }

    var rowBackground: Color {
        if isSelected { return .accentColor.opacity(0.1) }
        if isHovered { return Color.primary.opacity(0.04) }
        return .clear
    }
}

// MARK: - Join project sheet

private struct JoinProjectSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let onJoined: (String) -> Void

    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("加入项目")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text(project.title)
                    .font(.headline)
                Text(project.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let err = error {
                Text(err).font(.callout).foregroundStyle(.red)
            }

            HStack {
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                Button(isLoading ? "加入中..." : "加入项目") {
                    Task { await handleJoin() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
        }
        .padding(28)
        .frame(width: 400)
    }

    func handleJoin() async {
        isLoading = true
        error = nil
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            let groupId = try await api.joinProject(
                userId: appState.userId,
                projectId: project.projectId,
                userName: appState.username,
                userEmail: ""
            )
            onJoined(groupId)
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Create project sheet (teacher)

private struct CreateProjectSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onCreated: (String) -> Void

    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("创建项目")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("项目名称").font(.callout.bold())
                TextField("输入项目名称", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("项目描述").font(.callout.bold())
                TextEditor(text: $projectDescription)
                    .font(.callout)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 209/255, green: 213/255, blue: 219/255), lineWidth: 1)
                    )
            }

            if let err = error {
                Text(err).font(.callout).foregroundStyle(.red)
            }

            HStack {
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                Button(isLoading ? "创建中..." : "创建项目") {
                    Task { await handleCreate() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || projectName.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 440)
    }

    func handleCreate() async {
        isLoading = true
        error = nil
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            let projectId = try await api.createCollaborativeProject(
                projectName: projectName,
                description: projectDescription,
                userId: appState.userId,
                userName: appState.username,
                userEmail: ""
            )
            onCreated(projectId)
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Join open project sheet (browse all available projects)

private struct JoinOpenProjectSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let projects: [Project]
    let activeProjectIds: Set<String>
    let isLoading: Bool
    let onJoined: (Project, String) -> Void

    @State private var joiningId: String? = nil
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("加入开放项目")
                    .font(.title2.bold())
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(24)

            Divider()

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if projects.isEmpty {
                ContentUnavailableView(
                    "暂无开放项目",
                    systemImage: "folder.badge.questionmark",
                    description: Text("当前没有可加入的开放项目")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if let err = error {
                            Text(err)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                        }
                        ForEach(projects) { project in
                            let alreadyJoined = activeProjectIds.contains(project.projectId)
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.title)
                                        .font(.callout.bold())
                                        .lineLimit(1)
                                    Text(project.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if alreadyJoined {
                                    Label("已加入", systemImage: "checkmark.circle.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                } else {
                                    Button(joiningId == project.id ? "加入中…" : "加入") {
                                        Task { await handleJoin(project) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(joiningId != nil)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 24)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 520, height: 480)
    }

    func handleJoin(_ project: Project) async {
        joiningId = project.id
        error = nil
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            let groupId = try await api.joinProject(
                userId: appState.userId,
                projectId: project.projectId,
                userName: appState.username,
                userEmail: ""
            )
            onJoined(project, groupId)
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        joiningId = nil
    }
}
