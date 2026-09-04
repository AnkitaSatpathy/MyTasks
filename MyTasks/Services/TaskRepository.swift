//
//  TaskRepository.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 04/09/26.
//

import Foundation

protocol TaskRepository {
    func load() -> [Task]
    func save(_ tasks: [Task])
}

struct JSONTaskRepository: TaskRepository {
    private let fileURL: URL

    init(filename: String = "tasks.json") {
        fileURL = URL.documentsDirectory.appending(path: filename)
    }

    func load() -> [Task] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        do {
            return try JSONDecoder().decode([Task].self, from: data)
        } catch {
            print("Could not read tasks: \(error)")
            return []
        }
    }

    func save(_ tasks: [Task]) {
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Could not save tasks: \(error)")
        }
    }
}

/// Used by the SwiftUI previews so they never write to disk.
final class InMemoryTaskRepository: TaskRepository {
    private var tasks: [Task]

    init(tasks: [Task] = []) {
        self.tasks = tasks
    }

    func load() -> [Task] { tasks }

    func save(_ tasks: [Task]) { self.tasks = tasks }
}
