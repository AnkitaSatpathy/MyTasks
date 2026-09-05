//
//  FirestoreTaskService.swift
//  MyTasks
//
//  Created by Ankita Satpathy on 05/09/26.
//

import FirebaseCore
import FirebaseFirestore
import Foundation

/// Decides what the app talks to. Firebase needs a `GoogleService-Info.plist`
/// that cannot be committed for someone else's project, so when it is missing
/// the app runs on its local store alone and the board says "On this device"
/// instead of pretending to sync.
enum FirebaseRemote {
    private static var isBundled: Bool {
        Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    }

    /// Called once at launch, before anything asks for the service.
    static func configureIfPossible() {
        guard isBundled, FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()

        // Firestore only accepts settings before the instance is first used,
        // and treats a later change as fatal — so this happens here, once,
        // rather than anywhere near the calls that use it.
        let store = Firestore.firestore()
        let settings = store.settings
        settings.cacheSettings = MemoryCacheSettings()
        store.settings = settings
    }

    static func service() -> RemoteTaskService {
        if MockRemoteTaskService.isEnabled { return MockRemoteTaskService.fromLaunchArguments() }

        configureIfPossible()
        guard isBundled, FirebaseApp.app() != nil else { return UnconfiguredRemoteTaskService() }
        return FirestoreTaskService()
    }
}

/// The four operations, against one Firestore collection.
///
/// Firestore's own offline cache is switched off on purpose — see
/// `FirebaseRemote.configureIfPossible()`. The app already has a durable outbox
/// in SwiftData, and two queues over the same writes would make "has this
/// synced?" impossible to answer honestly.
struct FirestoreTaskService: RemoteTaskService {
    private let collectionName = "tasks"

    var isConfigured: Bool { FirebaseApp.app() != nil }

    private var collection: CollectionReference {
        Firestore.firestore().collection(collectionName)
    }

    func fetchTasks() async throws -> [Task] {
        let snapshot = try await collection.getDocuments(source: .server)
        return snapshot.documents.compactMap { Task(document: $0.data(), id: $0.documentID) }
    }

    func create(_ task: Task) async throws {
        try await collection.document(task.id.uuidString).setData(task.document)
    }

    func update(_ task: Task) async throws {
        // A create that never landed and an update are the same write here,
        // which keeps a replayed queue idempotent.
        try await collection.document(task.id.uuidString).setData(task.document, merge: true)
    }

    func delete(id: UUID) async throws {
        try await collection.document(id.uuidString).delete()
    }
}

// MARK: - Mapping

private extension Task {
    var document: [String: Any] {
        [
            "title": title,
            "details": details,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "order": order
        ]
    }

    /// Anything malformed is skipped rather than crashing the board — the
    /// collection is shared with whatever else writes to it.
    init?(document: [String: Any], id documentID: String) {
        guard let id = UUID(uuidString: documentID),
              let title = document["title"] as? String,
              let statusRaw = document["status"] as? String,
              let status = TaskStatus(rawValue: statusRaw)
        else { return nil }

        self.init(
            id: id,
            title: title,
            details: document["details"] as? String ?? "",
            status: status,
            createdAt: (document["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (document["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            order: document["order"] as? Int ?? 0,
            syncState: .synced
        )
    }
}
