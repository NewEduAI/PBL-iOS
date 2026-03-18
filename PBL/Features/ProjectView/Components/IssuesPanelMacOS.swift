//
//  IssuesPanelMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/26.
//

import SwiftUI

struct IssuesPanelMacOS: View {
    let projectId: String
    var isLocked: Bool = false
    var refreshTrigger: UUID = UUID()

    @Environment(AppState.self) private var appState

    @State private var issues: [TemplateIssue] = []
    @State private var agents: [ProjectAgent] = []
    @State private var isLoading = false
    @State private var hasTemplate = false
    @State private var error: String? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var selectedIssue: TemplateIssue? = nil
    @State private var showAddIssue = false
    @State private var showDeleteAlert = false

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

    var agentIds: [String] { agents.map(\.id) }

    var body: some View {
        HSplitView {
            issueList
                .frame(minWidth: 240, maxWidth: 320)
            issueDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await loadAll() }
        .onChange(of: refreshTrigger) { Task { await loadAll() } }
        .disabled(isLocked)
        .sheet(isPresented: $showAddIssue) {
            AddIssueSheet(agents: agents, parentId: nil) { newIssue in
                issues.append(newIssue)
                Task { await saveIssueboard() }
            }
        }
        .alert("删除任务模板", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { Task { await deleteTemplate() } }
        } message: {
            Text("确定要删除整个任务模板吗？此操作无法撤销。")
        }
    }

    // MARK: - Issue list

