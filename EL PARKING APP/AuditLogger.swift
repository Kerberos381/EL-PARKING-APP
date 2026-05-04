//
//  AuditLogger.swift
//  EL PARKING APP
//
//  Lightweight audit trail for admin and sensitive actions.
//  Writes to Firestore `audit_log` collection — one document per action.
//

import Foundation
import FirebaseFirestore

struct AuditLogger {

    private static var db: Firestore { Firestore.firestore() }

    /// Log an admin/system action to Firestore.
    /// - Parameters:
    ///   - action: Short machine-readable action type (e.g. "activate_user", "cancel_booking")
    ///   - detail: Human-readable description of what happened
    ///   - performedBy: UID of the user performing the action
    ///   - targetUID: Optional UID of the user being acted upon
    static func log(
        action: String,
        detail: String,
        performedBy: String,
        targetUID: String? = nil
    ) {
        var data: [String: Any] = [
            "action":      action,
            "detail":      detail,
            "performedBy": performedBy,
            "timestamp":   Timestamp(date: Date())
        ]
        if let target = targetUID {
            data["targetUID"] = target
        }
        db.collection("audit_log").addDocument(data: data)
    }
}
