//
//  TasksViewModel.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import Foundation

@Observable
final class TasksViewModel {
    private(set) var tasks: [Task] = []

    private let repository: TaskRepository

    init(repository: TaskRepository = SwiftDataTaskRepository.shared) {
        self.repository = repository
        tasks = repository.load()
    }

    var isEmpty: Bool { tasks.isEmpty }

    /// Tasks of one status, in board order.
    func tasks(in status: TaskStatus) -> [Task] {
        tasks.filter { $0.status == status }
    }

    func add(_ task: Task) {
        tasks.append(task)
        persist()
    }

    func update(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        tasks[index].updatedAt = Date()
        persist()
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

    private func persist() {
        repository.save(tasks)
    }
}
