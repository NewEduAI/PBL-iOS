//
//  AgentsPanelMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/26.
//

import SwiftUI

struct AgentsPanelMacOS: View {
    let projectId: String
    var isLocked: Bool = false
    var refreshTrigger: UUID = UUID()

    @Environment(AppState.self) private var appState

    @State private var agents: [ProjectAgent] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var selectedAgent: ProjectAgent? = nil

    // Add agent sheet
    @State private var showAddSheet = false
    @State private var templates: [ProjectAgent] = []
    @State private var isLoadingTemplates = false

    // Delete confirmation
    @State private var agentToDelete: ProjectAgent? = nil

    var body: some View {
        HSplitView {
            // Left: agent list
            agentList
                .frame(minWidth: 220, maxWidth: 280)

            // Right: agent detail / editor
            agentDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await loadAgents() }
        .onChange(of: refreshTrigger) { Task { await loadAgents() } }
        .disabled(isLocked)
        .sheet(isPresented: $showAddSheet) {
            AddAgentSheet(projectId: projectId, templates: templates) {
                Task { await loadAgents() }
            }
            .environment(appState)
        }
        .alert("删除智能体", isPresented: Binding(
            get: { agentToDelete != nil },
            set: { if !$0 { agentToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { agentToDelete = nil }
            Button("删除", role: .destructive) {
                if let agent = agentToDelete {
                    Task { await deleteAgent(agent) }
                }
            }
        } message: {
            Text("确定要删除「\(agentToDelete?.name ?? "")」吗？此操作无法撤销。")
        }
    }

    // MARK: - Agent list

    var agentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("智能体")
                    .font(.callout.bold())
                Spacer()
                Button {
                    Task { await loadTemplates() }
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("添加智能体")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            } else if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            } else if agents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("暂无智能体")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("添加智能体") {
                        Task { await loadTemplates() }
                        showAddSheet = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(agents) { agent in
                            AgentRow(
                                agent: agent,
                                isSelected: selectedAgent?.id == agent.id,
                                onSelect: { selectedAgent = agent },
                                onDelete: { agentToDelete = agent }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Agent detail

    @ViewBuilder
    var agentDetail: some View {
        if let agent = selectedAgent {
            AgentDetailView(agent: agent, projectId: projectId) { updated in
                if let i = agents.firstIndex(where: { $0.id == updated.id }) {
                    agents[i] = updated
                    selectedAgent = updated
                }
            }
            .environment(appState)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("选择一个智能体查看详情")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    func loadAgents() async {
        isLoading = true
        error = nil
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            agents = try await api.getAgents(projectId: projectId)
            if selectedAgent != nil {
                selectedAgent = agents.first(where: { $0.id == selectedAgent?.id })
            }
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadTemplates() async {
        isLoadingTemplates = true
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        templates = (try? await api.getTemplateAgents()) ?? []
        isLoadingTemplates = false
    }

    func deleteAgent(_ agent: ProjectAgent) async {
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        try? await api.deleteAgent(agentId: agent.id)
        agentToDelete = nil
        if selectedAgent?.id == agent.id { selectedAgent = nil }
        await loadAgents()
    }
}

// MARK: - Agent row

private struct AgentRow: View {
    let agent: ProjectAgent
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cpu")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.callout)
                    .lineLimit(1)
                Text(agent.actorRole)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .padding(.horizontal, 6)
    }
}

// MARK: - Agent detail view

private struct AgentDetailView: View {
    let agent: ProjectAgent
    let projectId: String
    let onSaved: (ProjectAgent) -> Void

    @Environment(AppState.self) private var appState

    @State private var systemPrompt: String = ""
    @State private var isSaving = false
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

    var hasChanges: Bool { systemPrompt != agent.systemPrompt }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.title3.bold())
                    Text(agent.actorRole)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Environment badges
                HStack(spacing: 4) {
                    ForEach(agent.env, id: \.self) { env in
                        Text(env)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // System prompt editor
            VStack(alignment: .leading, spacing: 8) {
                Text("系统提示词")
                    .font(.callout.bold())
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                TextEditor(text: $systemPrompt)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Save bar
            if hasChanges || saveError != nil {
                Divider()
                HStack(spacing: 10) {
                    if let err = saveError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if saveSuccess {
                        Label("已保存", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button("还原") {
                        systemPrompt = agent.systemPrompt
                        saveError = nil
                        saveSuccess = false
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await savePrompt() }
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
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .onAppear { systemPrompt = agent.systemPrompt }
        .onChange(of: agent.id) { systemPrompt = agent.systemPrompt; saveError = nil; saveSuccess = false }
    }

    func savePrompt() async {
        isSaving = true
        saveError = nil
        saveSuccess = false
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            try await api.updateAgentSystemPrompt(memberId: agent.id, systemPrompt: systemPrompt)
            saveSuccess = true
            let updated = ProjectAgent(id: agent.id, name: agent.name, systemPrompt: systemPrompt,
                                       actorRole: agent.actorRole, roleDivision: agent.roleDivision, env: agent.env)
            onSaved(updated)
        } catch let err as APIError {
            saveError = err.message
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Add agent sheet

private struct AddAgentSheet: View {
    let projectId: String
    let templates: [ProjectAgent]
    let onAdded: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: ProjectAgent? = nil
    @State private var name = ""
    @State private var actorRole = ""
    @State private var roleDivision = "development"
    @State private var systemPrompt = ""
    @State private var selectedEnvs: Set<String> = ["chat"]
    @State private var isCreating = false
    @State private var error: String? = nil

    private let envOptions = ["bash", "chat", "issueboard"]

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

    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !actorRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedEnvs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("添加智能体")
                .font(.title2.bold())

            // Template picker
            if !templates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("从模板选择（可选）")
                        .font(.callout.bold())
                    Picker("模板", selection: $selectedTemplate) {
                        Text("不使用模板").tag(Optional<ProjectAgent>.none)
                        ForEach(templates) { t in
                            Text(t.name).tag(Optional(t))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedTemplate) { _, tmpl in
                        guard let tmpl else { return }
                        name = tmpl.name
                        actorRole = tmpl.actorRole
                        roleDivision = tmpl.roleDivision
                        systemPrompt = tmpl.systemPrompt
                        selectedEnvs = Set(tmpl.env)
                    }
                }
            }

            // Name
            fieldGroup(label: "名称") {
                TextField("智能体名称", text: $name)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(inputBackground)
            }

            // Role
            fieldGroup(label: "角色描述") {
                TextField("例：前端开发者", text: $actorRole)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(inputBackground)
            }

            // Role division
            fieldGroup(label: "角色类型") {
                Picker("", selection: $roleDivision) {
                    Text("开发团队").tag("development")
                    Text("管理团队").tag("management")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // Environments
            fieldGroup(label: "可用环境") {
                HStack(spacing: 8) {
                    ForEach(envOptions, id: \.self) { env in
                        let isOn = selectedEnvs.contains(env)
                        Button {
                            if isOn { selectedEnvs.remove(env) } else { selectedEnvs.insert(env) }
                        } label: {
                            Text(env)
                                .font(.callout)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isOn
                                              ? AnyShapeStyle(brandGradient)
                                              : AnyShapeStyle(Color(NSColor.controlBackgroundColor)))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                )
                                .foregroundStyle(isOn ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Spacer()

            // Actions
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("取消").padding(.horizontal, 20).padding(.vertical, 9)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await createAgent() }
                } label: {
                    Text(isCreating ? "创建中…" : "创建")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(!canCreate || isCreating
                              ? AnyShapeStyle(Color.secondary.opacity(0.3))
                              : AnyShapeStyle(brandGradient))
                )
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .disabled(!canCreate || isCreating)
            }
        }
        .padding(24)
        .frame(width: 420, alignment: .top)
    }

    var inputBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    @ViewBuilder
    func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.callout.bold())
            content()
        }
    }

    func createAgent() async {
        isCreating = true
        error = nil
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            _ = try await api.addAgent(
                projectId: projectId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                actorRole: actorRole.trimmingCharacters(in: .whitespacesAndNewlines),
                roleDivision: roleDivision,
                systemPrompt: systemPrompt,
                env: Array(selectedEnvs)
            )
            onAdded()
            dismiss()
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}
