//
//  ChatPanelMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI

struct ChatPanelMacOS: View {
    let groupId: String
    let projectId: String
    /// All group members — passed from the parent so we can show a picker when creating a session.
    var members: [GroupMember] = []
    /// The current user's own actor ID — excluded from the member picker.
    var currentActorId: String? = nil

    @Environment(AppState.self) private var appState

    @State private var sessions: [ChatSession] = []
    @State private var selectedSession: ChatSession? = nil
    @State private var isLoadingSessions = false
    @State private var sessionError: String? = nil

    @State private var showNewSession = false
    @State private var newSessionName = ""
    @State private var isCreatingSession = false
    @State private var selectedMemberIds: Set<String> = []

    /// Group members excluding the current user's actor — shown in the new-session picker.
    var selectableMembers: [GroupMember] {
        members.filter { $0.actorId != currentActorId }
    }

    @State private var wsService: ChatWebSocketService? = nil
    @State private var restMessages: [ChatMessage] = []
    @State private var isLoadingHistory = false
    @State private var inputText = ""
    @State private var isSending = false
    /// Bumped on history load completion and on user send — the only two times we auto-scroll.
    @State private var scrollTrigger = UUID()

    /// All messages for the current session: history + live WS messages deduplicated,
    /// with any optimistic tmp IDs resolved to real server IDs.
    var displayMessages: [ChatMessage] {
        // Build tmpId → realId map from WS confirmations
        let idMap = (wsService?.sentConfirmations ?? [])
            .reduce(into: [String: String]()) { $0[$1.tmpId] = $1.realId }

        // Resolve any pending tmp IDs in rest messages
        let resolvedRest = restMessages.map { msg -> ChatMessage in
            guard let realId = idMap[msg.id] else { return msg }
            return ChatMessage(id: realId, sender: msg.sender, senderName: msg.senderName,
                               text: msg.text, time: msg.time, readBy: msg.readBy)
        }

        // Merge WS messages, deduplicating against resolved rest
        var seen = Set(resolvedRest.map(\.id))
        var result = resolvedRest
        for msg in wsService?.messages ?? [] {
            if seen.insert(msg.id).inserted {
                result.append(msg)
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            sessionSidebar
            Divider()
            chatArea
        }
    }

    // MARK: - Session sidebar

    var sessionSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("对话")
                    .font(.callout.bold())
                Spacer()
                Button {
                    showNewSession = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .help("新建对话")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if isLoadingSessions {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            } else if sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("暂无对话")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("新建对话") { showNewSession = true }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(sessions) { session in
                            SessionRow(
                                session: session,
                                isSelected: selectedSession?.id == session.id
                            ) {
                                Task { await selectSession(session) }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }

            Spacer()
        }
        .frame(width: 196)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showNewSession) {
            newSessionSheet
        }
        .task { await loadSessions() }
    }

    // MARK: - Chat area

