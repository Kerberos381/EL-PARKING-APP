//
//  LoginView.swift
//  EL PARKING APP
//
//  Passwordless login: Face ID / Touch ID retrieves credentials from Keychain.
//  Email + password only needed on first login or if biometrics fail.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var lang = LanguageManager.shared

    @State private var showEmailForm   = false   // collapsed by default when biometrics available
    @State private var email           = ""
    @State private var password        = ""
    @State private var showPassword       = false
    @State private var showForgotPassword = false
    @State private var resetEmailSent     = false

    private enum Field: Hashable { case email, password }
    @FocusState private var focusedField: Field?

    private let keychain = KeychainManager.shared

    /// Show biometric button when credentials are saved and biometrics available
    private var showBiometricButton: Bool {
        keychain.hasSavedCredentials && keychain.canUseBiometrics
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.055)
                .ignoresSafeArea()

            RadialGradient(
                colors: [AppConfig.accent.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 36) {
                    logoSection

                    if showBiometricButton && !showEmailForm {
                        biometricCard
                    } else {
                        formCard
                    }
                }
                .padding(.bottom, 60)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .onAppear {
            // Auto-trigger biometric on appear if credentials are saved
            if showBiometricButton {
                Task { await authManager.loginWithBiometrics() }
            }
        }
        .alert(L10n.resetPassword, isPresented: $showForgotPassword) {
            TextField(L10n.emailAddress, text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button(L10n.sendResetLink) {
                Task {
                    let success = await authManager.resetPassword(email: email)
                    if success { resetEmailSent = true }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.enterEmailForReset)
        }
        .alert(L10n.checkYourEmail, isPresented: $resetEmailSent) {
            Button(L10n.ok) {}
        } message: {
            Text(L10n.resetEmailSent(email))
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppConfig.accent.opacity(0.15))
                    .frame(width: 90, height: 90)
                Circle()
                    .stroke(AppConfig.accent.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 90, height: 90)
                Image(systemName: "parkingsign")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 64)

            Text("EL Parking")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("EssilorLuxottica")
                .font(.system(size: 13, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Biometric Card (shown when credentials saved)

    private var biometricCard: some View {
        VStack(spacing: 28) {
            // Biometric button
            Button {
                Task { await authManager.loginWithBiometrics() }
            } label: {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppConfig.accent.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Circle()
                            .stroke(AppConfig.accent.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 100, height: 100)
                        Image(systemName: keychain.biometricIcon)
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text(L10n.biometricWelcome(""))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        if let email = keychain.savedEmail {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Text(L10n.tapToSignIn(keychain.biometricName))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.top, 2)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())

            // Error message
            if let error = authManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.35))
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.35))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
                .transition(.opacity)
            }

            // Divider + use password fallback
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    Text("OR")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.25))
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                }

                Button {
                    withAnimation(.standard) {
                        showEmailForm = true
                    }
                } label: {
                    Text(L10n.signInWithPwd)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.clear)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Email / Password Form Card

    private var formCard: some View {
        VStack(spacing: 22) {

            // Back button when biometric card exists
            if showBiometricButton && showEmailForm {
                Button {
                    withAnimation(.standard) {
                        showEmailForm = false
                        authManager.errorMessage = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.back)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Text(L10n.welcomeBack)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                inputField(icon: "envelope", placeholder: L10n.emailAddress, text: $email,
                           keyboardType: .emailAddress, capitalization: .never,
                           submitLabel: .next, onSubmit: { focusedField = .password })
                    .focused($focusedField, equals: .email)

                passwordField(placeholder: L10n.password, text: $password,
                              submitLabel: .go,
                              onSubmit: { Task { await authManager.login(email: email, password: password) } })
                    .focused($focusedField, equals: .password)
            }

            // Biometric hint for new users
            if !showBiometricButton && keychain.canUseBiometrics {
                HStack(spacing: 6) {
                    Image(systemName: keychain.biometricIcon)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                    Text(L10n.biometricSetupInfo(keychain.biometricName))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Error message
            if let error = authManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.35))
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.35))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
            }

            // Primary action button
            Button {
                Task { await authManager.login(email: email, password: password) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFormValid ? AppConfig.accent : AppConfig.accent.opacity(0.4))
                    if authManager.isLoading {
                        ProgressView().tint(.black).scaleEffect(0.9)
                    } else {
                        Text(L10n.signIn)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(height: 54)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(authManager.isLoading || !isFormValid)

            Button {
                showForgotPassword = true
            } label: {
                Text(L10n.forgotPassword)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.clear)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Form Validation

    private var isEmailFormatValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: "@", maxSplits: 1)
        guard parts.count == 2,
              !parts[0].isEmpty,
              let domain = parts.last,
              domain.contains("."),
              domain.last != "."
        else { return false }
        return true
    }

    private var isFormValid: Bool {
        isEmailFormatValid && !password.isEmpty
    }

    // MARK: - Input Components

    @ViewBuilder
    private func inputField(icon: String, placeholder: String, text: Binding<String>,
                            keyboardType: UIKeyboardType = .default,
                            capitalization: TextInputAutocapitalization = .sentences,
                            submitLabel: SubmitLabel = .return,
                            onSubmit: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .foregroundStyle(.white)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
        }
        .padding(14)
        .appGlassField()
    }

    @ViewBuilder
    private func passwordField(placeholder: String, text: Binding<String>,
                               submitLabel: SubmitLabel = .return,
                               onSubmit: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)
            if showPassword {
                TextField(placeholder, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.white)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
            } else {
                SecureField(placeholder, text: text)
                    .foregroundStyle(.white)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
            }
            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(.white.opacity(0.35))
                    .font(.system(size: 15))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .appGlassField()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
