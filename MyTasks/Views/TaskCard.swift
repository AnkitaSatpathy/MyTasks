//
//  TaskCard.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

struct TaskCard: View {
    let task: Task
    var onTap: (() -> Void)?
    var onAdvance: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .strikethrough(task.status == .done, color: .secondary)

                    syncBadge

                    Spacer(minLength: 0)
                }

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
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.07), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move to \(next.title)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurface, in: .rect(cornerRadius: 14))
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.black.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        .contentShape(.rect)
        .onTapGesture { onTap?() }
    }

    /// Only shown when there is something to say: a task that has reached the
    /// service needs no decoration.
    @ViewBuilder
    private var syncBadge: some View {
        switch task.syncState {
        case .synced:
            EmptyView()
        case .pending:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Waiting to sync")
        case .failed:
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.caption2)
                .foregroundStyle(Color.brand)
                .accessibilityLabel("Could not sync")
        }
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
