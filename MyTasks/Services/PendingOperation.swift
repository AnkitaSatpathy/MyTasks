//
//  PendingOperation.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 05/09/26.
//

import Foundation
import SwiftData

/// One change waiting to reach the service.
///
/// The outbox is the whole offline story: an edit is written to SwiftData and
/// an operation is queued in the same transaction, so a change survives a
/// crash, a force quit or a flat battery and is replayed when the network
/// comes back.
struct PendingOperation: Identifiable, Equatable {
    enum Kind: String, Codable {
        case create
        case update
        case delete
    }

    let id: UUID
    let taskID: UUID
    var kind: Kind
    /// The task as it should end up remotely. `nil` for a delete.
    var task: Task?
    var queuedAt: Date
    var attempts: Int
    var lastError: String?

    init(kind: Kind, task: Task?, taskID: UUID, queuedAt: Date = Date()) {
        id = UUID()
        self.kind = kind
        self.task = task
        self.taskID = taskID
        self.queuedAt = queuedAt
        attempts = 0
        lastError = nil
    }

    /// Rebuilt from its row. The id has to come back with it — it is what
    /// identifies the row to update or clear once the service has answered.
    init(
        id: UUID,
        kind: Kind,
        task: Task?,
        taskID: UUID,
        queuedAt: Date,
        attempts: Int,
        lastError: String?
    ) {
        self.id = id
        self.kind = kind
        self.task = task
        self.taskID = taskID
        self.queuedAt = queuedAt
        self.attempts = attempts
        self.lastError = lastError
    }
}

/// The SwiftData row behind a `PendingOperation`.
@Model
final class StoredOperation {
    var id: UUID
    var taskID: UUID
    var kindRaw: String
    /// The task encoded as JSON, so the queue does not depend on the board.
    var payload: Data?
    var queuedAt: Date
    var attempts: Int
    var lastError: String?

    init(_ operation: PendingOperation) {
        id = operation.id
        taskID = operation.taskID
        kindRaw = operation.kind.rawValue
        payload = operation.task.flatMap { try? JSONEncoder().encode($0) }
        queuedAt = operation.queuedAt
        attempts = operation.attempts
        lastError = operation.lastError
    }

    var operation: PendingOperation? {
        guard let kind = PendingOperation.Kind(rawValue: kindRaw) else { return nil }

        return PendingOperation(
            id: id,
            kind: kind,
            task: payload.flatMap { try? JSONDecoder().decode(Task.self, from: $0) },
            taskID: taskID,
            queuedAt: queuedAt,
            attempts: attempts,
            lastError: lastError
        )
    }

    func apply(_ operation: PendingOperation) {
        kindRaw = operation.kind.rawValue
        payload = operation.task.flatMap { try? JSONEncoder().encode($0) }
        attempts = operation.attempts
        lastError = operation.lastError
    }
}
