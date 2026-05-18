//
//  AppUser.swift
//  EL PARKING APP
//
//  Firebase user model with roles and status.
//

import Foundation
import FirebaseFirestore

// MARK: - Enums

enum UserRole: String, Codable, CaseIterable {
    case user       = "user"
    case admin      = "admin"
    case privileged = "privileged"

    var displayName: String {
        switch self {
        case .user:       return "User"
        case .admin:      return "Admin"
        case .privileged: return "Privileged"
        }
    }
}

enum UserStatus: String, Codable, CaseIterable {
    case pending   = "pending"
    case active    = "active"
    case suspended = "suspended"

    var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .active:    return "Active"
        case .suspended: return "Suspended"
        }
    }
}

// MARK: - StrikeEntry

struct StrikeEntry: Identifiable, Codable, Equatable {
    let id: String
    let reason: String
    let assignedAt: Date
    let assignedBy: String          // admin email
    let strikeNumber: Int           // 1, 2, or 3
    let suspensionTriggered: Bool

    func toFirestore() -> [String: Any] {
        [
            "id":                  id,
            "reason":              reason,
            "assignedAt":          Timestamp(date: assignedAt),
            "assignedBy":          assignedBy,
            "strikeNumber":        strikeNumber,
            "suspensionTriggered": suspensionTriggered
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> StrikeEntry? {
        guard
            let id           = data["id"]           as? String,
            let reason       = data["reason"]       as? String,
            let assignedBy   = data["assignedBy"]   as? String,
            let strikeNumber = data["strikeNumber"] as? Int
        else { return nil }
        let assignedAt          = (data["assignedAt"] as? Timestamp)?.dateValue() ?? Date()
        let suspensionTriggered = data["suspensionTriggered"] as? Bool ?? false
        return StrikeEntry(id: id, reason: reason, assignedAt: assignedAt,
                           assignedBy: assignedBy, strikeNumber: strikeNumber,
                           suspensionTriggered: suspensionTriggered)
    }
}

// MARK: - AppUser

struct AppUser: Identifiable, Codable, Equatable {
    let uid: String
    let email: String
    var displayName: String
    var role: UserRole
    var status: UserStatus
    var registrationPlate: String
    var carDescription: String
    var carColor: String          // hex string e.g. "#CC3333", empty = unset
    var carType:  String          // CarBodyType rawValue, empty = unset
    var vehicleMiniaturePresetID: String = ""
    /// Optional manual vocative override for Czech greeting (e.g. "Katko", "Jane").
    var preferredVocative: String = ""
    var createdAt: Date
    var rejectionReason: String?
    /// True when the user has passed the invite/access gate for app data.
    var inviteAccepted: Bool = true
    /// True when the account was admin-created but the user hasn't yet completed their profile.
    var needsFinishRegistration: Bool
    /// Set to the date when the user completed their finish-registration flow.
    var activatedAt: Date?

    // MARK: Strike / suspension system
    var strikes: Int = 0
    var suspendedAt: Date? = nil
    var suspensionCount: Int = 0
    var strikeHistory: [StrikeEntry] = []
    /// Timestamp of the most recently assigned warning — used for the 30-day decay rule.
    var lastStrikeAt: Date? = nil

    var id: String { uid }

    // MARK: Computed helpers
    var isAdmin:      Bool { role == .admin }
    var isActive:     Bool { status == .active }
    var isPending:    Bool { status == .pending }
    var isSuspended:  Bool { status == .suspended }
    var isPrivileged: Bool { role == .privileged || role == .admin }
    /// Date when the 2-week strike-triggered suspension expires (nil if not suspended via strikes).
    var suspensionLiftDate: Date? {
        guard let suspendedAt else { return nil }
        return suspendedAt.addingTimeInterval(14 * 24 * 3600)
    }
    /// True when account was explicitly rejected by an admin (suspended + reason set).
    var isRejected:   Bool { status == .suspended && !(rejectionReason ?? "").isEmpty }

    var firstName: String {
        let parts = displayName.split(separator: " ")
        return String(parts.first ?? Substring(displayName))
    }

    // MARK: - Firestore Encoding

    func toFirestore() -> [String: Any] {
        var dict: [String: Any] = [
            "uid":                      uid,
            "email":                    email,
            "displayName":              displayName,
            "role":                     role.rawValue,
            "status":                   status.rawValue,
            "registrationPlate":        registrationPlate,
            "carDescription":           carDescription,
            "carColor":                 carColor,
            "carType":                  carType,
            "vehicleMiniaturePresetID": vehicleMiniaturePresetID,
            "preferredVocative":        preferredVocative,
            "createdAt":                Timestamp(date: createdAt),
            "inviteAccepted":           inviteAccepted,
            "needsFinishRegistration":  needsFinishRegistration
        ]
        if let reason = rejectionReason { dict["rejectionReason"] = reason }
        if let at = activatedAt { dict["activatedAt"] = Timestamp(date: at) }
        dict["strikes"]         = strikes
        dict["suspensionCount"] = suspensionCount
        if let suspendedAt { dict["suspendedAt"] = Timestamp(date: suspendedAt) }
        if let lastStrikeAt { dict["lastStrikeAt"] = Timestamp(date: lastStrikeAt) }
        if !strikeHistory.isEmpty { dict["strikeHistory"] = strikeHistory.map { $0.toFirestore() } }
        return dict
    }

    static func fromFirestore(_ data: [String: Any]) -> AppUser? {
        guard
            let uid         = data["uid"]         as? String,
            let email       = data["email"]       as? String,
            let displayName = data["displayName"] as? String,
            let roleRaw     = data["role"]        as? String,
            let role        = UserRole(rawValue: roleRaw),
            let statusRaw   = data["status"]      as? String,
            let status      = UserStatus(rawValue: statusRaw)
        else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let rejectionReason = data["rejectionReason"] as? String

        let activatedAt     = (data["activatedAt"]  as? Timestamp)?.dateValue()
        let suspendedAt     = (data["suspendedAt"]   as? Timestamp)?.dateValue()
        let lastStrikeAt    = (data["lastStrikeAt"]  as? Timestamp)?.dateValue()
        let strikes         = data["strikes"]         as? Int ?? 0
        let suspensionCount = data["suspensionCount"] as? Int ?? 0
        let strikeHistory   = (data["strikeHistory"] as? [[String: Any]] ?? [])
            .compactMap { StrikeEntry.fromFirestore($0) }
            .sorted { $0.assignedAt < $1.assignedAt }

        return AppUser(
            uid:                     uid,
            email:                   email,
            displayName:             displayName,
            role:                    role,
            status:                  status,
            registrationPlate:       data["registrationPlate"] as? String ?? "",
            carDescription:          data["carDescription"]    as? String ?? "",
            carColor:                data["carColor"]          as? String ?? "",
            carType:                 data["carType"]           as? String ?? "",
            vehicleMiniaturePresetID: (data["vehicleMiniaturePresetID"] as? String)
                ?? (data["vehiclePresetId"] as? String)
                ?? "",
            preferredVocative:       data["preferredVocative"] as? String ?? "",
            createdAt:               createdAt,
            rejectionReason:         rejectionReason,
            inviteAccepted:          data["inviteAccepted"] as? Bool ?? true,
            needsFinishRegistration: data["needsFinishRegistration"] as? Bool ?? false,
            activatedAt:             activatedAt,
            strikes:                 strikes,
            suspendedAt:             suspendedAt,
            suspensionCount:         suspensionCount,
            strikeHistory:           strikeHistory,
            lastStrikeAt:            lastStrikeAt
        )
    }
}
