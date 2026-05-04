//
//  PushNotificationManager.swift
//  EL PARKING APP
//
//  Firestore-based push notification inbox.
//  Listens to /users/{uid}/notifications + /broadcast_notifications for new items
//  and converts them into local UNNotifications — works when app is open or backgrounded.
//
//  For true killed-app push, add the FirebaseMessaging SDK and upload an APNs key
//  to Firebase Console → Project Settings → Cloud Messaging. The Firestore inbox
//  already stores all the right data; the Cloud Function in cloud-functions/index.js
//  (included in this project) watches the same collections and calls FCM.
//

import Foundation
@preconcurrency import FirebaseFirestore
import UserNotifications
import Combine

@MainActor
class PushNotificationManager: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()


    private lazy var db = Firestore.firestore()
    private var inboxListener:     ListenerRegistration?
    private var broadcastListener: ListenerRegistration?
    /// Only broadcast notifications created AFTER the app launched are delivered
    /// (prevents re-showing old announcements every time the listener fires).
    private var sessionStart = Date()

    // MARK: - Start / Stop

    func startListening(for uid: String) {
        stopListening()
        sessionStart = Date()
        listenInbox(uid: uid)
        listenBroadcast()
    }

    func stopListening() {
        inboxListener?.remove()
        broadcastListener?.remove()
        inboxListener     = nil
        broadcastListener = nil
    }

    // MARK: - Per-user inbox  (/users/{uid}/notifications)

    private func listenInbox(uid: String) {
        inboxListener = db
            .collection("users").document(uid)
            .collection("notifications")
            .whereField("delivered", isEqualTo: false)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                for change in snapshot.documentChanges where change.type == .added {
                    let doc  = change.document
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let body  = data["body"]  as? String else { continue }

                    Task { @MainActor in
                        await Self.scheduleLocal(id: doc.documentID, title: title, body: body)
                        // Mark delivered so re-opening the app doesn't repeat it
                        try? await doc.reference.updateData(["delivered": true])
                    }
                }
            }
    }

    // MARK: - Broadcast  (/broadcast_notifications)

    private func listenBroadcast() {
        broadcastListener = db
            .collection("broadcast_notifications")
            .whereField("createdAt", isGreaterThan: Timestamp(date: sessionStart))
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                for change in snapshot.documentChanges where change.type == .added {
                    let doc  = change.document
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let body  = data["body"]  as? String else { continue }

                    Task { @MainActor in
                        await Self.scheduleLocal(id: "bc_\(doc.documentID)", title: title, body: body)
                    }
                }
            }
    }

    // MARK: - Schedule local notification

    static func scheduleLocal(id: String, title: String, body: String) async {
        let content       = UNMutableNotificationContent()
        content.title     = title
        content.body      = body
        content.sound     = .default
        let trigger       = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request       = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Write helpers (called by admins)

    /// Send a notification to a specific user identified by email.
    /// Looks up the UID from Firestore /users, then writes to their inbox.
    static func sendToUser(email: String, title: String, body: String) {
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { snapshot, _ in
                guard let uid = snapshot?.documents.first?.documentID else { return }
                db.collection("users").document(uid)
                    .collection("notifications")
                    .addDocument(data: [
                        "title":     title,
                        "body":      body,
                        "delivered": false,
                        "createdAt": Timestamp(date: Date())
                    ])
            }
    }

    /// Broadcast a notification to all users.
    /// Every running instance picks this up via the broadcast_notifications listener.
    static func broadcast(title: String, body: String) {
        Firestore.firestore()
            .collection("broadcast_notifications")
            .addDocument(data: [
                "title":     title,
                "body":      body,
                "createdAt": Timestamp(date: Date())
            ])
    }
}
