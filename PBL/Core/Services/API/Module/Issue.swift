//
//  Issue.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import Foundation

// MARK: - Models

struct Issue: Codable, Identifiable, Equatable {
    let issueId: String
    let issueBoardId: String
    let index: Int?
    let title: String
    let personInCharge: String?
    let isDone: Bool
    let description: String?
    let detailedDescription: String?
    let participants: [String]?
    let notes: String?
    let children: [Issue]?

    var id: String { issueId }

    enum CodingKeys: String, CodingKey {
        case issueId = "issue_id"
        case issueBoardId = "issueboard_id"
        case index
        case title
        case personInCharge = "person_in_charge"
        case isDone = "is_done"
        case description
        case detailedDescription = "detailed_description"
        case participants
        case notes
        case children
    }

    /// Recursively counts total and completed issues (including children).
    var progressStats: (total: Int, done: Int) {
        let childStats = (children ?? []).reduce((total: 0, done: 0)) { acc, child in
            let s = child.progressStats
            return (total: acc.total + s.total, done: acc.done + s.done)
        }
        return (total: 1 + childStats.total, done: (isDone ? 1 : 0) + childStats.done)
    }
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

private struct UpdateIssueRequest: Codable {
    let issueBoardId: String
    let groupId: String
    let issueId: String
    let fields: Fields

    struct Fields: Codable {
        let isDone: Bool
        enum CodingKeys: String, CodingKey { case isDone = "is_done" }
    }

    enum CodingKeys: String, CodingKey {
        case issueBoardId = "issueboard_id"
        case groupId = "group_id"
        case issueId = "issue_id"
        case fields
    }
}

private struct IssueListResponse: Codable {
    let records: [Issue]
}

private struct IssueBoardIdBody: Codable {
    let issueBoardId: String
    enum CodingKeys: String, CodingKey { case issueBoardId = "issueboard_id" }
}

// MARK: - API

class IssueAPI: BaseAPI {

    /// Returns the issueboard ID for a group.
    func getIssueBoardId(groupId: String, userId: String) async throws -> String {
        try await request(
            path: "/group/issueboard/get_issueboard_id",
            method: .post,
            body: GroupUserRequest(groupId: groupId, userId: userId)
        )
    }

    /// Fetches the full issue tree for a group.
    func getIssues(groupId: String, userId: String) async throws -> [Issue] {
        let response: IssueListResponse = try await request(
            path: "/group/issueboard/get_issue",
            method: .post,
            body: GroupUserRequest(groupId: groupId, userId: userId)
        )
        return response.records
    }

    /// Returns activation status for all root issues: issueId → isActivated.
    func getActivationStatus(issueBoardId: String) async throws -> [String: Bool] {
        try await request(
            path: "/group/issueboard/get_issue_activation_status",
            method: .post,
            body: IssueBoardIdBody(issueBoardId: issueBoardId)
        )
    }

    /// Marks an issue as done or not done.
    func updateIssue(issueBoardId: String, groupId: String, issueId: String, isDone: Bool) async throws {
        try await requestEmpty(
            path: "/group/issueboard/update_issue",
            method: .post,
            body: UpdateIssueRequest(
                issueBoardId: issueBoardId,
                groupId: groupId,
                issueId: issueId,
                fields: .init(isDone: isDone)
            )
        )
    }
}
