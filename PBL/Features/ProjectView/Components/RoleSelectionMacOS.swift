//
//  RoleSelectionMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI

// MARK: - Role metadata

private struct RoleMeta {
    let icon: String
    let color: Color
    let description: String
}

private func roleMeta(for title: String) -> RoleMeta {
    if title.contains("开发") { return RoleMeta(icon: "chevron.left.forwardslash.chevron.right", color: Color(red: 59/255,  green: 130/255, blue: 246/255), description: "负责系统功能的设计、实现与迭代，主导技术架构决策") }
    if title.contains("设计") { return RoleMeta(icon: "swatchpalette.fill",                    color: Color(red: 168/255, green: 85/255,  blue: 247/255), description: "负责用户体验与界面设计，产出交互原型和视觉规范") }
    if title.contains("测试") { return RoleMeta(icon: "checkmark.shield.fill",                  color: Color(red: 34/255,  green: 197/255, blue: 94/255),  description: "负责制定测试计划、执行测试用例，保障交付质量") }
    if title.contains("管理") { return RoleMeta(icon: "person.badge.shield.checkmark.fill",     color: Color(red: 249/255, green: 115/255, blue: 22/255),  description: "负责项目进度把控、团队协调与风险管理") }
    return RoleMeta(icon: "person.fill", color: .indigo, description: "项目团队成员")
}

// MARK: - Main view

struct RoleSelectionMacOS: View {
    let groupId: String
    let onRoleSelected: () -> Void

    @Environment(AppState.self) private var appState

    @State private var members: [GroupMember] = []
    @State private var isLoading = true
    @State private var isConfirming = false
    @State private var selectedMember: GroupMember? = nil
    @State private var error: String? = nil

    var managementRoles: [GroupMember] { members.filter { $0.roleDivision == "management" } }
    var developmentRoles: [GroupMember] { members.filter { $0.roleDivision == "development" } }

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 98/255, green: 83/255, blue: 225/255),
                Color(red: 4/255, green: 190/255, blue: 254/255)
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("MAIC-PBL")
                    .font(.system(size: 13, weight: .bold))
                    .italic()
                    .foregroundStyle(brandGradient)
                Text("选择角色")
                    .font(.system(size: 28, weight: .bold))
                Text("选择你在本项目中扮演的角色以开始协作")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 28)

            Divider()

            // Role list
            if isLoading {
                Spacer()
                ProgressView("加载角色…").controlSize(.large)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if !developmentRoles.isEmpty {
                            sectionLabel("可选角色")
                            ForEach(developmentRoles) { member in
                                RoleRow(
                                    member: member,
                                    isSelected: selectedMember?.id == member.id
                                ) {
                                    if !member.isAssigned {
                                        selectedMember = (selectedMember?.id == member.id) ? nil : member
                                    }
                                }
                                Divider().padding(.leading, 68)
                            }
                        }

                        if !managementRoles.isEmpty {
                            sectionLabel("指导教师")
                            ForEach(managementRoles) { member in
                                RoleRow(member: member, isSelected: false, onTap: nil)
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .padding(.bottom, 80) // room for the bottom bar
                }

                if let err = error {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                }
            }

            // Bottom action bar
            Divider()
            HStack {
                if let selected = selectedMember {
                    HStack(spacing: 6) {
                        Image(systemName: roleMeta(for: selected.actorDescription).icon)
                            .foregroundStyle(roleMeta(for: selected.actorDescription).color)
                            .symbolRenderingMode(.hierarchical)
                        Text("已选择：\(selected.actorName)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                } else {
                    Text("点击上方一个可用角色以选择")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    Task { await confirmSelection() }
                } label: {
                    HStack(spacing: 6) {
                        if isConfirming {
                            ProgressView().controlSize(.small)
                        }
                        Text(selectedMember != nil
                             ? "以 \(selectedMember!.actorName) 进入"
                             : "选择一个角色")
                        Image(systemName: "arrow.right")
                            .font(.callout.bold())
                    }
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedMember != nil
                                  ? AnyShapeStyle(brandGradient)
                                  : AnyShapeStyle(Color.secondary.opacity(0.3)))
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedMember == nil || isConfirming)
                .animation(.easeInOut(duration: 0.15), value: selectedMember?.id)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .animation(.easeInOut(duration: 0.2), value: selectedMember?.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task { await loadMembers() }
    }

    @ViewBuilder
    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    // MARK: - Actions

    func loadMembers() async {
        isLoading = true
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            members = try await api.getGroupMembers(groupId: groupId)
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func confirmSelection() async {
        guard let member = selectedMember, !member.isAssigned else { return }
        isConfirming = true
        error = nil
        let api = ProjectAPI(baseURL: appState.organizationBaseUrl, token: appState.token)
        do {
            try await api.selectRole(
                groupId: groupId,
                actorId: member.actorId,
                userId: appState.userId,
                userName: appState.username
            )
            onRoleSelected()
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        isConfirming = false
    }
}

// MARK: - Role row

private struct RoleRow: View {
    let member: GroupMember
    let isSelected: Bool
    let onTap: (() -> Void)?

    @State private var isHovered = false

    var meta: RoleMeta { roleMeta(for: member.actorDescription) }
    var selectable: Bool { onTap != nil && !member.isAssigned }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(meta.color.opacity(selectable ? 0.12 : 0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: meta.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(selectable ? meta.color : meta.color.opacity(0.4))
                    .symbolRenderingMode(.hierarchical)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(member.actorName)
                        .font(.callout.bold())
                        .foregroundStyle(selectable ? .primary : .secondary)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(meta.color)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(member.actorDescription.isEmpty ? meta.description : member.actorDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status
            if member.isAssigned {
                Label("已占用", systemImage: "person.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
            } else if onTap != nil {
                Text("可选择")
                    .font(.caption.bold())
                    .foregroundStyle(meta.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(meta.color.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                Label("教师", systemImage: "graduationcap.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 99/255, green: 102/255, blue: 241/255))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 99/255, green: 102/255, blue: 241/255).opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            isSelected
            ? meta.color.opacity(0.06)
            : (isHovered && selectable ? Color.primary.opacity(0.03) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .grayscale(member.isAssigned ? 0.5 : 0)
    }
}
