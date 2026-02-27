//
//  TeacherProject.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/26.
//

import Foundation

// MARK: - Agent models

struct ProjectAgent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let systemPrompt: String
    let actorRole: String
    let roleDivision: String
    let env: [String]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case systemPrompt = "system_prompt"
        case actorRole = "actor_role"
        case roleDivision = "role_division"
        case env
    }
}

// MARK: - Issue models

struct TemplateIssue: Codable, Identifiable {
    let issueId: String
    let title: String
    let description: String?
    let detailedDescription: String?
    let personInCharge: String
    let participants: [String]
    let isDone: Bool
    let parentIssue: String?
    var children: [TemplateIssue]?

    var id: String { issueId }

    enum CodingKeys: String, CodingKey {
        case issueId = "issue_id"
        case title, description, participants
        case detailedDescription = "detailed_description"
        case personInCharge = "person_in_charge"
        case isDone = "is_done"
        case parentIssue = "parent_issue"
        case children
    }
}

// MARK: - GitLab models

struct GitLabRepository: Codable, Identifiable, Hashable {
    let id: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case url
    }
}

struct GitLabTreeItem: Codable, Identifiable {
    let id: String
    let name: String
    let type: String   // "blob" or "tree"
    let path: String
}

struct GitLabFileContent: Codable {
    let fileName: String
    let filePath: String
    let contentDecoded: String

    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case filePath = "file_path"
        case contentDecoded = "content_decoded"
    }
}

// MARK: - Teacher Project API

class TeacherProjectAPI: BaseAPI {

    // MARK: Agents

    func getAgents(projectId: String) async throws -> [ProjectAgent] {
        struct Body: Codable {
            let projectId: String
            enum CodingKeys: String, CodingKey { case projectId = "project_id" }
        }
        return try await request(
            path: "/project/get_agent_members",
            method: .post,
            body: Body(projectId: projectId)
        )
    }

    func getTemplateAgents() async throws -> [ProjectAgent] {
        return try await request(
            path: "/project/get_template_agents",
            method: .post,
            body: EmptyBody()
        )
    }

    func addAgent(projectId: String, name: String, actorRole: String, roleDivision: String,
                  systemPrompt: String, env: [String]) async throws -> String {
        struct Body: Codable {
            let projectId: String
            let name: String
            let actorRole: String
            let roleDivision: String
            let systemPrompt: String
            let env: [String]
            enum CodingKeys: String, CodingKey {
                case projectId = "project_id"
                case name
                case actorRole = "actor_role"
                case roleDivision = "role_division"
                case systemPrompt = "system_prompt"
                case env
            }
        }
        return try await request(
            path: "/project/add_agent",
            method: .post,
            body: Body(projectId: projectId, name: name, actorRole: actorRole,
                       roleDivision: roleDivision, systemPrompt: systemPrompt, env: env)
        )
    }

    func updateAgentSystemPrompt(memberId: String, systemPrompt: String) async throws {
        struct Body: Codable {
            let memberId: String
            let systemPrompt: String
            enum CodingKeys: String, CodingKey {
                case memberId = "member_id"
                case systemPrompt = "system_prompt"
            }
        }
        try await requestEmpty(
            path: "/project/update_agent_system_prompt",
            method: .post,
            body: Body(memberId: memberId, systemPrompt: systemPrompt)
        )
    }

    func deleteAgent(agentId: String) async throws {
        struct Body: Codable {
            let agentId: String
            enum CodingKeys: String, CodingKey { case agentId = "agent_id" }
        }
        try await requestEmpty(
            path: "/project/delete_agent",
            method: .post,
            body: Body(agentId: agentId)
        )
    }

    // MARK: Issues

    func getTemplateIssueboard(projectId: String) async throws -> [TemplateIssue] {
        struct Body: Codable {
            let projectId: String
            enum CodingKeys: String, CodingKey { case projectId = "project_id" }
        }
        struct Response: Codable {
            let records: [TemplateIssue]
        }
        let resp: Response = try await request(
            path: "/project/get_template_issueboard",
            method: .post,
            body: Body(projectId: projectId)
        )
        return resp.records
    }

    func createTemplateIssueboard(projectId: String, issues: [TemplateIssue], agentIds: [String]) async throws {
        struct Body: Codable {
            let projectId: String
            let issues: [TemplateIssue]
            let agentIds: [String]
            enum CodingKeys: String, CodingKey {
                case projectId = "project_id"
                case issues
                case agentIds = "agent_ids"
            }
        }
        try await requestEmpty(
            path: "/project/create_template_issueboard",
            method: .post,
            body: Body(projectId: projectId, issues: issues, agentIds: agentIds)
        )
    }

    func updateTemplateIssueboard(projectId: String, issues: [TemplateIssue], agentIds: [String]) async throws {
        struct Body: Codable {
            let projectId: String
            let issues: [TemplateIssue]
            let agentIds: [String]
            enum CodingKeys: String, CodingKey {
                case projectId = "project_id"
                case issues
                case agentIds = "agent_ids"
            }
        }
        try await requestEmpty(
            path: "/project/update_template_issueboard",
            method: .post,
            body: Body(projectId: projectId, issues: issues, agentIds: agentIds)
        )
    }

    func deleteTemplateIssueboard(projectId: String) async throws {
        struct Body: Codable {
            let projectId: String
            enum CodingKeys: String, CodingKey { case projectId = "project_id" }
        }
        try await requestEmpty(
            path: "/project/delete_template_issueboard",
            method: .post,
            body: Body(projectId: projectId)
        )
    }

    // MARK: GitLab

    func getGitLabRepositories(projectId: String) async throws -> [GitLabRepository] {
        return try await request(
            path: "/project/gitlab/get_url?project_id=\(projectId)",
            method: .get
        )
    }

    func getFileTree(projectId: String, url: String, ref: String = "main") async throws -> [GitLabTreeItem] {
        struct Response: Codable {
            let tree: [GitLabTreeItem]
        }
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let resp: Response = try await request(
            path: "/project/gitlab/get_file_tree?project_id=\(projectId)&url=\(encoded)&ref=\(ref)",
            method: .get
        )
        return resp.tree
    }

    func getFile(projectId: String, url: String, filePath: String, ref: String = "main") async throws -> GitLabFileContent {
        let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filePath
        return try await request(
            path: "/project/gitlab/get_file?project_id=\(projectId)&url=\(encodedUrl)&file_path=\(encodedPath)&ref=\(ref)",
            method: .get
        )
    }

    func updateFile(projectId: String, url: String, filePath: String,
                    content: String, commitMessage: String, branch: String = "main") async throws {
        struct Body: Codable {
            let projectId: String
            let url: String
            let filePath: String
            let content: String
            let commitMessage: String
            let branch: String
            enum CodingKeys: String, CodingKey {
                case projectId = "project_id"
                case url
                case filePath = "file_path"
                case content
                case commitMessage = "commit_message"
                case branch
            }
        }
        try await requestEmpty(
            path: "/project/gitlab/update_file",
            method: .post,
            body: Body(projectId: projectId, url: url, filePath: filePath,
                       content: content, commitMessage: commitMessage, branch: branch)
        )
    }
}

// MARK: - Empty body helper

private struct EmptyBody: Codable {}
