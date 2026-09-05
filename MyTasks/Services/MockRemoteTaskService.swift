//
//  MockRemoteTaskService.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 05/09/26.
//

import Foundation

/// A stand-in service that keeps tasks in memory.
///
/// It exists so the sync path — queueing, retrying, per-task state — can be
/// exercised and reviewed without Firebase credentials, and so failures can be
/// produced on demand rather than waited for. Enable with the launch argument
/// `-useMockRemote`, and make its writes fail with `-mockRemoteFailing`.
actor MockRemoteTaskService: RemoteTaskService {
    private var tasks: [UUID: Task] = [:]
    private let latency: Duration
    private var isFailing: Bool

    nonisolated var isConfigured: Bool { true }

    init(latency: Duration = .milliseconds(600), isFailing: Bool = false) {
        self.latency = latency
        self.isFailing = isFailing
    }

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-useMockRemote")
    }

    /// `-mockRemoteLatency 3` makes each call take three seconds, which is how
    /// the pending state is demonstrated.
    static func fromLaunchArguments() -> MockRemoteTaskService {
        let arguments = ProcessInfo.processInfo.arguments
        var seconds = 0.6
        if let flag = arguments.firstIndex(of: "-mockRemoteLatency"),
           arguments.index(after: flag) < arguments.endIndex,
           let value = Double(arguments[arguments.index(after: flag)]) {
            seconds = value
        }

        return MockRemoteTaskService(
            latency: .milliseconds(Int(seconds * 1000)),
            isFailing: arguments.contains("-mockRemoteFailing")
        )
    }

    func setFailing(_ failing: Bool) { isFailing = failing }

    private func work() async throws {
        try? await _Concurrency.Task.sleep(for: latency)
        if isFailing { throw MockRemoteError.unavailable }
    }

    func fetchTasks() async throws -> [Task] {
        try await work()
        return tasks.values.sorted { $0.order < $1.order }
    }

    func create(_ task: Task) async throws {
        try await work()
        tasks[task.id] = task
    }

    func update(_ task: Task) async throws {
        try await work()
        tasks[task.id] = task
    }

    func delete(id: UUID) async throws {
        try await work()
        tasks[id] = nil
    }
}

enum MockRemoteError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: "The service is unavailable."
        }
    }
}
