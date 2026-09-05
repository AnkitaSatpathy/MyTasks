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

    private let context: ModelContext

    init(inMemory: Bool = false) {
        context = ModelContext(Self.makeContainer(inMemory: inMemory))
    }

    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([StoredTask.self])

        if !inMemory {
            do {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
            } catch {
                // A store that will not open should not take the app down with
                // it — carry on in memory for this launch instead.
                print("Could not open the task store, falling back to memory: \(error)")
            }
        }

        do {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: memory)
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
}
