//
//  SyncState.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 05/09/26.
//

import Foundation

/// Where a task stands with the remote service. Local edits land as `pending`
/// and only become `synced` once the service has accepted them, so the board
/// can always tell the user what has actually left the device.
enum SyncState: String, Codable, Sendable {
    case synced
    case pending
    case failed
}
