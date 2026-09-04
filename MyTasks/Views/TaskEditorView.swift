//
//  TaskEditorView.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import SwiftUI

struct TaskEditorView: View {
    @State private var viewModel: TaskEditorViewModel
    @FocusState private var titleFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private let onSave: (Task) -> Void

    init(task: Task, isNew: Bool, onSave: @escaping (Task) -> Void) {
        _viewModel = State(initialValue: TaskEditorViewModel(task: task, isNew: isNew))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $viewModel.title)
                    .focused($titleFocused)

                TextField("Description", text: $viewModel.details, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(viewModel.makeTask())
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .onAppear { titleFocused = viewModel.isNew }
        }
    }
}

#Preview {
    TaskEditorView(task: Task(), isNew: true) { _ in }
}
