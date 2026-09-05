//
//  TaskEditorViewModel.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import Foundation

/// Holds the draft of a task while the editor sheet is open, so the list only
/// sees the change once it is saved. Status is part of the draft too: moving a
/// task from the sheet is the same edit as renaming it, and is applied on save.
@Observable
final class TaskEditorViewModel {
    var title: String
    var details: String
    var status: TaskStatus

    let isNew: Bool

    private let original: Task

    init(task: Task, isNew: Bool) {
        original = task
        title = task.title
        details = task.details
        status = task.status
        self.isNew = isNew
    }

    var screenTitle: String { isNew ? "New Task" : "Task Details" }

    var canSave: Bool { !title.trimmed.isEmpty }

    /// A finished task is a record rather than a draft: it can be read and
    /// deleted, but not rewritten.
    var isEditable: Bool { isNew || original.status != .done }

    /// Where the task can move on to, if anywhere. Drives the button that
    /// mirrors the swipe action.
    var nextStatus: TaskStatus? { original.status.next }

    /// Throws the draft away and goes back to what the board already has.
    func revert() {
        title = original.title
        details = original.details
        status = original.status
    }

    /// What the board already knows, shown for reference rather than editing.
    var createdAt: Date { original.createdAt }
    var updatedAt: Date { original.updatedAt }
    var syncState: SyncState { original.syncState }

    func makeTask() -> Task {
        var edited = original
        edited.title = title.trimmed
        edited.details = details.trimmed
        edited.status = status
        return edited
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
