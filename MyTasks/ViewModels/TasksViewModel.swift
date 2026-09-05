//
//  TasksViewModel.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import Foundation

@MainActor
@Observable
final class TasksViewModel {
    private(set) var tasks: [Task] = []

    private let repository: TaskRepository
    private let sync: SyncEngine

    /// The board as it was last written down, so a save can work out what
    /// actually changed and queue only that.
    private var lastPersisted: [UUID: Task] = [:]

    /// The board the app runs on: the store on disk and whatever service is
    /// configured. A factory rather than default arguments, because those are
    /// evaluated outside the main actor and cannot reach either of them.
    static func live() -> TasksViewModel {
        TasksViewModel(
            repository: SwiftDataTaskRepository.shared,
            remote: FirebaseRemote.service()
        )
    }

    init(repository: TaskRepository, remote: RemoteTaskService) {
        self.repository = repository
        sync = SyncEngine(repository: repository, remote: remote)
        tasks = repository.load()
        lastPersisted = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        sync.delegate = self
    }

    /// Called when the board appears. Idempotent.
    func start() {
        queueUnsentWork()
        sync.start()
    }

    /// Work the store still has as unsent with nothing queued against it —
    /// a board carried over from an older version, or edits made before a
    /// service was configured. Without this it would sit here for good.
    private func queueUnsentWork() {
        guard sync.isRemoteConfigured else { return }

        let queued = Set(repository.pendingOperations().map(\.taskID))
        for task in tasks where task.syncState != .synced && !queued.contains(task.id) {
            sync.enqueue(PendingOperation(kind: .create, task: task, taskID: task.id))
        }
    }

    var isEmpty: Bool { tasks.isEmpty }

    // MARK: - Sync, as the views need to see it

    var syncStatus: SyncEngine.Status { sync.status }
    var pendingCount: Int { sync.pendingCount }
    var loadFailure: String? { sync.loadFailure }
    var lastSyncedAt: Date? { sync.lastSyncedAt }
    var syncNotice: SyncNotice? { sync.notice }

    func retrySync() { sync.retryNow() }

    /// Pull to refresh.
    func refresh() async { await sync.refresh() }

    /// Tasks of one status, in board order.
    func tasks(in status: TaskStatus) -> [Task] {
        tasks.filter { $0.status == status }
    }

    // MARK: - Editing

    func add(_ task: Task) {
        tasks.append(task)
        persist()
    }

    func update(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        let previousStatus = tasks[index].status
        tasks[index] = task
        tasks[index].updatedAt = Date()
        persist()

        // Editing the status in the sheet is a move: the task belongs at the
        // bottom of the list it has just joined, not wherever it used to sit.
        if previousStatus != task.status {
            drop(task.id, above: nil, in: task.status)
        }
    }

    func delete(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    /// What the arrow button on a card does.
    func advance(_ task: Task) {
        guard let next = task.status.next else { return }
        move(task, to: next)
    }

    /// Moves a task to another status and drops it at the bottom of it.
    func move(_ task: Task, to status: TaskStatus) {
        guard task.status != status else { return }
        drop(task.id, above: nil, in: status)
    }

    func drop(_ id: UUID, above target: Task?, in status: TaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == id }), id != target?.id else { return }

        var moved = tasks.remove(at: index)
        if moved.status != status {
            moved.status = status
            moved.updatedAt = Date()
        }

        if let target, let targetIndex = tasks.firstIndex(where: { $0.id == target.id }) {
            tasks.insert(moved, at: targetIndex)
        } else if let lastInStatus = tasks.lastIndex(where: { $0.status == status }) {
            tasks.insert(moved, at: lastInStatus + 1)
        } else {
            tasks.append(moved)
        }

        persist()
    }

    // MARK: - Writing it down

    /// Saves the board and queues whatever the service has not been told yet.
    /// Local storage is written first, so a change is safe on the device before
    /// anything is attempted over the network.
    private func persist() {
        for index in tasks.indices {
            tasks[index].order = index
        }

        // With no service configured there is nothing to be pending for, so
        // the board is simply saved and every task reads as settled.
        guard sync.isRemoteConfigured else {
            for index in tasks.indices {
                tasks[index].syncState = .synced
            }
            repository.save(tasks)
            lastPersisted = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
            return
        }

        var queued: [PendingOperation] = []

        for index in tasks.indices {
            let task = tasks[index]
            if let previous = lastPersisted[task.id] {
                guard previous.differsRemotely(from: task) else { continue }
                tasks[index].syncState = .pending
                queued.append(PendingOperation(kind: .update, task: tasks[index], taskID: task.id))
            } else {
                tasks[index].syncState = .pending
                queued.append(PendingOperation(kind: .create, task: tasks[index], taskID: task.id))
            }
        }

        let liveIDs = Set(tasks.map(\.id))
        for id in lastPersisted.keys where !liveIDs.contains(id) {
            queued.append(PendingOperation(kind: .delete, task: nil, taskID: id))
        }

        repository.save(tasks)
        lastPersisted = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        for operation in queued {
            sync.enqueue(operation)
        }
    }

    /// Saves without queueing anything — used when the change came *from* the
    /// service, which obviously does not need telling about it.
    private func persistWithoutQueueing() {
        for index in tasks.indices {
            tasks[index].order = index
        }
        repository.save(tasks)
        lastPersisted = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }

    private func setState(_ state: SyncState, for ids: [UUID]) {
        let wanted = Set(ids)
        for index in tasks.indices where wanted.contains(tasks[index].id) {
            tasks[index].syncState = state
        }
        repository.save(tasks)
    }
}

// MARK: - SyncEngineDelegate

extension TasksViewModel: SyncEngineDelegate {
    /// Merges the service's board into this one. A task with local changes
    /// still in the queue keeps them: unsent work is never overwritten by a
    /// fetch.
    func syncEngine(_ engine: SyncEngine, didFetch remoteTasks: [Task]) {
        let unsent = Set(repository.pendingOperations().map(\.taskID))
        let remoteByID = Dictionary(remoteTasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var merged: [Task] = []

        for task in tasks {
            if unsent.contains(task.id) || task.syncState != .synced {
                // Ours. The service has never acknowledged this one, so its
                // absence from the fetch says nothing about it.
                merged.append(task)
            } else if let fresh = remoteByID[task.id] {
                merged.append(fresh)                      // theirs, we agree
            }
            // Only a task the service once had can be treated as deleted there.
        }

        let known = Set(merged.map(\.id))
        merged.append(contentsOf: remoteTasks.filter { !known.contains($0.id) })
        merged.sort { $0.order < $1.order }

        tasks = merged
        persistWithoutQueueing()
    }

    func syncEngine(_ engine: SyncEngine, didSync taskIDs: [UUID]) {
        setState(.synced, for: taskIDs)
    }

    func syncEngine(_ engine: SyncEngine, didFailToSync taskIDs: [UUID]) {
        setState(.failed, for: taskIDs)
    }
}