    var chatArea: some View {
        VStack(spacing: 0) {
            // Session title bar
            if let session = selectedSession {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundStyle(.secondary)
                    Text(session.name)
                        .font(.callout.bold())
                    Spacer()
                    if wsService?.isConnected == true {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                            .help("已连接")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()
            }

            // Messages
            if selectedSession == nil {
                emptyChatPlaceholder
            } else {
                messageList
                Divider()
                messageInput
            }
        }
    }

    var emptyChatPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("选择一个对话开始聊天")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if isLoadingHistory {
                        ProgressView().padding()
                    } else if displayMessages.isEmpty {
                        Text("暂无消息，发送第一条消息吧")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 40)
                    } else {
                        ForEach(displayMessages) { message in
                            MessageBubble(
                                message: message,
                                isOwn: message.sender == appState.userId
                            )
                            .id(message.id)
                        }
                    }
                    // Anchor for auto-scroll
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .onChange(of: scrollTrigger) {
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    var messageInput: some View {
        HStack(spacing: 12) {
            TextField("发送消息…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: isSending ? "hourglass.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
                        ? Color.secondary
                        : Color.accentColor
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - New session sheet

    var newSessionSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("新建对话")
                .font(.title2.bold())
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider()

            // Session name
            VStack(alignment: .leading, spacing: 8) {
                Text("对话名称")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextField("输入对话名称", text: $newSessionName)
                    .font(.callout)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Member picker
            VStack(alignment: .leading, spacing: 8) {
                Text("选择成员（至少选一位）")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                if selectableMembers.isEmpty {
                    Text("暂无其他成员")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 1) {
                        ForEach(selectableMembers) { member in
                            let isSelected = selectedMemberIds.contains(member.actorId)
                            Button {
                                if isSelected {
                                    selectedMemberIds.remove(member.actorId)
                                } else {
                                    selectedMemberIds.insert(member.actorId)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.headline)
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.actorName)
                                            .font(.callout)
                                            .foregroundStyle(.primary)
                                        Text(member.actorDescription)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Divider()

            // Action bar
            HStack {
                if !selectedMemberIds.isEmpty {
                    Text("已选 \(selectedMemberIds.count) 位成员")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") {
                    newSessionName = ""
                    selectedMemberIds = []
                    showNewSession = false
                }
                .buttonStyle(.bordered)

                Button(isCreatingSession ? "创建中…" : "创建") {
                    Task { await createSession() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    newSessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || selectedMemberIds.isEmpty
                    || isCreatingSession
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 380)
    }

    // MARK: - Actions

    func loadSessions() async {
        guard !groupId.isEmpty else { return }
        isLoadingSessions = true
        sessionError = nil
        let api = ChatAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            sessions = try await api.getSessions(groupId: groupId, userId: appState.userId)
            if let first = sessions.first, selectedSession == nil {
                await selectSession(first)
            }
        } catch {}
        isLoadingSessions = false
    }

    func selectSession(_ session: ChatSession) async {
        // Disconnect previous WS and reset
        wsService?.disconnect()
        let ws = ChatWebSocketService(
            baseURL: appState.organizationBaseUrl,
            token: appState.token,
            currentUserId: appState.userId
        )
        wsService = ws

        selectedSession = session
        isLoadingHistory = true
        restMessages = []

        let api = ChatAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            restMessages = try await api.getHistory(
                groupId: groupId,
                userId: appState.userId,
                sessionId: session.id
            )
        } catch {}

        isLoadingHistory = false
        scrollTrigger = UUID()
        ws.connect(groupId: groupId, userId: appState.userId, sessionId: session.id)
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session = selectedSession else { return }
        let tmpId = "tmp_" + UUID().uuidString
        inputText = ""

        // Optimistic: show the message immediately before server confirms
        let optimistic = ChatMessage(
            id: tmpId,
            sender: appState.userId,
            senderName: appState.username,
            text: text,
            time: ISO8601DateFormatter().string(from: Date()),
            readBy: nil
        )
        restMessages.append(optimistic)
        scrollTrigger = UUID()

        wsService?.send(sessionId: session.id, text: text, tmpId: tmpId)
    }

    func createSession() async {
        guard !newSessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !selectedMemberIds.isEmpty else { return }
        isCreatingSession = true
        let api = ChatAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            _ = try await api.createSession(
                groupId: groupId,
                userId: appState.userId,
                sessionName: newSessionName.trimmingCharacters(in: .whitespacesAndNewlines),
                members: Array(selectedMemberIds)
            )
            newSessionName = ""
            selectedMemberIds = []
            showNewSession = false
            await loadSessions()
        } catch {}
        isCreatingSession = false
    }
}

// MARK: - Session row

private struct SessionRow: View {
    let session: ChatSession
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 16)
                Text(session.name)
                    .font(.callout)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? AnyShapeStyle(Color.accentColor)
                          : AnyShapeStyle(isHovered
                                          ? Color.primary.opacity(0.05)
                                          : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let isOwn: Bool

    private static let avatarColors: [Color] = [.blue, .purple, .orange, .indigo, .teal, .pink, .red, .cyan]

    private var avatarColor: Color {
        Self.avatarColors[abs(message.senderName.hashValue) % Self.avatarColors.count]
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isOwn { Spacer(minLength: 60) }

            if !isOwn {
                ZStack {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 32, height: 32)
                    Text(String(message.senderName.prefix(1)))
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                if !isOwn {
                    Text(message.senderName)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Text(message.text)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isOwn
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(Color(NSColor.controlBackgroundColor))
                    )
                    .foregroundStyle(isOwn ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        !isOwn ? AnyShapeStyle(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        ) : AnyShapeStyle(Color.clear)
                    )
                Text(formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if isOwn {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }

    var formattedTime: String {
        // Parse as ISO8601 and format in the local timezone
        let display: DateFormatter = {
            let f = DateFormatter()
            f.timeStyle = .short
            f.dateStyle = .none
            return f
        }()
        // Try with fractional seconds first (server format), then without
        for opts: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime]
        ] {
            let parser = ISO8601DateFormatter()
            parser.formatOptions = opts
            if let date = parser.date(from: message.time) {
                return display.string(from: date)
            }
        }
        // Fallback: strip T and take HH:mm
        let parts = message.time.components(separatedBy: "T")
        guard parts.count > 1 else { return message.time }
        return String(parts[1].prefix(5))
    }
}
