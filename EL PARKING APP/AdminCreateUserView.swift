//
//  AdminCreateUserView.swift
//  EL PARKING APP
//
//  Admin-only screen to create a new user account and share credentials.
//

import SwiftUI

struct AdminCreateUserView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var lang = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name          = ""
    @State private var email         = ""
    @State private var tempPassword  = Self.generatePassword()
    @State private var selectedRole: UserRole = .user
    @State private var isLoading     = false
    @State private var errorMsg: String? = nil
    @State private var createdUser: AppUser? = nil
    @State private var credentialsCopied = false
    @State private var showShareSheet    = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    if let created = createdUser {
                        successView(created)
                    } else {
                        formView
                    }
                }
            }
            .navigationTitle(L10n.adminCreateUserTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                        .foregroundStyle(AppConfig.darkText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if createdUser != nil {
                        Button(L10n.done) {
                            Haptics.selection()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConfig.darkText)
                    } else if isLoading {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Button(L10n.adminCreateUser) {
                            guard isFormValid else { return }
                            Haptics.selection()
                            createUser()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(isFormValid ? AppConfig.accentFg : AppConfig.subtleGray)
                        .disabled(!isFormValid)
                    }
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(spacing: 16) {
            // Info banner
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text(L10n.adminCreateUserSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppConfig.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.top, 8)

            // Identity card
            sectionCard(title: L10n.userManagement.uppercased(), icon: "person.fill") {
                VStack(spacing: 8) {
                    inputRow(icon: "person", placeholder: L10n.fullName,
                             text: $name, capitalization: .words)
                    if let msg = nameValidationMessage {
                        inlineValidation(msg, isError: true)
                    }
                    inputRow(icon: "envelope", placeholder: L10n.emailAddress,
                             text: $email, keyboardType: .emailAddress, capitalization: .never)
                    if let msg = emailValidationMessage {
                        inlineValidation(msg, isError: true)
                    }
                }
            }

            // Role card
            sectionCard(title: L10n.assignRole.uppercased(), icon: "shield.fill") {
                HStack(spacing: 8) {
                    ForEach(UserRole.allCases, id: \.rawValue) { role in
                        let sel = role == selectedRole
                        Button {
                            guard selectedRole != role else { return }
                            Haptics.selection()
                            withAnimation(.quick) { selectedRole = role }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: roleIcon(role))
                                    .font(.system(size: 14, weight: .semibold))
                                Text(role.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(sel ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(sel ? AppConfig.surfaceHigh : AppConfig.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(sel ? AppConfig.separatorSoft : AppConfig.separatorSoft, lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(4)
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Password card
            sectionCard(title: L10n.tempPassword.uppercased(), icon: "lock.fill") {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "key")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(tempPassword)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            Haptics.selection()
                            withAnimation(.quick) {
                                tempPassword = Self.generatePassword()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(14)
                    .background(AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppConfig.outlineVariant.opacity(0.4), lineWidth: 1))

                    Button(L10n.generatePassword) {
                        Haptics.selection()
                        withAnimation { tempPassword = Self.generatePassword() }
                    }
                    .font(.caption)
                    .foregroundStyle(AppConfig.darkText)
                }
            }

            // Error
            if let err = errorMsg {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: errorBannerIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(errorBannerColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(errorBannerTitle)
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(errorBannerColor)
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(errorBannerColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(errorBannerColor.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Success

    @ViewBuilder
    private func successView(_ user: AppUser) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppConfig.activeGreen.opacity(0.15)).frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppConfig.activeGreen)
                }
                .padding(.top, 48)
                Text(L10n.userCreated)
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            // Credentials box
            VStack(alignment: .leading, spacing: 12) {
                credRow(icon: "person.fill",  label: L10n.fullName, value: user.displayName)
                Divider()
                credRow(icon: "envelope.fill", label: L10n.emailAddress, value: user.email)
                Divider()
                credRow(icon: "key", label: L10n.tempPassword, value: tempPassword)
                Divider()
                credRow(icon: "shield.fill", label: L10n.assignRole, value: user.role.displayName)
            }
            .padding(20)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
            .padding(.horizontal)

            // Email button – opens Mail with recipient pre-filled
            if let url = mailtoURL(
                to: user.email,
                subject: L10n.credentialsEmailSubject,
                body: L10n.credentialsEmailBody(name: user.displayName, email: user.email, password: tempPassword)
            ) {
                Button {
                    Haptics.selection()
                    UIApplication.shared.open(url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                        Text(L10n.sendViaEmail)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppConfig.darkText)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal)
            }

            // Share button (fallback — AirDrop, Messages, etc.)
            ShareLink(
                item: L10n.credentialsEmailBody(name: user.displayName, email: user.email, password: tempPassword),
                subject: Text(L10n.credentialsEmailSubject)
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(L10n.shareCredentials)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppConfig.darkText)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppConfig.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppConfig.separatorSoft, lineWidth: 1))
            }
            .padding(.horizontal)

            // Copy button
            Button {
                Haptics.selection()
                let text = L10n.credentialsEmailBody(name: user.displayName, email: user.email, password: tempPassword)
                UIPasteboard.general.string = text
                Haptics.notify(.success)
                withAnimation { credentialsCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { credentialsCopied = false }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: credentialsCopied ? "checkmark" : "doc.on.doc")
                    Text(credentialsCopied ? L10n.credentialsCopied : L10n.copyToClipboard)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
            }
            .buttonStyle(ScaleButtonStyle())

            Button(L10n.done) {
                Haptics.selection()
                dismiss()
            }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") && email.contains(".")
    }

    private var nameValidationMessage: String? {
        if name.isEmpty { return nil }
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? (L10n.lang == .czech ? "Jméno je povinné." : "Name is required.") : nil
    }

    private var emailValidationMessage: String? {
        if email.isEmpty { return nil }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let valid = trimmed.contains("@") && trimmed.contains(".")
        return valid ? nil : (L10n.lang == .czech ? "Zadejte platný e-mail." : "Enter a valid email address.")
    }

    private func createUser() {
        isLoading = true
        errorMsg  = nil
        Task {
            let result = await authManager.adminCreateUser(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                tempPassword: tempPassword,
                role: selectedRole
            )
            await MainActor.run {
                isLoading = false
                switch result {
                case .success(let user):
                    Haptics.notify(.success)
                    withAnimation { createdUser = user }
                case .failure(let err):
                    Haptics.notify(.error)
                    errorMsg = err.localizedDescription
                }
            }
        }
    }

    private func roleIcon(_ role: UserRole) -> String {
        switch role {
        case .admin:      return "checkmark.shield.fill"
        case .privileged: return "star.fill"
        case .user:       return "person.fill"
        }
    }

    private var errorBannerTitle: String {
        guard let errorMsg else { return "Error" }
        if errorMsg.contains("Firestore") { return "Firestore" }
        if errorMsg.contains("Authentication") { return "Authentication" }
        if errorMsg.contains("Firebase Setup") { return "Firebase Setup" }
        if errorMsg.contains("Admin Setup") { return "Admin Setup" }
        return "Create User Failed"
    }

    private var errorBannerIcon: String {
        guard let errorMsg else { return "xmark.circle.fill" }
        if errorMsg.contains("Firestore") { return "externaldrive.fill.badge.xmark" }
        if errorMsg.contains("Authentication") { return "person.crop.circle.badge.exclamationmark" }
        if errorMsg.contains("Setup") { return "wrench.and.screwdriver.fill" }
        return "xmark.circle.fill"
    }

    private var errorBannerColor: Color {
        guard let errorMsg else { return AppConfig.spotOccupied }
        if errorMsg.contains("Firestore") { return .orange }
        if errorMsg.contains("Authentication") { return AppConfig.spotOccupied }
        return AppConfig.spotOccupied
    }

    @ViewBuilder
    private func credRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 10) { content() }
                .padding(16)
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func inlineValidation(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12))
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(isError ? AppConfig.spotOccupied.opacity(0.85) : AppConfig.activeGreen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func inputRow(icon: String, placeholder: String, text: Binding<String>,
                          keyboardType: UIKeyboardType = .default,
                          capitalization: TextInputAutocapitalization = .sentences) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppConfig.outlineVariant.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Email Helper

    private func mailtoURL(to: String, subject: String, body: String) -> URL? {
        // URLComponents mis-parses the @ in email addresses as user@host —
        // build the mailto: string directly with explicit percent-encoding.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")
        let s = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let b = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "mailto:\(to)?subject=\(s)&body=\(b)")
    }

    // MARK: - Password Generator

    private static func generatePassword(length: Int = 10) -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
