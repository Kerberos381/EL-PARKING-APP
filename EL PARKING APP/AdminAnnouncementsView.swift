//
//  AdminAnnouncementsView.swift
//  EL PARKING APP
//
//  Admin: create, edit, activate/deactivate, pin and delete announcements.
//

import SwiftUI

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
        .refreshable {
            Haptics.selection()
            await announcementsManager.refresh()
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
                            .font(.system(size: 12, weight: .semibold))
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
                            Image(systemName: item.isExpired ? "clock.badge.xmark" : "timer")
                                .font(.system(size: 9, weight: .bold))
                            if item.isExpired {
                                Text(L10n.expired)
                                    .font(.caption2)
                            } else {
                                Text(exp, style: .date)
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(item.isExpired ? AppConfig.spotOccupied : .orange)
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
            .font(.system(size: 16, weight: .semibold))
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
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
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
        }
        .scrollContentBackground(.hidden)
    }

    private var skeletonRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))
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
    @State private var hasExpiry     = false
    @State private var expiryDate    = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var contactFields: [ContactField] = []
    @State private var isSaving      = false

    private let emojiPresets = ["📢", "ℹ️", "🚧", "🎉", "⚠️", "🔧", "🅿️", "🚗", "📅", "🔔", "🌟", "❗"]

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
                            toggleRow(icon: "pin.circle",  label: L10n.pinned,      subtitle: L10n.alwaysShownAtTop,  color: .orange,              value: $isPinned)
                            Divider().padding(.leading, 58)
                            toggleRow(icon: "timer",     label: L10n.setExpiry,   subtitle: L10n.autoHideAfterDate, color: .orange,               value: $hasExpiry)

                            // Inline date picker — only shown when expiry is on
                            if hasExpiry {
                                Divider().padding(.leading, 58)
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange.opacity(0.12))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.orange)
                                    }
                                    DatePicker(
                                        L10n.expiresOn,
                                        selection: $expiryDate,
                                        in: Date()...,
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                    .tint(.orange)
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
                    .foregroundStyle(isValid ? AppConfig.accentFg : AppConfig.subtleGray)
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
                expiryDate    = item.expiresAt ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                contactFields = item.fields
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(26)
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
            await announcementsManager.save(updated)
        } else {
            await announcementsManager.create(
                title:     title.trimmingCharacters(in: .whitespaces),
                body:      message.trimmingCharacters(in: .whitespaces),
                emoji:     emoji,
                isPinned:  isPinned,
                createdBy: authManager.currentUser?.email ?? "",
                expiresAt: hasExpiry ? expiryDate : nil,
                fields:    trimmedFields
            )
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
                        .frame(width: 36, height: 36)
                    Image(systemName: field.wrappedValue.type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(spacing: 4) {
                TextField(field.wrappedValue.type.defaultLabel, text: field.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                    .padding(8)
                    .background(AppConfig.pageBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(height: 34)

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
                    .padding(8)
                    .background(AppConfig.pageBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(height: 38)
            }

            Button {
                Haptics.destructive()
                withAnimation { onDelete() }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20))
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppConfig.subtleGray)
    }

    private func listSectionHeader(_ text: String) -> some View {
        Text(text)
            .textCase(nil)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(16)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppConfig.separatorSoft, lineWidth: 1)
            )
    }

    private var announcementPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.title3)
                Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.announcementTitlePlaceholder : title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppConfig.darkText)
                    .lineLimit(2)
                Spacer()
                if isPinned {
                    Image(systemName: "pin.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message)
                    .font(.system(size: 13, weight: .regular))
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
                        .foregroundStyle(.orange)
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
                    .font(.system(size: 14, weight: .semibold))
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
