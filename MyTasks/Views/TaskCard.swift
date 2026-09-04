//
//  TaskCard.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

struct TaskCard: View {
    let task: Task
    var isExpanded = false
    var title: Binding<String> = .constant("")
    var details: Binding<String> = .constant("")
    var onExpand: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onAdvance: (() -> Void)?
    var onMove: ((TaskStatus) -> Void)?
    var onDelete: (() -> Void)?

    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isExpanded {
                editor
                Divider()
                actions
            } else {
                summary
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        .onChange(of: isExpanded) { _, expanded in
            titleFocused = expanded
        }
    }

    private var summary: some View {
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
            .contentShape(.rect)
            .onTapGesture { onExpand?() }

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
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Title", text: title)
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { onSubmit?() }

            TextField("Description", text: details, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2...6)
        }
    }

    private var actions: some View {
        HStack {
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete?() }
                .tint(.red)

            Spacer()

            Menu {
                ForEach(TaskStatus.allCases.filter { $0 != task.status }) { other in
                    Button("Move to \(other.title)", systemImage: other.icon) {
                        onMove?(other)
                    }
                }
            } label: {
                Label("Move", systemImage: "arrow.left.arrow.right")
            }
        }
        .font(.subheadline)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

#Preview {
    VStack(spacing: 10) {
        TaskCard(task: Task(title: "Buy groceries", details: "Milk, bread, coffee."))
        TaskCard(
            task: Task(title: "Book the dentist", details: "Ring the surgery on Monday."),
            isExpanded: true,
            title: .constant("Book the dentist"),
            details: .constant("Ring the surgery on Monday.")
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
