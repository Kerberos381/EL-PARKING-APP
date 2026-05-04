//
//  BiometricLockView.swift
//  EL PARKING APP
//
//  Full-screen biometric gate. Shown on app launch when Face ID / Touch ID lock is enabled.
//  Matches the login screen's obsidian aesthetic.
//

import SwiftUI
import LocalAuthentication

struct BiometricLockView: View {
    @Binding var isUnlocked: Bool

    @State private var authFailed = false
    @State private var animatePulse = false
    @ObservedObject private var lang = LanguageManager.shared

    private var biometricType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    private var biometricIcon: String {
        switch biometricType {
        case .none:    return "lock.shield"
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        @unknown default: return "lock.shield"
        }
    }

    private var biometricLabel: String {
        switch biometricType {
        case .none:    return "Biometrics"
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.055)
                .ignoresSafeArea()

            // Subtle green glow
            RadialGradient(
                colors: [AppConfig.accent.opacity(0.10), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon
                ZStack {
                    Circle()
                        .fill(AppConfig.accent.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(AppConfig.accent.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 80, height: 80)
                    Image(systemName: "parkingsign")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppConfig.accentFg)
                }

                Text("EL Parking")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                // Biometric button
                Button {
                    authenticate()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppConfig.accent.opacity(animatePulse ? 0.18 : 0.08))
                            .frame(width: 90, height: 90)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animatePulse)

                        Image(systemName: biometricIcon)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(AppConfig.accentFg)
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                if authFailed {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(L10n.authFailed)
                            .font(.caption)
                    }
                    .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.35))
                    .transition(.opacity)
                }

                Spacer()

                // Passcode fallback
                Button {
                    authenticateWithPasscode()
                } label: {
                    Text(L10n.usePasscode)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            animatePulse = true
            authenticate()
        }
        .onDisappear {
            animatePulse = false
        }
    }

    // MARK: - Authentication

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics available — fall back to passcode or just unlock
            authenticateWithPasscode()
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: L10n.unlockReason
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    Haptics.impact(.soft)
                    withAnimation(.easeOut(duration: 0.25)) {
                        isUnlocked = true
                    }
                } else {
                    Haptics.notify(.error)
                    withAnimation { authFailed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { authFailed = false }
                    }
                }
            }
        }
    }

    /// Falls back to device passcode (PIN / password)
    private func authenticateWithPasscode() {
        let context = LAContext()
        context.evaluatePolicy(
            .deviceOwnerAuthentication,  // includes passcode fallback
            localizedReason: L10n.unlockReason
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    Haptics.impact(.soft)
                    withAnimation(.easeOut(duration: 0.25)) {
                        isUnlocked = true
                    }
                }
            }
        }
    }
}
