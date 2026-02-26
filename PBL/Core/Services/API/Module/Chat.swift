//
//  Chat.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import Foundation
import UserNotifications
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Models

struct ChatMember: Codable, Identifiable {
    let id: String
    let name: String
    let status: String?
}

struct ChatSession: Codable, Identifiable {
    let id: String
    let name: String
    let members: [ChatMember]?
}

struct ChatMessage: Codable, Identifiable {
    let id: String
    let sender: String
    let senderName: String
    let text: String
    let time: String
    let readBy: [ChatMember]?
}

// MARK: - Private request types

private struct GroupUserRequest: Codable {
    let groupId: String
    let userId: String
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
    }
}

private struct ChatHistoryRequest: Codable {
    let groupId: String
    let userId: String
    let sessionId: String
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case sessionId = "session_id"
    }
}

private struct CreateSessionRequest: Codable {
    let groupId: String
    let userId: String
    let sessionName: String
    let members: [String]
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case sessionName = "session_name"
        case members
    }
}

// MARK: - REST API

class ChatAPI: BaseAPI {

    func getSessions(groupId: String, userId: String) async throws -> [ChatSession] {
        try await request(
            path: "/group/chat/get_chat_sessions",
            method: .post,
            body: GroupUserRequest(groupId: groupId, userId: userId)
        )
    }

    func getHistory(groupId: String, userId: String, sessionId: String) async throws -> [ChatMessage] {
        try await request(
            path: "/group/chat/get_chat_history",
            method: .post,
            body: ChatHistoryRequest(groupId: groupId, userId: userId, sessionId: sessionId)
        )
    }

    func createSession(groupId: String, userId: String, sessionName: String, members: [String]) async throws -> String {
        try await request(
            path: "/group/chat/create_chat_session",
            method: .post,
            body: CreateSessionRequest(groupId: groupId, userId: userId, sessionName: sessionName, members: members)
        )
    }
}

// MARK: - WebSocket service

struct SentConfirmation {
    let tmpId: String
    let realId: String
}

@Observable
final class ChatWebSocketService {
    var messages: [ChatMessage] = []
    var isConnected = false
    /// Filled when the server confirms a sent message: maps tmpId → realId.
    var sentConfirmations: [SentConfirmation] = []

    private var wsTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    private let baseURL: String
    private let token: String
    private let currentUserId: String
    /// Only messages whose session_id matches this are kept.
    private(set) var currentSessionId: String = ""

    init(baseURL: String, token: String, currentUserId: String = "") {
        self.baseURL = baseURL
        self.token = token
        self.currentUserId = currentUserId
    }

    func connect(groupId: String, userId: String, sessionId: String) {
        currentSessionId = sessionId
        disconnect()

        let wsBase = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let urlString = "\(wsBase)/group/chat/ws?group_id=\(groupId)&user_id=\(userId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        wsTask = URLSession.shared.webSocketTask(with: request)
        wsTask?.resume()
        isConnected = true
        startReceiving()
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        isConnected = false
    }

    func send(sessionId: String, text: String, tmpId: String) {
        struct OutMessage: Encodable {
            let type: String
            let sessionId: String
            let text: String
            let tmpId: String
            enum CodingKeys: String, CodingKey {
                case type
                case sessionId = "session_id"
                case text
                case tmpId = "tmp_id"
            }
        }
        guard let data = try? JSONEncoder().encode(
            OutMessage(type: "send_message", sessionId: sessionId, text: text, tmpId: tmpId)
        ), let payload = String(data: data, encoding: .utf8) else { return }
        wsTask?.send(.string(payload)) { _ in }
    }

    private func sendNotification(for message: ChatMessage) {
        Task { @MainActor in
#if canImport(AppKit)
            guard !NSApplication.shared.isActive else { return }
#endif
            let content = UNMutableNotificationContent()
            content.title = message.senderName
            content.body = message.text
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: message.id,
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let task = self.wsTask else { break }
                do {
                    let message = try await task.receive()
                    if case .string(let text) = message,
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
            let type: String
            let sessionId: String?
            let data: [ChatMessage]?
            let messageId: String?
            let tmpId: String?
            enum CodingKeys: String, CodingKey {
                case type, data
                case sessionId = "session_id"
                case messageId = "message_id"
                case tmpId = "tmp_id"
            }
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }

        switch envelope.type {
        case "new_messages":
            // Only accept messages that belong to the currently active session
            guard envelope.sessionId == currentSessionId, let msgs = envelope.data else { break }
            let existing = Set(messages.map(\.id))
            let incoming = msgs.filter { !existing.contains($0.id) }
            messages.append(contentsOf: incoming)
            // Notify for messages not sent by the current user
            for msg in incoming where msg.sender != currentUserId {
                sendNotification(for: msg)
            }
        case "message_sent":
            if let tmpId = envelope.tmpId, let realId = envelope.messageId {
                sentConfirmations.append(SentConfirmation(tmpId: tmpId, realId: realId))
            }
        default:
            break
        }
    }
}
