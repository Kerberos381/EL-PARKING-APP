//
//  AdminInfoView.swift
//  EL PARKING APP
//
//  Admin CRUD for /info_items — the Info section on the Home screen.
//  When creating, admin can optionally push the card to all users instantly.
//  When editing, a separate "Push to All" button is available.
//

import SwiftUI
import PhotosUI

struct AdminInfoView: View {
    @EnvironmentObject var infoManager: InfoManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var lang = LanguageManager.shared

    @State private var showAddSheet = false
    @State private var editingItem:  InfoItem?
    @State private var pushSentFor:  String?   // id of item just pushed — shows tick confirmation
    @State private var isInitialLoading = true

    var body: some View {
        ZStack {
            AppConfig.pageBg.ignoresSafeArea()

            // ── Error banner (shown when Firestore rejects a write, e.g. rules not deployed) ──
            VStack {
                if let err = infoManager.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppConfig.warning)
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(AppConfig.darkText)
                        Spacer()
                        Button { infoManager.errorMessage = nil } label: {
                            Image(systemName: "xmark").font(.caption2)
                                .foregroundStyle(AppConfig.subtleGray)
                        }
                        .accessibilityLabel("Dismiss error")
                    }
                    .padding(12)
                    .background(AppConfig.warning.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .zIndex(1)
            .animation(reduceMotion ? .none : .standard, value: infoManager.errorMessage)

            if isInitialLoading && infoManager.items.isEmpty && infoManager.errorMessage == nil {
                loadingSkeleton
            } else if infoManager.items.isEmpty && infoManager.errorMessage == nil {
                VStack(spacing: 16) {
                    AppEmptyStateCard(
                        icon: "info.circle",
                        title: L10n.noInfoCards,
                        subtitle: L10n.tapPlusToAdd
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    Spacer(minLength: 0)
                }
            } else {
                List {
                    ForEach(infoManager.items) { item in
                        Button {
                            Haptics.action()
                            editingItem = item
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppConfig.surfaceHigh)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: item.icon)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                    if !item.body.isEmpty {
                                        Text(item.body)
                                            .font(.footnote)
                                            .foregroundStyle(AppConfig.subtleGray)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                // Quick push button
                                Button {
                                    Haptics.action()
                                    infoManager.pushNotification(for: item)
                                    withAnimation(reduceMotion ? .none : .standard) { pushSentFor = item.id }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation(reduceMotion ? .none : .standard) { pushSentFor = nil }
                                    }
                                } label: {
                                    Image(systemName: pushSentFor == item.id ? "checkmark.circle.fill" : "bell.badge.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(pushSentFor == item.id ? AppConfig.infoTint : Color.secondary)
                                        .frame(width: 32, height: 32)
                                        .background(AppConfig.surfaceLow)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppConfig.separatorSoft, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .help("Push notification to all users")
                                .accessibilityLabel("Push notification")
                                .accessibilityHint("Sends \(item.title) to all users")
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(AppConfig.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppConfig.radius16)
                                    .stroke(AppConfig.separatorSoft, lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        Haptics.destructive()
                        for index in indexSet {
                            let item = infoManager.items[index]
                            Task { await infoManager.delete(item) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(AppConfig.groupedPageBg.ignoresSafeArea())
                .scrollEdgeEffectStyle(.soft, for: .top)
                .refreshable {
                    await infoManager.refresh()
                    Haptics.refreshCompleted()
                }
            }
        }
        .navigationTitle(L10n.infoCards)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.action()
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
                .foregroundStyle(AppConfig.darkText)
                .accessibilityLabel("New info card")
                .accessibilityHint("Opens create info card form")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            InfoItemFormView(mode: .add) { icon, title, body, fields, linkTitle, linkURL, imageURL, imageBase64, sendPush in
                Task {
                    await infoManager.create(
                        icon: icon,
                        title: title,
                        body: body,
                        fields: fields,
                        linkTitle: linkTitle,
                        linkURL: linkURL,
                        imageURL: imageURL,
                        imageBase64: imageBase64,
                        sendPush: sendPush
                    )
                }
            }
        }
        .sheet(item: $editingItem) { item in
            InfoItemFormView(mode: .edit(item)) { icon, title, body, fields, linkTitle, linkURL, imageURL, imageBase64, sendPush in
                var updated = item
                updated.icon      = icon
                updated.title     = title
                updated.body      = body
                updated.fields    = fields
                updated.linkTitle = linkTitle
                updated.linkURL   = linkURL
                updated.imageURL = imageURL
                updated.imageBase64 = imageBase64
                Task { await infoManager.update(updated, sendPush: sendPush) }
            }
        }
        .task {
            guard isInitialLoading else { return }
            await infoManager.refresh()
            withAnimation(reduceMotion ? .none : .quick) { isInitialLoading = false }
        }
    }

    private var loadingSkeleton: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppConfig.tertiaryFillBg)
                        .frame(width: 40, height: 40)
                        .shimmering(active: true)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(height: 14, cornerRadius: 7)
                            .frame(maxWidth: 150, alignment: .leading)
                        SkeletonBlock(height: 11, cornerRadius: 6)
                            .frame(maxWidth: 230, alignment: .leading)
                    }

                    Spacer()

                    SkeletonBlock(height: 16, cornerRadius: 8)
                        .frame(width: 16)
                }
                .padding(.vertical, 4)
                .listRowBackground(AppConfig.cardBg)
            }
        }
        .listStyle(.insetGrouped)
    }

}

