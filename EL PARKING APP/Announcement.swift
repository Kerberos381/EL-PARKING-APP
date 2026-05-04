//
//  Announcement.swift
//  EL PARKING APP
//

import Foundation
import FirebaseFirestore

struct Announcement: Identifiable, Equatable {
    var id: String
    var title: String
    var body: String
    var emoji: String
    var createdBy: String
    var createdAt: Date
    var isActive: Bool
    var isPinned: Bool
    var expiresAt: Date?          // nil = never expires
    var fields: [ContactField]    // structured contact / info fields

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return exp < Date()
    }

    static func == (lhs: Announcement, rhs: Announcement) -> Bool {
        lhs.id == rhs.id
    }

    func toFirestore() -> [String: Any] {
        var dict: [String: Any] = [
            "id":        id,
            "title":     title,
            "body":      body,
            "emoji":     emoji,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "isActive":  isActive,
            "isPinned":  isPinned,
            "fields":    fields.map { $0.toDict() }
        ]
        // Always write the field so edits that remove an expiry actually clear it in Firestore
        dict["expiresAt"] = expiresAt.map { Timestamp(date: $0) } ?? NSNull()
        return dict
    }

    static func fromFirestore(_ data: [String: Any], id docID: String) -> Announcement? {
        guard
            let title     = data["title"]     as? String,
            let body      = data["body"]      as? String,
            let createdBy = data["createdBy"] as? String,
            let timestamp = data["createdAt"] as? Timestamp
        else { return nil }

        let rawFields = (data["fields"] as? [[String: Any]]) ?? []
        return Announcement(
            id:        (data["id"] as? String) ?? docID,
            title:     title,
            body:      body,
            emoji:     (data["emoji"]    as? String) ?? "📢",
            createdBy: createdBy,
            createdAt: timestamp.dateValue(),
            isActive:  (data["isActive"] as? Bool) ?? true,
            isPinned:  (data["isPinned"] as? Bool) ?? false,
            expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue(),
            fields:    rawFields.compactMap { ContactField.fromDict($0) }
        )
    }
}
