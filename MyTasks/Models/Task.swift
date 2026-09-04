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

    init(title: String = "", details: String = "", status: TaskStatus = .todo) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.status = status
        self.createdAt = Date()
        self.updatedAt = createdAt
    }
}
