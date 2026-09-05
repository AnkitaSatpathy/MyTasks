//
//  TaskRepository.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import Foundation
import SwiftData

protocol TaskRepository {
    func load() -> [Task]
    func save(_ tasks: [Task])
    func pendingOperations() -> [PendingOperation]
    func enqueue(_ operation: PendingOperation)
    func update(_ operation: PendingOperation)
    func remove(operationID: UUID)

    var isEphemeral: Bool { get }
}

extension TaskRepository {
    var isEphemeral: Bool { false }
}

/// Stores the board in SwiftData, on disk in the app's own container.
/// Nothing here touches the network, so the app works offline by default.
///
/// The board is one flat, ordered array, so every save writes each task's
/// position back to `StoredTask.order` and a load sorts by it.
struct SwiftDataTaskRepository: TaskRepository {
    /// One store for the app. A second container over the same file would only
    /// duplicate work, so the default view model shares this.
    static let shared = SwiftDataTaskRepository()

    fileprivate let context: ModelContext
    let isEphemeral: Bool

    init(inMemory: Bool = false) {
        let (container, onDisk) = Self.makeContainer(inMemory: inMemory)
        context = ModelContext(container)
        isEphemeral = !onDisk
    }

    /// Returns the container and whether it is actually backed by the disk.
    private static func makeContainer(inMemory: Bool) -> (ModelContainer, Bool) {
        let schema = Schema([StoredTask.self, StoredOperation.self])

        if !inMemory {
            do {
                return (try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema)), true)
            } catch {
                print("Could not open the task store, falling back to memory: \(error)")
            }
        }

        do {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try ModelContainer(for: schema, configurations: memory), inMemory)
        } catch {
            fatalError("Could not build the task store: \(error)")
        }
    }

    func load() -> [Task] {
        let descriptor = FetchDescriptor<StoredTask>(sortBy: [SortDescriptor(\.order)])

        do {
            let rows = try context.fetch(descriptor)
            if rows.isEmpty, let imported = LegacyJSONImport.take() {
                save(imported)
                return imported
            }
            return rows.map(\.task)
        } catch {
            print("Could not read tasks: \(error)")
            return []
        }
    }

    /// Writes the board as it now stands: existing rows are updated in place,
    /// new ones inserted, and anything no longer on the board deleted.
    func save(_ tasks: [Task]) {
        do {
            let existing = try context.fetch(FetchDescriptor<StoredTask>())
            var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            for (order, task) in tasks.enumerated() {
                if let row = byID.removeValue(forKey: task.id) {
                    row.apply(task, order: order)
                } else {
                    context.insert(StoredTask(task, order: order))
                }
            }

            // Whatever is left was removed from the board.
            for orphan in byID.values {
                context.delete(orphan)
            }

            try context.save()
        } catch {
            print("Could not save tasks: \(error)")
        }
    }
}

extension SwiftDataTaskRepository {
    func pendingOperations() -> [PendingOperation] {
        let descriptor = FetchDescriptor<StoredOperation>(sortBy: [SortDescriptor(\.queuedAt)])
        return (try? context.fetch(descriptor))?.compactMap(\.operation) ?? []
    }

    func enqueue(_ operation: PendingOperation) {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredOperation>())
            if let existing = rows.first(where: { $0.taskID == operation.taskID }) {
                if let merged = Self.merge(existing.operation, with: operation) {
                    existing.apply(merged)
                } else {
                    context.delete(existing)
                }
            } else {
                context.insert(StoredOperation(operation))
            }
            try context.save()
        } catch {
            print("Could not queue a change: \(error)")
        }
    }

    /// Folds a new change into the one already queued for that task.
    /// Returning `nil` means the pair cancels out.
    private static func merge(
        _ existing: PendingOperation?,
        with new: PendingOperation
    ) -> PendingOperation? {
        guard let existing else { return new }

        switch (existing.kind, new.kind) {
        case (.create, .delete):
            return nil
        case (.create, _):
            var merged = existing
            merged.task = new.task
            merged.attempts = 0
            merged.lastError = nil
            return merged
        default:
            var merged = new
            merged.attempts = 0
            merged.lastError = nil
            return merged
        }
    }

    func update(_ operation: PendingOperation) {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredOperation>())
            guard let row = rows.first(where: { $0.id == operation.id }) else { return }
            row.apply(operation)
            try context.save()
        } catch {
            print("Could not update a queued change: \(error)")
        }
    }

    func remove(operationID: UUID) {
        do {
            let rows = try context.fetch(FetchDescriptor<StoredOperation>())
            guard let row = rows.first(where: { $0.id == operationID }) else { return }
            context.delete(row)
            try context.save()
        } catch {
            print("Could not clear a queued change: \(error)")
        }
    }
}

/// Reads the `tasks.json` file earlier versions wrote, once, so a board built
/// before SwiftData is not lost. After that the flag keeps it out of the way —
/// without it, emptying the board would refill it on the next launch.
enum LegacyJSONImport {
    private static let flag = "didImportLegacyJSONTasks"
    private static var fileURL: URL { URL.documentsDirectory.appending(path: "tasks.json") }

    static func take() -> [Task]? {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: flag) else { return nil }
        defaults.set(true, forKey: flag)

        guard let data = try? Data(contentsOf: fileURL),
              let tasks = try? JSONDecoder().decode([Task].self, from: data),
              !tasks.isEmpty
        else { return nil }

        return tasks
    }
}

/// Used by the Xcode previews so they never touch the store.
final class InMemoryTaskRepository: TaskRepository {
    private var tasks: [Task]

    init(tasks: [Task] = []) {
        self.tasks = tasks
    }

    func load() -> [Task] { tasks }

    func save(_ tasks: [Task]) { self.tasks = tasks }

    private var queue: [PendingOperation] = []

    func pendingOperations() -> [PendingOperation] { queue }

    func enqueue(_ operation: PendingOperation) {
        if let index = queue.firstIndex(where: { $0.taskID == operation.taskID }) {
            if operation.kind == .delete, queue[index].kind == .create {
                queue.remove(at: index)
            } else if queue[index].kind == .create {
                queue[index].task = operation.task
            } else {
                queue[index] = operation
            }
        } else {
            queue.append(operation)
        }
    }

    func update(_ operation: PendingOperation) {
        guard let index = queue.firstIndex(where: { $0.id == operation.id }) else { return }
        queue[index] = operation
    }

    func remove(operationID: UUID) {
        queue.removeAll { $0.id == operationID }
    }
}
