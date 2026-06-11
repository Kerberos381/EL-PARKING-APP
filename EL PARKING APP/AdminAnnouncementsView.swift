//
//  AdminAnnouncementsView.swift
//  EL PARKING APP
//
//  Admin: create, edit, activate/deactivate, pin and delete announcements.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

// MARK: - List View

struct AdminAnnouncementsView: View {
    @EnvironmentObject var authManager:           AuthManager
    @EnvironmentObject var announcementsManager:  AnnouncementsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var lang = LanguageManager.shared

    @State private var showCompose  = false
    @State private var editingItem: Announcement?
    @State private var isInitialLoading = true

    private var active:   [Announcement] { announcementsManager.announcements.filter {  $0.isActive } }
    private var inactive: [Announcement] { announcementsManager.announcements.filter { !$0.isActive } }

    var body: some View {
        ZStack {
            AppConfig.pageBg.ignoresSafeArea()

            if isInitialLoading && announcementsManager.announcements.isEmpty {
                loadingSkeleton
            } else if announcementsManager.announcements.isEmpty {
                emptyState
            } else {
                announcementList
            }
        }
        .navigationTitle(L10n.newsAndAnnouncements)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptics.action()
                    showCompose = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("New announcement")
                .accessibilityHint("Opens compose announcement screen")
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeAnnouncementSheet(editing: nil)
                .environmentObject(authManager)
                .environmentObject(announcementsManager)
        }
        .sheet(item: $editingItem) { item in
            ComposeAnnouncementSheet(editing: item)
                .environmentObject(authManager)
                .environmentObject(announcementsManager)
        }
        .task {
            guard isInitialLoading else { return }
            await announcementsManager.refresh()
            withAnimation(reduceMotion ? .none : .quick) { isInitialLoading = false }
        }
    }

    // MARK: - List

    private var announcementList: some View {
        List {
            if !active.isEmpty {
                Section {
                    ForEach(active) { item in announcementRow(item) }
                        .onDelete { idx in
                            Haptics.destructive()
                            for i in idx { Task { await announcementsManager.delete(active[i]) } }
                        }
                } header: {
                    listSectionHeader(L10n.activeSectionHeader(active.count))
                }
            }
            if !inactive.isEmpty {
                Section {
                    ForEach(inactive) { item in announcementRow(item) }
                        .onDelete { idx in
                            Haptics.destructive()
                            for i in idx { Task { await announcementsManager.delete(inactive[i]) } }
                        }
                } header: {
                    listSectionHeader(L10n.inactiveSectionHeader(inactive.count))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable {
            await announcementsManager.refresh()
            Haptics.refreshCompleted()
        }
    }

    private func announcementRow(_ item: Announcement) -> some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.title2)
                .frame(width: 46, height: 46)
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppConfig.separatorSoft, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if item.isPinned {
                        Image(systemName: "pin.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.darkText)
                        .lineLimit(1)
                }
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.footnote)
                        .foregroundStyle(AppConfig.subtleGray)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(item.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.6))

                    if let exp = item.expiresAt {
                        HStack(spacing: 3) {
                            Image(systemName: item.isExpired ? "clock.badge.xmark" : item.isExpiringSoon ? "exclamationmark.triangle.fill" : "timer")
                                .font(.caption2.weight(.bold))
                            if item.isExpired {
                                Text(L10n.expired)
                                    .font(.caption2)
                            } else if let days = item.daysUntilExpiry, days <= 7 {
                                Text("\(days)d left")
                                    .font(.caption2.weight(.semibold))
                            } else {
                                Text(exp, style: .date)
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(item.isExpired ? AppConfig.spotOccupied : item.isExpiringSoon ? AppConfig.danger : AppConfig.warning)

                        if item.isExpiringSoon || item.isExpired {
                            Button {
                                Haptics.action()
                                Task { await announcementsManager.renewExpiry(item) }
                            } label: {
                                Text("Renew")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppConfig.darkText)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Button {
                    Haptics.action()
                    Task { await announcementsManager.toggleActive(item) }
                } label: {
                    statusControlIcon(
                        symbol: item.isActive ? "checkmark.circle.fill" : "circle",
                        tint: item.isActive ? .primary : AppConfig.subtleGray.opacity(0.7)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(item.isActive ? "Set inactive" : "Set active")

                Button {
                    Haptics.action()
                    Task { await announcementsManager.togglePinned(item) }
                } label: {
                    statusControlIcon(
                        symbol: item.isPinned ? "pin.circle" : "pin.circle",
                        tint: item.isPinned ? .primary : AppConfig.subtleGray.opacity(0.7)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(item.isPinned ? "Unpin" : "Pin")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            editingItem = item
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .overlay(
            RoundedRectangle(cornerRadius: AppConfig.radius16)
                .stroke(AppConfig.separatorSoft, lineWidth: 1)
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 8, trailing: 12))
        .listRowBackground(Color.clear)
    }

    private func statusControlIcon(symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(AppConfig.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppConfig.separatorSoft, lineWidth: 1)
            )
    }

    private func listSectionHeader(_ text: String) -> some View {
        Text(text)
            .textCase(nil)
            .font(.body.weight(.semibold))
            .foregroundStyle(AppConfig.subtleGray)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            AppEmptyStateCard(
                icon: "megaphone.fill",
                title: L10n.noAnnouncementsYet,
                subtitle: L10n.tapPlusToCreate,
                actionTitle: L10n.newAnnouncement,
                actionIcon: "plus"
            ) {
                showCompose = true
            }
            .padding(.horizontal)
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    private var loadingSkeleton: some View {
        List {
            Section {
                ForEach(0..<4, id: \.self) { _ in
                    skeletonRow
                        .listRowBackground(AppConfig.cardBg)
                }
            } header: {
                listSectionHeader(L10n.activeSectionHeader(0))
            }
            .listRowBackground(AppConfig.groupedCardBg)
        }
        .scrollContentBackground(.hidden)
    }

    private var skeletonRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppConfig.tertiaryFillBg)
                .frame(width: 44, height: 44)
                .shimmering(active: true)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 14, cornerRadius: 7)
                    .frame(maxWidth: 160, alignment: .leading)
                SkeletonBlock(height: 11, cornerRadius: 6)
                    .frame(maxWidth: 230, alignment: .leading)
                SkeletonBlock(height: 10, cornerRadius: 5)
                    .frame(width: 90, alignment: .leading)
            }
            Spacer()
            VStack(spacing: 10) {
                SkeletonBlock(height: 16, cornerRadius: 8)
                    .frame(width: 16)
                SkeletonBlock(height: 16, cornerRadius: 8)
                    .frame(width: 16)
            }
            SkeletonBlock(height: 18, cornerRadius: 9)
                .frame(width: 18)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Compose / Edit Sheet

struct ComposeAnnouncementSheet: View {
    @EnvironmentObject var authManager:          AuthManager
    @EnvironmentObject var announcementsManager: AnnouncementsManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var lang = LanguageManager.shared

    let editing: Announcement?

    @State private var title         = ""
    @State private var message       = ""
    @State private var emoji         = "📢"
    @State private var isActive      = true
    @State private var isPinned      = false
    @State private var hasExpiry     = true
    @State private var expiryDate    = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var contactFields: [ContactField] = []
    @State private var isSaving      = false
    @State private var selectedColor: String?
    @State private var selectedTextColorMode: AnnouncementTextColorMode = .auto
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var existingImageURL: String?
    @State private var existingImageBase64: String?
    @State private var imageUploadErrorMessage: String?
    @State private var showImageUploadSection = false

    private let emojiPresets = [
        "📢", "ℹ️", "🚧", "🎉", "⚠️", "🔧", "🅿️", "🚗", "🚙", "🚘", "🛑", "❗",
        "📅", "🗓️", "⏰", "🕒", "🔔", "✅", "📌", "📍", "🛠️", "⚙️", "🧭", "📣",
        "🔒", "🔓", "🚨", "🧹", "🧾", "💡", "🌟", "🎊"
    ]

    private let colorPresets: [(name: String, hex: String)] = [
        ("Default",  ""),
        ("Slate",    "#2D3142"),
        ("Ocean",    "#1A5276"),
        ("Forest",   "#1E6B3A"),
        ("Wine",     "#7D1128"),
        ("Purple",   "#5B2C8C"),
        ("Sunset",   "#C44B25"),
        ("Amber",    "#B8860B"),
        ("Midnight", "#141A2E"),
        ("Teal",     "#006D6F"),
        ("Rose",     "#C44569"),
    ]

    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Emoji picker
                        editorCard {
                            sectionLabel(L10n.iconLabel)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(emojiPresets, id: \.self) { e in
                                        Button { emoji = e } label: {
                                            Text(e)
                                                .font(.title2)
                                                .frame(width: 52, height: 52)
                                                .background(emoji == e ? AppConfig.surfaceHigh : AppConfig.cardBg)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(emoji == e ? AppConfig.darkText.opacity(0.35) : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        // Card Color
                        editorCard {
                            sectionLabel("Card Color")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(colorPresets, id: \.hex) { preset in
                                        Button {
                                            selectedColor = preset.hex.isEmpty ? nil : preset.hex
                                        } label: {
                                            let isSelected = (selectedColor ?? "") == preset.hex || (selectedColor == nil && preset.hex.isEmpty)
                                            ZStack {
                                                if preset.hex.isEmpty {
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color(red: 0.15, green: 0.15, blue: 0.25), Color(red: 0.3, green: 0.3, blue: 0.45)],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                        .frame(width: 52, height: 52)
                                                    Text("Auto")
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(.white.opacity(0.7))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .fill(Color(hex: preset.hex))
                                                        .frame(width: 52, height: 52)
                                                }
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(isSelected ? AppConfig.darkText.opacity(0.5) : Color.clear, lineWidth: 2.5)
                                            )
                                            .overlay(alignment: .bottomTrailing) {
                                                if isSelected {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.body)
                                                        .foregroundStyle(.white)
                                                        .background(Circle().fill(AppConfig.darkText).frame(width: 15, height: 15))
                                                        .offset(x: 3, y: 3)
                                                }
                                            }
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        // Text Color
                        editorCard {
                            sectionLabel("Text Color")
                            Menu {
                                ForEach(AnnouncementTextColorMode.allCases, id: \.self) { mode in
                                    Button {
                                        selectedTextColorMode = mode
                                    } label: {
                                        HStack {
                                            Text(mode.title)
                                            if selectedTextColorMode == mode {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "textformat")
                                        .foregroundStyle(AppConfig.subtleGray)
                                        .frame(width: 20)
                                    Text("Text Color")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppConfig.darkText)
                                    Spacer()
                                    Text(selectedTextColorMode.title)
                                        .font(.subheadline)
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppConfig.subtleGray.opacity(0.65))
                                }
                                .padding(14)
                                .background(AppConfig.surfaceLow)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppConfig.outlineVariant.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())

                            Text("Auto adapts for readability. Use White/Black to force a style.")
                                .font(.caption2)
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
                        }

                        // Card Image (subtle / secondary)
                        editorCard {
                            sectionLabel("Card Image (optional)")
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
                                        } else if existingImageURL != nil {
                                            AsyncImage(url: URL(string: existingImageURL!)) { phase in
                                                if let img = phase.image {
                                                    img.resizable()
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
                                                    withAnimation { existingImageURL = nil; existingImageBase64 = nil }
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
                                                    withAnimation { existingImageURL = nil; existingImageBase64 = nil }
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
                                            Label(selectedImageData != nil || existingImageURL != nil || existingImageBase64 != nil ? "Change Photo" : "Choose Photo", systemImage: "photo.on.rectangle.angled")
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
                                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                                // Keep announcement images visually faithful.
                                                // Only apply light compression for very large files.
                                                if let uiImage = UIImage(data: data) {
                                                    let preparedData: Data
                                                    if data.count > 4_000_000 {
                                                        preparedData = uiImage.jpegData(compressionQuality: 0.9) ?? data
                                                    } else {
                                                        preparedData = uiImage.jpegData(compressionQuality: 0.98) ?? data
                                                    }
                                                    selectedImageData = preparedData
                                                    existingImageURL = nil
                                                    existingImageBase64 = nil
                                                }
                                            }
                                        }
                                    }

                                    Text("Secondary option. Prefer default icons for regular announcements.")
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

                        // Title
                        editorCard {
                            sectionLabel(L10n.titleLabel)
                            TextField(L10n.announcementTitlePlaceholder, text: $title)
                                .font(.body)
                                .foregroundStyle(AppConfig.darkText)
                                .padding(14)
                                .background(AppConfig.surfaceLow)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Body
                        editorCard {
                            sectionLabel(L10n.messageOptional)
                            ZStack(alignment: .topLeading) {
                                if message.isEmpty {
                                    Text(L10n.announcementBodyPlaceholder)
                                        .font(.body)
                                        .foregroundStyle(AppConfig.subtleGray.opacity(0.45))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                }
                                TextEditor(text: $message)
                                    .font(.body)
                                    .foregroundStyle(AppConfig.darkText)
                                    .frame(minHeight: 100)
                                    .padding(10)
                                    .scrollContentBackground(.hidden)
                            }
                            .background(AppConfig.surfaceLow)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Contact / info fields
                        editorCard {
                            sectionLabel("Contact fields (optional)")
                            VStack(spacing: 8) {
                                ForEach($contactFields) { $field in
                                    announcementFieldRow(field: $field) {
                                        contactFields.removeAll { $0.id == field.id }
                                    }
                                }
                                Button {
                                    withAnimation(reduceMotion ? .none : .standard) {
                                        contactFields.append(ContactField(type: .phone, label: "", value: ""))
                                    }
                                } label: {
                                    Label("Add Field", systemImage: "plus.circle")
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

                        // Toggles
                        editorCard {
                            VStack(spacing: 0) {
                            toggleRow(icon: "checkmark.circle.fill",  label: L10n.activeLabel, subtitle: L10n.visibleToAllOnHome, color: AppConfig.activeGreen, value: $isActive)
                            Divider().padding(.leading, 58)
                            toggleRow(icon: "pin.circle",  label: L10n.pinned,      subtitle: L10n.alwaysShownAtTop,  color: AppConfig.warning,              value: $isPinned)
                            Divider().padding(.leading, 58)
                            toggleRow(icon: "timer",     label: L10n.setExpiry,   subtitle: L10n.autoHideAfterDate, color: AppConfig.warning,               value: $hasExpiry)

                            // Inline date picker — only shown when expiry is on
                            if hasExpiry {
                                Divider().padding(.leading, 58)
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(AppConfig.warning.opacity(0.12))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(AppConfig.warning)
                                    }
                                    DatePicker(
                                        L10n.expiresOn,
                                        selection: $expiryDate,
                                        in: Date()...,
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                    .tint(AppConfig.warning)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                            }
                            }
                        .animation(reduceMotion ? .none : .standard, value: hasExpiry)
                        }

                        if AppConfig.enableAdminAnnouncementsUnifiedStyle {
                            editorCard {
                                sectionLabel("Preview")
                                announcementPreviewCard
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(editing == nil ? L10n.newAnnouncement : L10n.editAnnouncement)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                    .foregroundStyle(AppConfig.subtleGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editing == nil ? L10n.postAnnouncement : L10n.save) {
                        Haptics.action()
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? AppConfig.darkText : AppConfig.subtleGray)
                    .disabled(!isValid || isSaving)
                }
            })
        }
        .onAppear {
            if let item = editing {
                title         = item.title
                message       = item.body
                emoji         = item.emoji
                isActive      = item.isActive
                isPinned      = item.isPinned
                hasExpiry     = item.expiresAt != nil
                expiryDate    = item.expiresAt ?? Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                contactFields = item.fields
                selectedColor = item.backgroundColorHex
                selectedTextColorMode = AnnouncementTextColorMode(rawValue: item.textColorMode) ?? .auto
                existingImageURL = item.imageURL
                existingImageBase64 = item.imageBase64
                showImageUploadSection = item.imageURL != nil || item.imageBase64 != nil
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(26)
        .alert(
            "Image Upload Failed",
            isPresented: Binding(
                get: { imageUploadErrorMessage != nil },
                set: { show in if !show { imageUploadErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { }
            },
            message: {
                Text(imageUploadErrorMessage ?? "Please try again.")
            }
        )
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let trimmedFields = contactFields.map { f -> ContactField in
            var copy = f
            copy.value = f.value.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.label = f.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return copy
        }.filter { !$0.value.isEmpty }

        if let existing = editing {
            var updated = existing
            updated.title     = title.trimmingCharacters(in: .whitespaces)
            updated.body      = message.trimmingCharacters(in: .whitespaces)
            updated.emoji     = emoji
            updated.isActive  = isActive
            updated.isPinned  = isPinned
            updated.expiresAt = hasExpiry ? expiryDate : nil
            updated.fields    = trimmedFields
            updated.backgroundColorHex = selectedColor
            updated.textColorMode = selectedTextColorMode.rawValue

            if let imageData = selectedImageData {
                if let url = await announcementsManager.uploadImage(imageData, for: existing.id) {
                    updated.imageURL = url
                    updated.imageBase64 = nil
                } else if let inlineImage = announcementsManager.firestoreInlineImageBase64(from: imageData) {
                    updated.imageURL = nil
                    updated.imageBase64 = inlineImage
                } else {
                    imageUploadErrorMessage = announcementsManager.userFacingImageUploadError()
                    return
                }
            } else if existingImageURL == nil && existingImageBase64 == nil &&
                        (existing.imageURL != nil || existing.imageBase64 != nil) {
                if existing.imageURL != nil {
                    await announcementsManager.deleteImage(for: existing.id)
                }
                updated.imageURL = nil
                updated.imageBase64 = nil
            }

            await announcementsManager.save(updated)
        } else {
            let newID = UUID().uuidString
            var imageURL: String?
            var imageBase64: String?
            if let imageData = selectedImageData {
                if let url = await announcementsManager.uploadImage(imageData, for: newID) {
                    imageURL = url
                } else if let inlineImage = announcementsManager.firestoreInlineImageBase64(from: imageData) {
                    imageBase64 = inlineImage
                } else {
                    imageUploadErrorMessage = announcementsManager.userFacingImageUploadError()
                    return
                }
            }

            let item = Announcement(
                id: newID,
                title: title.trimmingCharacters(in: .whitespaces),
                body: message.trimmingCharacters(in: .whitespaces),
                emoji: emoji,
                createdBy: authManager.currentUser?.email ?? "",
                createdAt: Date(),
                isActive: true,
                isPinned: isPinned,
                expiresAt: hasExpiry ? expiryDate : nil,
                fields: trimmedFields,
                backgroundColorHex: selectedColor,
                imageURL: imageURL,
                imageBase64: imageBase64,
                textColorMode: selectedTextColorMode.rawValue
            )
            do {
                try await Firestore.firestore().collection("announcements").document(newID).setData(item.toFirestore())
                PushNotificationManager.broadcast(title: "\(emoji) \(title.trimmingCharacters(in: .whitespaces))", body: message.trimmingCharacters(in: .whitespaces))
            } catch {
                print("AnnouncementsManager create error: \(error.localizedDescription)")
            }
        }
        dismiss()
    }

    // MARK: - Field Row

    @ViewBuilder
    private func announcementFieldRow(field: Binding<ContactField>, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
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
                        .frame(width: 44, height: 44)
                    Image(systemName: field.wrappedValue.type.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(spacing: 4) {
                TextField(field.wrappedValue.type.defaultLabel, text: field.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(AppConfig.pageBg)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                TextField("Value", text: field.value)
                    .keyboardType(field.wrappedValue.type == .phone ? .phonePad :
                                  field.wrappedValue.type == .email ? .emailAddress :
                                  field.wrappedValue.type == .website ? .URL : .default)
                    .textInputAutocapitalization(
                        field.wrappedValue.type == .email || field.wrappedValue.type == .website ? .never : .sentences
                    )
                    .autocorrectionDisabled(
                        field.wrappedValue.type == .email || field.wrappedValue.type == .website
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(AppConfig.pageBg)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                Haptics.destructive()
                withAnimation { onDelete() }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.title3)
                    .foregroundStyle(AppConfig.spotOccupied.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(10)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppConfig.separatorSoft, lineWidth: 1))
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppConfig.subtleGray)
    }

    private func listSectionHeader(_ text: String) -> some View {
        Text(text)
            .textCase(nil)
            .font(.body.weight(.semibold))
            .foregroundStyle(AppConfig.subtleGray)
    }

    @ViewBuilder
    private func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(16)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var announcementPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.title3)
                Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.announcementTitlePlaceholder : title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
                    .lineLimit(2)
                Spacer()
                if isPinned {
                    Image(systemName: "pin.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message)
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(AppConfig.subtleGray)
                    .lineLimit(3)
            }

            HStack(spacing: 6) {
                Text(isActive ? "Active" : "Inactive")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActive ? .primary : AppConfig.subtleGray)
                if hasExpiry {
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                    Text(expiryDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(AppConfig.warning)
                }
            }
        }
        .padding(12)
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleRow(icon: String, label: String, subtitle: String, color: Color, value: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(AppConfig.darkText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppConfig.subtleGray)
            }
            Spacer()
            Toggle("", isOn: value)
                .tint(color)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    AdminAnnouncementsView()
        .environmentObject(AuthManager())
        .environmentObject(AnnouncementsManager())
}
