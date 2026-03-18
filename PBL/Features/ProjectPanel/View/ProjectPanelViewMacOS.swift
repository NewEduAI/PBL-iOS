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
    @State private var showAccessTokens = false

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
                    openWindow(id: "project-edit", value: projectId)
                }
            }
            .environment(appState)
        }
        .sheet(isPresented: $showAccessTokens) {
            AccessTokenSheet()
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
                BrandingText(fontSize: 18)

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

//                SidebarActionRow(icon: "ticket", label: "加入课程码") {
//                    showJoinByCode = true
//                }
                SidebarActionRow(icon: "globe", label: "加入开放项目") {
                    showJoinOpen = true
                }
                SidebarActionRow(icon: "key", label: "添加到其他 AI 应用") {
                    showAccessTokens = true
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
                                    openWindow(id: "project-edit", value: project.projectId)
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
                teacherProjects = try await api.getProjectsAsTeacher()
            } else {
                async let assignmentsTask = api.getStudentAssignments()
                async let projectsTask = api.getAllCollaborativeProjects()
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

    var body: some View {
        HStack(spacing: 14) {
            // Colored monogram icon
            ProjectMonogramView(title: title, size: 44)

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
                userEmail: appState.email
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
                userEmail: appState.email
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
                userEmail: appState.email
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

// MARK: - Project icon (hash-generated, shared)

/// Generates a unique symmetric pattern icon from the project title, similar to GitHub identicons.
/// Uses a 5×5 grid mirrored horizontally (only 15 bits needed) for a pleasing symmetric look.
struct ProjectMonogramView: View {
    let title: String
    let size: CGFloat

    private static let gradientPairs: [(Color, Color)] = [
        (Color(red: 98/255, green: 83/255, blue: 225/255), Color(red: 4/255, green: 190/255, blue: 254/255)),
        (Color(red: 255/255, green: 111/255, blue: 97/255), Color(red: 255/255, green: 175/255, blue: 64/255)),
        (Color(red: 0/255, green: 198/255, blue: 168/255), Color(red: 48/255, green: 108/255, blue: 224/255)),
        (Color(red: 168/255, green: 85/255, blue: 247/255), Color(red: 246/255, green: 97/255, blue: 168/255)),
        (Color(red: 59/255, green: 130/255, blue: 246/255), Color(red: 16/255, green: 185/255, blue: 129/255)),
        (Color(red: 236/255, green: 72/255, blue: 153/255), Color(red: 239/255, green: 134/255, blue: 67/255)),
        (Color(red: 34/255, green: 197/255, blue: 94/255), Color(red: 6/255, green: 182/255, blue: 212/255)),
        (Color(red: 99/255, green: 102/255, blue: 241/255), Color(red: 168/255, green: 85/255, blue: 247/255)),
    ]

    /// Deterministic hash (djb2) — stable across app launches.
    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for char in string.unicodeScalars {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(char.value)
        }
        return hash
    }

    private var hashValue_: UInt64 { Self.stableHash(title) }

    private var gradient: LinearGradient {
        let idx = Int(hashValue_ % UInt64(Self.gradientPairs.count))
        let pair = Self.gradientPairs[idx]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 5×5 symmetric grid: only the left 3 columns are hashed, right 2 mirror left 2.
    private var grid: [[Bool]] {
        let bits = hashValue_ >> 3 // shift past the color bits
        var result = [[Bool]]()
        for row in 0..<5 {
            var line = [Bool]()
            for col in 0..<3 {
                let bitIndex = row * 3 + col
                line.append((bits >> bitIndex) & 1 == 1)
            }
            // Mirror: col 3 = col 1, col 4 = col 0
            line.append(line[1])
            line.append(line[0])
            result.append(line)
        }
        return result
    }

    var body: some View {
        Canvas { context, canvasSize in
            let corner = size * 0.22
            let path = RoundedRectangle(cornerRadius: corner).path(in: CGRect(origin: .zero, size: canvasSize))
            context.clip(to: path)

            // Background
            context.fill(path, with: .linearGradient(
                Gradient(colors: [Self.gradientPairs[Int(hashValue_ % UInt64(Self.gradientPairs.count))].0.opacity(0.25),
                                  Self.gradientPairs[Int(hashValue_ % UInt64(Self.gradientPairs.count))].1.opacity(0.25)]),
                startPoint: .zero,
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
            ))

            // Pattern cells
            let padding = size * 0.15
            let cellSize = (size - padding * 2) / 5
            let g = grid
            for row in 0..<5 {
                for col in 0..<5 {
                    if g[row][col] {
                        let rect = CGRect(
                            x: padding + CGFloat(col) * cellSize,
                            y: padding + CGFloat(row) * cellSize,
                            width: cellSize * 0.88,
                            height: cellSize * 0.88
                        )
                        let cellPath = RoundedRectangle(cornerRadius: cellSize * 0.2).path(in: rect)
                        context.fill(cellPath, with: .linearGradient(
                            Gradient(colors: [Self.gradientPairs[Int(hashValue_ % UInt64(Self.gradientPairs.count))].0,
                                              Self.gradientPairs[Int(hashValue_ % UInt64(Self.gradientPairs.count))].1]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                        ))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}

// MARK: - Branding text (shared)

struct BrandingText: View {
    var fontSize: CGFloat = 18

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

    private var flameGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 255/255, green: 200/255, blue: 55/255),
                Color(red: 255/255, green: 100/255, blue: 50/255),
                Color(red: 220/255, green: 40/255, blue: 40/255)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("OpenMAIC")
                .foregroundStyle(brandGradient)
            Text(" × ")
                .foregroundStyle(.secondary.opacity(0.6))
            Text("Pro")
                .foregroundStyle(flameGradient)
        }
        .font(.system(size: fontSize, weight: .bold))
        .italic()
    }
}

// MARK: - Access Token Management

private struct AccessTokenSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var tokens: [AccessToken] = []
    @State private var isLoading = true
    @State private var newTokenName = ""
    @State private var isCreating = false
    @State private var createdToken: String? = nil
    @State private var copied = false
    @State private var revokeTarget: AccessToken? = nil
    @State private var error: String? = nil

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 98/255, green: 83/255, blue: 225/255),
                Color(red: 4/255, green: 190/255, blue: 254/255)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("添加到其他 AI 应用")
                        .font(.title2.bold())
                    Text("创建访问令牌，让 OpenClaw 等 AI 应用访问你的项目数据。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            // Created token banner (shown once after creation)
            if let token = createdToken {
                VStack(alignment: .leading, spacing: 8) {
                    Label("令牌已创建 — 请立即复制，关闭后无法再次查看", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    HStack {
                        Text(token)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(token, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.callout)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.06))

                Divider()
            }

            // Token list
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tokens.isEmpty && createdToken == nil {
                VStack(spacing: 8) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("暂无访问令牌")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(tokens) { token in
                            HStack(spacing: 12) {
                                Image(systemName: token.isActive ? "key.fill" : "key")
                                    .foregroundStyle(token.isActive ? .green : .secondary)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(token.name)
                                        .font(.callout.bold())
                                    Text(token.createdAt.prefix(10))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if token.isActive {
                                    Button {
                                        revokeTarget = token
                                    } label: {
                                        Text("撤销")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                } else {
                                    Text("已撤销")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Divider()

            // Create new token
            HStack(spacing: 10) {
                TextField("令牌名称（如 OpenClaw）", text: $newTokenName)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .onSubmit { Task { await createToken() } }

                Button {
                    Task { await createToken() }
                } label: {
                    Text(isCreating ? "创建中…" : "创建令牌")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(newTokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating
                              ? AnyShapeStyle(Color.secondary.opacity(0.3))
                              : AnyShapeStyle(brandGradient))
                )
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .disabled(newTokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
            .padding(24)
        }
        .frame(width: 560, height: 500)
        .task { await loadTokens() }
        .alert("撤销令牌", isPresented: Binding(
            get: { revokeTarget != nil },
            set: { if !$0 { revokeTarget = nil } }
        )) {
            Button("取消", role: .cancel) { revokeTarget = nil }
            Button("撤销", role: .destructive) {
                if let t = revokeTarget {
                    Task { await revokeToken(t) }
                }
            }
        } message: {
            Text("撤销后，使用此令牌的应用将立即失去访问权限。")
        }
    }

    func loadTokens() async {
        isLoading = true
        error = nil
        let api = UserAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            tokens = try await api.listAccessTokens()
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createToken() async {
        let name = newTokenName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isCreating = true
        error = nil
        let api = UserAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            let result = try await api.createAccessToken(name: name)
            createdToken = result.token
            newTokenName = ""
            await loadTokens()
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }

    func revokeToken(_ token: AccessToken) async {
        error = nil
        let api = UserAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            try await api.revokeAccessToken(tokenId: token.id)
            revokeTarget = nil
            await loadTokens()
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
    }
}
