//
//  TAAgentPanelMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/26.
//

import SwiftUI

// MARK: - Message model

struct TAAgentMessage: Identifiable {
    let id: String
    let role: Role
    let content: String

    enum Role { case user, assistant, error }
}

// MARK: - WebSocket service

@Observable
final class TAAgentWebSocketService {
    var messages: [TAAgentMessage] = []
    var isConnected = false
    var isProcessing = false
    /// Set to the raw action_type string each time an action arrives (triggers onChange in parent).
    var lastAction: String = ""
    /// Set to the mode value when a mode_ta_set_mode action arrives.
    var lastActionMode: String = ""

    // Per-panel refresh triggers — bumped immediately when the corresponding action arrives.
    var issueboardRefreshTrigger: UUID = UUID()
    var agentRefreshTrigger: UUID = UUID()
    // GitLab action details — set together whenever a gitlab_* action arrives.
    var gitlabActionType: String = ""
    var gitlabActionFilePath: String? = nil
    /// Human-readable description of what the TA is currently doing, shown in the panel header.
    var currentActionDescription: String = ""

    private var wsTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    func connect(baseURL: String, token: String, projectId: String) {
        disconnect()

        let wsBase = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let urlString = "\(wsBase)/project/agent/ws?project_id=\(projectId)&token=\(encodedToken)"
        guard let url = URL(string: urlString) else { return }

        wsTask = URLSession.shared.webSocketTask(with: url)
        wsTask?.resume()
        isConnected = true
        startReceiving()
        startHeartbeat()
    }

    func disconnect() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        isConnected = false
        isProcessing = false
    }

    private func startHeartbeat() {
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { break }
                let ping = "{\"type\":\"ping\"}"
                self.wsTask?.send(.string(ping)) { _ in }
            }
        }
    }

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let task = self.wsTask else { break }
                do {
                    let msg = try await task.receive()
                    if case .string(let text) = msg,
                       let data = text.data(using: .utf8) {
                        self.handleIncoming(data: data)
                    }
                } catch {
                    self.isConnected = false
                    break
                }
            }
        }
    }

    private func handleIncoming(data: Data) {
        struct Envelope: Decodable {
            let type: String?
            let role: String?
            let content: String?
            let message: String?
            let actionType: String?
            let mode: String?
            let filePath: String?
            enum CodingKeys: String, CodingKey {
                case type, role, content, message, mode
                case actionType = "action_type"
                case filePath = "file_path"
            }
        }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else { return }

        // Special typed messages
        if let type_ = env.type {
            switch type_ {
            case "heartbeat", "pong", "connected":
                return
            case "error":
                messages.append(TAAgentMessage(id: UUID().uuidString, role: .error,
                                               content: env.message ?? "未知错误"))
                return
            default:
                break
            }
        }

        // Text messages: server sends { role, content } without a "type" field
        if let role = env.role, let content = env.content {
            let msgRole: TAAgentMessage.Role = role == "user" ? .user : .assistant
            messages.append(TAAgentMessage(id: UUID().uuidString, role: msgRole, content: content))
            return
        }

        // Action messages: { action_type: ... }
        if let actionType = env.actionType {
            switch actionType {
            case "teaching_assistant_state_begin":
                isProcessing = true
            case "teaching_assistant_state_end":
                isProcessing = false
                currentActionDescription = ""
            case "mode_ta_set_mode":
                lastActionMode = env.mode ?? ""
                lastAction = actionType
            default:
                // Set human-readable status and immediately signal the relevant panel to refresh.
                let issueboardDescriptions: [String: String] = [
                    "issueboard_ta_create_issueboard": "正在创建任务看板",
                    "issueboard_ta_delete_issueboard": "正在删除任务看板",
                    "issueboard_ta_update_issueboard_agents": "正在更新负责人",
                    "issueboard_ta_create_issue": "正在创建任务",
                    "issueboard_ta_update_issue": "正在更新任务",
                    "issueboard_ta_delete_issue": "正在删除任务",
                    "issueboard_ta_reorder_issues": "正在重排任务"
                ]
                let gitlabDescriptions: [String: String] = [
                    "gitlab_ta_list_repositories": "正在列出代码库",
                    "gitlab_ta_add_repository": "正在添加代码库",
                    "gitlab_ta_remove_repository": "正在移除代码库",
                    "gitlab_ta_update_repository_url": "正在更新代码库",
                    "gitlab_ta_get_file": "正在读取文件",
                    "gitlab_ta_create_or_update_file": "正在编辑文件",
                    "gitlab_ta_delete_file": "正在删除文件",
                    "gitlab_ta_fork_repository": "正在复刻代码库"
                ]
                if let desc = issueboardDescriptions[actionType] {
                    currentActionDescription = desc
                    issueboardRefreshTrigger = UUID()
                } else if let desc = gitlabDescriptions[actionType] {
                    currentActionDescription = desc
                    gitlabActionType = actionType
                    gitlabActionFilePath = env.filePath
                } else if actionType.hasPrefix("agent_") {
                    currentActionDescription = "正在更新智能体"
                    agentRefreshTrigger = UUID()
                }
                lastAction = actionType
            }
        }
    }
}

