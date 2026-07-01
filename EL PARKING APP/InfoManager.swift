//
//  InfoManager.swift
//  EL PARKING APP
//
//  One-shot Firestore fetch for /info_items (on launch + pull-to-refresh).
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

    init() { Task { await refresh() } }

    // info_items is static reference content (contact cards, building/parking rules) that an
    // admin edits on a weeks/months cadence, so a permanently-open listener bought almost
    // nothing — it stayed live for a signed-in user's ENTIRE session regardless of screen.
    // One-shot refresh() on launch + pull-to-refresh covers it; CRUD methods below call
    // refresh() after writing so the admin's own screen updates immediately without a listener.

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
        imageURL: String? = nil,
        imageBase64: String? = nil,
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
            imageURL: imageURL,
            imageBase64: imageBase64,
            sortOrder: maxOrder + 1, createdAt: Date()
        )
        do {
            try await db.collection("info_items").document(id).setData(item.toFirestore())
            if sendPush {
                PushNotificationManager.broadcast(title: item.title, body: item.body)
            }
            await refresh()
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
            await refresh()
        } catch {
            errorMessage = "Could not update: \(error.localizedDescription)"
        }
    }

    func delete(_ item: InfoItem) async {
        errorMessage = nil
        do {
            try await db.collection("info_items").document(item.id).delete()
            await refresh()
        } catch {
            errorMessage = "Could not delete: \(error.localizedDescription)"
        }
    }

    /// Re-push an existing card as a broadcast notification.
    func pushNotification(for item: InfoItem) {
        PushNotificationManager.broadcast(title: item.title, body: item.body)
    }
}
