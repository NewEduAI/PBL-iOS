//
//  ProjectCardStudent.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import SwiftUI

struct ProjectCardStudent: View {
    let assignment: StudentAssignment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(assignment.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(assignment.groupId == nil ? "尚未开始" : "进行中")
                    .font(.caption)
                    .foregroundStyle(assignment.groupId == nil ? .secondary : Color.blue)
            }

            Text(assignment.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
