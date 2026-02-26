//
//  IssueBoardMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI

struct IssueBoardMacOS: View {
    let groupId: String
    let initialIssues: [Issue]
    /// issueId → isActivated, from the parent. Empty = treat all as unlocked.
    var activationStatus: [String: Bool] = [:]
    let onIssueUpdated: () -> Void

    @Environment(AppState.self) private var appState

    @State private var issues: [Issue] = []
    @State private var isLoading = false
    @State private var selectedIssue: Issue? = nil
    @State private var updatingIds: Set<String> = []

    var totalStats: (total: Int, done: Int) {
        issues.reduce((total: 0, done: 0)) { acc, issue in
            let s = issue.progressStats
            return (total: acc.total + s.total, done: acc.done + s.done)
        }
    }

    /// True when the root issue owning the selected issue is locked.
    var selectedIssueLocked: Bool {
        guard let sel = selectedIssue, !activationStatus.isEmpty else { return false }
        for root in issues {
            if issueTree(root, contains: sel.issueId) {
                return !(activationStatus[root.issueId] ?? false)
            }
        }
        return false
    }

    func isRootLocked(_ issue: Issue) -> Bool {
        activationStatus.isEmpty ? false : !(activationStatus[issue.issueId] ?? false)
    }

    func issueTree(_ issue: Issue, contains id: String) -> Bool {
        issue.issueId == id || (issue.children ?? []).contains { issueTree($0, contains: id) }
    }

    var body: some View {
        HStack(spacing: 0) {
            issueList
            if let issue = selectedIssue {
                Divider()
                issueDetail(issue)
                    .frame(width: 280)
            }
        }
        .onAppear {
            issues = initialIssues
        }
        .onChange(of: initialIssues) { _, newValue in issues = newValue }
    }

    // MARK: - Issue list

