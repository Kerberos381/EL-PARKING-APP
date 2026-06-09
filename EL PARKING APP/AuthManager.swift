//
//  AuthManager.swift
//  EL PARKING APP
//
//  Firebase Auth + Firestore user lifecycle manager.
//  Passwordless via Keychain biometric sign-in after first manual login.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

// MARK: - Auth State

enum AuthState: Equatable {
    case loading
    case unauthenticated
    case pendingApproval                    // legacy: awaiting admin activation
    case needsFinishRegistration(AppUser)   // admin-created account — user must complete profile
    case authenticated(AppUser)
}

// MARK: - AuthManager

@MainActor
class AuthManager: ObservableObject {

    @Published var authState: AuthState = .loading
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    // Admin — list of all users (kept live via Firestore listener)
    @Published var allUsers: [AppUser] = []

    // Computed so it stays in sync with allUsers automatically.
    // A stored @Published var can go stale when allUsers is updated by fetchAllUsers()
    // but the Firestore snapshot listener hasn't fired yet.
    var pendingCount: Int { allUsers.filter { $0.isPending }.count }

    private var stateListener: AuthStateDidChangeListenerHandle?
    private var usersListener: ListenerRegistration?
    private lazy var db = Firestore.firestore()
    private var lastAllUsersSignature: Int?

    // MARK: - Init

    init() {
        setupAuthListener()
    }

    deinit {
        if let listener = stateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        usersListener?.remove()
    }

    // MARK: - Auth State Listener

