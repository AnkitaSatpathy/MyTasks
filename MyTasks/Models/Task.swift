//
//  Task.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import Foundation

struct Task: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var details: String
    var status: TaskStatus
    let createdAt: Date
    var updatedAt: Date
    /// Position on the board. Carried on the task so a reorder is a change the
    /// service can be told about, like any other.
    var order: Int = 0
    /// Local bookkeeping: where this task stands with the service. It is never
    /// encoded, so it is not sent to the remote and not read back from it.
    var syncState: SyncState = .pending

    private enum CodingKeys: String, CodingKey {
        case id, title, details, status, createdAt, updatedAt, order
    }

    /// Everything the service needs to agree on. Excludes the local-only
    /// bookkeeping, so re-saving an unchanged task queues nothing.
    func differsRemotely(from other: Task) -> Bool {
        title != other.title
            || details != other.details
            || status != other.status
            || order != other.order
    }

    init(title: String = "", details: String = "", status: TaskStatus = .todo) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.status = status
        self.createdAt = Date()
        self.updatedAt = createdAt
    }

    /// Rebuilds a task that already exists. The store uses this to hand back a
    /// row with its original id and dates intact.
    init(
        id: UUID,
        title: String,
        details: String,
        status: TaskStatus,
        createdAt: Date,
        updatedAt: Date,
        order: Int = 0,
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.order = order
        self.syncState = syncState
    }
}
