//
//  FirestoreSchemaValidator.swift
//  EL PARKING APP
//
//  Lightweight schema drift diagnostics for cross-platform Firestore documents.
//  Debug-only logging is emitted by callers.
//

import Foundation
import FirebaseFirestore

enum FirestoreSchemaValidator {
    static func bookingWarnings(data: [String: Any], docID: String) -> [String] {
        var warnings: [String] = []

        if !hasAny(data, keys: ["id"]) {
            warnings.append("bookings/\(docID): missing id (falls back to documentID)")
        }
        if !hasAny(data, keys: ["bookingDate"]) {
            warnings.append("bookings/\(docID): missing bookingDate")
        } else if !isDateLike(data["bookingDate"]) {
            warnings.append("bookings/\(docID): bookingDate type is not Timestamp/date/string/number")
        }
        if !hasAny(data, keys: ["spot", "spotLabel"]) {
            warnings.append("bookings/\(docID): missing spot/spotLabel")
        }
        if !hasAny(data, keys: ["email", "userEmail"]) {
            warnings.append("bookings/\(docID): missing email/userEmail")
        }
        if !hasAny(data, keys: ["fromTime", "from", "timeFrom"]) {
            warnings.append("bookings/\(docID): missing fromTime aliases")
        }
        if !hasAny(data, keys: ["toTime", "to", "timeTo"]) {
            warnings.append("bookings/\(docID): missing toTime aliases")
        }
        if let spot = firstString(data, keys: ["spot", "spotLabel"]), spot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("bookings/\(docID): empty spot value")
        }
        if let email = firstString(data, keys: ["email", "userEmail"]), email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("bookings/\(docID): empty email value")
        }

        return warnings
    }

    static func userWarnings(data: [String: Any], docID: String) -> [String] {
        var warnings: [String] = []

        if !hasAny(data, keys: ["uid"]) {
            warnings.append("users/\(docID): missing uid")
        }
        if !hasAny(data, keys: ["email"]) {
            warnings.append("users/\(docID): missing email")
        }
        if !hasAny(data, keys: ["displayName"]) {
            warnings.append("users/\(docID): missing displayName")
        }
        if !hasAny(data, keys: ["role"]) {
            warnings.append("users/\(docID): missing role")
        }
        if !hasAny(data, keys: ["status"]) {
            warnings.append("users/\(docID): missing status")
        }
        if hasAny(data, keys: ["vehiclePresetId"]) && !hasAny(data, keys: ["vehicleMiniaturePresetID"]) {
            warnings.append("users/\(docID): legacy vehiclePresetId present without canonical vehicleMiniaturePresetID")
        }

        return warnings
    }

    private static func hasAny(_ data: [String: Any], keys: [String]) -> Bool {
        keys.contains { data[$0] != nil && !(data[$0] is NSNull) }
    }

    private static func firstString(_ data: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = data[key] as? String { return value }
        }
        return nil
    }

    private static func isDateLike(_ value: Any?) -> Bool {
        switch value {
        case is Timestamp: return true
        case is Date: return true
        case is String: return true
        case is NSNumber: return true
        default: return false
        }
    }
}
