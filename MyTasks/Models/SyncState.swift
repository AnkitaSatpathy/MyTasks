//
//  SyncState.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 05/09/26.
//

import Foundation

enum SyncState: String, Codable, Sendable {
    case synced
    case pending
    case failed
}