    var issueList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with progress
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("任务板")
                        .font(.title3.bold())
                    if totalStats.total > 0 {
                        Text("\(totalStats.done) / \(totalStats.total) 已完成")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isLoading {
                    ProgressView().controlSize(.small)
                }

                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
                .help("刷新任务板")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Progress bar
            if totalStats.total > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 4)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 98/255, green: 83/255, blue: 225/255),
                                        Color(red: 4/255, green: 190/255, blue: 254/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * CGFloat(totalStats.done) / CGFloat(totalStats.total),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Divider()

            // Column header — matches row column positions
            if !issues.isEmpty {
                HStack(spacing: 0) {
                    Spacer().frame(width: 60)  // Reserve left area (indent+chevron+checkbox)
                    Text("任务").font(.caption.bold()).foregroundStyle(.tertiary)
                    Spacer()
                    Text("负责人").font(.caption.bold()).foregroundStyle(.tertiary).frame(width: 80, alignment: .leading)
                    Text("参与者").font(.caption.bold()).foregroundStyle(.tertiary).frame(width: 100, alignment: .leading)
                    Text("进度").font(.caption.bold()).foregroundStyle(.tertiary).frame(width: 36, alignment: .trailing).padding(.trailing, 12)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.primary.opacity(0.03))
                Divider()
            }

            if issues.isEmpty && !isLoading {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(issues) { issue in
                            IssueRowView(
                                issue: issue,
                                depth: 0,
                                isUpdating: updatingIds.contains(issue.issueId),
                                isSelected: selectedIssue?.id == issue.id,
                                isLocked: isRootLocked(issue),
                                currentUsername: appState.username,
                                onToggle: { issue in Task { await toggleIssue(issue) } },
                                onSelect: { selectedIssue = $0 }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(groupId.isEmpty ? "加入项目后可查看任务板" : "暂无任务")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Issue detail panel

    @ViewBuilder
    func issueDetail(_ issue: Issue) -> some View {
        let isLocked = selectedIssueLocked
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("任务详情")
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    selectedIssue = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status toggle
                    let canToggle = issue.personInCharge == appState.username
                    HStack(spacing: 8) {
                        Button {
                            Task { await toggleIssue(issue) }
                        } label: {
                            Image(systemName: issue.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(issue.isDone ? Color.green : (canToggle ? Color.secondary : Color.primary.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                        .disabled(updatingIds.contains(issue.issueId) || !canToggle || isLocked)

                        Text(issue.isDone ? "已完成" : (canToggle ? "标记完成" : "未完成"))
                            .font(.callout)
                            .foregroundStyle(issue.isDone ? .green : .secondary)
                    }

                    // Title
                    Text(issue.title)
                        .font(.headline)

                    // Assignee
                    if let person = issue.personInCharge, !person.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle")
                                .foregroundStyle(.secondary)
                            Text(person)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Description / locked state
                    if isLocked {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("该任务的指导内容是锁定的，请先完成前一阶段的学习")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        if let desc = issue.description, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("描述")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                                Text(desc)
                                    .font(.callout)
                            }
                        }

                        if let detail = issue.detailedDescription, !detail.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("详细说明")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                                Text(detail)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let parts = issue.participants, !parts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("参与者")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                                FlowLayout(spacing: 4) {
                                    ForEach(parts, id: \.self) { name in
                                        Text(name)
                                            .font(.caption)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color.accentColor.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        if let notes = issue.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("备注")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                                Text(notes)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Children
                    if let children = issue.children, !children.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("子任务 (\(children.filter(\.isDone).count)/\(children.count))")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)

                            ForEach(children) { child in
                                HStack(spacing: 8) {
                                    Image(systemName: child.isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.caption)
                                        .foregroundStyle(child.isDone ? .green : .secondary)
                                    Text(child.title)
                                        .font(.caption)
                                        .strikethrough(child.isDone)
                                        .foregroundStyle(child.isDone ? .secondary : .primary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions

    func reload() async {
        guard !groupId.isEmpty else { return }
        isLoading = true
        let api = IssueAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            issues = try await api.getIssues(groupId: groupId, userId: appState.userId)
            onIssueUpdated()
        } catch {}
        isLoading = false
    }

    func toggleIssue(_ issue: Issue) async {
        guard !updatingIds.contains(issue.issueId),
              issue.personInCharge == appState.username else { return }
        updatingIds.insert(issue.issueId)
        let api = IssueAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            try await api.updateIssue(
                issueBoardId: issue.issueBoardId,
                groupId: groupId,
                issueId: issue.issueId,
                isDone: !issue.isDone
            )
            await reload()
            if selectedIssue?.id == issue.id {
                selectedIssue = issues.flatMap { flatIssues($0) }.first { $0.id == issue.id }
            }
        } catch {}
        updatingIds.remove(issue.issueId)
    }

    func flatIssues(_ issue: Issue) -> [Issue] {
        [issue] + (issue.children ?? []).flatMap { flatIssues($0) }
    }
}

// MARK: - Issue row view

private struct IssueRowView: View {
    let issue: Issue
    let depth: Int
    let isUpdating: Bool
    let isSelected: Bool
    let isLocked: Bool
    let currentUsername: String
    let onToggle: (Issue) -> Void
    let onSelect: (Issue) -> Void

    @State private var isExpanded = true
    @State private var isHovered = false

    var hasChildren: Bool { !(issue.children ?? []).isEmpty }
    var canToggle: Bool { issue.personInCharge == currentUsername }

    @ViewBuilder
    func participantsLabel(_ participants: [String]?, isLocked: Bool) -> some View {
        if !isLocked, let parts = participants, !parts.isEmpty {
            let names = Array(parts.prefix(2)).joined(separator: "、")
            let suffix = parts.count > 2 ? " +\(parts.count - 2)" : ""
            Text(names + suffix)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // INNER HStack: content without padding (so we can control it externally)
            HStack(spacing: 0) {
                // LEFT: Tree controls (indent + chevron + checkbox) — 60px fixed
                HStack(spacing: 0) {
                    Rectangle().fill(.clear).frame(width: CGFloat(depth) * 20)
                    Button {
                        if hasChildren { isExpanded.toggle() }
                    } label: {
                        if hasChildren {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary).frame(width: 16)
                        } else {
                            Rectangle().fill(.clear).frame(width: 16)
                        }
                    }
                    .buttonStyle(.plain)
                    Button {
                        onToggle(issue)
                    } label: {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16)).foregroundStyle(.secondary)
                        } else if isUpdating {
                            ProgressView().controlSize(.mini).frame(width: 20, height: 20)
                        } else {
                            Image(systemName: issue.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundStyle(issue.isDone ? Color.green : (canToggle ? Color.secondary : Color.primary.opacity(0.25)))
                        }
                    }
                    .buttonStyle(.plain).disabled(isLocked || (!canToggle && !issue.isDone))
                }
                .frame(width: 60)

                // MIDDLE: Title + description
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title)
                        .font(.callout).strikethrough(issue.isDone)
                        .foregroundStyle(issue.isDone ? .secondary : .primary).lineLimit(1)
                    if !isLocked, let desc = issue.description, !desc.isEmpty {
                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }

                Spacer()  // Push right columns to edge like header does

                // RIGHT COLUMNS: 负责人 | 参与者 | 进度
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .frame(width: 80, alignment: .center)
                } else if let person = issue.personInCharge, !person.isEmpty {
                    Text(person).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        .frame(width: 80, alignment: .leading)
                } else {
                    Rectangle().fill(.clear).frame(width: 80)
                }

                participantsLabel(issue.participants, isLocked: isLocked)
                    .frame(width: 100, alignment: .leading)

                if hasChildren, let children = issue.children {
                    let done = children.filter(\.isDone).count
                    Text("\(done)/\(children.count)").font(.caption2).foregroundStyle(.tertiary)
                        .monospacedDigit().frame(width: 36, alignment: .trailing)
                } else {
                    Rectangle().fill(.clear).frame(width: 36)
                }

                Rectangle().fill(.clear).frame(width: 12)  // Match .padding(.trailing, 12) from header
            }
            .padding(.horizontal, 8).padding(.vertical, 7)  // SAME padding as header
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.1)
                          : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
            .onTapGesture { onSelect(issue) }
            .onHover { isHovered = $0 }

            // Children
            if hasChildren && isExpanded {
                ForEach(issue.children ?? []) { child in
                    IssueRowView(
                        issue: child, depth: depth + 1, isUpdating: false, isSelected: false,
                        isLocked: isLocked, currentUsername: currentUsername,
                        onToggle: onToggle, onSelect: onSelect
                    )
                }
            }
        }
    }
}

// MARK: - Flow layout for participant tags

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
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
