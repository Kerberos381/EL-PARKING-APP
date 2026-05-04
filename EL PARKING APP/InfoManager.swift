//
//  InfoManager.swift
//  EL PARKING APP
//
//  Real-time Firestore listener for /info_items.
//  Admins: full CRUD.  All users: read.
//

import Foundation
import Combine
@preconcurrency import FirebaseFirestore

@MainActor
class InfoManager: ObservableObject {

    @Published var items: [InfoItem] = []
    @Published var errorMessage: String?

    private lazy var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() { startListener() }
    deinit { listener?.remove() }

    // MARK: - Listener

    private func startListener() {
        listener?.remove()
        listener = db.collection("info_items")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                guard let snapshot else { return }
                let loaded = snapshot.documents.compactMap {
                    InfoItem.fromFirestore($0.data(), id: $0.documentID)
                }
                Task { @MainActor in
                    self.items = loaded
                    self.errorMessage = nil
                }
            }
    }

    func refresh() async {
        do {
            let snapshot = try await db.collection("info_items")
                .order(by: "sortOrder")
                .getDocuments()

            items = snapshot.documents.compactMap {
                InfoItem.fromFirestore($0.data(), id: $0.documentID)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not refresh: \(error.localizedDescription)"
        }
    }

    // MARK: - CRUD

    func create(
        icon: String,
        title: String,
        body: String,
        details: String = "",
        fields: [ContactField] = [],
        linkTitle: String = "",
        linkURL: String = "",
        sendPush: Bool = false
    ) async {
        errorMessage = nil
        let maxOrder = items.map(\.sortOrder).max() ?? -1
        let id   = UUID().uuidString
        let item = InfoItem(
            id: id,
            icon: icon,
            title: title,
            body: body,
            details: details,
            fields: fields,
            linkTitle: linkTitle,
            linkURL: linkURL,
            sortOrder: maxOrder + 1, createdAt: Date()
        )
        do {
            try await db.collection("info_items").document(id).setData(item.toFirestore())
            if sendPush {
                PushNotificationManager.broadcast(title: item.title, body: item.body)
            }
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    func update(_ item: InfoItem, sendPush: Bool = false) async {
        errorMessage = nil
        do {
            try await db.collection("info_items").document(item.id).setData(item.toFirestore())
            if sendPush {
                PushNotificationManager.broadcast(title: item.title, body: item.body)
            }
        } catch {
            errorMessage = "Could not update: \(error.localizedDescription)"
        }
    }

    func delete(_ item: InfoItem) async {
        errorMessage = nil
        do {
            try await db.collection("info_items").document(item.id).delete()
        } catch {
            errorMessage = "Could not delete: \(error.localizedDescription)"
        }
    }

    /// Re-push an existing card as a broadcast notification.
    func pushNotification(for item: InfoItem) {
        PushNotificationManager.broadcast(title: item.title, body: item.body)
    }
}
