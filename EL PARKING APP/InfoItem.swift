//
//  InfoItem.swift
//  EL PARKING APP
//
//  Persistent info card shown on the Home screen.
//  Admins create / edit / delete via AdminInfoView.
//  Stored in Firestore /info_items collection.
//

import Foundation
import FirebaseFirestore

// MARK: - ContactField

/// A single structured field (Phone, Email, Location, etc.) on an info card.
struct ContactField: Identifiable {
    var id: String = UUID().uuidString
    var type: FieldType
    var label: String   // empty = use type's defaultLabel
    var value: String

    enum FieldType: String, CaseIterable {
        case phone, email, location, website, custom

        var icon: String {
            switch self {
            case .phone:    return "phone.fill"
            case .email:    return "envelope.fill"
            case .location: return "mappin.circle.fill"
            case .website:  return "globe"
            case .custom:   return "text.bubble.fill"
            }
        }

        var defaultLabel: String {
            switch self {
            case .phone:    return "Phone"
            case .email:    return "Email"
            case .location: return "Location"
            case .website:  return "Website"
            case .custom:   return "Info"
            }
        }
    }

    var displayLabel: String { label.isEmpty ? type.defaultLabel : label }

    // MARK: Firestore helpers

    func toDict() -> [String: Any] {
        ["id": id, "type": type.rawValue, "label": label, "value": value]
    }

    static func fromDict(_ dict: [String: Any]) -> ContactField? {
        guard let typeStr = dict["type"] as? String,
              let type    = FieldType(rawValue: typeStr),
              let value   = dict["value"] as? String else { return nil }
        return ContactField(
            id:    (dict["id"]    as? String) ?? UUID().uuidString,
            type:  type,
            label: (dict["label"] as? String) ?? "",
            value: value
        )
    }
}

// MARK: - InfoItem

struct InfoItem: Identifiable {
    let id: String
    var icon: String        // SF Symbol name
    var title: String
    var body: String
    var details: String     // legacy free-text notes (still shown if populated)
    var fields: [ContactField]
    var linkTitle: String
    var linkURL: String
    var sortOrder: Int
    var createdAt: Date

    // MARK: - Firestore

    func toFirestore() -> [String: Any] {
        [
            "icon":      icon,
            "title":     title,
            "body":      body,
            "details":   details,
            "fields":    fields.map { $0.toDict() },
            "linkTitle": linkTitle,
            "linkURL":   linkURL,
            "sortOrder": sortOrder,
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    static func fromFirestore(_ data: [String: Any], id: String) -> InfoItem? {
        guard let title = data["title"] as? String,
              let body  = data["body"]  as? String else { return nil }
        let rawFields = (data["fields"] as? [[String: Any]]) ?? []
        return InfoItem(
            id:        id,
            icon:      (data["icon"]      as? String) ?? "info.circle.fill",
            title:     title,
            body:      body,
            details:   (data["details"]   as? String) ?? "",
            fields:    rawFields.compactMap { ContactField.fromDict($0) },
            linkTitle: (data["linkTitle"] as? String) ?? "",
            linkURL:   (data["linkURL"]   as? String) ?? "",
            sortOrder: (data["sortOrder"] as? Int)    ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    // MARK: - Preset icons admins can pick from

    static let presetIcons: [String] = [
        "info.circle.fill",
        "clock.fill",
        "parkingsign.circle.fill",
        "car.side.fill",
        "mappin.circle.fill",
        "phone.fill",
        "envelope.fill",
        "person.badge.shield.checkmark.fill",
        "exclamationmark.triangle.fill",
        "checkmark.shield.fill",
        "key.fill",
        "calendar",
        "wifi",
        "building.2.fill",
        "figure.walk",
        "accessibility",
        "camera.fill",
        "lock.fill",
        "star.fill",
        "house.fill"
    ]
}
