//
//  Project.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import Foundation

// MARK: - Models

struct GroupMember: Codable, Identifiable {
    let actorId: String
    let groupId: String
    /// Format: "姓名：角色" e.g. "李明：开发者" — or just a role name if unassigned.
    let actorRole: String
    /// "development" (selectable by students) or "management" (teachers, non-selectable).
    let roleDivision: String
    let actorType: String?
    /// Nil means the role slot is unassigned and available to claim.
    let userId: String?

    var id: String { actorId }

    var isAssigned: Bool { !(userId?.isEmpty ?? true) }

    /// The character's persona name, e.g. "李四" (part before "：").
    var actorName: String {
        actorRole.components(separatedBy: "：").first ?? actorRole
    }

    /// The character's background description (part after "：").
    var actorDescription: String {
        let parts = actorRole.components(separatedBy: "：")
        return parts.count > 1 ? parts.dropFirst().joined(separator: "：") : ""
    }

    enum CodingKeys: String, CodingKey {
        case actorId = "actor_id"
        case groupId = "group_id"
        case actorRole = "actor_role"
        case roleDivision = "role_division"
        case actorType = "actor_type"
        case userId = "user_id"
    }
}

struct Project: Codable, Identifiable {
    let projectId: String
    let title: String
    let description: String
    let isPublished: Bool?

    var id: String { projectId }

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case title, description
        case isPublished = "is_published"
    }
}

struct StudentAssignment: Codable, Identifiable {
    let userId: String
    let groupId: String?
    let title: String
    let description: String
    let time: String
    let isCollaborative: Bool
    let projectId: String
    let loopEndTime: String?

    var id: String { projectId }
    var isActive: Bool { groupId != nil }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case groupId = "group_id"
        case title, description, time
        case isCollaborative = "is_collaborative"
        case projectId = "project_id"
        case loopEndTime = "loop_end_time"
    }
}

// MARK: - Private request types

private struct UserIdRequest: Codable {
    let userId: String
    enum CodingKeys: String, CodingKey { case userId = "user_id" }
}

private struct ProjectIdRequest: Codable {
    let projectId: String
    enum CodingKeys: String, CodingKey { case projectId = "project_id" }
}

private struct IsInProjectRequest: Codable {
    let userId: String
    let projectId: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case projectId = "project_id"
    }
}

private struct JoinProjectRequest: Codable {
    let userId: String
    let projectId: String
    let userName: String
    let userEmail: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case projectId = "project_id"
        case userName = "user_name"
        case userEmail = "user_email"
    }
}

private struct GetCorrespondingActorRequest: Codable {
    let userId: String
    let projectId: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case projectId = "project_id"
    }
}

private struct SelectRoleRequest: Codable {
    let groupId: String
    let actorId: String
    let userId: String
    let userName: String
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case actorId = "actor_id"
        case userId = "user_id"
        case userName = "user_name"
    }
}

private struct WithdrawGroupRequest: Codable {
    let projectId: String
    let userId: String
    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case userId = "user_id"
    }
}

private struct CreateProjectRequest: Codable {
    let projectName: String
    let description: String
    let userId: String
    let userName: String
    let userEmail: String
    enum CodingKeys: String, CodingKey {
        case projectName = "project_name"
        case description
        case userId = "user_id"
        case userName = "user_name"
        case userEmail = "user_email"
    }
}

// MARK: - API

class ProjectAPI: BaseAPI {

    // MARK: Student — group-based

    /// Active assignments the student is enrolled in.
    func getStudentAssignments(userId: String) async throws -> [StudentAssignment] {
        try await request(
            path: "/group/user/get_student_assignments",
            method: .post,
            body: UserIdRequest(userId: userId)
        )
    }

    /// All collaborative projects available to browse / join.
    func getAllCollaborativeProjects(userId: String) async throws -> [Project] {
        try await request(
            path: "/project/all_collaborative_projects",
            method: .post,
            body: UserIdRequest(userId: userId)
        )
    }

