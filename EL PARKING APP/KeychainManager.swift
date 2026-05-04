//
//  KeychainManager.swift
//  EL PARKING APP
//
//  Secure credential storage using iOS Keychain with biometric access control.
//  Credentials are encrypted at rest and can only be read after Face ID / Touch ID succeeds.
//  If the user re-enrolls Face ID (new face added), stored credentials are invalidated — by design.
//

import Foundation
import Security
import LocalAuthentication

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private let service = Bundle.main.bundleIdentifier ?? "com.el.parking"
    private let accountKey = "el_parking_credentials"
    private let savedEmailKey = "biometric_saved_email"

    // MARK: - Public API

    /// Whether biometric credentials are stored for a user
    var hasSavedCredentials: Bool {
        savedEmail != nil
    }

    /// The email address of the saved credential (not biometric-protected)
    var savedEmail: String? {
        UserDefaults.standard.string(forKey: savedEmailKey)
    }

    /// Save email + password to Keychain, protected by biometric access.
    /// Called after a successful manual email/password login.
    func saveCredentials(email: String, password: String) {
        guard let data = password.data(using: .utf8) else { return }

        // Create biometric access control
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else { return }

        // Delete any existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new entry
        let addQuery: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      accountKey,
            kSecValueData as String:        data,
            kSecAttrAccessControl as String: access
        ]
        SecItemAdd(addQuery as CFDictionary, nil)

        // Save email unprotected (just to know which account to sign into)
        UserDefaults.standard.set(email, forKey: savedEmailKey)
    }

    /// Retrieve password from Keychain — triggers Face ID / Touch ID prompt automatically.
    /// The system uses NSFaceIDUsageDescription from Info.plist as the prompt reason.
    /// Returns nil if authentication fails or credentials not found.
    func retrievePassword(reason: String) async -> String? {
        guard savedEmail != nil else { return nil }

        // Use a fresh LAContext — the Keychain framework triggers biometrics via access control
        let context = LAContext()
        let query: [String: Any] = [
            kSecClass as String:                    kSecClassGenericPassword,
            kSecAttrService as String:              service,
            kSecAttrAccount as String:              accountKey,
            kSecReturnData as String:               true,
            kSecUseAuthenticationContext as String: context
        ]

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                if status == errSecSuccess,
                   let data = result as? Data,
                   let password = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: password)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Delete saved credentials (e.g. on sign-out)
    func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: savedEmailKey)
    }

    /// Whether the device supports biometric authentication
    var canUseBiometrics: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometricType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .none:    return "Biometrics"
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .none:    return "lock.shield"
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        @unknown default: return "lock.shield"
        }
    }
}
