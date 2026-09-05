//
//  StatusFilterBar.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct StatusFilterBar: View {
    @Binding var selection: TaskStatus
    let count: (TaskStatus) -> Int
    let onDrop: (UUID, TaskStatus) -> Void

    @State private var targeted: TaskStatus?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TaskStatus.allCases) { status in
                chip(for: status)
            }
        }
    }

    private func chip(for status: TaskStatus) -> some View {
        let isSelected = status == selection
        let isTargeted = targeted == status

        return Button {
            selection = status
        } label: {
            HStack(spacing: 5) {
                Text(status.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(count(status), format: .number)
                    .opacity(isSelected ? 0.8 : 0.6)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? status.tint : Color.primary.opacity(0.06), in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(status.tint, lineWidth: 2)
                    .opacity(isTargeted ? 1 : 0)
            }
            .scaleEffect(isTargeted ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .onDrop(of: [.text], delegate: MoveDropDelegate(
            onDrop: { id in onDrop(id, status) },
            onTargeted: { hovering in targeted = hovering ? status : nil }
        ))
    }
}

#Preview {
    StatusFilterBar(selection: .constant(.todo), count: { _ in 3 }, onDrop: { _, _ in })
        .padding()
}
