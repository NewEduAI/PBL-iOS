//
//  GitLabPanelMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/26.
//

import SwiftUI

struct GitLabPanelMacOS: View {
    let projectId: String
    var isLocked: Bool = false
    var gitlabActionType: String = ""
    var gitlabActionFilePath: String? = nil

    @Environment(AppState.self) private var appState

    @State private var repositories: [GitLabRepository] = []
    @State private var selectedRepo: GitLabRepository? = nil
    @State private var fileTree: [GitLabTreeItem] = []
    @State private var selectedFile: GitLabTreeItem? = nil
    @State private var fileContent = ""
    @State private var originalContent = ""

    @State private var isLoadingRepos = false
    @State private var isLoadingTree = false
    @State private var isLoadingFile = false
    @State private var isSaving = false

    @State private var repoError: String? = nil
    @State private var fileError: String? = nil
    @State private var saveError: String? = nil
    @State private var saveSuccess = false

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

    var hasChanges: Bool { fileContent != originalContent }

    var body: some View {
        HSplitView {
            // Left: repo + file tree
            leftPanel
                .frame(minWidth: 220, maxWidth: 300)

            // Right: file editor
            rightPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await loadRepositories() }
        .onChange(of: gitlabActionType) { _, type in
            guard !type.isEmpty else { return }
            Task { await handleGitLabAction(type) }
        }
        .disabled(isLocked)
    }

    // MARK: - Left panel

    var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Repo picker header
            HStack {
                Text("课程材料")
                    .font(.callout.bold())
                Spacer()
                if isLoadingTree {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if isLoadingRepos {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            } else if let error = repoError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            } else if repositories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.questionmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("暂无关联代码库")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                // Repo selector
                Picker("代码库", selection: $selectedRepo) {
                    Text("选择代码库").tag(Optional<GitLabRepository>.none)
                    ForEach(repositories) { repo in
                        Text(repoName(from: repo.url))
                            .tag(Optional(repo))
                    }
                }
                .labelsHidden()
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .onChange(of: selectedRepo) { _, repo in
                    guard let repo else { return }
                    Task { await loadFileTree(repo: repo) }
                }

                Divider()

                // File tree
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(fileTree) { item in
                            FileTreeRow(
                                item: item,
                                isSelected: selectedFile?.id == item.id
                            ) {
                                if item.type == "blob" {
                                    selectedFile = item
                                    Task { await loadFile(item) }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Right panel

    @ViewBuilder
    var rightPanel: some View {
        if selectedFile == nil {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("从左侧选择文件查看内容")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // File header
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(selectedFile?.name ?? "")
                        .font(.callout.bold())
                    Spacer()
                    if isLoadingFile {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Editor
                if isLoadingFile {
                    ProgressView("加载文件…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: $fileContent)
                        .font(.system(.callout, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(12)
                }

                // Save bar
                if hasChanges || saveError != nil || saveSuccess {
                    Divider()
                    HStack(spacing: 10) {
                        if let err = saveError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                        if saveSuccess {
                            Label("已保存", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        Button("还原") {
                            fileContent = originalContent
                            saveError = nil
                            saveSuccess = false
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await saveFile() }
                        } label: {
                            Text(isSaving ? "保存中…" : "保存")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 9)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSaving
                                      ? AnyShapeStyle(Color.secondary.opacity(0.3))
                                      : AnyShapeStyle(brandGradient))
                        )
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                        .disabled(isSaving || !hasChanges)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
    }

    // MARK: - Actions

    func loadRepositories() async {
        isLoadingRepos = true
        repoError = nil
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            repositories = try await api.getGitLabRepositories(projectId: projectId)
            if let first = repositories.first {
                selectedRepo = first
                await loadFileTree(repo: first)
            }
        } catch let err as APIError {
            repoError = err.message
        } catch {
            repoError = error.localizedDescription
        }
        isLoadingRepos = false
    }

    func loadFileTree(repo: GitLabRepository) async {
        isLoadingTree = true
        fileTree = []
        selectedFile = nil
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            fileTree = try await api.getFileTree(projectId: projectId, url: repo.url)
        } catch { }
        isLoadingTree = false
    }

    func loadFile(_ item: GitLabTreeItem) async {
        guard let repo = selectedRepo else { return }
        isLoadingFile = true
        fileError = nil
        saveError = nil
        saveSuccess = false
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            let content = try await api.getFile(projectId: projectId, url: repo.url, filePath: item.path)
            fileContent = content.contentDecoded
            originalContent = content.contentDecoded
        } catch let err as APIError {
            fileError = err.message
        } catch {
            fileError = error.localizedDescription
        }
        isLoadingFile = false
    }

    func saveFile() async {
        guard let repo = selectedRepo, let file = selectedFile else { return }
        isSaving = true
        saveError = nil
        saveSuccess = false
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            try await api.updateFile(
                projectId: projectId,
                url: repo.url,
                filePath: file.path,
                content: fileContent,
                commitMessage: "Update \(file.name)"
            )
            originalContent = fileContent
            saveSuccess = true
        } catch let err as APIError {
            saveError = err.message
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    func handleGitLabAction(_ actionType: String) async {
        switch actionType {
        case "gitlab_ta_add_repository", "gitlab_ta_remove_repository", "gitlab_ta_update_repository_url":
            await loadRepositories()

        case "gitlab_ta_create_or_update_file":
            guard let repo = selectedRepo else { return }
            await loadFileTree(repo: repo)
            if let path = gitlabActionFilePath,
               let item = fileTree.first(where: { $0.path == path }) {
                selectedFile = item
                await loadFile(item)
            }

        case "gitlab_ta_delete_file":
            guard let repo = selectedRepo else { return }
            if selectedFile?.path == gitlabActionFilePath {
                selectedFile = nil
                fileContent = ""
                originalContent = ""
            }
            await loadFileTree(repo: repo)

        default:
            if let repo = selectedRepo {
                await loadFileTree(repo: repo)
            }
        }
    }

    func repoName(from url: String) -> String {
        url.components(separatedBy: "/").last?.replacingOccurrences(of: ".git", with: "") ?? url
    }
}

// MARK: - File tree row

private struct FileTreeRow: View {
    let item: GitLabTreeItem
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var icon: String {
        item.type == "tree" ? "folder" : "doc.text"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(item.type == "tree" ? .orange : .secondary)
                .frame(width: 16)
            Text(item.name)
                .font(.callout)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.12)
                      : isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .padding(.horizontal, 6)
    }
}
