//
//  SyncEngine.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 05/09/26.
//

import Foundation
import Network

/// `Task` is this app's model, so the concurrency one needs its full name.
private typealias Job = _Concurrency.Task

@MainActor
protocol SyncEngineDelegate: AnyObject {
    /// The service's view of the board, from a fetch.
    func syncEngine(_ engine: SyncEngine, didFetch tasks: [Task])
    /// These tasks are now agreed with the service.
    func syncEngine(_ engine: SyncEngine, didSync taskIDs: [UUID])
    /// These tasks could not be sent. Their edits are still on the device.
    func syncEngine(_ engine: SyncEngine, didFailToSync taskIDs: [UUID])
}

/// Drains the outbox into the remote service and reports where things stand.
///
/// Nothing here throws work away: an operation stays queued until the service
/// accepts it, so a failure is always a delay rather than lost user input.
@MainActor
@Observable
final class SyncEngine {
    enum Status: Equatable {
        /// No remote configured — the app is a good local task board and says so.
        case localOnly
        case offline
        case syncing
        case upToDate
        case failed(String)
    }

    private(set) var status: Status = .upToDate
    private(set) var pendingCount = 0
    /// Set when the first load could not reach the service. The board still
    /// shows what is on the device.
    private(set) var loadFailure: String?
    /// When the service last agreed with us. Kept across launches so the board
    /// can still answer "is my work safe?" before the first sync of a session.
    private(set) var lastSyncedAt: Date?
    /// A message to show briefly and then drop. Posted when something actually
    /// happened, so it is not re-derived — and so re-drawing the board cannot
    /// bring it back.
    private(set) var notice: SyncNotice?

    weak var delegate: SyncEngineDelegate?

    /// Whether there is a service to sync with at all.
    var isRemoteConfigured: Bool { remote.isConfigured }

    private let repository: TaskRepository
    private let remote: RemoteTaskService
    private let monitor = NWPathMonitor()
    private var isOnline = true
    private var isDraining = false
    private var hasStarted = false
    private var retry: Job<Void, Never>?
    private var noticeDismissal: Job<Void, Never>?

    private static let lastSyncedKey = "lastSyncedAt"

    init(repository: TaskRepository, remote: RemoteTaskService) {
        self.repository = repository
        self.remote = remote
        pendingCount = repository.pendingOperations().count
        lastSyncedAt = UserDefaults.standard.object(forKey: Self.lastSyncedKey) as? Date
        status = remote.isConfigured ? (pendingCount == 0 ? .upToDate : .syncing) : .localOnly
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Lifecycle

    /// Safe to call more than once: only the first call takes effect.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        guard remote.isConfigured else {
            post("Saved on this device", "internaldrive", .neutral)
            return
        }

        monitor.pathUpdateHandler = { [weak self] path in
            Job { @MainActor in self?.networkChanged(isUp: path.status == .satisfied) }
        }
        monitor.start(queue: DispatchQueue(label: "sync.reachability"))