// MARK: - Panel view

struct TAAgentPanelMacOS: View {
    let projectId: String
    let service: TAAgentWebSocketService

    @Environment(AppState.self) private var appState

    @State private var inputText = ""
    @State private var isSending = false
    @State private var scrollTrigger = UUID()

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
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "cpu")
                    .foregroundStyle(brandGradient)
                VStack(alignment: .leading, spacing: 1) {
                    Text("TA 助手")
                        .font(.callout.bold())
                    Text(service.isConnected
                         ? (service.currentActionDescription.isEmpty ? "已连接" : service.currentActionDescription)
                         : "未连接")
                        .font(.caption2)
                        .foregroundStyle(service.currentActionDescription.isEmpty
                                         ? AnyShapeStyle(.secondary)
                                         : AnyShapeStyle(Color.blue))
                        .animation(.easeInOut, value: service.currentActionDescription)
                }
                Spacer()
                Circle()
                    .fill(service.isConnected ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            messageList

            Divider()

            messageInput
        }
        .onAppear {
            if !service.isConnected {
                service.connect(
                    baseURL: appState.organizationBaseUrl,
                    token: appState.token,
                    projectId: projectId
                )
            }
        }
    }

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if service.messages.isEmpty {
                        Text("与 TA 助手对话，它可以帮你管理项目内容")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.top, 40)
                    }
                    ForEach(service.messages) { msg in
                        TAMessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if service.isProcessing {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("处理中…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .id("processing")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
            }
            .onChange(of: scrollTrigger) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: service.messages.count) {
                scrollTrigger = UUID()
            }
            .onChange(of: service.isProcessing) {
                scrollTrigger = UUID()
            }
        }
    }

    var messageInput: some View {
        HStack(spacing: 10) {
            TextField("给 TA 助手发消息…", text: $inputText)
                .textFieldStyle(.plain)
                .font(.callout)
                .lineLimit(1)
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
                .onSubmit { Task { await sendMessage() } }

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      ? "arrow.up.circle" : "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
                                  ? AnyShapeStyle(Color.secondary.opacity(0.3))
                                  : AnyShapeStyle(brandGradient))
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        inputText = ""
        isSending = true

        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        try? await api.sendTAAgentMessage(projectId: projectId, userId: appState.userId, message: text)
        isSending = false
    }
}

// MARK: - Message bubble

private struct TAMessageBubble: View {
    let message: TAAgentMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.content)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 98/255, green: 83/255, blue: 225/255),
                                Color(red: 4/255, green: 190/255, blue: 254/255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .assistant:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
                Text((try? AttributedString(markdown: message.content
                    .replacingOccurrences(of: "\n", with: "\n\n")))
                     ?? AttributedString(message.content))
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 40)
            }
        case .error:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message.content)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
