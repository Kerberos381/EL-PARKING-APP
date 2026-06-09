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
    @Environment(\.colorScheme) private var colorScheme

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
            backgroundColor.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    if showBiometricButton && !showEmailForm {
                        logoSection
                        biometricCard
                    } else {
                        logoSection
                        formCard
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.top, 34)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        // Do not auto-trigger biometric on appear.
        // User must explicitly tap the biometric button to sign in.
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
        VStack(spacing: 10) {
            Group {
                if UIImage(named: "AppIconImage") != nil {
                    Image("AppIconImage")
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "parkingsign")
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 14, y: 6)
            .padding(.top, 20)

            Text("EL Parking")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .tracking(0.2)

            Text("EssilorLuxottica")
                .font(.system(size: 12, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(secondaryTextColor)
        }
    }

    // MARK: - Biometric Card (shown when credentials saved)

    private var biometricCard: some View {
        VStack(spacing: 28) {
            // Biometric button
            Button {
                Task {
                    let ok = await authManager.loginWithBiometrics()
                    if !ok {
                        await MainActor.run {
                            withAnimation(.standard) {
                                showEmailForm = true
                            }
                        }
                    }
                }
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
                    keychain.deleteCredentials()
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

                Button {
                    showForgotPassword = true
                } label: {
                    Text(L10n.forgotPassword)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.35))
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
        VStack(spacing: 18) {

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
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Text(L10n.signIn)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .minimumScaleFactor(0.85)
                .lineLimit(1)

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

            HStack {
                Spacer()
                Button {
                    showForgotPassword = true
                } label: {
                    Text(L10n.forgotPassword)
                        .font(.subheadline)
                        .foregroundStyle(secondaryTextColor)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // Biometric hint for new users
            if !showBiometricButton && keychain.canUseBiometrics {
                HStack(spacing: 6) {
                    Image(systemName: keychain.biometricIcon)
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                    Text(L10n.biometricSetupInfo(keychain.biometricName))
                        .font(.caption2)
                        .foregroundStyle(secondaryTextColor)
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

            Button {
                Task { await authManager.login(email: email, password: password) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isFormValid ? AppConfig.accent : AppConfig.accent.opacity(0.4))
                    if authManager.isLoading {
                        ProgressView().tint(.black).scaleEffect(0.9)
                    } else {
                        Text(L10n.signIn)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                    }
                }
                .frame(height: 60)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(authManager.isLoading || !isFormValid)

            privacyPolicyLink
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .shadow(color: shadowColor, radius: 14, y: 6)
        )
        .frame(maxWidth: 480)
    }

    private var privacyPolicyLink: some View {
        Link(destination: AppConfig.privacyPolicyURL) {
            Text(L10n.privacyPolicy)
                .font(.footnote.weight(.medium))
                .foregroundStyle(secondaryTextColor)
                .underline(false)
        }
        .padding(.top, 2)
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
                .foregroundStyle(secondaryTextColor)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .foregroundStyle(primaryTextColor)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fieldColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func passwordField(placeholder: String, text: Binding<String>,
                               submitLabel: SubmitLabel = .return,
                               onSubmit: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundStyle(secondaryTextColor)
                .frame(width: 20)
            if showPassword {
                TextField(placeholder, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(primaryTextColor)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
            } else {
                SecureField(placeholder, text: text)
                    .foregroundStyle(primaryTextColor)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
            }
            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(secondaryTextColor)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fieldColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.06, green: 0.06, blue: 0.07) : Color(red: 0.96, green: 0.96, blue: 0.97)
    }

    private var cardColor: Color {
        colorScheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.16) : .white
    }

    private var fieldColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.09, green: 0.09, blue: 0.11)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.48)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.08)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
