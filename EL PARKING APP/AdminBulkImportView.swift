//
//  AdminBulkImportView.swift
//  EL PARKING APP
//
//  Admin tool: create multiple user accounts at once from a
//  pasted name + email list. Generates temporary passwords,
//  shows progress, and produces a copyable credential template.
//

import SwiftUI

struct AdminBulkImportView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared

    // MARK: - State

    @State private var inputText       = ""
    @State private var isImporting     = false
    @State private var progress        = 0
    @State private var results: [ImportResult] = []
    @State private var showResults     = false
    @State private var templateCopied  = false

    // MARK: - Model

    struct ImportResult: Identifiable {
        let id       = UUID()
        let name:      String
        let email:     String
        let password:  String
        let success:   Bool
        let errorMsg:  String?
    }

    private struct ParsedEntry {
        let name:     String
        let email:    String
        let isValid:  Bool
        let original: String
    }

    // MARK: - Computed

    private var parsedEntries: [ParsedEntry] {
        inputText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                let parts: [String] = line.contains(",")
                    ? line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    : line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

                let emailPart  = parts.first { $0.contains("@") } ?? ""
                let nameParts  = parts.filter { !$0.contains("@") }
                let name       = nameParts.isEmpty
                    ? String(emailPart.components(separatedBy: "@").first ?? "")
                    : nameParts.joined(separator: " ")
                let isValid    = isValidEmail(emailPart) && !name.trimmingCharacters(in: .whitespaces).isEmpty

                return ParsedEntry(name: name, email: emailPart.lowercased(), isValid: isValid, original: line)
            }
    }

    private var validEntries: [ParsedEntry] {
        parsedEntries.filter { $0.isValid }
    }

    private var successResults: [ImportResult] {
        results.filter { $0.success }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                if showResults {
                    resultsView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity))
                } else {
                    inputView
                }
            }
            .navigationTitle(L10n.bulkImport)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showResults && !isImporting {
                        Button(L10n.cancel) {
                            Haptics.selection()
                            dismiss()
                        }
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                }
            }
            .animation(.standard, value: showResults)
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Instruction banner
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text(L10n.bulkImportHint)
                            .font(.subheadline)
                            .foregroundStyle(AppConfig.subtleGray)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(14)
                    .background(AppConfig.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Text editor
                    ZStack(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text(L10n.bulkImportPlaceholder)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.45))
                                .padding(.top, 10)
                                .padding(.leading, 6)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(AppConfig.darkText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(10)
                    .background(AppConfig.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.03), radius: 6, y: 2)

                    // Preview list
                    if !parsedEntries.isEmpty {
                        previewList
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }

            // Bottom action bar
            bottomBar
        }
        .overlay {
            if isImporting { progressOverlay }
        }
    }

    // MARK: - Preview List

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(L10n.preview.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(parsedEntries.enumerated()), id: \.offset) { idx, entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(entry.isValid ? AppConfig.activeGreen : AppConfig.spotOccupied)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name.isEmpty ? entry.original : entry.name)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(entry.isValid ? AppConfig.darkText : AppConfig.subtleGray)
                            Text(entry.email.isEmpty ? "— invalid format —" : entry.email)
                                .font(.caption)
                                .foregroundStyle(entry.isValid ? AppConfig.subtleGray : AppConfig.spotOccupied)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if idx < parsedEntries.count - 1 {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                if !parsedEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(validEntries.count) \(L10n.valid)")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.activeGreen)
                        let invalid = parsedEntries.count - validEntries.count
                        if invalid > 0 {
                            Text("\(invalid) \(L10n.invalid)")
                                .font(.caption)
                                .foregroundStyle(AppConfig.spotOccupied)
                        }
                    }
                }
                Spacer()
                let count = validEntries.count
                Button {
                    Haptics.selection()
                    Task { await startImport() }
                } label: {
                    Text(L10n.bulkImportN(count))
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(count > 0 ? Color.white : AppConfig.subtleGray)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(count > 0 ? AppConfig.darkText : AppConfig.surfaceLow)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(count == 0 || isImporting)
                .animation(.standard, value: count)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppConfig.cardBg)
        }
    }

    // MARK: - Progress Overlay

    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("\(progress) / \(validEntries.count)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(L10n.importing)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26))
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Summary stat cards
                    let failCount = results.filter { !$0.success }.count
                    HStack(spacing: 12) {
                        statCard(value: successResults.count, label: L10n.createdLabel, color: AppConfig.activeGreen)
                        if failCount > 0 {
                            statCard(value: failCount, label: L10n.failedLabel, color: AppConfig.spotOccupied)
                        }
                    }

                    // Copy credential template + Send via Email
                    if !successResults.isEmpty {
                        // Send via Email – opens Mail with BCC pre-filled for all imported users
                        Button {
                            Haptics.selection()
                            sendViaEmail()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(L10n.sendViaEmail)
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppConfig.darkText)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(ScaleButtonStyle())

                        // Copy credential template
                        Button {
                            Haptics.selection()
                            copyTemplate()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: templateCopied ? "checkmark.circle.fill" : "doc.on.clipboard.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(templateCopied ? L10n.credentialsCopied : L10n.copyCredentialTemplate)
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .foregroundStyle(templateCopied ? AppConfig.activeGreen : AppConfig.darkText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(templateCopied ? AppConfig.activeGreen.opacity(0.1) : AppConfig.surfaceHigh)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(templateCopied ? AppConfig.activeGreen : AppConfig.separatorSoft, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .animation(.standard, value: templateCopied)
                    }

                    // Per-user results
                    VStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, result in
                            HStack(spacing: 12) {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(result.success ? AppConfig.activeGreen : AppConfig.spotOccupied)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.name)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(AppConfig.darkText)
                                    Text(result.email)
                                        .font(.caption)
                                        .foregroundStyle(AppConfig.subtleGray)

                                    if result.success {
                                        HStack(spacing: 5) {
                                            Image(systemName: "key")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                            Text(result.password)
                                                .font(.system(.caption, design: .monospaced).weight(.semibold))
                                                .foregroundStyle(AppConfig.darkText)
                                        }
                                    } else if let err = result.errorMsg {
                                        Text(err)
                                            .font(.caption2)
                                            .foregroundStyle(AppConfig.spotOccupied)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            if idx < results.count - 1 {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                    .background(AppConfig.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }

            // Done button
            VStack(spacing: 0) {
                Divider()
                Button {
                    Haptics.selection()
                    Task {
                        await authManager.fetchAllUsers()
                    }
                    dismiss()
                } label: {
                    Text(L10n.done)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppConfig.darkText)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(AppConfig.cardBg)
            }
        }
    }

    // MARK: - Stat Card Helper

    private func statCard(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppConfig.subtleGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Import Logic

    private func startImport() async {
        let entries = validEntries
        guard !entries.isEmpty else { return }

        let passwords = entries.map { _ in generatePassword() }

        await MainActor.run {
            isImporting = true
            progress    = 0
            results     = []
        }

        for (i, entry) in entries.enumerated() {
            let pwd    = passwords[i]
            let result = await authManager.adminCreateUser(
                name:         entry.name,
                email:        entry.email,
                tempPassword: pwd,
                role:         .user
            )
            await MainActor.run {
                progress = i + 1
                switch result {
                case .success:
                    results.append(ImportResult(
                        name: entry.name, email: entry.email, password: pwd,
                        success: true, errorMsg: nil
                    ))
                case .failure(let error):
                    results.append(ImportResult(
                        name: entry.name, email: entry.email, password: pwd,
                        success: false, errorMsg: friendlyError(error)
                    ))
                }
            }
        }

        await MainActor.run {
            isImporting = false
            let failedCount = results.filter { !$0.success }.count
            if failedCount == 0 {
                Haptics.notify(.success)
            } else {
                Haptics.notify(.error)
            }
            withAnimation(.standard) {
                showResults = true
            }
        }
    }

    private func copyTemplate() {
        let template = L10n.bulkCredentialsTemplate(
            results: successResults.map { (name: $0.name, email: $0.email, password: $0.password) }
        )
        UIPasteboard.general.string = template
        Haptics.notify(.success)
        withAnimation(.standard) { templateCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation(.standard) { templateCopied = false }
            }
        }
    }

    private func sendViaEmail() {
        // Put all imported users in BCC so recipients don't see each other's addresses.
        // Build the mailto: string manually — URLComponents mangles @ in addresses.
        let bcc     = successResults.map { $0.email }.joined(separator: ",")
        let subject = L10n.credentialsEmailSubject
        let body    = L10n.bulkCredentialsTemplate(
            results: successResults.map { (name: $0.name, email: $0.email, password: $0.password) }
        )
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")
        let bccEnc  = bcc.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let subEnc  = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let bodyEnc = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        if let url = URL(string: "mailto:?bcc=\(bccEnc)&subject=\(subEnc)&body=\(bodyEnc)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Utilities

    private func generatePassword() -> String {
        // Avoids visually ambiguous chars (0/O, 1/l/I)
        let chars = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<10).compactMap { _ in chars.randomElement() })
    }

    private func isValidEmail(_ s: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("already in use") || msg.contains("email-already-exists") {
            return "Email already exists"
        }
        if msg.contains("invalid email") {
            return "Invalid email address"
        }
        if msg.contains("permissions") {
            return "Permission denied"
        }
        return "Failed"
    }
}

// MARK: - L10n helpers needed here
private extension L10n {
    static var valid:   String { lang == .czech ? "platných"   : "valid" }
    static var invalid: String { lang == .czech ? "neplatných" : "invalid" }
}
