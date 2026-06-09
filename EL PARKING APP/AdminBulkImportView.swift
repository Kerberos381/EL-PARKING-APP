import SwiftUI
import UniformTypeIdentifiers

struct AdminBulkImportView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var mode: EntryMode = .manual
    @State private var rows: [DraftUserRow] = [DraftUserRow.empty()]
    @State private var isImporting = false
    @State private var showFileImporter = false
    @State private var fileImportError: String?

    @State private var showSuccess = false
    @State private var createdUsers: [CreatedUser] = []

    private let uploadAccent = Color(uiColor: .systemBlue)

    enum EntryMode {
        case manual
        case upload
    }

    struct DraftUserRow: Identifiable, Hashable {
        let id: UUID
        var name: String
        var email: String
        var password: String
        var emailLoginDetails: Bool

        static func empty() -> DraftUserRow {
            DraftUserRow(
                id: UUID(),
                name: "",
                email: "",
                password: Self.generatePassword(),
                emailLoginDetails: true
            )
        }

        static func generatePassword() -> String {
            let chars = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789")
            func part(_ n: Int) -> String { String((0..<n).compactMap { _ in chars.randomElement() }) }
            return "\(part(4))-\(part(4))-\(part(4))"
        }
    }

    struct CreatedUser: Identifiable {
        let id = UUID()
        let name: String
        let email: String
        let password: String
        let emailLoginDetails: Bool
    }

    enum RowValidation: Equatable {
        case empty
        case valid
        case invalidEmail
        case missingName
        case missingEmail
        case duplicate
    }

    private var nonEmptyRows: [DraftUserRow] {
        rows.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var validationByID: [UUID: RowValidation] {
        var result: [UUID: RowValidation] = [:]
        var seenEmails = Set<String>()

        for row in rows {
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = row.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if name.isEmpty && email.isEmpty {
                result[row.id] = .empty
                continue
            }
            if name.isEmpty {
                result[row.id] = .missingName
                continue
            }
            if email.isEmpty {
                result[row.id] = .missingEmail
                continue
            }
            guard isValidEmail(email) else {
                result[row.id] = .invalidEmail
                continue
            }
            if seenEmails.contains(email) {
                result[row.id] = .duplicate
                continue
            }
            seenEmails.insert(email)
            result[row.id] = .valid
        }

        return result
    }

    private var readyCount: Int {
        rows.filter { validationByID[$0.id] == .valid }.count
    }

    private var invalidCount: Int {
        rows.filter {
            if let v = validationByID[$0.id] {
                return v != .valid && v != .empty
            }
            return false
        }.count
    }

    private var duplicateCount: Int {
        rows.filter { validationByID[$0.id] == .duplicate }.count
    }

    private var canRegister: Bool {
        !rows.isEmpty && invalidCount == 0 && readyCount == rows.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppConfig.pageBg.ignoresSafeArea()

                if showSuccess {
                    successView
                } else {
                    editorView
                }

                if !showSuccess {
                    stickyRegisterButton
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.selection()
                        dismiss()
                    }
                    .foregroundStyle(Color.blue)
                    .font(.system(size: 18, weight: .regular))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var editorView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("EL PARK  ·  PEOPLE")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.75))

                Text("Bulk User Registration")
                    .font(.system(size: 46, weight: .black))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(AppConfig.darkText)

                modeSwitcher

                if mode == .upload {
                    uploadView
                }

                rowsEditorCard
                addAnotherButton

                if let fileImportError {
                    Text(fileImportError)
                        .font(.footnote)
                        .foregroundStyle(AppConfig.spotOccupied)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppConfig.spotOccupied.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !rows.isEmpty {
                    HStack(spacing: 14) {
                        Text("\(rows.count) PEOPLE")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(AppConfig.subtleGray)
                        Text("• \(readyCount) ready")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.blue)
                        if invalidCount > 0 {
                            Text("• \(invalidCount) invalid")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppConfig.spotOccupied)
                        }
                        if duplicateCount > 0 {
                            Text("• \(duplicateCount) duplicate")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            Button {
                Haptics.selection()
                mode = .manual
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Enter manually")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(mode == .manual ? AppConfig.darkText : AppConfig.subtleGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(mode == .manual ? AppConfig.cardBg : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button {
                Haptics.selection()
                mode = .upload
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Upload file")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(mode == .upload ? AppConfig.darkText : AppConfig.subtleGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(mode == .upload ? AppConfig.cardBg : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(AppConfig.surfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var uploadView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Haptics.selection()
                showFileImporter = true
            } label: {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(uploadAccent.opacity(0.14))
                            .frame(width: 66, height: 66)
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(uploadAccent)
                    }
                    Text("Drag a file here")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppConfig.darkText)
                    HStack(spacing: 4) {
                        Text("or")
                            .foregroundStyle(AppConfig.subtleGray)
                        Text("choose from device")
                            .foregroundStyle(uploadAccent)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    Text("CSV  ·  JSON  ·  TXT")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppConfig.separatorSoft, style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                templateChip(title: "CSV template") {
                    UIPasteboard.general.string = "name,email\nJane Doe,jane.doe@elpark.com\nMarco Bianchi,marco.bianchi@elpark.com"
                }
                templateChip(title: "JSON template") {
                    UIPasteboard.general.string = "[{\"name\":\"Jane Doe\",\"email\":\"jane.doe@elpark.com\"},{\"name\":\"Marco Bianchi\",\"email\":\"marco.bianchi@elpark.com\"}]"
                }
                Spacer()
            }
        }
    }

    private func templateChip(title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down")
                Text(title)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(uploadAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(AppConfig.surfaceHigh)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var rowsEditorCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                rowEditor(row: row)
                if index < rows.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppConfig.separatorSoft.opacity(0.6), lineWidth: 1)
        )
    }

    private var addAnotherButton: some View {
        Button {
            Haptics.selection()
            rows.append(.empty())
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Add another")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(uploadAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppConfig.separatorSoft.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func rowEditor(row: DraftUserRow) -> some View {
        let validation = validationByID[row.id] ?? .empty
        return VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Name")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(AppConfig.darkText)
                        .frame(width: 56, alignment: .leading)

                    TextField("Full name", text: binding(for: row.id, keyPath: \.name))
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(AppConfig.darkText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    removeRowButton(id: row.id)
                }
                .padding(.vertical, 12)

                Divider()

                HStack(spacing: 12) {
                    Text("Email")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(AppConfig.darkText)
                        .frame(width: 56, alignment: .leading)

                    TextField("name@elpark.com", text: binding(for: row.id, keyPath: \.email))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(validation == .invalidEmail || validation == .missingEmail || validation == .duplicate ? AppConfig.spotOccupied : AppConfig.subtleGray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)

            if validation == .valid {
                passwordRow(row: row)

                Button {
                    Haptics.selection()
                    toggleEmailLoginDetails(row.id)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(row.emailLoginDetails ? uploadAccent : AppConfig.surfaceLow)
                                .frame(width: 30, height: 30)
                            if row.emailLoginDetails {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text("Email login details")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                }
                .buttonStyle(.plain)
            }

            if validation != .valid && validation != .empty {
                Text(errorText(for: validation))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppConfig.spotOccupied)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func removeRowButton(id: UUID) -> some View {
        Button {
            Haptics.selection()
            removeRow(id)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
                .frame(width: 36, height: 36)
                .background(AppConfig.surfaceLow)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func passwordRow(row: DraftUserRow) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "key")
                    .foregroundStyle(AppConfig.subtleGray)
                Text(row.password)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppConfig.darkText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppConfig.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Haptics.selection()
                UIPasteboard.general.string = row.password
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.selection()
                regeneratePassword(row.id)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
    }

    private var stickyRegisterButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Haptics.action()
                Task { await registerUsers() }
            } label: {
                Text("Register  \(readyCount) users")
                    .font(.system(size: 17, weight: .bold))
                    .minimumScaleFactor(0.9)
                    .lineLimit(1)
                    .foregroundStyle(canRegister ? .white : AppConfig.subtleGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canRegister ? uploadAccent : AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .disabled(!canRegister || isImporting)
            .overlay {
                if isImporting {
                    ProgressView()
                        .tint(.white)
                }
            }
            .background(AppConfig.cardBg)
        }
    }

    private var successView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("EL PARK  ·  PEOPLE")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.75))

                Text("Bulk User Registration")
                    .font(.system(size: 46, weight: .black))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(AppConfig.darkText)

                HStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.12)).frame(width: 70, height: 70)
                            Image(systemName: "checkmark")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(uploadAccent)
                        }
                        Text("\(createdUsers.count) users registered")
                            .font(.system(size: 30, weight: .bold))
                            .minimumScaleFactor(0.8)
                        Text("Resend or copy credentials for anyone below.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppConfig.subtleGray)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }

                VStack(spacing: 0) {
                    ForEach(Array(createdUsers.enumerated()), id: \.element.id) { index, user in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.14))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Text(initials(for: user.name, fallbackEmail: user.email))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(uploadAccent)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.system(size: 17, weight: .semibold))
                                Text(user.email)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppConfig.subtleGray)
                            }
                            Spacer()

                            Button {
                                Haptics.selection()
                                UIPasteboard.general.string = "\(user.name)\n\(user.email)\n\(user.password)"
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(AppConfig.subtleGray)
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)

                            Button {
                                Haptics.selection()
                                resendCredentials(to: user)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope")
                                    Text("Resend")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(user.emailLoginDetails ? AppConfig.subtleGray : AppConfig.subtleGray.opacity(0.55))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(AppConfig.surfaceLow)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .disabled(!user.emailLoginDetails)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < createdUsers.count - 1 {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppConfig.separatorSoft.opacity(0.6), lineWidth: 1)
                )

                Button {
                    Haptics.selection()
                    resetForm()
                } label: {
                    Text("Register more people")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(uploadAccent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
    }

    private func binding(for id: UUID, keyPath: WritableKeyPath<DraftUserRow, String>) -> Binding<String> {
        Binding {
            rows.first(where: { $0.id == id })?[keyPath: keyPath] ?? ""
        } set: { newValue in
            guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
            rows[idx][keyPath: keyPath] = newValue
            fileImportError = nil
        }
    }

    private func removeRow(_ id: UUID) {
        if rows.count == 1 {
            rows[0] = .empty()
            return
        }
        rows.removeAll { $0.id == id }
    }

    private func regeneratePassword(_ id: UUID) {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[idx].password = DraftUserRow.generatePassword()
    }

    private func toggleEmailLoginDetails(_ id: UUID) {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[idx].emailLoginDetails.toggle()
    }

    private func registerUsers() async {
        guard canRegister else { return }
        let payload = rows
        await MainActor.run {
            isImporting = true
        }

        var created: [CreatedUser] = []

        for row in payload {
            let result = await authManager.adminCreateUser(
                name: row.name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: row.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                tempPassword: row.password,
                role: .user
            )

            switch result {
            case .success:
                created.append(
                    CreatedUser(
                        name: row.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        email: row.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                        password: row.password,
                        emailLoginDetails: row.emailLoginDetails
                    )
                )
            case .failure(let error):
                await MainActor.run {
                    isImporting = false
                    Haptics.notify(.error)
                    fileImportError = "Failed to create \(row.email): \(friendlyError(error))"
                }
                return
            }
        }

        await MainActor.run {
            createdUsers = created
            isImporting = false
            Haptics.notify(.success)
            showSuccess = true
        }
    }

    private func resetForm() {
        rows = [.empty()]
        createdUsers = []
        fileImportError = nil
        showSuccess = false
        mode = .manual
    }

    private func resendCredentials(to user: CreatedUser) {
        let subject = "Your EL PARK account credentials"
        let body = "Hello \(user.name),\n\nYour login details:\nEmail: \(user.email)\nPassword: \(user.password)\n\nPlease change your password after first login."

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")

        let to = user.email.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let sub = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let bdy = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""

        if let url = URL(string: "mailto:\(to)?subject=\(sub)&body=\(bdy)") {
            UIApplication.shared.open(url)
        }
    }

    private func initials(for name: String, fallbackEmail: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let parts = trimmed.split(separator: " ").prefix(2)
            let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
            if !letters.isEmpty { return letters }
        }
        let local = fallbackEmail.split(separator: "@").first.map(String.init) ?? "U"
        return String(local.prefix(2)).uppercased()
    }

    private func errorText(for validation: RowValidation) -> String {
        switch validation {
        case .invalidEmail: return "Invalid email"
        case .missingEmail: return "Missing email"
        case .missingName: return "Missing name"
        case .duplicate: return "Already in list"
        case .empty, .valid: return ""
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("already in use") || msg.contains("email-already-exists") { return "Email already exists" }
        if msg.contains("invalid email") { return "Invalid email address" }
        if msg.contains("permissions") { return "Permission denied" }
        return "Failed"
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            Haptics.notify(.error)
            fileImportError = "Could not open file."
        case .success(let urls):
            guard let url = urls.first else {
                Haptics.notify(.error)
                fileImportError = "No file selected."
                return
            }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)
                let ext = url.pathExtension.lowercased()
                let importedRows: [DraftUserRow]

                if ext == "json" {
                    importedRows = try parseJSONRows(from: data)
                } else {
                    guard let raw = String(data: data, encoding: .utf8) else {
                        throw NSError(domain: "import", code: 1)
                    }
                    importedRows = parseDelimitedRows(raw)
                }

                guard !importedRows.isEmpty else {
                    throw NSError(domain: "import", code: 2)
                }

                rows = importedRows
                mode = .manual
                fileImportError = nil
                Haptics.notify(.success)
            } catch {
                Haptics.notify(.error)
                fileImportError = "Unsupported file format. Use CSV, JSON, or TXT with name + email."
            }
        }
    }

    private func parseDelimitedRows(_ raw: String) -> [DraftUserRow] {
        raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                if line.lowercased().contains("email") && line.lowercased().contains("name") { return nil }
                let normalized = line.replacingOccurrences(of: ";", with: ",")
                if normalized.contains(",") {
                    let parts = normalized.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    let email = parts.first(where: { $0.contains("@") }) ?? ""
                    let name = parts.filter { !$0.contains("@") }.joined(separator: " ")
                    return DraftUserRow(
                        id: UUID(),
                        name: name,
                        email: email,
                        password: DraftUserRow.generatePassword(),
                        emailLoginDetails: true
                    )
                }

                let parts = normalized.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                let email = parts.first(where: { $0.contains("@") }) ?? ""
                let name = parts.filter { !$0.contains("@") }.joined(separator: " ")
                return DraftUserRow(
                    id: UUID(),
                    name: name,
                    email: email,
                    password: DraftUserRow.generatePassword(),
                    emailLoginDetails: true
                )
            }
    }

    private func parseJSONRows(from data: Data) throws -> [DraftUserRow] {
        let object = try JSONSerialization.jsonObject(with: data)
        let items: [[String: Any]]

        if let arr = object as? [[String: Any]] {
            items = arr
        } else if let dict = object as? [String: Any], let users = dict["users"] as? [[String: Any]] {
            items = users
        } else {
            items = []
        }

        return items.compactMap { item in
            let name = (item["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let email = (
                item["email"] as? String ??
                item["mail"] as? String ??
                item["username"] as? String ?? ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            if name.isEmpty && email.isEmpty { return nil }

            return DraftUserRow(
                id: UUID(),
                name: name,
                email: email,
                password: DraftUserRow.generatePassword(),
                emailLoginDetails: true
            )
        }
    }
}
