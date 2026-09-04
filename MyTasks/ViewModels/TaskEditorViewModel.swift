//
//  TaskEditorViewModel.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import Foundation

/// Holds the draft of a task while the editor sheet is open, so the list
/// only sees the change once it is saved. Status is not part of the draft —
/// the cards move tasks around, the editor only touches the text.
@Observable
final class TaskEditorViewModel {
    var title: String
    var details: String

    let isNew: Bool

    private let original: Task

    init(task: Task, isNew: Bool) {
        original = task
        title = task.title
        details = task.details
        self.isNew = isNew
    }

    var screenTitle: String { isNew ? "New Task" : "Edit Task" }

    var canSave: Bool { !title.trimmed.isEmpty }

    func makeTask() -> Task {
        var edited = original
        edited.title = title.trimmed
        edited.details = details.trimmed
        return edited
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
