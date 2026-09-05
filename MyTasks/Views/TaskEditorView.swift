//
//  TaskEditorView.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

/// The task, opened for reading. Touching the title or the description turns it
/// into an editor — a finished task never does, and a new one starts that way.
struct TaskEditorView: View {
    private enum Field {
        case title
        case details
    }

    @State private var viewModel: TaskEditorViewModel
    @State private var isEditing: Bool
    @FocusState private var focused: Field?
    @Environment(\.dismiss) private var dismiss

    private let onSave: (Task) -> Void
    /// Absent for a task that does not exist yet — there is nothing to delete.
    private let onDelete: (() -> Void)?
    /// Moves the task on one step, exactly as the swipe does.
    private let onAdvance: (() -> Void)?

    init(
        task: Task,
        isNew: Bool,
        onSave: @escaping (Task) -> Void,
        onDelete: (() -> Void)? = nil,
        onAdvance: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: TaskEditorViewModel(task: task, isNew: isNew))
        _isEditing = State(initialValue: isNew)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onAdvance = onAdvance
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isEditing {
                        editableFields
                            .transition(.opacity)
                    } else {
                        readableFields
                            .transition(.opacity)
                    }
                }

                if !viewModel.isNew {
                    details
                    actions
                }
            }
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(viewModel.makeTask())
                            dismiss()
                        }
                        .disabled(!viewModel.canSave)
                    }
                }
            }
            .onAppear {
                if viewModel.isNew { focused = .title }
            }
        }
    }

    private var editableFields: some View {
        Group {
            TextField("Title", text: $viewModel.title)
                .focused($focused, equals: .title)

            TextField("Description", text: $viewModel.details, axis: .vertical)
                .lineLimit(3...8)
                .focused($focused, equals: .details)
        }
    }

    @ViewBuilder
    private var readableFields: some View {
        readableRow(Text(viewModel.title), field: .title)

        if viewModel.details.isEmpty {
            // Only worth offering on a task that can still be written to.
            if viewModel.isEditable {
                readableRow(
                    Text("Add a description").foregroundStyle(.tertiary),
                    field: .details
                )
            }
        } else {
            readableRow(
                Text(viewModel.details).foregroundStyle(.secondary),
                field: .details
            )
        }
    }

    /// The text has to fill the row before it is given a tap shape, or only the
    /// words themselves respond and the rest of the row looks broken.
    private func readableRow(_ text: Text, field: Field) -> some View {
        text
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { beginEditing(field) }
    }

    private var details: some View {
        Section("Details") {
            LabeledContent("Created", value: viewModel.createdAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Last updated", value: viewModel.updatedAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Sync", value: syncDescription)
        }
    }

    /// Delete on the left, move on to the right — the same pair, and the same
    /// colours, as the swipe actions on the card.
    private var actions: some View {
        Section {
            HStack(spacing: 12) {
                Button(role: .destructive, action: delete) {
                    actionLabel("Delete", systemImage: "trash.fill", tint: .red, filled: false)
                }
                .buttonStyle(.plain)

                if let next = viewModel.nextStatus {
                    Button { advance() } label: {
                        actionLabel(next.title, systemImage: "arrow.right", tint: next.tint, filled: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    /// The frame belongs to the label, not the button: put it on the button and
    /// the row stops taking taps.
    private func actionLabel(
        _ title: String,
        systemImage: String,
        tint: Color,
        filled: Bool
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(filled ? Color.primary : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(filled ? tint : tint.opacity(0.12), in: .rect(cornerRadius: 12))
            .contentShape(.rect)
    }

    private func delete() {
        onDelete?()
        dismiss()
    }

    /// Moving the task on shouldn't quietly throw away text typed just before
    /// it, so any pending edit is saved first.
    private func advance() {
        if isEditing, viewModel.canSave {
            onSave(viewModel.makeTask())
        }
        onAdvance?()
        dismiss()
    }

    private func beginEditing(_ field: Field) {
        guard viewModel.isEditable else { return }

        // The row grows as the text turns into a field: let it grow rather
        // than snap.
        withAnimation(.snappy(duration: 0.28)) { isEditing = true }
        focused = field
    }

    /// On a new task there is nothing to go back to, so this closes the sheet.
    /// On an existing one it puts the draft back and returns to reading.
    private func cancel() {
        guard !viewModel.isNew else {
            dismiss()
            return
        }

        viewModel.revert()
        focused = nil
        withAnimation(.snappy(duration: 0.28)) { isEditing = false }
    }

    private var syncDescription: String {
        switch viewModel.syncState {
        case .synced: "Synced"
        case .pending: "Waiting to sync"
        case .failed: "Not synced"
        }
    }
}

#Preview("New") {
    TaskEditorView(task: Task(), isNew: true) { _ in }
}

#Preview("Existing") {
    TaskEditorView(
        task: Task(title: "Buy groceries", details: "Milk, bread, coffee.", status: .inProgress),
        isNew: false,
        onSave: { _ in },
        onDelete: {},
        onAdvance: {}
    )
}
