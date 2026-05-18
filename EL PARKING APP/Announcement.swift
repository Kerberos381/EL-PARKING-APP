//
//  Announcement.swift
//  EL PARKING APP
//

import Foundation
import FirebaseFirestore

enum AnnouncementTextColorMode: String, CaseIterable {
    case auto
    case light
    case dark

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "White"
        case .dark: return "Black"
        }
    }
}

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
    var backgroundColorHex: String?
    var imageURL: String?
    var imageBase64: String?
    var textColorMode: String = AnnouncementTextColorMode.auto.rawValue

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return exp < Date()
    }

    var daysUntilExpiry: Int? {
        guard let exp = expiresAt else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
    }

    var isExpiringSoon: Bool {
        guard let days = daysUntilExpiry else { return false }
        return days >= 0 && days <= 7
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
        dict["expiresAt"] = expiresAt.map { Timestamp(date: $0) } ?? NSNull()
        dict["backgroundColorHex"] = backgroundColorHex ?? NSNull()
        dict["imageURL"] = imageURL ?? NSNull()
        dict["imageBase64"] = imageBase64 ?? NSNull()
        dict["textColorMode"] = textColorMode
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
            fields:    rawFields.compactMap { ContactField.fromDict($0) },
            backgroundColorHex: data["backgroundColorHex"] as? String,
            imageURL:  data["imageURL"] as? String,
            imageBase64: data["imageBase64"] as? String,
            textColorMode: (data["textColorMode"] as? String) ?? AnnouncementTextColorMode.auto.rawValue
        )
    }
}