// MARK: - Form

enum InfoFormMode: Identifiable {
    case add
    case edit(InfoItem)
    var id: String {
        if case .edit(let item) = self { return item.id }
        return "add"
    }
}

struct InfoItemFormView: View {
    let mode: InfoFormMode
    /// (icon, title, body, fields, linkTitle, linkURL, imageURL, imageBase64, sendPush)
    let onSave: (String, String, String, [ContactField], String, String, String?, String?, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var lang = LanguageManager.shared

    @State private var selectedIcon: String
    @State private var title: String
    @State private var cardBody: String
    @State private var contactFields: [ContactField]
    @State private var linkTitle: String
    @State private var linkURL: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var imageURLInput: String
    @State private var existingImageURL: String?
    @State private var existingImageBase64: String?
    @State private var showImageUploadSection: Bool
    @State private var sendPush: Bool

    init(mode: InfoFormMode, onSave: @escaping (String, String, String, [ContactField], String, String, String?, String?, Bool) -> Void) {
        self.mode   = mode
        self.onSave = onSave
        if case .edit(let item) = mode {
            _selectedIcon   = State(initialValue: item.icon)
            _title          = State(initialValue: item.title)
            _cardBody       = State(initialValue: item.body)
            _contactFields  = State(initialValue: item.fields)
            _linkTitle      = State(initialValue: item.linkTitle)
            _linkURL        = State(initialValue: item.linkURL)
            _selectedPhotoItem = State(initialValue: nil)
            _selectedImageData = State(initialValue: nil)
            _imageURLInput = State(initialValue: item.imageURL ?? "")
            _existingImageURL = State(initialValue: item.imageURL)
            _existingImageBase64 = State(initialValue: item.imageBase64)
            _showImageUploadSection = State(initialValue: item.imageURL != nil || item.imageBase64 != nil)
            _sendPush       = State(initialValue: false)
        } else {
            _selectedIcon   = State(initialValue: InfoItem.presetIcons[0])
            _title          = State(initialValue: "")
            _cardBody       = State(initialValue: "")
            _contactFields  = State(initialValue: [])
            _linkTitle      = State(initialValue: "")
            _linkURL        = State(initialValue: "")
            _selectedPhotoItem = State(initialValue: nil)
            _selectedImageData = State(initialValue: nil)
            _imageURLInput = State(initialValue: "")
            _existingImageURL = State(initialValue: nil)
            _existingImageBase64 = State(initialValue: nil)
            _showImageUploadSection = State(initialValue: false)
            _sendPush       = State(initialValue: false)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Live preview
                        previewCard

                        // Icon picker
                        formSection(label: L10n.iconLabel) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(InfoItem.presetIcons, id: \.self) { icon in
                                        Button {
                                            withAnimation(reduceMotion ? .none : .quick) { selectedIcon = icon }
                                        } label: {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(selectedIcon == icon ? AppConfig.surfaceHigh : AppConfig.cardBg)
                                                Image(systemName: icon)
                                                    .font(.title3.weight(.semibold))
                                                    .foregroundStyle(selectedIcon == icon ? AppConfig.darkText : AppConfig.subtleGray)
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedIcon == icon ? AppConfig.separatorSoft : Color.clear, lineWidth: 1)
                                            )
                                            .frame(width: 48, height: 48)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }

                        // Title
                        formSection(label: L10n.titleLabel) {
                            TextField(L10n.infoTitlePlaceholder, text: $title)
                                .styledInput()
                        }

                        // Description
                        formSection(label: L10n.descriptionLabel) {
                            TextField(L10n.infoDescPlaceholder, text: $cardBody, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .styledInput()
                        }

                        formSection(label: "Card Image (optional)") {
                            DisclosureGroup(isExpanded: $showImageUploadSection) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 12) {
                                        if let imageData = selectedImageData,
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                                .overlay(alignment: .topTrailing) {
                                                    Button {
                                                        withAnimation {
                                                            selectedImageData = nil
                                                            selectedPhotoItem = nil
                                                            imageURLInput = ""
                                                            existingImageURL = nil
                                                            existingImageBase64 = nil
                                                        }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.title3)
                                                            .foregroundStyle(.white, .black.opacity(0.5))
                                                    }
                                                    .offset(x: 6, y: -6)
                                                }
                                        } else if let existingImageURL,
                                                  let url = URL(string: existingImageURL) {
                                            AsyncImage(url: url) { phase in
                                                if let img = phase.image {
                                                    img
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 80, height: 80)
                                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .fill(AppConfig.surfaceLow)
                                                        .frame(width: 80, height: 80)
                                                        .overlay(ProgressView())
                                                }
                                            }
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                        withAnimation {
                                                            imageURLInput = ""
                                                            self.existingImageURL = nil
                                                            existingImageBase64 = nil
                                                        }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.title3)
                                                        .foregroundStyle(.white, .black.opacity(0.5))
                                                }
                                                .offset(x: 6, y: -6)
                                            }
                                        } else if let base64 = existingImageBase64,
                                                  let data = Data(base64Encoded: base64),
                                                  let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                                .overlay(alignment: .topTrailing) {
                                                    Button {
                                                        withAnimation {
                                                            imageURLInput = ""
                                                            existingImageURL = nil
                                                            existingImageBase64 = nil
                                                        }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.title3)
                                                            .foregroundStyle(.white, .black.opacity(0.5))
                                                    }
                                                    .offset(x: 6, y: -6)
                                                }
                                        }

                                        PhotosPicker(
                                            selection: $selectedPhotoItem,
                                            matching: .images,
                                            photoLibrary: .shared()
                                        ) {
                                            Label(
                                                selectedImageData != nil || existingImageURL != nil || existingImageBase64 != nil
                                                    ? "Change Photo"
                                                    : "Choose Photo",
                                                systemImage: "photo.on.rectangle.angled"
                                            )
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(AppConfig.subtleGray)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 9)
                                            .background(AppConfig.surfaceLow)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                    .onChange(of: selectedPhotoItem) { _, newItem in
                                        guard let newItem else { return }
                                        Task {
                                            if let data = try? await newItem.loadTransferable(type: Data.self),
                                               let uiImage = UIImage(data: data) {
                                                let preparedData: Data
                                                if data.count > 4_000_000 {
                                                    preparedData = uiImage.jpegData(compressionQuality: 0.9) ?? data
                                                } else {
                                                    preparedData = uiImage.jpegData(compressionQuality: 0.98) ?? data
                                                }
                                                selectedImageData = preparedData
                                                imageURLInput = ""
                                                existingImageURL = nil
                                                existingImageBase64 = nil
                                            }
                                        }
                                    }

                                    TextField("or paste image URL (https://...)", text: $imageURLInput)
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .styledInput()
                                        .onChange(of: imageURLInput) { _, newValue in
                                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                            guard !trimmed.isEmpty else { return }
                                            selectedImageData = nil
                                            selectedPhotoItem = nil
                                            existingImageBase64 = nil
                                            existingImageURL = trimmed
                                        }

                                    Text("Secondary option. Prefer default icons for regular info cards.")
                                        .font(.caption2)
                                        .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
                                }
                                .padding(.top, 8)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppConfig.subtleGray)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Use custom photo")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppConfig.darkText)
                                        Text("Hidden by default to keep posts consistent")
                                            .font(.caption2)
                                            .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
                                    }
                                    Spacer()
                                    if selectedImageData != nil || existingImageURL != nil || existingImageBase64 != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(AppConfig.darkText)
                                    }
                                }
                            }
                        }

                        // Structured contact / info fields
                        formSection(label: "Contact fields (optional)") {
                            VStack(spacing: 8) {
                                ForEach($contactFields) { $field in
                                    contactFieldRow(field: $field) {
                                        contactFields.removeAll { $0.id == field.id }
                                    }
                                }
                                Button {
                                    withAnimation(reduceMotion ? .none : .standard) {
                                        contactFields.append(ContactField(type: .phone, label: "", value: ""))
                                    }
                                } label: {
                                    Label("Add Field", systemImage: "plus.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(AppConfig.surfaceHigh)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(AppConfig.separatorSoft, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }

                        // Optional link
                        formSection(label: "Link (optional)") {
                            VStack(spacing: 8) {
                                TextField("Link title (e.g. Contact admin)", text: $linkTitle)
                                    .styledInput()
                                TextField("https://...", text: $linkURL)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .styledInput()
                            }
                        }

                        // ── Push Notification Toggle ─────────────────────────
                        pushToggleCard

                        // Save button
                        Button {
                            Haptics.action()
                            performSave()
                        } label: {
                            Text(isEditing ? (sendPush ? L10n.saveAndNotify : L10n.save) : (sendPush ? L10n.addCardAndNotify : L10n.addCard))
                                .font(.body.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isFormValid ? AppConfig.darkText : AppConfig.surfaceHigh)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(!isFormValid)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(isEditing ? L10n.editInfoCard : L10n.newInfoCard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                        .foregroundStyle(AppConfig.subtleGray)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(26)
    }

    // MARK: - Push Toggle Card

    private var pushToggleCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(sendPush ? Color.blue.opacity(0.15) : AppConfig.surfaceHigh)
                    .frame(width: 44, height: 44)
                Image(systemName: sendPush ? "bell.badge.fill" : "bell.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(sendPush ? Color.blue : AppConfig.subtleGray)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.pushToAll)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(AppConfig.darkText)
                Text(isEditing ? L10n.sendNotifOnSave : L10n.sendNotifOnPublish)
                    .font(.caption)
                    .foregroundStyle(AppConfig.subtleGray)
            }

            Spacer()

            Toggle("", isOn: $sendPush)
                .tint(.blue)
                .labelsHidden()
        }
        .padding(16)
        .background(sendPush ? Color.blue.opacity(0.07) : AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(sendPush ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .animation(reduceMotion ? .none : .standard, value: sendPush)
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = selectedImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if let existingImageURL,
                      let url = URL(string: existingImageURL) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            } else if let base64 = existingImageBase64,
                      let data = Data(base64Encoded: base64),
                      let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Image(systemName: selectedIcon)
                .font(.title3)
                .foregroundStyle(AppConfig.subtleGray)
            Text(title.isEmpty ? "Title" : title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(title.isEmpty ? AppConfig.subtleGray.opacity(0.4) : AppConfig.darkText)
            Text(cardBody.isEmpty ? "Description" : cardBody)
                .font(.caption)
                .foregroundStyle(cardBody.isEmpty ? AppConfig.subtleGray.opacity(0.3) : AppConfig.subtleGray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
    }

    // MARK: - Contact Field Row

    @ViewBuilder
    private func contactFieldRow(field: Binding<ContactField>, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            // Type picker
            Menu {
                ForEach(ContactField.FieldType.allCases, id: \.self) { type in
                    Button {
                        withAnimation { field.wrappedValue.type = type }
                    } label: {
                        Label(type.defaultLabel, systemImage: type.icon)
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppConfig.surfaceHigh)
                        .frame(width: 36, height: 36)
                    Image(systemName: field.wrappedValue.type.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(spacing: 4) {
                // Optional custom label
                TextField(field.wrappedValue.type.defaultLabel, text: field.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                    .styledInput()
                    .frame(height: 34)

                // Value
                TextField("Value", text: field.value)
                    .keyboardType(field.wrappedValue.type == .phone ? .phonePad :
                                  field.wrappedValue.type == .email ? .emailAddress :
                                  field.wrappedValue.type == .website ? .URL : .default)
                    .textInputAutocapitalization(
                        field.wrappedValue.type == .email || field.wrappedValue.type == .website
                            ? .never : .sentences
                    )
                    .autocorrectionDisabled(
                        field.wrappedValue.type == .email || field.wrappedValue.type == .website
                    )
                    .styledInput()
                    .frame(height: 38)
            }

            // Delete
            Button {
                Haptics.destructive()
                withAnimation { onDelete() }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppConfig.spotOccupied.opacity(0.7))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(10)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppConfig.separatorSoft, lineWidth: 1))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
            content()
        }
    }

    private func performSave() {
        let trimmedFields = contactFields.map { f -> ContactField in
            var copy = f
            copy.value = f.value.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.label = f.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return copy
        }.filter { !$0.value.isEmpty }

        let trimmedImageURL = imageURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let base64Image = selectedImageData?.base64EncodedString() ?? existingImageBase64
        let resolvedImageURL: String? = (selectedImageData == nil && base64Image == nil && !trimmedImageURL.isEmpty)
            ? trimmedImageURL
            : nil

        onSave(
            selectedIcon,
            title.trimmingCharacters(in: .whitespaces),
            cardBody.trimmingCharacters(in: .whitespaces),
            trimmedFields,
            linkTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            linkURL.trimmingCharacters(in: .whitespacesAndNewlines),
            resolvedImageURL,
            base64Image,
            sendPush
        )
        dismiss()
    }
}

// MARK: - Input style modifier

private extension View {
    func styledInput() -> some View {
        self
            .padding(14)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppConfig.separatorSoft, lineWidth: 1))
    }
}
