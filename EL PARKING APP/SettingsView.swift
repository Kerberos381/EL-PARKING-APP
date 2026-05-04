//
//  SettingsView.swift
//  EL PARKING APP
//
//  Profile, car info, theme toggle, booking rules. Clean card layout.
//

import SwiftUI
import LocalAuthentication
// import ActivityKit  // Live Activity disabled

struct SettingsView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var authManager:   AuthManager
    @ObservedObject private var langManager = LanguageManager.shared
    @AppStorage("appTheme") private var themeRaw: Int = 0
    @AppStorage("dailyReminderEnabled")   private var reminderEnabled      = false
    @AppStorage("reminderMinutesBefore")  private var reminderMinutesBefore = 60
    @AppStorage("biometricLockEnabled")   private var biometricEnabled      = false
    @AppStorage("favoriteSpotID",   store: .appGroup) private var favoriteSpotID:   String = ""
    @AppStorage("favoriteFromTime", store: .appGroup) private var favoriteFromTime: String = AppConfig.defaultTimeFrom
    @AppStorage("favoriteToTime",   store: .appGroup) private var favoriteToTime:   String = AppConfig.defaultTimeTo
    @State private var showingClearAlert   = false
    @State private var showDeleteAccount   = false
    @State private var deleteConfirmText   = ""
    @State private var showChangePassword  = false
    @State private var showOnboarding      = false


    // Advance-notice options shown as pills
    private var reminderOptions: [(label: String, sublabel: String, minutes: Int)] {
        L10n.reminderOptions
    }

    // Vehicle save state
    private enum VehicleSaveState { case idle, saving, saved }
    @State private var vehicleSaveState: VehicleSaveState = .idle
    @State private var lastSavedPlate:   String = ""
    @State private var lastSavedCar:     String = ""
    @State private var lastSavedColor:   String = ""
    @State private var lastSavedCarType: String = ""
    @State private var carSuggestions:   [String] = []
    @State private var pickerColor:      Color = .red
    @State private var showCustomPicker  = false  // notification custom time picker
    @State private var biometricsAvailable = false
    @State private var biometricDisplayName = "Biometrics"
    @State private var hasSavedBiometricCredentials = false

    private var isShortcutsOwner: Bool {
        let email = bookingManager.currentUserEmail.lowercased()
        return email == "stiv.malakjan@gmail.com" ||
               email == "stiv.malakjan@ext.essilor.com" ||
               email == "stiv.malakjan@ext.essilorluxottica.id"
    }

    private var vehicleIsDirty: Bool {
        bookingManager.registrationPlate != lastSavedPlate   ||
        bookingManager.carDescription    != lastSavedCar     ||
        bookingManager.carColor          != lastSavedColor   ||
        bookingManager.carType           != lastSavedCarType
    }

    private var theme: AppTheme {
        AppTheme(rawValue: themeRaw) ?? .system
    }

    private var selectedVehicleColorHex: String {
        bookingManager.carColor.normalizedHexColor ?? ""
    }

    // MARK: - Typography Tokens (Step 1 polish pass)
    private enum SettingsType {
        static let sectionHeader = Font.caption.weight(.semibold)
        static let sectionHeaderTracking: CGFloat = 0.8
        static let sectionTitle = Font.headline.weight(.semibold)
        static let sectionIcon = Font.caption.weight(.semibold)

        static let rowTitle = Font.subheadline.weight(.semibold)
        static let rowMeta = Font.caption
        static let rowChevron = Font.caption
        static let rowIcon = Font.footnote.weight(.semibold)

        static let inputLabel = Font.caption
        static let inputValue = Font.subheadline
        static let footerBrand = Font.caption.weight(.bold)
        static let footerVersion = Font.caption2
    }

    // MARK: - Spacing Tokens (Step 2 polish pass)
    private enum SettingsSpace {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: - Notification Picker Helpers

    private var isCustomValue: Bool {
        !reminderOptions.contains(where: { $0.minutes == reminderMinutesBefore })
    }

    private var reminderSummary: String {
        let d = reminderMinutesBefore / 1440
        let h = (reminderMinutesBefore % 1440) / 60
        let m = reminderMinutesBefore % 60
        var parts: [String] = []
        if d > 0 { parts.append(L10n.reminderDays(d)) }
        if h > 0 { parts.append(L10n.reminderHours(h)) }
        if m > 0 { parts.append(L10n.reminderMinutes(m)) }
        return parts.isEmpty ? L10n.atStart : parts.joined(separator: " ") + " \(L10n.before)"
    }

    private var pickerDays: Binding<Int> {
        Binding(
            get: { reminderMinutesBefore / 1440 },
            set: { v in
                let h = (reminderMinutesBefore % 1440) / 60
                let m = reminderMinutesBefore % 60
                reminderMinutesBefore = v * 1440 + h * 60 + m
            }
        )
    }

    private var pickerHours: Binding<Int> {
        Binding(
            get: { (reminderMinutesBefore % 1440) / 60 },
            set: { v in
                let d = reminderMinutesBefore / 1440
                let m = reminderMinutesBefore % 60
                reminderMinutesBefore = d * 1440 + v * 60 + m
            }
        )
    }

    private var pickerMinutes: Binding<Int> {
        Binding(
            get: { reminderMinutesBefore % 60 },
            set: { v in
                let d = reminderMinutesBefore / 1440
                let h = (reminderMinutesBefore % 1440) / 60
                reminderMinutesBefore = d * 1440 + h * 60 + v
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: SettingsSpace.xl) {
                        profileCard
                        languageSection
                        themeSection
                        notificationsSection
                        carInfoSection
                        if isShortcutsOwner { shortcutsSection }
                        accountSection
                        rulesSection
                        statsSection
                        dataSection
                        signOutSection
                        footerSection
                    }
                    .padding(.bottom, 100)
                }
                .id(langManager.language)
                .transition(.opacity)
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle(L10n.settings)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                lastSavedPlate   = bookingManager.registrationPlate
                lastSavedCar     = bookingManager.carDescription
                lastSavedColor   = bookingManager.carColor
                lastSavedCarType = bookingManager.carType
                refreshBiometricState()
                // Seed pickerColor if user has a custom color already
                if let normalizedColor = bookingManager.carColor.normalizedHexColor,
                   !AppConfig.carColors.map(\.hex).contains(normalizedColor) {
                    pickerColor = Color(hex: normalizedColor)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ThemeToggleButton()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.done) {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConfig.accentFg)
                }
            }
            .alert(L10n.clearAllBookings, isPresented: $showingClearAlert) {
                Button(L10n.clear, role: .destructive) {
                    withAnimation {
                        bookingManager.bookings.removeAll()
                        UserDefaults.standard.removeObject(forKey: "bookings")
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.clearConfirmMsg)
            }
            .sheet(isPresented: $showCustomPicker) {
                customPickerSheet
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordSheet()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: - Custom Reminder Picker Sheet

    private var customPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(L10n.howFarInAdvance)
                    .font(.subheadline)
                    .foregroundStyle(AppConfig.subtleGray)
                    .padding(.top, 8)

                HStack(spacing: 0) {
                    reminderPickerColumn("days",  binding: pickerDays,
                                         range: Array(0...13))
                    reminderPickerColumn("hours", binding: pickerHours,
                                         range: Array(0...23))
                    reminderPickerColumn("min",   binding: pickerMinutes,
                                         range: Array(stride(from: 0, through: 55, by: 5)))
                }
                .frame(height: 160)
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Text(reminderSummary)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppConfig.accentFg)

                Spacer()
            }
            .navigationTitle(L10n.customReminder)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        showCustomPicker = false
                        bookingManager.scheduleDailyReminders()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConfig.accentFg)
                }
            }
            .background(AppConfig.pageBg.ignoresSafeArea())
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppConfig.surfaceLow)
                    Image(systemName: "person.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(AppConfig.subtleGray)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 3) {
                    Text(bookingManager.currentUserName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppConfig.darkText)
                        .lineLimit(1)
                    Text(bookingManager.currentUserEmail)
                        .font(.subheadline)
                        .foregroundStyle(AppConfig.subtleGray)
                        .lineLimit(1)
                    Text(currentRoleLabel)
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
            }
            .padding(18)

            if biometricsAvailable {
                Divider().overlay(AppConfig.separatorSoft)
                    .padding(.horizontal, 16)

                Toggle(isOn: $biometricEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(biometricDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppConfig.darkText)
                        Text(L10n.signInWithoutPwd)
                            .font(.caption2)
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                }
                .toggleStyle(.switch)
                .tint(AppConfig.darkText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: biometricEnabled) { _, _ in
                    toggleBiometric()
                }

                if hasSavedBiometricCredentials && biometricEnabled {
                    Divider().overlay(AppConfig.separatorSoft)
                        .padding(.horizontal, 16)
                    Button {
                        KeychainManager.shared.deleteCredentials()
                        hasSavedBiometricCredentials = false
                        biometricEnabled = false
                    } label: {
                        Text(L10n.forgetDevice)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppConfig.spotOccupied.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppConfig.separatorSoft.opacity(0.35), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.018), radius: 4, y: 1)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var currentRoleLabel: String {
        if bookingManager.isAdmin { return L10n.administrator }
        if bookingManager.isPrivileged { return L10n.privilegedUser }
        return "User"
    }

    private func toggleBiometric() {
        Haptics.selection()
        if biometricEnabled {
            let ctx = LAContext()
            ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: L10n.biometricReason(biometricDisplayName)
            ) { success, _ in
                DispatchQueue.main.async {
                    withAnimation(.standard) {
                        self.biometricEnabled = success
                    }
                    self.refreshBiometricState()
                }
            }
        } else {
            KeychainManager.shared.deleteCredentials()
            hasSavedBiometricCredentials = false
        }
    }

    private func refreshBiometricState() {
        let keychain = KeychainManager.shared
        biometricsAvailable = keychain.canUseBiometrics
        biometricDisplayName = keychain.biometricName
        hasSavedBiometricCredentials = keychain.hasSavedCredentials
        if !biometricsAvailable, biometricEnabled {
            biometricEnabled = false
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        settingsSection(title: L10n.language, icon: "globe", iconTint: .blue) {
            HStack(spacing: 0) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                    let isSelected = langManager.language == lang
                    Button {
                        if !isSelected { Haptics.selection() }
                        withAnimation(.standard) {
                            langManager.language = lang
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(lang.flag).font(.subheadline)
                            Text(lang.displayName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(AppConfig.darkText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? AppConfig.surfaceHigh : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? AppConfig.separatorStrong : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(6)
            .background(AppConfig.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        settingsSection(title: L10n.appearance, icon: "paintpalette.fill", iconTint: .purple) {
            HStack(spacing: 0) {
                ForEach(AppTheme.allCases, id: \.rawValue) { option in
                    let isSelected = theme == option
                    Button {
                        if !isSelected { Haptics.selection() }
                        withAnimation(.standard) {
                            themeRaw = option.rawValue
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: option.icon)
                                .font(.caption.weight(.semibold))
                            Text(option.label)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(AppConfig.darkText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? AppConfig.surfaceHigh : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? AppConfig.separatorStrong : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(6)
            .background(AppConfig.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        settingsSection(title: L10n.notifications, icon: "bell.badge.fill", iconTint: .red) {
            VStack(spacing: 14) {

                // Enable toggle
                HStack(spacing: 14) {
                    settingsIconTile(
                        icon: reminderEnabled ? "bell.badge.fill" : "bell.slash.fill",
                        tint: .red,
                        size: 32,
                        iconSize: 15
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.bookingReminders)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppConfig.darkText)
                        Text(L10n.notifyBeforeBooking)
                            .font(.caption2)
                            .foregroundStyle(AppConfig.subtleGray)
                    }

                    Spacer()

                    Toggle("", isOn: $reminderEnabled)
                        .labelsHidden()
                        .tint(AppConfig.accent.opacity(0.55))
                }
                .onChange(of: reminderEnabled) { _, _ in
                    Haptics.selection()
                    bookingManager.scheduleDailyReminders()
                }

                if reminderEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppConfig.subtleGray)
                            Text(L10n.notifyMe)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(AppConfig.subtleGray)
                            Spacer()
                            Text(reminderSummary)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppConfig.darkText)
                        }

                        // 2-column grid of advance-notice pills
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(reminderOptions, id: \.minutes) { option in
                                let selected = reminderMinutesBefore == option.minutes
                                Button {
                                    withAnimation(.quick) {
                                        reminderMinutesBefore = option.minutes
                                    }
                                    bookingManager.scheduleDailyReminders()
                                } label: {
                                    HStack(spacing: 0) {
                                        Text(option.label)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(AppConfig.darkText)
                                        Text(" \(option.sublabel)")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(AppConfig.subtleGray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selected ? AppConfig.surfaceHigh : AppConfig.surfaceLow)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selected ? AppConfig.separatorStrong : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }

                        // Custom time picker row
                        Button { showCustomPicker = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppConfig.subtleGray)
                                    .frame(width: 24)
                                Text(L10n.custom)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppConfig.darkText)
                                Spacer()
                                Text(isCustomValue ? reminderSummary : L10n.setCustomTime)
                                    .font(.system(size: 12))
                                    .foregroundStyle(isCustomValue ? AppConfig.darkText : AppConfig.subtleGray)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isCustomValue ? AppConfig.surfaceHigh : AppConfig.surfaceLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isCustomValue ? AppConfig.separatorStrong : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Car Info Section

    private var carInfoSection: some View {
        settingsSection(title: L10n.vehicle, icon: "car.fill", iconTint: .green) {
            VStack(spacing: 14) {

                // Car make + model with suggestions
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.carDescription.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(AppConfig.subtleGray)
                        .padding(.leading, 2)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "car.side")
                                .foregroundStyle(AppConfig.subtleGray)
                                .frame(width: 18)
                            TextField(L10n.carPlaceholder, text: $bookingManager.carDescription)
                                .autocorrectionDisabled()
                                .foregroundStyle(AppConfig.darkText)
                                .onChange(of: bookingManager.carDescription) { _, val in
                                    withAnimation(.quick) {
                                        carSuggestions = CarData.filter(val)
                                    }
                                }
                        }
                        .padding(12)
                        .background(AppConfig.surfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppConfig.outlineVariant.opacity(0.4), lineWidth: 1))

                        if !carSuggestions.isEmpty {
                            suggestionsDropdown
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.quick, value: carSuggestions.isEmpty)
                }

                // Registration plate
                inputField(
                    icon: "rectangle.and.text.magnifyingglass",
                    label: L10n.regPlate,
                    placeholder: L10n.regPlatePlaceholder,
                    text: $bookingManager.registrationPlate,
                    capitalization: .characters
                )

                // Body type chips
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.2")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                        Text(L10n.carBodyType.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CarBodyType.allCases) { bodyType in
                                let isSelected = bookingManager.carType == bodyType.rawValue
                                Button {
                                    withAnimation(.quick) {
                                        bookingManager.carType = isSelected ? "" : bodyType.rawValue
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: bodyType.icon)
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(bodyType.label)
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(isSelected ? AppConfig.onAccent : AppConfig.subtleGray)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? AppConfig.accent : AppConfig.surfaceLow)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            isSelected ? AppConfig.accentFg.opacity(0.3) : AppConfig.outlineVariant.opacity(0.4),
                                            lineWidth: 1
                                        )
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                VehicleMiniatureView(
                    carType: bookingManager.carType,
                    colorHex: selectedVehicleColorHex,
                    description: bookingManager.carDescription
                )
                .frame(width: 82, height: 46)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)

                // Car color picker
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                        Text(L10n.carColor)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppConfig.subtleGray)
                        Spacer()
                        let colorHex = selectedVehicleColorHex
                        if let match = AppConfig.carColors.first(where: { $0.hex == colorHex }) {
                            HStack(spacing: 5) {
                                Circle().fill(Color(hex: colorHex)).frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                                Text(match.name).font(.caption2).foregroundStyle(AppConfig.subtleGray)
                            }
                        } else if !colorHex.isEmpty {
                            HStack(spacing: 5) {
                                Circle().fill(Color(hex: colorHex)).frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                                Text(L10n.carColorCustom).font(.caption2).foregroundStyle(AppConfig.subtleGray)
                            }
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 38))], spacing: 8) {
                        ForEach(AppConfig.carColors, id: \.hex) { color in
                            let isSelected = selectedVehicleColorHex == color.hex
                            Button {
                                withAnimation(.quick) { bookingManager.carColor = color.hex }
                            } label: {
                                ZStack {
                                    Circle().fill(Color(hex: color.hex)).frame(width: 34, height: 34)
                                        .overlay(Circle().stroke(
                                            isSelected ? AppConfig.accentFg : Color.white.opacity(0.15),
                                            lineWidth: isSelected ? 2.5 : 1
                                        ))
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(
                                                color.hex == "#FFFFFF" || color.hex == "#F9A825" ? Color.black : Color.white
                                            )
                                    }
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        VehicleCustomColorButton(
                            selectedHex: $bookingManager.carColor,
                            pickerColor: $pickerColor,
                            size: 34,
                            checkmarkSize: 10,
                            plusSize: 15
                        )
                    }
                }

                // Save row
                HStack(spacing: 10) {
                    if vehicleIsDirty {
                        HStack(spacing: 5) {
                            Circle().fill(.orange).frame(width: 6, height: 6)
                            Text(L10n.unsavedChanges).font(.caption2).foregroundStyle(AppConfig.subtleGray)
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    Spacer()
                    Button { saveVehicle() } label: {
                        ZStack {
                            Capsule().fill(vehicleIsDirty ? AppConfig.accent : AppConfig.surfaceLow)
                            switch vehicleSaveState {
                            case .idle:
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.down").font(.system(size: 12, weight: .bold))
                                    Text(vehicleIsDirty ? L10n.save : L10n.saved).font(.subheadline).fontWeight(.bold)
                                }
                                .foregroundStyle(vehicleIsDirty ? AppConfig.onAccent : AppConfig.subtleGray)
                            case .saving:
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.75).tint(AppConfig.onAccent)
                                    Text(L10n.saving).font(.subheadline).fontWeight(.bold).foregroundStyle(AppConfig.onAccent)
                                }
                            case .saved:
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                                    Text(L10n.saved).font(.subheadline).fontWeight(.bold)
                                }
                                .foregroundStyle(AppConfig.activeGreen)
                            }
                        }
                        .frame(height: 38).padding(.horizontal, 18)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(vehicleSaveState == .saving || !vehicleIsDirty)
                    .animation(.standard, value: vehicleSaveState)
                    .animation(.standard, value: vehicleIsDirty)
                }
                .padding(.top, 4)
                .animation(.standard, value: vehicleIsDirty)
            }
        }
    }

    // Inline suggestions dropdown for SettingsView
    private var suggestionsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(Array(carSuggestions.enumerated()), id: \.offset) { idx, suggestion in
                Button {
                    withAnimation(.quick) {
                        bookingManager.carDescription = suggestion
                        carSuggestions = []
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(AppConfig.subtleGray)
                        Text(suggestion).font(.subheadline).foregroundStyle(AppConfig.darkText)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .buttonStyle(ScaleButtonStyle())
                if idx < carSuggestions.count - 1 { Divider().padding(.horizontal, 14) }
            }
        }
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    private func saveVehicle() {
        bookingManager.carColor = selectedVehicleColorHex
        vehicleSaveState = .saving
        bookingManager.saveUserProfile()
        Task {
            await authManager.updateProfile(
                displayName:    bookingManager.currentUserName,
                plate:          bookingManager.registrationPlate,
                carDescription: bookingManager.carDescription,
                carColor:       bookingManager.carColor,
                carType:        bookingManager.carType
            )
            withAnimation(.standard) {
                vehicleSaveState   = .saved
                lastSavedPlate     = bookingManager.registrationPlate
                lastSavedCar       = bookingManager.carDescription
                lastSavedColor     = bookingManager.carColor
                lastSavedCarType   = bookingManager.carType
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.standard) { vehicleSaveState = .idle }
        }
    }

    // MARK: - Shortcuts & Favorite Section

    private var shortcutsSection: some View {
        settingsSection(title: "Shortcuts & Favorite", icon: "wand.and.stars", iconTint: .orange) {
            VStack(spacing: 14) {
                // Explanation
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(AppConfig.subtleGray)
                    Text("Set a favourite spot and preferred time. Then say \"Book a spot in EL Parking\" to Siri — it books for tomorrow by default, or you can pick today.")
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(AppConfig.accentFg.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Divider()

                // Favorite spot picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("FAVORITE SPOT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(AppConfig.subtleGray)

                    Menu {
                        Button("None") { favoriteSpotID = "" }
                        ForEach(AppConfig.allParkingSpots, id: \.id) { spot in
                            Button(spot.label) { favoriteSpotID = spot.id }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "parkingsign.circle")
                                .foregroundStyle(AppConfig.subtleGray)
                                .frame(width: 20)
                            Text(favoriteSpotID.isEmpty
                                 ? "Select a spot…"
                                 : AppConfig.allParkingSpots.first(where: { $0.id == favoriteSpotID })?.label ?? favoriteSpotID)
                                .font(.subheadline)
                                .foregroundStyle(favoriteSpotID.isEmpty ? AppConfig.subtleGray : AppConfig.darkText)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                        }
                        .padding(12)
                        .background(AppConfig.surfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppConfig.outlineVariant.opacity(0.4), lineWidth: 1))
                    }
                }

                // Time window pickers
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FROM")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(AppConfig.subtleGray)

                        Menu {
                            ForEach(AppConfig.availableTimeSlots, id: \.self) { slot in
                                Button(slot) { favoriteFromTime = slot }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(AppConfig.subtleGray)
                                Text(favoriteFromTime)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(AppConfig.darkText)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                            }
                            .padding(12)
                            .background(AppConfig.surfaceLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppConfig.outlineVariant.opacity(0.4), lineWidth: 1))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("TO")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(AppConfig.subtleGray)

                        Menu {
                            ForEach(AppConfig.availableTimeSlots, id: \.self) { slot in
                                Button(slot) { favoriteToTime = slot }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock.badge.checkmark")
                                    .foregroundStyle(AppConfig.subtleGray)
                                Text(favoriteToTime)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(AppConfig.darkText)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                            }
                            .padding(12)
                            .background(AppConfig.surfaceLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppConfig.outlineVariant.opacity(0.4), lineWidth: 1))
                        }
                    }
                }

                // Status indicator
                if !favoriteSpotID.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppConfig.activeGreen)
                            .font(.caption)
                        Text("Ready — say \"Book a spot in EL Parking\" to Siri")
                            .font(.caption)
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.3), value: favoriteSpotID.isEmpty)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        settingsSection(title: L10n.account, icon: "person.crop.circle.fill", iconTint: .gray) {
            VStack(spacing: 0) {
                settingsValueRow(
                    title: L10n.name,
                    value: bookingManager.currentUserName,
                    icon: "person.text.rectangle.fill",
                    tint: .gray
                )
                Divider().overlay(AppConfig.separatorSoft)
                settingsValueRow(
                    title: L10n.email,
                    value: bookingManager.currentUserEmail,
                    icon: "envelope.fill",
                    tint: .blue
                )
                Divider().overlay(AppConfig.separatorSoft)

                Button {
                    showChangePassword = true
                } label: {
                    settingsActionRow(
                        title: L10n.changePassword,
                        icon: "key.fill",
                        tint: .gray,
                        textTint: AppConfig.darkText
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func settingsValueRow(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            settingsIconTile(icon: icon, tint: tint, size: 30, iconSize: 13)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppConfig.darkText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        settingsSection(title: L10n.bookingRules, icon: "checklist", iconTint: .indigo) {
            VStack(spacing: 0) {
                infoRow(icon: "calendar", label: L10n.personalAdvance, value: "\(AppConfig.selfBookingMaxAdvanceDays) days")
                infoRow(icon: "person.2", label: L10n.forOthersAdvance, value: "\(AppConfig.othersBookingMaxAdvanceDays) days")
                infoRow(icon: "1.circle", label: L10n.maxPerDay, value: "\(AppConfig.selfBookingMaxPerDay)")
                infoRow(icon: "clock", label: L10n.defaultTime, value: "\(AppConfig.defaultTimeFrom) – \(AppConfig.defaultTimeTo)")
                infoRow(icon: "moon.fill", label: L10n.autoAdvanceAfter, value: "\(AppConfig.autoAdvanceHour):00")
                Divider().padding(.vertical, 4).overlay(Color.white.opacity(0.06))
                Button { showOnboarding = true } label: {
                    settingsActionRow(
                        title: "App Tutorial",
                        icon: "graduationcap.fill",
                        tint: AppConfig.darkText
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        settingsSection(title: L10n.statistics, icon: "chart.bar.fill", iconTint: .teal) {
            let myCount = bookingManager.getBookingsForUser(bookingManager.currentUserEmail).count
            VStack(spacing: 0) {
                infoRow(icon: "car.fill", label: L10n.myBookingsCount, value: "\(myCount)")
                infoRow(icon: "calendar.badge.checkmark", label: L10n.totalBookings, value: "\(bookingManager.bookings.count)")
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        settingsSection(title: L10n.data, icon: "externaldrive.fill", iconTint: .blue) {
            Button {
                showingClearAlert = true
            } label: {
                if AppConfig.enableSettingsGroupedTone {
                    settingsActionRow(
                        title: L10n.clearAllBookings,
                        icon: "trash.fill",
                        tint: AppConfig.spotOccupied.opacity(0.78),
                        emphasizeDestructive: true
                    )
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(AppConfig.spotOccupied)
                            .frame(width: 24)
                        Text(L10n.clearAllBookings)
                            .foregroundStyle(AppConfig.spotOccupied)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Group {
            if AppConfig.enableSettingsGroupedTone {
                settingsSection(title: L10n.account, icon: "rectangle.portrait.and.arrow.right", iconTint: .gray) {
                    VStack(spacing: 10) {
                        Button {
                            // Keep Keychain credentials so Face ID still works on next sign-in
                            authManager.signOut()
                        } label: {
                            settingsActionRow(
                                title: L10n.signOut,
                                icon: "rectangle.portrait.and.arrow.right",
                                tint: AppConfig.subtleGray
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Button {
                            showDeleteAccount = true
                        } label: {
                            settingsActionRow(
                                title: L10n.deleteAccount,
                                icon: "person.crop.circle.badge.xmark",
                                tint: AppConfig.spotOccupied.opacity(0.78),
                                emphasizeDestructive: true
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Button {
                        // Keep Keychain credentials so Face ID still works on next sign-in
                        authManager.signOut()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.body)
                            Text(L10n.signOut)
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                        }
                        .foregroundStyle(AppConfig.spotOccupied)
                        .padding(18)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.06), radius: 14, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        showDeleteAccount = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .font(.body)
                            Text(L10n.deleteAccount)
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                        }
                        .foregroundStyle(AppConfig.spotOccupied.opacity(0.7))
                        .padding(18)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.06), radius: 14, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal)
            }
        }
        .alert(L10n.deleteAccount, isPresented: $showDeleteAccount) {
            TextField(L10n.deleteConfirmPlaceholder, text: $deleteConfirmText)
                .textInputAutocapitalization(.characters)
            Button(L10n.deletePermanently, role: .destructive) {
                guard deleteConfirmText.uppercased() == "DELETE" else { return }
                Task {
                    let success = await authManager.deleteAccount()
                    if success {
                        bookingManager.clearUser()
                    }
                    deleteConfirmText = ""
                }
            }
            Button(L10n.cancel, role: .cancel) { deleteConfirmText = "" }
        } message: {
            Text(L10n.deleteAccountMsg)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text(AppConfig.companyName)
                .font(SettingsType.footerBrand)
                .tracking(2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.4))
            Text("EL Parking v1.0")
                .font(SettingsType.footerVersion)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.3))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Reusable Components

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        iconTint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                settingsIconTile(icon: icon, tint: iconTint, size: 40, iconSize: 20)
                Text(title)
                    .font(.title3)
                    .foregroundStyle(AppConfig.darkText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider()
                .padding(.leading, 72)
                .overlay(AppConfig.separatorSoft)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, SettingsSpace.lg)
            .padding(.vertical, SettingsSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppConfig.separatorSoft.opacity(0.35), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }

    private func settingsIconTile(icon: String, tint: Color, size: CGFloat = 32, iconSize: CGFloat = 15) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(tint)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func settingsActionRow(
        title: String,
        icon: String,
        tint: Color,
        textTint: Color? = nil,
        emphasizeDestructive: Bool = false
    ) -> some View {
        let rowBackground: Color = emphasizeDestructive
            ? AppConfig.spotOccupied.opacity(0.03)
            : Color.clear

        return HStack(spacing: SettingsSpace.md) {
            settingsIconTile(icon: icon, tint: tint, size: 32, iconSize: 15)

            Text(title)
                .font(SettingsType.rowTitle)
                .foregroundStyle(textTint ?? tint)

            Spacer()

            Image(systemName: "chevron.right")
                .font(SettingsType.rowChevron)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
        }
        .padding(.horizontal, SettingsSpace.sm)
        .padding(.vertical, SettingsSpace.sm)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func inputField(
        icon: String,
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .words
    ) -> some View {
        HStack(spacing: SettingsSpace.md) {
            settingsIconTile(icon: icon, tint: .gray, size: 32, iconSize: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(SettingsType.inputLabel)
                    .foregroundStyle(AppConfig.subtleGray)
                TextField(placeholder, text: text)
                    .font(SettingsType.inputValue)
                    .foregroundStyle(AppConfig.darkText)
                    .textInputAutocapitalization(capitalization)
                    .keyboardType(keyboard)
            }
        }
        .padding(SettingsSpace.md)
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reminderPickerColumn(_ label: String, binding: Binding<Int>, range: [Int]) -> some View {
        VStack(spacing: 2) {
            Picker(label, selection: binding) {
                ForEach(range, id: \.self) { v in Text("\(v)").tag(v) }
            }
            .pickerStyle(.wheel)
            .clipped()
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(AppConfig.subtleGray)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoRow(
        icon: String,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: SettingsSpace.md) {
            settingsIconTile(icon: icon, tint: .gray, size: 30, iconSize: 13)

            Text(label)
                .font(SettingsType.rowTitle)
                .foregroundStyle(AppConfig.darkText)

            Spacer()

            Text(value)
                .font(SettingsType.rowTitle)
                .foregroundStyle(AppConfig.subtleGray)
                .fontWeight(.medium)
        }
        .padding(.vertical, SettingsSpace.sm)
    }
}

// MARK: - Change Password Sheet

private struct ChangePasswordSheet: View {
    @ObservedObject private var lang = LanguageManager.shared
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword     = ""
    @State private var confirmPassword = ""
    @State private var showCurrent     = false
    @State private var showNew         = false
    @State private var showConfirm     = false
    @State private var errorMessage:   String?
    @State private var resetSent       = false
    @State private var isWorking       = false
    @State private var didSucceed      = false

    private enum PwdField: Hashable { case current, new, confirm }
    @FocusState private var pwdFocus: PwdField?

    private var email: String { authManager.currentUser?.email ?? "" }

    private var canSubmit: Bool {
        !currentPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword && !didSucceed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Fields card
                        VStack(spacing: 0) {
                            pwField(L10n.currentPassword, text: $currentPassword, show: $showCurrent,
                                    focus: $pwdFocus, field: .current, submitLabel: .next) { pwdFocus = .new }
                            Divider().padding(.leading, 56)
                            pwField(L10n.newPassword, text: $newPassword, show: $showNew,
                                    focus: $pwdFocus, field: .new, submitLabel: .next) { pwdFocus = .confirm }
                            Divider().padding(.leading, 56)
                            pwField(L10n.confirmNewPassword, text: $confirmPassword, show: $showConfirm,
                                    focus: $pwdFocus, field: .confirm, submitLabel: .go) {
                                if canSubmit { Task { await submit() } }
                            }
                        }
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.06), radius: 14, y: 4)
                        .padding(.horizontal)

                        // Error
                        if let err = errorMessage {
                            Text(err)
                                .font(.subheadline)
                                .foregroundStyle(AppConfig.spotOccupied)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .transition(.opacity)
                        }

                        // Change Password button
                        Button { Task { await submit() } } label: {
                            ZStack {
                                if isWorking {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.white)
                                        Text(L10n.saving).foregroundStyle(.white).fontWeight(.semibold)
                                    }
                                } else if didSucceed {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(L10n.passwordChanged).fontWeight(.semibold)
                                    }
                                    .foregroundStyle(AppConfig.activeGreen)
                                } else {
                                    Text(L10n.changePassword)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? AppConfig.accent : AppConfig.surfaceHigh)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(!canSubmit || isWorking)
                        .padding(.horizontal)
                        .animation(.standard, value: isWorking)
                        .animation(.standard, value: didSucceed)

                        // Forgot current password
                        VStack(spacing: 8) {
                            Button { Task { await sendReset() } } label: {
                                Text(L10n.forgotCurrentPassword)
                                    .font(.subheadline)
                                    .foregroundStyle(AppConfig.accentFg)
                            }
                            .buttonStyle(ScaleButtonStyle())

                            if resetSent {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppConfig.activeGreen)
                                    Text(L10n.checkYourEmail)
                                        .font(.subheadline)
                                        .foregroundStyle(AppConfig.activeGreen)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.standard, value: resetSent)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle(L10n.changePassword)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundStyle(AppConfig.accentFg)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.done) { pwdFocus = nil }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConfig.accentFg)
                }
            }
        }
    }

    private func pwField(_ label: String, text: Binding<String>, show: Binding<Bool>,
                         focus: FocusState<PwdField?>.Binding,
                         field: PwdField,
                         submitLabel: SubmitLabel = .return,
                         onSubmit: (() -> Void)? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.body)
                .foregroundStyle(AppConfig.accentFg)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Font.caption)
                    .foregroundStyle(AppConfig.subtleGray)
                Group {
                    if show.wrappedValue {
                        TextField(label, text: text)
                    } else {
                        SecureField(label, text: text)
                    }
                }
                .font(Font.subheadline)
                .foregroundStyle(AppConfig.darkText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focus, equals: field)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
            }

            Button { show.wrappedValue.toggle() } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(AppConfig.subtleGray)
                    .font(.system(size: 14))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
    }

    private func submit() async {
        errorMessage = nil
        guard newPassword == confirmPassword else {
            errorMessage = L10n.passwordsMismatch; return
        }
        isWorking = true
        let ok = await authManager.changePassword(current: currentPassword, new: newPassword)
        isWorking = false
        if ok {
            withAnimation { didSucceed = true }
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } else {
            withAnimation { errorMessage = authManager.errorMessage }
        }
    }

    private func sendReset() async {
        let ok = await authManager.resetPassword(email: email)
        if ok { withAnimation { resetSent = true } }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BookingManager())
        .environmentObject(AuthManager())
}
