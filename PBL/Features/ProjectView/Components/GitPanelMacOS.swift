//
//  GitPanelMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI

struct GitPanelMacOS: View {
    let projectId: String
    let groupId: String

    @Environment(AppState.self) private var appState

    @State private var cloneUrls: [String] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var copiedUrl: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("代码库")
                    .font(.title3.bold())
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
                Button { Task { await loadUrls() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
                .help("刷新")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            content
        }
        .task { await loadUrls() }
    }

    @ViewBuilder
    var content: some View {
        if isLoading {
            ProgressView("获取仓库信息…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = error {
            ContentUnavailableView(
                "无法获取代码库",
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else if cloneUrls.isEmpty {
            ContentUnavailableView(
                "尚未配置代码库",
                systemImage: "externaldrive.badge.questionmark",
                description: Text("此项目还没有关联 GitLab 仓库")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header icon
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 252/255, green: 109/255, blue: 38/255),
                                            Color(red: 226/255, green: 67/255, blue: 41/255)
                                        ],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: 56, height: 56)
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("GitLab 仓库")
                            .font(.title2.bold())
                        Text("使用以下命令克隆项目代码到本地")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    // Clone URL rows
                    VStack(spacing: 10) {
                        ForEach(cloneUrls, id: \.self) { url in
                            CloneUrlRow(url: url, isCopied: copiedUrl == url) {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString("git clone " + url, forType: .string)
                                copiedUrl = url
                                Task {
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    if copiedUrl == url { copiedUrl = nil }
                                }
                            }
                        }
                    }
                }
                .padding(32)
            }
        }
    }

    func loadUrls() async {
        guard !groupId.isEmpty else { return }
        isLoading = true
        error = nil
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            cloneUrls = try await api.getBashCloneUrls(groupId: groupId, userId: appState.userId)
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Clone URL row

private struct CloneUrlRow: View {
    let url: String
    let isCopied: Bool
    let onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text("git clone " + url)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onCopy) {
                Label(isCopied ? "已复制" : "复制", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption.bold())
                    .foregroundStyle(isCopied ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .animation(.easeInOut(duration: 0.2), value: isCopied)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(isHovered ? 0.05 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}
