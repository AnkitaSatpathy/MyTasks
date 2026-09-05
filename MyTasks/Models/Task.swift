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
    var order: Int = 0
    var syncState: SyncState = .pending

    private enum CodingKeys: String, CodingKey {
        case id, title, details, status, createdAt, updatedAt, order
    }

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

    init(id: UUID,
         title: String,
         details: String,
         status: TaskStatus,
         createdAt: Date,
         updatedAt: Date,
         order: Int = 0,
         syncState: SyncState = .synced) {
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