    var issueList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("任务模板")
                    .font(.callout.bold())
                Spacer()
                if hasTemplate {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.borderless)
                    .help("删除模板")
                }
                Button {
                    showAddIssue = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("添加任务")
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
            } else if issues.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("暂无任务模板")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("创建第一个任务") { showAddIssue = true }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(issues) { issue in
                            IssueRow(
                                issue: issue,
                                depth: 0,
                                selectedIssueId: selectedIssue?.id,
                                onSelect: { selectedIssue = $0 },
                                onDelete: { deleteIssue($0) }
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

    // MARK: - Issue detail

    @ViewBuilder
    var issueDetail: some View {
        if let issue = selectedIssue {
            IssueDetailView(
                issue: issue,
                agents: agents,
                onSave: { updated in
                    updateIssueInList(updated)
                    selectedIssue = updated
                    Task { await saveIssueboard() }
                },
                onAddChild: { child in
                    addChildIssue(child, parentId: issue.issueId)
                    Task { await saveIssueboard() }
                }
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("选择一个任务查看详情")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    func loadAll() async {
        isLoading = true
        error = nil
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            async let issuesTask = api.getTemplateIssueboard(projectId: projectId)
            async let agentsTask = api.getAgents(projectId: projectId)
            let (loaded, loadedAgents) = try await (issuesTask, agentsTask)
            issues = loaded
            agents = loadedAgents
            hasTemplate = !loaded.isEmpty
        } catch let err as APIError {
            // A 404-style "not found" means no template yet — treat as empty
            if err.message.lowercased().contains("not found") || err.statusCode == 404 {
                hasTemplate = false
            } else {
                error = err.message
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func saveIssueboard() async {
        isSaving = true
        saveError = nil
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            if hasTemplate {
                try await api.updateTemplateIssueboard(projectId: projectId, issues: issues, agentIds: agentIds)
            } else {
                try await api.createTemplateIssueboard(projectId: projectId, issues: issues, agentIds: agentIds)
                hasTemplate = true
            }
        } catch let err as APIError {
            saveError = err.message
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    func deleteTemplate() async {
        let api = TeacherProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        try? await api.deleteTemplateIssueboard(projectId: projectId)
        issues = []
        hasTemplate = false
        selectedIssue = nil
    }

    func deleteIssue(_ issue: TemplateIssue) {
        issues = removeIssue(issue.issueId, from: issues)
        if selectedIssue?.id == issue.id { selectedIssue = nil }
        Task { await saveIssueboard() }
    }

    func updateIssueInList(_ updated: TemplateIssue) {
        issues = replaceIssue(updated, in: issues)
    }

    func addChildIssue(_ child: TemplateIssue, parentId: String) {
        issues = appendChild(child, parentId: parentId, in: issues)
    }

    // MARK: - Recursive helpers

    func removeIssue(_ id: String, from list: [TemplateIssue]) -> [TemplateIssue] {
        list.compactMap { issue in
            if issue.issueId == id { return nil }
            var copy = issue
            copy = TemplateIssue(
                issueId: copy.issueId, title: copy.title, description: copy.description,
                detailedDescription: copy.detailedDescription, personInCharge: copy.personInCharge,
                participants: copy.participants, isDone: copy.isDone, notes: copy.notes,
                parentIssue: copy.parentIssue,
                children: copy.children.map { removeIssue(id, from: $0) }
            )
            return copy
        }
    }

    func replaceIssue(_ updated: TemplateIssue, in list: [TemplateIssue]) -> [TemplateIssue] {
        list.map { issue in
            if issue.issueId == updated.issueId { return updated }
            return TemplateIssue(
                issueId: issue.issueId, title: issue.title, description: issue.description,
                detailedDescription: issue.detailedDescription, personInCharge: issue.personInCharge,
                participants: issue.participants, isDone: issue.isDone, notes: issue.notes,
                parentIssue: issue.parentIssue,
                children: issue.children.map { replaceIssue(updated, in: $0) }
            )
        }
    }

    func appendChild(_ child: TemplateIssue, parentId: String, in list: [TemplateIssue]) -> [TemplateIssue] {
        list.map { issue in
            if issue.issueId == parentId {
                var children = issue.children ?? []
                children.append(child)
                return TemplateIssue(
                    issueId: issue.issueId, title: issue.title, description: issue.description,
                    detailedDescription: issue.detailedDescription, personInCharge: issue.personInCharge,
                    participants: issue.participants, isDone: issue.isDone, notes: issue.notes,
                    parentIssue: issue.parentIssue, children: children
                )
            }
            return TemplateIssue(
                issueId: issue.issueId, title: issue.title, description: issue.description,
                detailedDescription: issue.detailedDescription, personInCharge: issue.personInCharge,
                participants: issue.participants, isDone: issue.isDone, notes: issue.notes,
                parentIssue: issue.parentIssue,
                children: issue.children.map { appendChild(child, parentId: parentId, in: $0) }
            )
        }
    }
}

// MARK: - Issue row

private struct IssueRow: View {
    let issue: TemplateIssue
    let depth: Int
    let selectedIssueId: String?
    let onSelect: (TemplateIssue) -> Void
    let onDelete: (TemplateIssue) -> Void

    @State private var isHovered = false

    private var isSelected: Bool { selectedIssueId == issue.id }

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 8) {
                // Indent for depth
                if depth > 0 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1)
                        .padding(.leading, CGFloat(depth) * 16)
                }

                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.secondary)

                Text(issue.title)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()

                if isHovered {
                    Button { onDelete(issue) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture { onSelect(issue) }
            .padding(.horizontal, 6)

            // Children
            if let children = issue.children {
                ForEach(children) { child in
                    IssueRow(
                        issue: child,
                        depth: depth + 1,
                        selectedIssueId: selectedIssueId,
                        onSelect: onSelect,
                        onDelete: onDelete
                    )
                }
            }
        }
    }
}

// MARK: - Issue detail view

private struct IssueDetailView: View {
    let issue: TemplateIssue
    let agents: [ProjectAgent]
    let onSave: (TemplateIssue) -> Void
    let onAddChild: (TemplateIssue) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var detailedDescription = ""
    @State private var notes = ""
    @State private var personInCharge = ""
    @State private var participants: Set<String> = []
    @State private var showAddChild = false
    /// Which text field is currently being edited (nil = all show markdown)
    @State private var editingField: String? = nil
    @FocusState private var focusedField: String?

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

    /// Agents available as participants (excludes the current assignee)
    var availableParticipants: [ProjectAgent] {
        agents.filter { $0.name != personInCharge }
    }

    var hasChanges: Bool {
        title != issue.title
            || description != (issue.description ?? "")
            || detailedDescription != (issue.detailedDescription ?? "")
            || notes != (issue.notes ?? "")
            || personInCharge != issue.personInCharge
            || participants != Set(issue.participants)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("任务详情")
                    .font(.title3.bold())
                Spacer()
                Button {
                    showAddChild = true
                } label: {
                    Label("添加子任务", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    fieldGroup(label: "标题") {
                        markdownField(text: $title, field: "title", placeholder: "任务标题", minHeight: 28)
                    }

                    // Assignee
                    fieldGroup(label: "负责人") {
                        Picker("负责人", selection: $personInCharge) {
                            Text("未分配").tag("")
                            ForEach(agents) { agent in
                                Text(agent.name).tag(agent.name)
                            }
                        }
                        .labelsHidden()
                    }

                    // Participants (excluding assignee)
                    fieldGroup(label: "参与者") {
                        if availableParticipants.isEmpty {
                            Text("暂无可选智能体")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(availableParticipants) { agent in
                                    let isOn = participants.contains(agent.name)
                                    Button {
                                        if isOn { participants.remove(agent.name) }
                                        else { participants.insert(agent.name) }
                                    } label: {
                                        Text(agent.name)
                                            .font(.callout)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(isOn
                                                          ? AnyShapeStyle(brandGradient)
                                                          : AnyShapeStyle(Color(NSColor.controlBackgroundColor)))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                                    )
                                            )
                                            .foregroundStyle(isOn ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Description
                    fieldGroup(label: "描述") {
                        markdownField(text: $description, field: "description", placeholder: "描述", minHeight: 80)
                    }

                    // Detailed description
                    fieldGroup(label: "详细描述") {
                        markdownField(text: $detailedDescription, field: "detailedDescription", placeholder: "详细描述", minHeight: 120)
                    }

                    // Notes
                    fieldGroup(label: "备注") {
                        markdownField(text: $notes, field: "notes", placeholder: "备注", minHeight: 80)
                    }
                }
                .padding(20)
            }

            // Save bar
            if hasChanges {
                Divider()
                HStack {
                    Spacer()
                    Button("还原") {
                        loadValues()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        saveChanges()
                    } label: {
                        Text("保存")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AnyShapeStyle(brandGradient))
                    )
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .onAppear { loadValues() }
        .onChange(of: issue.id) { loadValues() }
        .onChange(of: focusedField) { _, newValue in
            if newValue == nil { editingField = nil }
        }
        .sheet(isPresented: $showAddChild) {
            AddIssueSheet(agents: agents, parentId: issue.issueId) { child in
                onAddChild(child)
            }
        }
    }

    // MARK: - Markdown / raw toggle field

    /// Shows rendered markdown by default; switches to raw TextEditor on click.
    @ViewBuilder
    func markdownField(text: Binding<String>, field: String, placeholder: String, minHeight: CGFloat) -> some View {
        if editingField == field {
            TextEditor(text: text)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(10)
                .background(inputBackground)
                .focused($focusedField, equals: field)
                .onAppear { focusedField = field }
        } else {
            Group {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(markdownAttributed(text.wrappedValue))
                        .font(.callout)
                        .textSelection(.disabled)
                }
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(10)
            .background(inputBackground)
            .contentShape(Rectangle())
            .onTapGesture { editingField = field }
        }
    }

    func markdownAttributed(_ source: String) -> AttributedString {
        let normalized = source.replacingOccurrences(of: "\n", with: "\n\n")
        return (try? AttributedString(markdown: normalized)) ?? AttributedString(source)
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

    func loadValues() {
        title = issue.title
        description = issue.description ?? ""
        detailedDescription = issue.detailedDescription ?? ""
        notes = issue.notes ?? ""
        personInCharge = issue.personInCharge
        participants = Set(issue.participants)
        editingField = nil
    }

    func saveChanges() {
        let updated = TemplateIssue(
            issueId: issue.issueId,
            title: title,
            description: description.isEmpty ? nil : description,
            detailedDescription: detailedDescription.isEmpty ? nil : detailedDescription,
            personInCharge: personInCharge,
            participants: Array(participants),
            isDone: issue.isDone,
            notes: notes.isEmpty ? nil : notes,
            parentIssue: issue.parentIssue,
            children: issue.children
        )
        onSave(updated)
    }
}

// MARK: - Add issue sheet

struct AddIssueSheet: View {
    let agents: [ProjectAgent]
    let parentId: String?
    let onAdded: (TemplateIssue) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var personInCharge = ""
    @State private var participants: Set<String> = []

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

    var canCreate: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(parentId != nil ? "添加子任务" : "添加任务")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("标题").font(.callout.bold())
                TextField("任务标题", text: $title)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(inputBackground)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("负责人").font(.callout.bold())
                Picker("负责人", selection: $personInCharge) {
                    Text("未分配").tag("")
                    ForEach(agents) { agent in
                        Text(agent.name).tag(agent.name)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("参与者").font(.callout.bold())
                let available = agents.filter { $0.name != personInCharge }
                if available.isEmpty {
                    Text("暂无可选智能体")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(available) { agent in
                            let isOn = participants.contains(agent.name)
                            Button {
                                if isOn { participants.remove(agent.name) }
                                else { participants.insert(agent.name) }
                            } label: {
                                Text(agent.name)
                                    .font(.callout)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isOn
                                                  ? AnyShapeStyle(brandGradient)
                                                  : AnyShapeStyle(Color(NSColor.controlBackgroundColor)))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                            )
                                    )
                                    .foregroundStyle(isOn ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("描述").font(.callout.bold())
                TextField("可选描述", text: $description)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(inputBackground)
            }

            Spacer()

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("取消").padding(.horizontal, 20).padding(.vertical, 9)
                }
                .buttonStyle(.bordered)

                Button {
                    let issue = TemplateIssue(
                        issueId: UUID().uuidString,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description.isEmpty ? nil : description,
                        detailedDescription: nil,
                        personInCharge: personInCharge,
                        participants: Array(participants),
                        isDone: false,
                        notes: nil,
                        parentIssue: parentId,
                        children: nil
                    )
                    onAdded(issue)
                    dismiss()
                } label: {
                    Text("添加").padding(.horizontal, 20).padding(.vertical, 9)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(!canCreate
                              ? AnyShapeStyle(Color.secondary.opacity(0.3))
                              : AnyShapeStyle(brandGradient))
                )
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .disabled(!canCreate)
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
}

// MARK: - Flow layout (wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