    /// Check whether a student is already in a specific project.
    func isInProject(userId: String, projectId: String) async throws -> Bool {
        try await request(
            path: "/group/is_in_project",
            method: .post,
            body: IsInProjectRequest(userId: userId, projectId: projectId)
        )
    }

    /// Join a project; returns the new group_id.
    func joinProject(userId: String, projectId: String, userName: String, userEmail: String) async throws -> String {
        try await request(
            path: "/group/join_project",
            method: .post,
            body: JoinProjectRequest(userId: userId, projectId: projectId, userName: userName, userEmail: userEmail)
        )
    }

    /// Leave a project.
    func withdrawGroup(projectId: String, userId: String) async throws {
        try await requestEmpty(
            path: "/group/withdraw_group",
            method: .post,
            body: WithdrawGroupRequest(projectId: projectId, userId: userId)
        )
    }

    // MARK: Shared

    /// Fetch full detail for a single project.
    func getProject(projectId: String) async throws -> Project {
        try await request(
            path: "/project/get_project/\(projectId)",
            method: .get
        )
    }

    // MARK: Teacher

    /// All collaborative projects created by a teacher.
    func getProjectsAsTeacher(userId: String) async throws -> [Project] {
        try await request(
            path: "/project/get_collaborative_projects",
            method: .post,
            body: UserIdRequest(userId: userId)
        )
    }

    /// Create a new collaborative project; returns the new project_id.
    func createCollaborativeProject(
        projectName: String,
        description: String,
        userId: String,
        userName: String,
        userEmail: String
    ) async throws -> String {
        try await request(
            path: "/project/create_collaborative",
            method: .post,
            body: CreateProjectRequest(
                projectName: projectName,
                description: description,
                userId: userId,
                userName: userName,
                userEmail: userEmail
            )
        )
    }

    /// Delete a collaborative project.
    func deleteCollaborativeProject(projectId: String) async throws {
        try await requestEmpty(
            path: "/project/delete_collaborative",
            method: .post,
            body: ProjectIdRequest(projectId: projectId)
        )
    }

    // MARK: Group

    /// Fetch all members (role slots) of a group.
    func getGroupMembers(groupId: String) async throws -> [GroupMember] {
        try await request(
            path: "/group/\(groupId)/members",
            method: .get
        )
    }

    /// Returns the role assigned to the user in a project, or nil if none yet.
    func getCorrespondingActor(userId: String, projectId: String) async throws -> GroupMember? {
        try await requestOptional(
            path: "/group/get_corresponding_actor",
            method: .post,
            body: GetCorrespondingActorRequest(userId: userId, projectId: projectId)
        )
    }

    /// Assigns a role slot to the current user.
    func selectRole(groupId: String, actorId: String, userId: String, userName: String) async throws {
        try await requestEmpty(
            path: "/group/select_role",
            method: .post,
            body: SelectRoleRequest(groupId: groupId, actorId: actorId, userId: userId, userName: userName)
        )
    }

    // MARK: GitLab

    /// Returns the bash clone URLs for a group's GitLab repository.
    func getBashCloneUrls(groupId: String, userId: String) async throws -> [String] {
        struct Body: Codable {
            let groupId: String
            let userId: String
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case userId = "user_id"
            }
        }
        return try await request(
            path: "/group/gitlab/get_bash_clone_url",
            method: .post,
            body: Body(groupId: groupId, userId: userId)
        )
    }

    /// Get online status for a group member.
    func getMemberStatus(groupId: String, memberId: String) async throws -> String {
        struct Body: Codable {
            let groupId: String
            let memberId: String
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
                case memberId = "member_id"
            }
        }
        return try await request(
            path: "/group/get_member_status",
            method: .post,
            body: Body(groupId: groupId, memberId: memberId)
        )
    }
}

// Backwards-compatibility alias for any iOS code still using the old name.
typealias StudentProjectAPI = ProjectAPI
