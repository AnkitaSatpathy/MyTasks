//
//  StoredTask.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import Foundation
import SwiftData

/// The SwiftData row behind a `Task`.
///
/// It stays inside the repository: the view models and views keep working in
/// plain `Task` values, so nothing above `TaskRepository` holds a managed
/// object. `order` carries the board arrangement, because a fetch has no
/// inherent order of its own.
@Model
final class StoredTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var status: TaskStatus
    var createdAt: Date
    var updatedAt: Date
    /// Position in the flat board array, so an arrangement survives a relaunch.
    var order: Int
    /// Survives a relaunch too, so a change queued offline is still shown as
    /// pending after the app is killed.
    var syncState: SyncState

    init(_ task: Task, order: Int) {
        id = task.id
        title = task.title
        details = task.details
        status = task.status
        createdAt = task.createdAt
        updatedAt = task.updatedAt
        syncState = task.syncState
        self.order = order
    }

    /// The value the rest of the app works in.
    var task: Task {
        Task(
            id: id,
            title: title,
            details: details,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            order: order,
            syncState: syncState
        )
    }

    func apply(_ task: Task, order: Int) {
        title = task.title
        details = task.details
        status = task.status
        updatedAt = task.updatedAt
        syncState = task.syncState
        self.order = order
    }
}
