//
//  RemoteTaskService.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 05/09/26.
//

import Foundation

/// The four things the app asks of the remote service. Everything is `async`
/// and can throw: the caller is the sync engine, which decides what a failure
/// means for the queue.
protocol RemoteTaskService: Sendable {
    /// Whether a remote is actually configured. When it is not, the app runs
    /// purely on its local store and says so, rather than pretending to sync.
    var isConfigured: Bool { get }

    func fetchTasks() async throws -> [Task]
    func create(_ task: Task) async throws
    func update(_ task: Task) async throws
    func delete(id: UUID) async throws
}

enum RemoteTaskServiceError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured: "No remote service is configured."
        }
    }
}

/// Stands in when no `GoogleService-Info.plist` is bundled, so the app is fully
/// usable — and reviewable — without Firebase credentials. Everything stays on
/// the device and the board reports that it is local-only.
struct UnconfiguredRemoteTaskService: RemoteTaskService {
    var isConfigured: Bool { false }

    func fetchTasks() async throws -> [Task] { throw RemoteTaskServiceError.notConfigured }
    func create(_ task: Task) async throws { throw RemoteTaskServiceError.notConfigured }
    func update(_ task: Task) async throws { throw RemoteTaskServiceError.notConfigured }
    func delete(id: UUID) async throws { throw RemoteTaskServiceError.notConfigured }
}
