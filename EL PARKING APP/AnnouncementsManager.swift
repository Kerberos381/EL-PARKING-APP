//
//  AnnouncementsManager.swift
//  EL PARKING APP
//
//  Real-time Firestore listener for announcements.
//  Admins: full CRUD. All users: read active announcements.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class AnnouncementsManager: ObservableObject {

    @Published var announcements: [Announcement] = []

    /// Active, non-expired items: pinned first, then newest-first
    var activeAnnouncements: [Announcement] {
        let now = Date()
        return announcements
            .filter { $0.isActive && ($0.expiresAt == nil || $0.expiresAt! > now) }
            .sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                return a.createdAt > b.createdAt
            }
    }

    private lazy var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() { startListener() }

    deinit { listener?.remove() }

    // MARK: - Listener

    private func startListener() {
        listener?.remove()
        listener = db.collection("announcements")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                let items = snapshot.documents.compactMap {
                    Announcement.fromFirestore($0.data(), id: $0.documentID)
                }
                Task { @MainActor in
                    self.announcements = items
                }
            }
    }

    func refresh() async {
        do {
            let snapshot = try await db.collection("announcements")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            announcements = snapshot.documents.compactMap {
                Announcement.fromFirestore($0.data(), id: $0.documentID)
            }
        } catch {
            print("AnnouncementsManager refresh error: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD

    func create(title: String, body: String, emoji: String, isPinned: Bool, createdBy: String, expiresAt: Date? = nil, fields: [ContactField] = []) async {
        let id = UUID().uuidString
        let item = Announcement(
            id: id, title: title, body: body, emoji: emoji,
            createdBy: createdBy, createdAt: Date(),
            isActive: true, isPinned: isPinned,
            expiresAt: expiresAt, fields: fields
        )
        do {
            try await db.collection("announcements").document(id).setData(item.toFirestore())
            // Broadcast a push notification to all active users
            PushNotificationManager.broadcast(title: "\(emoji) \(title)", body: body)
        } catch {
            print("AnnouncementsManager create error: \(error.localizedDescription)")
        }
    }

    func save(_ item: Announcement) async {
        do {
            try await db.collection("announcements").document(item.id).setData(item.toFirestore())
        } catch {
            print("AnnouncementsManager save error: \(error.localizedDescription)")
        }
    }

    func delete(_ item: Announcement) async {
        do {
            try await db.collection("announcements").document(item.id).delete()
        } catch {
            print("AnnouncementsManager delete error: \(error.localizedDescription)")
        }
    }

    func toggleActive(_ item: Announcement) async {
        var updated = item; updated.isActive = !item.isActive
        await save(updated)
    }

    func togglePinned(_ item: Announcement) async {
        var updated = item; updated.isPinned = !item.isPinned
        await save(updated)
    }
}
