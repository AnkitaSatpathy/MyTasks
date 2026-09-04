//
//  TaskCard.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

/// A single task: its title, its description and the arrow to the next status.
/// Tapping it opens the editor sheet; the row's swipe actions handle the rest.
struct TaskCard: View {
    let task: Task
    var onTap: (() -> Void)?
    var onAdvance: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.status == .done, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !task.details.isEmpty {
                    Text(task.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let next = task.status.next {
                Button {
                    onAdvance?()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(next.tint)
                        .frame(width: 34, height: 34)
                        .background(next.tint.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move to \(next.title)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        // The whole card opens the editor, apart from the arrow button.
        .contentShape(.rect)
        .onTapGesture { onTap?() }
    }
}

#Preview {
    VStack(spacing: 10) {
        TaskCard(task: Task(title: "Buy groceries", details: "Milk, bread, coffee."))
        TaskCard(task: Task(title: "Book the dentist"))
        TaskCard(task: Task(title: "Set up the Xcode project", status: .done))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