        Job { await self.refresh() }
    }

    private func networkChanged(isUp: Bool) {
        let wasOffline = !isOnline
        isOnline = isUp

        if !isUp {
            status = .offline
            postOffline()
        } else if wasOffline {
            // Back online: everything queued while away goes now.
            Job { await self.drain() }
        }
    }

    // MARK: - Reading

    /// Pulls the service's copy of the board. A failure here is reported and
    /// left at that: the local store already has something to show.
    func refresh() async {
        guard remote.isConfigured, isOnline else { return }

        status = .syncing
        do {
            let remoteTasks = try await remote.fetchTasks()
            loadFailure = nil
            markSynced()
            delegate?.syncEngine(self, didFetch: remoteTasks)
        } catch {
            loadFailure = error.localizedDescription
            post("Couldn't reach the service", "exclamationmark.triangle.fill", .failure)
        }
        await drain()
    }

    // MARK: - Writing

    func enqueue(_ operation: PendingOperation) {
        repository.enqueue(operation)
        pendingCount = repository.pendingOperations().count

        // Queued with nowhere to send it: say so now, while the change is
        // fresh in the user's mind, rather than only when the network dropped.
        if !isOnline { postOffline() }

        Job { await self.drain() }
    }

    /// The user asking to try again after a failure.
    func retryNow() {
        retry?.cancel()
        Job { await self.refresh() }
    }

    /// Sends queued changes oldest first, stopping at the first failure so the
    /// service sees them in the order the user made them.
    func drain() async {
        guard remote.isConfigured, isOnline, !isDraining else { return }

        isDraining = true
        defer {
            isDraining = false
            pendingCount = repository.pendingOperations().count
        }

        var synced: [UUID] = []
        /// Guards against an operation that will not clear: better to stop than
        /// to hammer the service with the same write forever.
        var alreadySent: Set<UUID> = []

        // Re-reads the queue each pass, so a change made while a send was in
        // flight goes out now rather than waiting for the next trigger.
        while true {
            let batch = repository.pendingOperations().filter { !alreadySent.contains($0.id) }
            guard !batch.isEmpty else { break }

            for var operation in batch {
                if status != .syncing {
                    post(pendingCount == 1 ? "Syncing 1 change…" : "Syncing \(pendingCount) changes…", "", .progress)
                }
                status = .syncing
                do {
                    try await send(operation)
                    alreadySent.insert(operation.id)
                    repository.remove(operationID: operation.id)
                    synced.append(operation.taskID)
                } catch {
                    operation.attempts += 1
                    operation.lastError = error.localizedDescription
                    repository.update(operation)

                    if !synced.isEmpty { delegate?.syncEngine(self, didSync: synced) }
                    delegate?.syncEngine(self, didFailToSync: [operation.taskID])

                    let count = repository.pendingOperations().count
                    post(
                        count == 1 ? "Couldn't sync 1 change" : "Couldn't sync \(count) changes",
                        "exclamationmark.icloud.fill",
                        .failure
                    )
                    status = .failed(error.localizedDescription)
                    scheduleRetry(after: backoff(for: operation.attempts))
                    return
                }
            }
        }

        if !synced.isEmpty {
            delegate?.syncEngine(self, didSync: synced)
            // Only worth announcing when something was actually sent.
            post("All changes synced", "checkmark.icloud", .success)
        }
        markSynced()
        status = .upToDate
    }

    private func send(_ operation: PendingOperation) async throws {
        switch operation.kind {
        case .create:
            guard let task = operation.task else { return }
            try await remote.create(task)
        case .update:
            guard let task = operation.task else { return }
            try await remote.update(task)
        case .delete:
            try await remote.delete(id: operation.taskID)
        }
    }

    /// Offline, and how much work that is holding up.
    private func postOffline() {
        let text = switch pendingCount {
        case 0: "Offline"
        case 1: "Offline · 1 change waiting"
        default: "Offline · \(pendingCount) changes waiting"
        }
        post(text, "wifi.slash", .neutral)
    }

    /// Shows a message for a moment, replacing whatever was there.
    private func post(_ text: String, _ symbol: String, _ tone: SyncNotice.Tone) {
        notice = SyncNotice(text: text, symbol: symbol, tone: tone)
        noticeDismissal?.cancel()
        noticeDismissal = Job { [weak self] in
            try? await Job<Never, Never>.sleep(for: .seconds(2.5))
            guard !Job<Never, Never>.isCancelled else { return }
            self?.notice = nil
        }
    }

    private func markSynced() {
        lastSyncedAt = Date()
        UserDefaults.standard.set(lastSyncedAt, forKey: Self.lastSyncedKey)
    }

    // MARK: - Retry

    /// Backs off so a service that is down is not hammered, capped so the app
    /// never sits idle for long once it recovers.
    private func backoff(for attempts: Int) -> Duration {
        .seconds(min(60, 1 << min(attempts, 6)))
    }

    private func scheduleRetry(after delay: Duration) {
        retry?.cancel()
        retry = Job { [weak self] in
            try? await Job<Never, Never>.sleep(for: delay)
            guard !Job<Never, Never>.isCancelled else { return }
            await self?.drain()
        }
    }
}