    private func setupAuthListener() {
        stateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let firebaseUser {
                    await self.loadUserProfile(uid: firebaseUser.uid)
                } else {
                    self.authState = .unauthenticated
                    self.currentUser = nil
                }
            }
        }
    }

    private func loadUserProfile(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            #if DEBUG
            if let data = doc.data() {
                let warnings = FirestoreSchemaValidator.userWarnings(data: data, docID: doc.documentID)
                if !warnings.isEmpty {
                    print("AuthManager user schema warnings (\(warnings.count)):\n- \(warnings.joined(separator: "\n- "))")
                }
            }
            #endif
            guard let data = doc.data() else {
                if let bootstrapped = await bootstrapMissingUserProfile(uid: uid) {
                    currentUser = bootstrapped
                    if bootstrapped.needsFinishRegistration {
                        authState = .needsFinishRegistration(bootstrapped)
                    } else if bootstrapped.isActive {
                        authState = .authenticated(bootstrapped)
                        if bootstrapped.isAdmin { startUsersListener() }
                    } else {
                        authState = .pendingApproval
                    }
                    return
                }
                errorMessage = "Account profile is missing. Please sign in with password once, then contact admin if this persists."
                authState = .unauthenticated
                try? Auth.auth().signOut()
                return
            }

            guard var user = AppUser.fromFirestore(data) else {
                if let repaired = await repairInvalidUserProfile(uid: uid, data: data) {
                    currentUser = repaired
                    if repaired.needsFinishRegistration {
                        authState = .needsFinishRegistration(repaired)
                    } else if repaired.isActive {
                        authState = .authenticated(repaired)
                        if repaired.isAdmin { startUsersListener() }
                    } else {
                        authState = .pendingApproval
                    }
                    return
                }
                errorMessage = "Account profile is invalid. Please contact admin."
                authState = .unauthenticated
                try? Auth.auth().signOut()
                return
            }

            // One-time seed: auto-promote users in the seed lists
            user = await autoPromoteIfSeeded(user)

            // Auto-lift expired strike suspension (Firestore rule enforces the server-side time gate)
            if user.isSuspended, let suspendedAt = user.suspendedAt,
               Date() >= suspendedAt.addingTimeInterval(14 * 24 * 3600) {
                user = await liftExpiredSuspension(user)
            }

            // Decay one warning per 30-day period of good behaviour
            if !user.isSuspended && user.strikes > 0 {
                user = await checkStrikeDecay(user)
            }

            currentUser = user

            if user.needsFinishRegistration {
                authState = .needsFinishRegistration(user)
            } else if user.isActive {
                authState = .authenticated(user)
                if user.isAdmin { startUsersListener() }
            } else {
                authState = .pendingApproval
            }
        } catch {
            errorMessage = "Unable to load account profile."
            authState = .unauthenticated
        }
    }

    private func bootstrapMissingUserProfile(uid: String) async -> AppUser? {
        guard let authUser = Auth.auth().currentUser else { return nil }
        guard let email = authUser.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty else {
            return nil
        }

        let fallbackName: String
        if let name = authUser.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            fallbackName = name
        } else {
            fallbackName = email
        }

        let profile = AppUser(
            uid: uid,
            email: email,
            displayName: fallbackName,
            role: .user,
            status: .pending,
            registrationPlate: "",
            carDescription: "",
            carColor: "",
            carType: "",
            vehicleMiniaturePresetID: "",
            preferredVocative: "",
            companyBadge: CompanyBadge.infer(from: email),
            createdAt: Date(),
            rejectionReason: nil,
            inviteAccepted: false,
            needsFinishRegistration: true,
            activatedAt: nil
        )

        do {
            try await db.collection("users").document(uid).setData(profile.toFirestore(), merge: true)
            return profile
        } catch {
            return nil
        }
    }

    private func repairInvalidUserProfile(uid: String, data: [String: Any]) async -> AppUser? {
        guard let authUser = Auth.auth().currentUser else { return nil }
        guard let email = authUser.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty else {
            return nil
        }

        let fallbackName: String
        if let rawName = data["displayName"] as? String, !rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fallbackName = rawName
        } else if let authName = authUser.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !authName.isEmpty {
            fallbackName = authName
        } else {
            fallbackName = email
        }

        let repairedRole = UserRole(rawValue: (data["role"] as? String) ?? "") ?? .user
        let repairedStatus = UserStatus(rawValue: (data["status"] as? String) ?? "") ?? .active

        let repairedHistory = (data["strikeHistory"] as? [[String: Any]] ?? [])
            .compactMap { StrikeEntry.fromFirestore($0) }
            .sorted { $0.assignedAt < $1.assignedAt }

        let repaired = AppUser(
            uid: uid,
            email: (data["email"] as? String)?.lowercased() ?? email,
            displayName: fallbackName,
            role: repairedRole,
            status: repairedStatus,
            registrationPlate: data["registrationPlate"] as? String ?? "",
            carDescription: data["carDescription"] as? String ?? "",
            carColor: data["carColor"] as? String ?? "",
            carType: data["carType"] as? String ?? "",
            vehicleMiniaturePresetID: (data["vehicleMiniaturePresetID"] as? String) ?? "",
            preferredVocative: data["preferredVocative"] as? String ?? "",
            companyBadge: CompanyBadge(rawValue: (data["companyBadge"] as? String) ?? "") ?? CompanyBadge.infer(from: email),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            rejectionReason: data["rejectionReason"] as? String,
            inviteAccepted: data["inviteAccepted"] as? Bool ?? true,
            needsFinishRegistration: data["needsFinishRegistration"] as? Bool ?? false,
            activatedAt: (data["activatedAt"] as? Timestamp)?.dateValue(),
            strikes: data["strikes"] as? Int ?? 0,
            suspendedAt: (data["suspendedAt"] as? Timestamp)?.dateValue(),
            suspensionCount: data["suspensionCount"] as? Int ?? 0,
            strikeHistory: repairedHistory,
            lastStrikeAt: (data["lastStrikeAt"] as? Timestamp)?.dateValue()
        )

        do {
            try await db.collection("users").document(uid).setData(repaired.toFirestore(), merge: true)
            return repaired
        } catch {
            return nil
        }
    }

    // MARK: - Auto-Promote Seed Admins (one-time migration)

    private func autoPromoteIfSeeded(_ user: AppUser) async -> AppUser {
        var updated = user
        let email = user.email.lowercased()

        if AppConfig.seedAdminEmails.contains(email) && user.role != .admin {
            updated.role = .admin
            updated.status = .active
            try? await db.collection("users").document(user.uid).updateData([
                "role":   UserRole.admin.rawValue,
                "status": UserStatus.active.rawValue,
                "inviteAccepted": true
            ])
        } else if AppConfig.seedPrivilegedEmails.contains(email) && user.role == .user {
            updated.role = .privileged
            updated.status = .active
            try? await db.collection("users").document(user.uid).updateData([
                "role":   UserRole.privileged.rawValue,
                "status": UserStatus.active.rawValue,
                "inviteAccepted": true
            ])
        }

        return updated
    }

    // MARK: - Live Users Listener (admin only)

    private func startUsersListener() {
        usersListener?.remove()
        usersListener = db.collection("users")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                #if DEBUG
                let warnings = snapshot.documents.flatMap {
                    FirestoreSchemaValidator.userWarnings(data: $0.data(), docID: $0.documentID)
                }
                if !warnings.isEmpty {
                    print("AuthManager users listener schema warnings (\(warnings.count)):\n- \(warnings.prefix(10).joined(separator: "\n- "))")
                }
                #endif
                let users = snapshot.documents
                    .compactMap { AppUser.fromFirestore($0.data()) }
                    .sorted { $0.displayName < $1.displayName }
                Task { @MainActor in
                    let signature = self.usersSignature(users)
                    guard signature != self.lastAllUsersSignature else { return }
                    self.lastAllUsersSignature = signature
                    self.allUsers = users
                }
            }
    }

    // MARK: - Register (Email / Password)

    func register(name: String, email: String, password: String, plate: String = "", car: String = "") async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let email = email.trimmingCharacters(in: .whitespaces).lowercased()

        // Domain restriction — checked against hashed list, domain strings are not in the binary
        if !AppConfig.isAllowedEmailDomain(email) {
            errorMessage = "Only company email addresses are allowed to register."
            return
        }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            let user = AppUser(
                uid:                     uid,
                email:                   email,
                displayName:             name,
                role:                    .user,
                status:                  .pending,
                registrationPlate:       plate.trimmingCharacters(in: .whitespaces).uppercased(),
                carDescription:          car.trimmingCharacters(in: .whitespaces),
                carColor:                "",
                carType:                 "",
                companyBadge:            CompanyBadge.infer(from: email),
                createdAt:               Date(),
                rejectionReason:         nil,
                inviteAccepted:          false,
                needsFinishRegistration: false,
                activatedAt:             nil
            )

            try await db.collection("users").document(uid).setData(user.toFirestore())

            // Save credentials for future biometric sign-in
            if KeychainManager.shared.canUseBiometrics {
                KeychainManager.shared.saveCredentials(email: email, password: password)
            }

            currentUser = user
            authState = .pendingApproval
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Login (Email / Password)

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let email = email.trimmingCharacters(in: .whitespaces).lowercased()

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)

            // Save credentials so biometric sign-in works next time
            if KeychainManager.shared.canUseBiometrics {
                KeychainManager.shared.saveCredentials(email: email, password: password)
            }
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Biometric Sign-In (passwordless after first login)

    func loginWithBiometrics() async -> Bool {
        guard let email = KeychainManager.shared.savedEmail else {
            errorMessage = "No saved credentials found. Please sign in with your password first."
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // This call triggers the Face ID / Touch ID prompt
        guard let password = await KeychainManager.shared.retrievePassword(
            reason: "Sign in to EL Parking"
        ) else {
            errorMessage = "Face ID credentials are unavailable. Please sign in with your password."
            return false
        }

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            return true
        } catch {
            errorMessage = friendlyError(error)
            // Credentials may be stale (password changed elsewhere) — clear them
            KeychainManager.shared.deleteCredentials()
            return false
        }
    }

    // MARK: - Sign Out

    func signOut(forgetBiometricCredentials: Bool = true) {
        try? Auth.auth().signOut()
        usersListener?.remove()
        usersListener = nil
        lastAllUsersSignature = nil
        currentUser   = nil
        allUsers      = []
        // pendingCount is computed from allUsers — no explicit reset needed
        authState     = .unauthenticated
        if forgetBiometricCredentials {
            KeychainManager.shared.deleteCredentials()
            UserDefaults.standard.set(false, forKey: "biometricLockEnabled")
        }
    }

    private func usersSignature(_ users: [AppUser]) -> Int {
        var hasher = Hasher()
        hasher.combine(users.count)
        for user in users {
            hasher.combine(user.uid)
            hasher.combine(user.email)
            hasher.combine(user.displayName)
            hasher.combine(user.role.rawValue)
            hasher.combine(user.status.rawValue)
            hasher.combine(user.registrationPlate)
            hasher.combine(user.carDescription)
            hasher.combine(user.carColor)
            hasher.combine(user.carType)
            hasher.combine(user.preferredVocative)
            hasher.combine(user.strikes)
            hasher.combine(user.suspensionCount)
            hasher.combine(user.suspendedAt?.timeIntervalSinceReferenceDate)
            hasher.combine(user.lastStrikeAt?.timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }

    // MARK: - Update Profile

    func updateProfile(
        displayName: String,
        plate: String,
        carDescription: String,
        carColor: String = "",
        carType: String = "",
        vehicleMiniaturePresetID: String = "",
        preferredVocative: String = "",
        companyBadge: CompanyBadge? = nil
    ) async {
        guard let uid = currentUser?.uid else { return }
        do {
            let trimmedVocative = preferredVocative.trimmingCharacters(in: .whitespacesAndNewlines)
            var update: [String: Any] = [
                "displayName":       displayName,
                "registrationPlate": plate,
                "carDescription":    carDescription,
                "vehicleMiniaturePresetID": vehicleMiniaturePresetID,
                "preferredVocative": trimmedVocative
            ]
            if !carColor.isEmpty { update["carColor"] = carColor }
            if !carType.isEmpty  { update["carType"]  = carType  }
            if let companyBadge { update["companyBadge"] = companyBadge.rawValue }
            try await db.collection("users").document(uid).updateData(update)
            currentUser?.displayName       = displayName
            currentUser?.registrationPlate = plate
            currentUser?.carDescription    = carDescription
            currentUser?.vehicleMiniaturePresetID = vehicleMiniaturePresetID
            currentUser?.preferredVocative = trimmedVocative
            if !carColor.isEmpty { currentUser?.carColor = carColor }
            if !carType.isEmpty  { currentUser?.carType  = carType  }
            if let companyBadge { currentUser?.companyBadge = companyBadge }
        } catch {
            print("AuthManager profile update error: \(error.localizedDescription)")
        }
    }

    func adminUpdateUserCompanyBadge(_ user: AppUser, companyBadge: CompanyBadge) async {
        do {
            try await db.collection("users").document(user.uid).updateData([
                "companyBadge": companyBadge.rawValue
            ])
            AuditLogger.log(
                action: "admin_update_company_badge",
                detail: "Updated company badge for \(user.email) to \(companyBadge.rawValue)",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager adminUpdateUserCompanyBadge error: \(error.localizedDescription)")
        }
    }

    // MARK: - Finish Registration (admin-created accounts)

    func finishRegistration(plate: String, car: String, color: String, carType: String = "", vehicleMiniaturePresetID: String = "", newPassword: String?) async {
        guard let firebaseUser = Auth.auth().currentUser,
              let uid = currentUser?.uid else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Optionally update password before writing Firestore (requires fresh auth session)
            if let pwd = newPassword, !pwd.isEmpty {
                try? await firebaseUser.updatePassword(to: pwd)
                if KeychainManager.shared.hasSavedCredentials, let email = currentUser?.email {
                    KeychainManager.shared.saveCredentials(email: email, password: pwd)
                }
            }

            try await db.collection("users").document(uid).updateData([
                "registrationPlate":       plate.trimmingCharacters(in: .whitespaces).uppercased(),
                "carDescription":          car.trimmingCharacters(in: .whitespaces),
                "carColor":                color,
                "carType":                 carType,
                "vehicleMiniaturePresetID": vehicleMiniaturePresetID,
                "inviteAccepted":          true,
                "needsFinishRegistration": false,
                "activatedAt":             Timestamp(date: Date())
            ])
            // Re-read the profile immediately so authState transitions to .authenticated.
            // There is no per-user document listener for regular users, so we must do
            // this manually instead of waiting for a snapshot callback that will never fire.
            await loadUserProfile(uid: uid)
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Admin: Create User (secondary FirebaseApp so admin isn't signed out)

    func adminCreateUser(
        name: String,
        email: String,
        tempPassword: String,
        role: UserRole,
        companyBadge: CompanyBadge? = nil
    ) async -> Result<AppUser, Error> {
        errorMessage = nil

        guard currentUser?.isAdmin == true else {
            let error = NSError(
                domain: "AuthManager",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Admin Setup: Only admins can create users."]
            )
            errorMessage = error.localizedDescription
            return .failure(error)
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            let error = NSError(
                domain: "AuthManager",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Admin Setup: Please enter the user's full name."]
            )
            errorMessage = error.localizedDescription
            return .failure(error)
        }

        guard AppConfig.isAllowedEmailDomain(normalizedEmail) else {
            let error = NSError(
                domain: "AuthManager",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Admin Setup: Only allowed company email addresses can be created."]
            )
            errorMessage = error.localizedDescription
            return .failure(error)
        }

        guard let primaryOptions = FirebaseApp.app()?.options else {
            let error = NSError(domain: "AuthManager", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Firebase Setup: Firebase is not configured."])
            errorMessage = error.localizedDescription
            return .failure(error)
        }

        let appName = "adminCreation_\(UUID().uuidString)"
        FirebaseApp.configure(name: appName, options: primaryOptions)
        guard let secondaryApp = FirebaseApp.app(name: appName) else {
            let error = NSError(
                domain: "AuthManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Firebase Setup: Could not create secondary Firebase app."]
            )
            errorMessage = error.localizedDescription
            return .failure(error)
        }

        let secondaryAuth = Auth.auth(app: secondaryApp)

        do {
            let result = try await secondaryAuth.createUser(withEmail: normalizedEmail, password: tempPassword)
            let createdFirebaseUser = result.user
            let uid = createdFirebaseUser.uid

            let user = AppUser(
                uid:                     uid,
                email:                   normalizedEmail,
                displayName:             trimmedName,
                role:                    role,
                status:                  .active,
                registrationPlate:       "",
                carDescription:          "",
                carColor:                "",
                carType:                 "",
                companyBadge:            companyBadge ?? CompanyBadge.infer(from: normalizedEmail),
                createdAt:               Date(),
                rejectionReason:         nil,
                inviteAccepted:          true,
                needsFinishRegistration: true,
                activatedAt:             nil
            )

            // Write using the secondary app's own Firestore instance.
            // On iOS, Firebase stores auth tokens in the Keychain under a project-scoped
            // key. Both primary and secondary apps share the same project, so
            // secondaryAuth.createUser() can overwrite the Keychain entry that
            // Firestore.firestore() (the primary db) reads — making subsequent writes
            // arrive with request.auth.uid == newUserUid instead of the admin's UID.
            // Using the secondary app's Firestore makes the auth context deterministic:
            // request.auth.uid == uid, which the "admin-provisioned fallback" create
            // rule in firestore.rules explicitly permits.
            let secondaryDb = Firestore.firestore(app: secondaryApp)
            try await secondaryDb.collection("users").document(uid).setData(user.toFirestore())
            try? secondaryAuth.signOut()
            await secondaryApp.delete()

            // Audit log uses primary db — at this point the secondary app is gone and
            // Auth.auth() is unambiguously the admin again.
            AuditLogger.log(
                action: "admin_create_user",
                detail: "Created account for \(normalizedEmail) with role \(role.rawValue)",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: uid
            )

            await fetchAllUsers()
            return .success(user)
        } catch {
            let authUserWasCreated = secondaryAuth.currentUser != nil
            let baseMessage = friendlyError(error)

            if authUserWasCreated {
                errorMessage = "Firestore Profile Creation Failed: \(baseMessage)"
                if let createdUser = secondaryAuth.currentUser {
                    do {
                        try await createdUser.delete()
                    } catch {
                        let cleanupMessage = "Rollback failed. Please delete the Auth user manually in Firebase Console."
                        errorMessage = "\(errorMessage ?? "") \(cleanupMessage)"
                    }
                }
            } else {
                errorMessage = "Authentication Account Creation Failed: \(baseMessage)"
            }

            try? secondaryAuth.signOut()
            await secondaryApp.delete()

            return .failure(NSError(
                domain: "AuthManager",
                code: (error as NSError).code,
                userInfo: [NSLocalizedDescriptionKey: errorMessage ?? baseMessage]
            ))
        }
    }

    // MARK: - Admin: Fetch All Users

    func fetchAllUsers() async {
        guard currentUser?.isAdmin == true else { return }
        do {
            let snapshot = try await db.collection("users")
                .order(by: "displayName")
                .getDocuments()
            allUsers = snapshot.documents.compactMap { AppUser.fromFirestore($0.data()) }
        } catch {
            print("AuthManager fetchAllUsers error: \(error.localizedDescription)")
        }
    }

    // MARK: - Admin: Activate User

    func activateUser(_ user: AppUser, role: UserRole = .user) async {
        do {
            try await db.collection("users").document(user.uid).updateData([
                "status": UserStatus.active.rawValue,
                "role":   role.rawValue,
                "inviteAccepted": true
            ])
            AuditLogger.log(
                action: "activate_user",
                detail: "Activated \(user.email) with role \(role.rawValue)",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager activateUser error: \(error.localizedDescription)")
        }
    }

    // MARK: - Admin: Suspend User

    func suspendUser(_ user: AppUser) async {
        do {
            try await db.collection("users").document(user.uid).updateData([
                "status": UserStatus.suspended.rawValue
            ])
            AuditLogger.log(
                action: "suspend_user",
                detail: "Suspended \(user.email)",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager suspendUser error: \(error.localizedDescription)")
        }
    }

    // MARK: - Strike System

    /// Lifts an expired 2-week suspension. Called automatically on login when the 14-day
    /// window has passed. The Firestore rule enforces the time gate server-side.
    private func liftExpiredSuspension(_ user: AppUser) async -> AppUser {
        var lifted = user
        lifted.status = .active
        lifted.strikes = 0
        do {
            try await db.collection("users").document(user.uid).updateData([
                "status":  UserStatus.active.rawValue,
                "strikes": 0,
                "inviteAccepted": true
            ])
            PushNotificationManager.sendToUser(
                email: user.email,
                title: "Suspension Lifted",
                body: "Your 2-week suspension has ended. You can book parking spots again. Welcome back!"
            )
            AuditLogger.log(
                action: "auto_lift_suspension",
                detail: "Auto-lifted suspension for \(user.email) after 14-day period",
                performedBy: user.uid,
                targetUID: user.uid
            )
        } catch {
            // Firestore rejected (time gate not yet met server-side, or network error) — keep suspended
            lifted = user
            print("AuthManager liftExpiredSuspension error: \(error.localizedDescription)")
        }
        return lifted
    }

    /// Admin assigns a warning strike to a user.
    /// 3 strikes → automatic 2-week suspension. User is notified at each step.
    func assignStrike(to user: AppUser, reason: String) async {
        guard currentUser?.isAdmin == true else { return }
        let trimmedReason  = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let newStrikeCount = user.strikes + 1
        let triggeredSuspension = newStrikeCount >= 3

        let entry = StrikeEntry(
            id:                  UUID().uuidString,
            reason:              trimmedReason.isEmpty ? "Misbehavior" : trimmedReason,
            assignedAt:          Date(),
            assignedBy:          currentUser?.email ?? "admin",
            strikeNumber:        newStrikeCount,
            suspensionTriggered: triggeredSuspension
        )

        let now = Date()
        var update: [String: Any] = [
            "strikes":       newStrikeCount,
            "lastStrikeAt":  Timestamp(date: now),
            "strikeHistory": FieldValue.arrayUnion([entry.toFirestore()])
        ]
        if triggeredSuspension {
            update["status"]          = UserStatus.suspended.rawValue
            update["suspendedAt"]     = Timestamp(date: now)
            update["suspensionCount"] = FieldValue.increment(Int64(1))
        }

        do {
            try await db.collection("users").document(user.uid).updateData(update)

            if triggeredSuspension {
                PushNotificationManager.sendToUser(
                    email: user.email,
                    title: "⚠️ Account Suspended",
                    body: "You received your 3rd warning. Your account has been suspended for 2 weeks. Reason: \(entry.reason)"
                )
            } else {
                let suffix = newStrikeCount == 2
                    ? " — One more warning will result in a 2-week suspension."
                    : ""
                PushNotificationManager.sendToUser(
                    email: user.email,
                    title: "Warning (\(newStrikeCount)/3)",
                    body: "You received a parking warning. Reason: \(entry.reason)\(suffix)"
                )
            }

            AuditLogger.log(
                action: "assign_strike",
                detail: "Strike \(newStrikeCount)/3 → \(user.email). Reason: \(entry.reason)\(triggeredSuspension ? " — SUSPENDED" : "")",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager assignStrike error: \(error.localizedDescription)")
        }
    }

    /// Admin manually restores a suspended user and clears all active strikes.
    func adminRestoreUser(_ user: AppUser) async {
        do {
            try await db.collection("users").document(user.uid).updateData([
                "status":  UserStatus.active.rawValue,
                "strikes": 0,
                "inviteAccepted": true
            ])
            PushNotificationManager.sendToUser(
                email: user.email,
                title: "Account Restored",
                body: "An administrator has restored your account. You can book parking spots again."
            )
            AuditLogger.log(
                action: "admin_restore_user",
                detail: "Admin restored \(user.email) and cleared active strikes",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager adminRestoreUser error: \(error.localizedDescription)")
        }
    }

    /// Decays one warning per 30-day window since the last warning was assigned.
    /// Called on every login for non-suspended users who have active strikes.
    private func checkStrikeDecay(_ user: AppUser) async -> AppUser {
        // Fall back to the latest strikeHistory date if lastStrikeAt is missing (legacy docs)
        let referenceDate = user.lastStrikeAt
            ?? user.strikeHistory.map(\.assignedAt).max()
        guard let ref = referenceDate else { return user }

        let daysSince = Date().timeIntervalSince(ref) / (24 * 3600)
        let decayAmount = min(user.strikes, Int(daysSince / 30.0))
        guard decayAmount > 0 else { return user }

        let newStrikes = user.strikes - decayAmount
        var updated = user
        updated.strikes = newStrikes
        if newStrikes == 0 { updated.lastStrikeAt = nil }

        do {
            var update: [String: Any] = ["strikes": newStrikes]
            if newStrikes == 0 { update["lastStrikeAt"] = FieldValue.delete() }
            try await db.collection("users").document(user.uid).updateData(update)
            AuditLogger.log(
                action: "strike_decay",
                detail: "Auto-decayed \(decayAmount) warning(s) for \(user.email). \(user.strikes) → \(newStrikes)",
                performedBy: user.uid,
                targetUID: user.uid
            )
        } catch {
            // Firestore rejected (network error or rule mismatch) — keep current count
            updated = user
            print("AuthManager checkStrikeDecay error: \(error.localizedDescription)")
        }
        return updated
    }

    /// Admin manually removes one warning from a user.
    func adminRemoveStrike(from user: AppUser) async {
        guard currentUser?.isAdmin == true, user.strikes > 0 else { return }
        let newStrikes = user.strikes - 1
        var update: [String: Any] = ["strikes": newStrikes]
        if newStrikes == 0 { update["lastStrikeAt"] = FieldValue.delete() }
        do {
            try await db.collection("users").document(user.uid).updateData(update)
            let suffix = newStrikes == 0 ? "You have no active warnings." : "You now have \(newStrikes)/3 active warning(s)."
            PushNotificationManager.sendToUser(
                email: user.email,
                title: "Warning Removed",
                body: "An administrator removed one of your warnings. \(suffix)"
            )
            AuditLogger.log(
                action: "admin_remove_strike",
                detail: "Removed 1 warning from \(user.email). \(user.strikes) → \(newStrikes)",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager adminRemoveStrike error: \(error.localizedDescription)")
        }
    }

    /// Admin deletes a specific warning entry from a user's history.
    /// Also decrements active strike count by 1 to keep warning state aligned with admin action.
    func adminDeleteStrikeEntry(_ entry: StrikeEntry, from user: AppUser) async {
        guard currentUser?.isAdmin == true else { return }

        let remainingHistory = user.strikeHistory
            .filter { $0.id != entry.id }
            .sorted { $0.assignedAt < $1.assignedAt }
        guard remainingHistory.count != user.strikeHistory.count else { return }

        let newStrikes = max(0, user.strikes - 1)
        var update: [String: Any] = [
            "strikes": newStrikes,
            "strikeHistory": remainingHistory.map { $0.toFirestore() }
        ]

        if newStrikes > 0, let newestStrikeDate = remainingHistory.map(\.assignedAt).max() {
            update["lastStrikeAt"] = Timestamp(date: newestStrikeDate)
        } else {
            update["lastStrikeAt"] = FieldValue.delete()
        }

        let isStrikeSuspension = user.isSuspended && (user.rejectionReason ?? "").isEmpty
        if isStrikeSuspension && newStrikes < 3 {
            update["status"] = UserStatus.active.rawValue
            update["suspendedAt"] = FieldValue.delete()
        }

        do {
            try await db.collection("users").document(user.uid).updateData(update)

            let becameActive = isStrikeSuspension && newStrikes < 3
            let body: String = becameActive
                ? "An administrator deleted a warning and your account suspension was lifted."
                : "An administrator deleted a warning from your record. You now have \(newStrikes)/3 active warning(s)."
            PushNotificationManager.sendToUser(
                email: user.email,
                title: "Warning Deleted",
                body: body
            )

            AuditLogger.log(
                action: "admin_delete_strike_entry",
                detail: "Deleted warning \(entry.id) from \(user.email). \(user.strikes) → \(newStrikes)\(becameActive ? " — restored to active" : "")",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager adminDeleteStrikeEntry error: \(error.localizedDescription)")
        }
    }

    // MARK: - Admin: Update Role

    func updateUserRole(_ user: AppUser, role: UserRole) async {
        do {
            try await db.collection("users").document(user.uid).updateData([
                "role": role.rawValue
            ])
            AuditLogger.log(
                action: "update_role",
                detail: "Changed \(user.email) role to \(role.rawValue)",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager updateRole error: \(error.localizedDescription)")
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return true
        } catch {
            errorMessage = friendlyError(error)
            return false
        }
    }

    // MARK: - Admin: Reject Pending Account

    func rejectUser(_ user: AppUser, reason: String) async {
        do {
            var update: [String: Any] = ["status": UserStatus.suspended.rawValue]
            if !reason.trimmingCharacters(in: .whitespaces).isEmpty {
                update["rejectionReason"] = reason.trimmingCharacters(in: .whitespaces)
            }
            try await db.collection("users").document(user.uid).updateData(update)

            let body = reason.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Your account registration was rejected by an administrator."
                : "Your account registration was rejected. Reason: \(reason.trimmingCharacters(in: .whitespaces))"
            PushNotificationManager.sendToUser(email: user.email, title: "Registration Rejected", body: body)

            AuditLogger.log(
                action: "reject_user",
                detail: "Rejected \(user.email)\(reason.isEmpty ? "" : " — reason: \(reason)")",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager rejectUser error: \(error.localizedDescription)")
        }
    }

    // MARK: - Admin: Delete User

    /// Updates a user's vehicle info (admin only).
    func adminUpdateUserVehicle(_ user: AppUser, plate: String, car: String, color: String, carType: String = "", vehicleMiniaturePresetID: String = "") async {
        let trimmedPlate    = plate.trimmingCharacters(in: .whitespaces).uppercased()
        let trimmedCar      = car.trimmingCharacters(in: .whitespaces)
        let trimmedColor    = color.trimmingCharacters(in: .whitespaces)
        let trimmedCarType  = carType.trimmingCharacters(in: .whitespaces)
        do {
            try await db.collection("users").document(user.uid).updateData([
                "registrationPlate": trimmedPlate,
                "carDescription":    trimmedCar,
                "carColor":          trimmedColor,
                "carType":           trimmedCarType,
                "vehicleMiniaturePresetID": vehicleMiniaturePresetID
            ])
            AuditLogger.log(
                action: "admin_update_vehicle",
                detail: "Updated vehicle for \(user.email): plate=\(trimmedPlate) car=\(trimmedCar) color=\(trimmedColor) type=\(trimmedCarType)",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
        } catch {
            print("AuthManager adminUpdateUserVehicle error: \(error.localizedDescription)")
        }
    }

    /// Deletes all of a user's bookings and their Firestore document.
    /// The orphaned Firebase Auth account is harmless — without a Firestore document
    /// the app immediately returns .unauthenticated on login, fully locking out the user.
    /// Full Auth deletion requires the Admin SDK (server-side only); orphaned accounts
    /// can be cleaned up manually in Firebase Console → Authentication if needed.
    func adminDeleteUser(_ user: AppUser) async -> Bool {
        do {
            let bookingSnap = try await db.collection("bookings")
                .whereField("email", isEqualTo: user.email)
                .getDocuments()
            let batch = db.batch()
            for doc in bookingSnap.documents {
                batch.deleteDocument(doc.reference)
            }
            batch.deleteDocument(db.collection("users").document(user.uid))
            try await batch.commit()

            AuditLogger.log(
                action: "admin_delete_user",
                detail: "Deleted user \(user.email) and \(bookingSnap.documents.count) booking(s)",
                performedBy: currentUser?.uid ?? "unknown",
                targetUID: user.uid
            )
            await fetchAllUsers()
            return true
        } catch {
            print("AuthManager adminDeleteUser error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Change Password

    /// Re-authenticates with current password then updates to new password.
    /// Also refreshes Keychain credentials so biometric sign-in keeps working.
    func changePassword(current: String, new: String) async -> Bool {
        guard let firebaseUser = Auth.auth().currentUser,
              let email = currentUser?.email else { return false }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: current)
            try await firebaseUser.reauthenticate(with: credential)
            try await firebaseUser.updatePassword(to: new)

            // Keep Keychain in sync so biometric sign-in doesn't break
            if KeychainManager.shared.hasSavedCredentials {
                KeychainManager.shared.saveCredentials(email: email, password: new)
            }
            return true
        } catch {
            let code = (error as NSError).code
            errorMessage = code == 17009 ? L10n.wrongCurrentPassword : friendlyError(error)
            return false
        }
    }

    // MARK: - Delete Account

    /// Permanently deletes the current user's Firestore document, their bookings, and their Firebase Auth account.
    func deleteAccount() async -> Bool {
        guard let firebaseUser = Auth.auth().currentUser,
              let user = currentUser else { return false }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let uid = user.uid

            // 1. Delete all bookings created by or belonging to this user
            let bookingSnapshot = try await db.collection("bookings")
                .whereField("email", isEqualTo: user.email)
                .getDocuments()
            let batch = db.batch()
            for doc in bookingSnapshot.documents {
                batch.deleteDocument(doc.reference)
            }

            // 2. Delete user Firestore document
            batch.deleteDocument(db.collection("users").document(uid))

            try await batch.commit()

            // 3. Log the action
            AuditLogger.log(
                action: "delete_account",
                detail: "User \(user.email) deleted their own account",
                performedBy: uid,
                targetUID: uid
            )

            // 4. Delete Firebase Auth account (must be last — can't call Firestore after this)
            try await firebaseUser.delete()

            // 5. Clean up local state
            KeychainManager.shared.deleteCredentials()
            usersListener?.remove()
            usersListener = nil
            currentUser   = nil
            allUsers      = []
            // pendingCount is computed from allUsers — no explicit reset needed
            authState     = .unauthenticated

            return true
        } catch {
            let code = (error as NSError).code
            if code == 17014 {
                // Firebase requires recent authentication — user must re-login first
                errorMessage = "For security, please sign out, sign back in, and try again."
            } else {
                errorMessage = friendlyError(error)
            }
            return false
        }
    }

    // MARK: - Error Handling

    private func friendlyError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17007: return "This email is already registered."   // registration-only, email existence OK to reveal here
        case 17008: return "Please enter a valid email address."
        case 17026: return "Password must be at least 6 characters."
        case 17009, 17011: return "Incorrect email or password."  // merged — don't reveal which one is wrong
        case 17020: return "Network error. Check your connection."
        case 17010: return "Too many attempts. Please try again later."
        default:    return error.localizedDescription
        }
    }
}
