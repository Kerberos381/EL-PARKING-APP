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
    @AppStorage("appPalette") private var paletteRaw: Int = 0
    @AppStorage("homeStyle") private var homeStyleRaw: String = "roomy"
    @State private var phoneField: String = ""
    @State private var phoneSaveTask: Task<Void, Never>?
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
        let before = L10n.before
        return [
            ("30 min", before, 30),
            (LanguageManager.shared.language == .czech ? "1 hod" : "1 hour", before, 60)
        ]
    }

    // Vehicle save state
    private enum VehicleSaveState { case idle, saving, saved }
    private enum ProfileSaveState { case idle, saving, saved }
    @State private var vehicleSaveState: VehicleSaveState = .idle
    @State private var profileSaveState: ProfileSaveState = .idle
    @State private var lastSavedPlate:   String = ""
    @State private var lastSavedCar:     String = ""
    @State private var lastSavedColor:   String = ""
    @State private var lastSavedCarType: String = ""
    @State private var lastSavedPreferredVocative: String = ""
    @State private var selectedCompanyBadge: CompanyBadge = .none
    @State private var lastSavedCompanyBadge: CompanyBadge = .none
    @State private var selectedVehicleMake = ""
    @State private var selectedVehicleModel = ""
    @State private var showCustomPicker  = false  // notification custom time picker
    @State private var showVehiclePresetSheet = false
    @State private var showVehicleColorPicker = false
    @State private var biometricsAvailable = false
    @State private var biometricDisplayName = "Biometrics"
    @State private var hasSavedBiometricCredentials = false
    // Native settings pattern: no global edit mode.
    private let useNativeSettingsRevamp = true
    @State private var nativeReminderInterval: NativeReminderInterval = .oneHour

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

    private var profileIsDirty: Bool {
        bookingManager.preferredVocative.trimmingCharacters(in: .whitespacesAndNewlines)
            != lastSavedPreferredVocative.trimmingCharacters(in: .whitespacesAndNewlines)
            || selectedCompanyBadge != lastSavedCompanyBadge
    }

    private var hasUnsavedSettingsChanges: Bool { vehicleIsDirty || profileIsDirty }

    private var theme: AppTheme {
        AppTheme(rawValue: themeRaw) ?? .system
    }

    private var selectedVehicleColorHex: String {
        bookingManager.carColor.normalizedHexColor ?? ""
    }

    private var selectedVehiclePreset: VehicleMiniaturePreset? {
        if !bookingManager.vehicleMiniaturePresetID.isEmpty {
            return VehicleMiniaturePreset.all.first { $0.id == bookingManager.vehicleMiniaturePresetID }
        }
        return VehicleMiniaturePreset.matching(
            description: bookingManager.carDescription,
            carType: bookingManager.carType
        )
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
            Group {
                if useNativeSettingsRevamp {
                    nativeSettingsLayout
                } else {
                    legacySettingsLayout
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle(L10n.settings)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                phoneField = authManager.currentUser?.phone ?? ""
                lastSavedPlate   = bookingManager.registrationPlate
                lastSavedCar     = bookingManager.carDescription
                lastSavedColor   = bookingManager.carColor
                lastSavedCarType = bookingManager.carType
                lastSavedPreferredVocative = bookingManager.preferredVocative
                selectedCompanyBadge = authManager.currentUser?.companyBadge ?? .none
                lastSavedCompanyBadge = selectedCompanyBadge
                syncVehicleMakeModelFromDescription()
                refreshBiometricState()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.done) {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConfig.darkText)
                }
            }
            .alert(L10n.clearAllBookings, isPresented: $showingClearAlert) {
                Button(L10n.clear, role: .destructive) {
                    Haptics.destructive()
                    withAnimation {
                        bookingManager.bookings.removeAll()
                        UserDefaults.standard.removeObject(forKey: "bookings")
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.clearConfirmMsg)
            }
            // Hosted at body level so it presents from BOTH the native and
            // legacy layouts (the native layout has no other host for it).
            .alert(L10n.deleteAccount, isPresented: $showDeleteAccount) {
                TextField(L10n.deleteConfirmPlaceholder, text: $deleteConfirmText)
                    .textInputAutocapitalization(.characters)
                Button(L10n.deletePermanently, role: .destructive) {
                    guard deleteConfirmText.uppercased() == "DELETE" else { return }
                    Haptics.destructive()
                    Task {
                        let success = await authManager.deleteAccount()
                        if success {
                            bookingManager.clearUser()
                        } else if let message = authManager.errorMessage {
                            ToastManager.shared.show(message, style: .error)
                        }
                        deleteConfirmText = ""
                    }
                }
                Button(L10n.cancel, role: .cancel) { deleteConfirmText = "" }
            } message: {
                Text(L10n.deleteAccountMsg)
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
            .sheet(isPresented: $showVehiclePresetSheet) {
                VehicleMiniaturePresetPickerSheet(
                    title: "Choose Vehicle Icon",
                    selectedColorHex: selectedVehicleColorHex,
                    selectedPresetID: selectedVehiclePreset?.id,
                    selectedMake: selectedVehicleMake,
                    selectedModel: selectedVehicleModel
                ) { preset in
                    bookingManager.vehicleMiniaturePresetID = preset.id
                    bookingManager.carDescription = preset.searchDescription
                    bookingManager.carType = ""
                    syncVehicleMakeModelFromDescription()
                }
            }
        }
    }

    private var legacySettingsLayout: some View {
        ZStack {
            AppConfig.groupedPageBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SettingsSpace.xl) {
                    themeSection
                    profileCard
                    languageSection
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
            .transition(.opacity)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var nativeSettingsLayout: some View {
        List {
            Section {
                profileCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }.listRowBackground(AppConfig.groupedCardBg)

            Section("Appearance") {
                Menu {
                    ForEach(AppTheme.allCases, id: \.rawValue) { option in
                        Button {
                            themeRaw = option.rawValue
                        } label: {
                            HStack {
                                Label(option.label, systemImage: option.icon)
                                if theme == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    nativeValueRow(L10n.appearance, value: theme.label, enabled: true)
                }
                .tint(AppConfig.darkText)

                Menu {
                    ForEach(AppConfig.AppPalette.allCases, id: \.rawValue) { option in
                        Button {
                            Haptics.selection()
                            paletteRaw = option.rawValue
                        } label: {
                            HStack {
                                Label(option.label, systemImage: option.icon)
                                if paletteRaw == option.rawValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    nativeValueRow(
                        L10n.colorPalette,
                        value: (AppConfig.AppPalette(rawValue: paletteRaw) ?? .standard).label,
                        enabled: true
                    )
                }
                .tint(AppConfig.darkText)

                Menu {
                    Button {
                        Haptics.selection()
                        homeStyleRaw = "roomy"
                    } label: {
                        HStack {
                            Label(L10n.homeRoomy, systemImage: "rectangle.grid.1x2")
                            if homeStyleRaw == "roomy" { Image(systemName: "checkmark") }
                        }
                    }
                    Button {
                        Haptics.selection()
                        homeStyleRaw = "compact"
                    } label: {
                        HStack {
                            Label(L10n.homeCompact, systemImage: "square.grid.2x2")
                            if homeStyleRaw == "compact" { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    nativeValueRow(
                        L10n.homeLayout,
                        value: homeStyleRaw == "compact" ? L10n.homeCompact : L10n.homeRoomy,
                        enabled: true
                    )
                }
                .tint(AppConfig.darkText)
            }.listRowBackground(AppConfig.groupedCardBg)

            Section("Language") {
                Menu {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                        Button {
                            langManager.language = lang
                        } label: {
                            HStack {
                                Text("\(lang.flag) \(lang.displayName)")
                                if langManager.language == lang {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    nativeValueRow(L10n.language, value: "\(langManager.language.flag) \(langManager.language.displayName)", enabled: true)
                }
                .tint(AppConfig.darkText)
            }.listRowBackground(AppConfig.groupedCardBg)

            Section("Vehicle") {
                Button {
                    Haptics.selection()
                    showVehiclePresetSheet = true
                } label: {
                    nativeValueRow(
                        "Choose Icon",
                        value: selectedVehiclePreset?.title ?? "Choose Icon",
                        enabled: true
                    )
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(CarData.makes, id: \.self) { make in
                        Button(make) {
                            selectedVehicleMake = make
                            selectedVehicleModel = ""
                            bookingManager.carDescription = make
                        }
                    }
                } label: {
                    nativeValueRow("Make", value: selectedVehicleMake.isEmpty ? "Choose make" : selectedVehicleMake, enabled: true)
                }

                Menu {
                    if selectedVehicleMake.isEmpty {
                        Button("Select make first") {}.disabled(true)
                    } else {
                        ForEach(CarData.models(for: selectedVehicleMake), id: \.self) { model in
                            Button(model) {
                                selectedVehicleModel = model
                                bookingManager.carDescription = CarData.compose(make: selectedVehicleMake, model: model)
                            }
                        }
                    }
                } label: {
                    nativeValueRow("Model", value: selectedVehicleModel.isEmpty ? "Choose model" : selectedVehicleModel, enabled: true)
                }

                NavigationLink {
                    TextEditDetailView(
                        title: L10n.regPlate,
                        text: $bookingManager.registrationPlate,
                        capitalization: .characters
                    )
                } label: {
                    LabeledContent(L10n.regPlate, value: bookingManager.registrationPlate.isEmpty ? L10n.regPlatePlaceholder : bookingManager.registrationPlate)
                }
            }.listRowBackground(AppConfig.groupedCardBg)

            if isShortcutsOwner {
                Section("Shortcuts") {
                    Text("Set favorite spot and default booking time for quick Siri or shortcut actions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Menu {
                        Button("None") { favoriteSpotID = "" }
                        ForEach(AppConfig.allParkingSpots, id: \.id) { spot in
                            Button(spot.label) { favoriteSpotID = spot.id }
                        }
                    } label: {
                        nativeValueRow("Favorite Spot",
                                       value: favoriteSpotID.isEmpty ? "None" : (AppConfig.allParkingSpots.first(where: { $0.id == favoriteSpotID })?.label ?? favoriteSpotID),
                                       enabled: true)
                    }

                    Menu {
                        ForEach(AppConfig.availableTimeSlots, id: \.self) { slot in
                            Button(slot) { favoriteFromTime = slot }
                        }
                    } label: {
                        nativeValueRow("From", value: favoriteFromTime, enabled: true)
                    }

                    Menu {
                        ForEach(AppConfig.availableTimeSlots, id: \.self) { slot in
                            Button(slot) { favoriteToTime = slot }
                        }
                    } label: {
                        nativeValueRow("To", value: favoriteToTime, enabled: true)
                    }
                }
            }

            Section("Notifications") {
                Toggle(isOn: $reminderEnabled.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.bookingReminders)
                                .font(.body)
                            Text(L10n.notifyBeforeBooking)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(AppConfig.darkText.opacity(0.7))
                .onChange(of: reminderEnabled) { _, _ in
                    bookingManager.scheduleDailyReminders()
                }

                if reminderEnabled {
                    NavigationLink {
                        ReminderIntervalPickerView(selectedInterval: $nativeReminderInterval) { picked in
                            switch picked {
                            case .thirtyMinutes:
                                reminderMinutesBefore = 30
                                bookingManager.scheduleDailyReminders()
                            case .oneHour:
                                reminderMinutesBefore = 60
                                bookingManager.scheduleDailyReminders()
                            case .custom:
                                showCustomPicker = true
                            }
                        }
                    } label: {
                        LabeledContent("Remind Me", value: nativeReminderIntervalDisplay)
                    }
                }
            }.listRowBackground(AppConfig.groupedCardBg)

            Section("Security") {
                if biometricsAvailable {
                    Toggle(L10n.faceIDAppLock, isOn: $biometricEnabled)
                        .tint(AppConfig.darkText.opacity(0.7))
                        .onChange(of: biometricEnabled) { _, _ in toggleBiometric() }
                    if hasSavedBiometricCredentials && biometricEnabled {
                        Button(role: .destructive) {
                            KeychainManager.shared.deleteCredentials()
                            hasSavedBiometricCredentials = false
                            biometricEnabled = false
                        } label: {
                            Text(L10n.forgetSavedSignInDevice)
                        }
                    }
                }
            }.listRowBackground(AppConfig.groupedCardBg)

            Section("Account") {
                LabeledContent(L10n.name, value: bookingManager.currentUserName)
                LabeledContent(L10n.email, value: bookingManager.currentUserEmail)

                NavigationLink {
                    TextEditDetailView(
                        title: L10n.phoneNumber,
                        text: $phoneField,
                        keyboardType: .phonePad
                    )
                } label: {
                    LabeledContent(
                        L10n.phoneOptional,
                        value: phoneField.isEmpty ? "—" : phoneField
                    )
                }
                .onChange(of: phoneField) { _, newValue in
                    // Debounce: save once typing pauses, not on every keystroke.
                    phoneSaveTask?.cancel()
                    phoneSaveTask = Task {
                        try? await Task.sleep(for: .milliseconds(600))
                        guard !Task.isCancelled else { return }
                        await authManager.updateProfile(
                            displayName: bookingManager.currentUserName,
                            plate: bookingManager.registrationPlate,
                            carDescription: bookingManager.carDescription,
                            carColor: bookingManager.carColor,
                            carType: bookingManager.carType,
                            vehicleMiniaturePresetID: bookingManager.vehicleMiniaturePresetID,
                            preferredVocative: bookingManager.preferredVocative,
                            phone: newValue
                        )
                    }
                }

                if bookingManager.isAdmin {
                Menu {
                        ForEach(CompanyBadge.allCases, id: \.rawValue) { badge in
                            Button {
                                selectedCompanyBadge = badge
                                Task {
                                    await authManager.updateProfile(
                                        displayName: bookingManager.currentUserName,
                                        plate: bookingManager.registrationPlate,
                                        carDescription: bookingManager.carDescription,
                                        carColor: bookingManager.carColor,
                                        carType: bookingManager.carType,
                                        vehicleMiniaturePresetID: bookingManager.vehicleMiniaturePresetID,
                                        preferredVocative: bookingManager.preferredVocative,
                                        companyBadge: selectedCompanyBadge
                                    )
                                }
                            } label: {
                                HStack {
                                    Text(companyBadgeLabel(badge))
                                    if selectedCompanyBadge == badge { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        nativeValueRow(L10n.companyBadge, value: companyBadgeLabel(selectedCompanyBadge), enabled: true)
                    }
                    .tint(AppConfig.darkText)
                } else {
                    LabeledContent(L10n.companyBadge, value: companyBadgeLabel(selectedCompanyBadge))
                }

                NavigationLink {
                    TextEditDetailView(
                        title: L10n.greetingName,
                        text: $bookingManager.preferredVocative,
                        capitalization: .words
                    )
                } label: {
                    LabeledContent(L10n.greetingName, value: bookingManager.preferredVocative.isEmpty ? L10n.greetingNameHint : bookingManager.preferredVocative)
                }

                Button {
                    showChangePassword = true
                } label: {
                    nativeValueRow(L10n.changePassword, value: "", enabled: true)
                }
                .buttonStyle(.plain)
            }.listRowBackground(AppConfig.groupedCardBg)

            Section(L10n.bookingRules) {
                LabeledContent(L10n.personalAdvance, value: "\(AppConfig.selfBookingMaxAdvanceDays) days")
                LabeledContent(L10n.forOthersAdvance, value: "\(AppConfig.othersBookingMaxAdvanceDays) days")
                LabeledContent(L10n.maxPerDay, value: "\(AppConfig.selfBookingMaxPerDay)")
            }.listRowBackground(AppConfig.groupedCardBg)

            Section(L10n.statistics) {
                let myCount = bookingManager.getBookingsForUser(bookingManager.currentUserEmail).count
                LabeledContent(L10n.myBookingsCount, value: "\(myCount)")
                LabeledContent(L10n.totalBookings, value: "\(bookingManager.bookings.count)")
            }.listRowBackground(AppConfig.groupedCardBg)

            Section(L10n.data) {
                Button(role: .destructive) { showingClearAlert = true } label: {
                    Text(L10n.clearAllBookings)
                }
            }.listRowBackground(AppConfig.groupedCardBg)

            Section("Session") {
                Button {
                    authManager.signOut()
                } label: {
                    Text(L10n.signOut)
                        .foregroundStyle(AppConfig.darkText)
                }
                .buttonStyle(.plain)
                Button(role: .destructive) { showDeleteAccount = true } label: {
                    Text(L10n.deleteAccount)
                }
            }.listRowBackground(AppConfig.groupedCardBg)

            Section {
                Link(destination: AppConfig.privacyPolicyURL) {
                    HStack {
                        Text(L10n.privacyPolicy)
                            .foregroundStyle(AppConfig.darkText)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                }
                Link(destination: AppConfig.supportURL) {
                    HStack {
                        Text(L10n.support)
                            .foregroundStyle(AppConfig.darkText)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                }
            }.listRowBackground(AppConfig.groupedCardBg)

            Section {
                VStack(spacing: 4) {
                    Text("EL PARKING")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") · \(L10n.releasedLabel) \(AppConfig.releaseDate)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }.listRowBackground(AppConfig.groupedCardBg)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppConfig.groupedPageBg)
        .onAppear {
            nativeReminderInterval = nativeIntervalFromMinutes(reminderMinutesBefore)
        }
        .onChange(of: reminderMinutesBefore) { _, newValue in
            nativeReminderInterval = nativeIntervalFromMinutes(newValue)
        }
    }

    private func nativeValueRow(_ title: String, value: String, enabled: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppConfig.darkText)
            Spacer()
            Text(value)
                .foregroundStyle(enabled ? Color.secondary : Color.secondary.opacity(0.7))
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(enabled ? Color.secondary.opacity(0.7) : Color.secondary.opacity(0.35))
        }
    }

    private var nativeReminderIntervalDisplay: String {
        switch nativeReminderInterval {
        case .thirtyMinutes:
            return "30 min before"
        case .oneHour:
            return "1 hour before"
        case .custom:
            return reminderSummary
        }
    }

    private func nativeIntervalFromMinutes(_ minutes: Int) -> NativeReminderInterval {
        switch minutes {
        case 30: return .thirtyMinutes
        case 60: return .oneHour
        default: return .custom
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
                    .foregroundStyle(AppConfig.darkText)

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
                    .foregroundStyle(AppConfig.darkText)
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
                profileIdentityBadge

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
            }
            .padding(18)

        }
        .frame(maxWidth: .infinity)
        .background(AppConfig.groupedCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .cardShadow()
        .padding(.top, 8)
    }

    private var currentRoleLabel: String {
        if bookingManager.isAdmin { return L10n.administrator }
        if bookingManager.isPrivileged { return L10n.privilegedUser }
        return "User"
    }

    private var profileInitials: String {
        let words = bookingManager.currentUserName
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        if words.count >= 2 {
            let first = words[0].prefix(1).uppercased()
            let second = words[1].prefix(1).uppercased()
            return "\(first)\(second)"
        }
        return String(bookingManager.currentUserName.prefix(2)).uppercased()
    }

    @ViewBuilder
    private var profileIdentityBadge: some View {
        if VehicleMiniatureView.hasSpecificMiniature(
            carType: bookingManager.carType,
            description: bookingManager.carDescription,
            presetID: bookingManager.vehicleMiniaturePresetID.isEmpty ? nil : bookingManager.vehicleMiniaturePresetID
        ) {
            VehicleMiniatureView(
                carType: bookingManager.carType,
                colorHex: bookingManager.carColor,
                description: bookingManager.carDescription,
                presetID: bookingManager.vehicleMiniaturePresetID.isEmpty ? nil : bookingManager.vehicleMiniaturePresetID
            )
            .frame(width: 86, height: 52)
        } else {
            ZStack {
                Circle()
                    .fill(AppConfig.surfaceLow)
                Text(profileInitials)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .frame(width: 72, height: 72)
        }
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
            Menu {
                ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                    Button {
                        if langManager.language != lang {
                            Haptics.selection()
                        }
                        langManager.language = lang
                    } label: {
                        HStack {
                            Text("\(lang.flag) \(lang.displayName)")
                            if langManager.language == lang {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                settingsActionRow(
                    title: "\(L10n.language): \(langManager.language.flag) \(langManager.language.displayName)",
                    icon: "globe",
                    tint: .blue,
                    textTint: AppConfig.darkText
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        settingsSection(title: L10n.appearance, icon: "paintpalette.fill", iconTint: .purple) {
            Menu {
                ForEach(AppTheme.allCases, id: \.rawValue) { option in
                    Button {
                        if theme != option {
                            Haptics.selection()
                        }
                        themeRaw = option.rawValue
                    } label: {
                        HStack {
                            Label(option.label, systemImage: option.icon)
                            if theme == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                settingsActionRow(
                    title: "\(L10n.appearance): \(theme.label)",
                    icon: "paintpalette.fill",
                    tint: .purple,
                    textTint: AppConfig.darkText
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        settingsSection(title: L10n.notifications, icon: "bell.badge.fill", iconTint: AppConfig.danger) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    settingsIconTile(
                        icon: reminderEnabled ? "bell.badge.fill" : "bell.slash.fill",
                        tint: AppConfig.danger,
                        size: 24,
                        iconSize: 11
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
                        .tint(AppConfig.darkText.opacity(0.55))
                }
                .padding(.vertical, 8)
                .onChange(of: reminderEnabled) { _, _ in
                    Haptics.selection()
                    bookingManager.scheduleDailyReminders()
                }

                if reminderEnabled {
                    Divider().overlay(AppConfig.separatorSoft)
                    Picker("", selection: $reminderMinutesBefore) {
                        ForEach(reminderOptions, id: \.minutes) { option in
                            Text("\(option.label) \(option.sublabel)").tag(option.minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                    .onChange(of: reminderMinutesBefore) { _, _ in
                        bookingManager.scheduleDailyReminders()
                    }

                    Divider().overlay(AppConfig.separatorSoft)
                    Button { showCustomPicker = true } label: {
                        settingsActionRow(
                            title: "\(L10n.custom): \(isCustomValue ? reminderSummary : L10n.setCustomTime)",
                            icon: "slider.horizontal.3",
                            tint: .gray,
                            textTint: AppConfig.darkText
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Car Info Section

    private var carInfoSection: some View {
        settingsSection(title: L10n.vehicle, icon: "car.fill", iconTint: AppConfig.darkText) {
            VStack(spacing: 16) {
                Button {
                    Haptics.selection()
                    showVehiclePresetSheet = true
                } label: {
                    iconPickerRow(
                        title: langManager.language == .czech ? "Ikona" : "Choose Icon",
                        value: selectedVehiclePreset?.title ?? "Choose Icon",
                        isPlaceholder: selectedVehiclePreset == nil
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(false)

                VStack(spacing: 10) {
                    Menu {
                        ForEach(CarData.makes, id: \.self) { make in
                            Button {
                                selectedVehicleMake = make
                                selectedVehicleModel = ""
                                bookingManager.carDescription = make
                            } label: {
                                HStack(spacing: 8) {
                                    CarMakerLogoBadge(make: make, size: 18)
                                    Text(make)
                                }
                            }
                        }
                    } label: {
                        makeModelPickerRow(
                            icon: "building.2.crop.circle",
                            title: langManager.language == .czech ? "Značka" : "Make",
                            value: selectedVehicleMake.isEmpty ? (langManager.language == .czech ? "Vyberte značku" : "Choose make") : selectedVehicleMake,
                            isPlaceholder: selectedVehicleMake.isEmpty,
                            makerLogo: selectedVehicleMake.isEmpty ? nil : selectedVehicleMake
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Menu {
                        if selectedVehicleMake.isEmpty {
                            Button(langManager.language == .czech ? "Nejprve vyberte značku" : "Select make first") {}
                                .disabled(true)
                        } else {
                            ForEach(CarData.models(for: selectedVehicleMake), id: \.self) { model in
                                Button(model) {
                                    selectedVehicleModel = model
                                    bookingManager.carDescription = CarData.compose(make: selectedVehicleMake, model: model)
                                }
                            }
                        }
                    } label: {
                        makeModelPickerRow(
                            icon: "car.side",
                            title: langManager.language == .czech ? "Model" : "Model",
                            value: selectedVehicleModel.isEmpty ? (langManager.language == .czech ? "Vyberte model" : "Choose model") : selectedVehicleModel,
                            isPlaceholder: selectedVehicleModel.isEmpty
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    inputField(
                        icon: "number",
                        label: L10n.regPlate,
                        placeholder: L10n.regPlatePlaceholder,
                        text: $bookingManager.registrationPlate,
                        capitalization: .characters
                    )
                    .disabled(false)
                }
                .opacity(1)

                VStack(alignment: .leading, spacing: 10) {
                    DisclosureGroup(isExpanded: $showVehicleColorPicker) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 38))], spacing: 8) {
                            ForEach(AppConfig.carColors, id: \.hex) { color in
                                let isSelected = selectedVehicleColorHex == color.hex
                                Button {
                                    withAnimation(.quick) { bookingManager.carColor = color.hex }
                                } label: {
                                    ZStack {
                                        Circle().fill(Color(hex: color.hex)).frame(width: 30, height: 30)
                                            .overlay(Circle().stroke(
                                                isSelected ? AppConfig.darkText.opacity(0.55) : AppConfig.outlineVariant.opacity(0.4),
                                                lineWidth: isSelected ? 2 : 1
                                            ))
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(
                                                    color.hex == "#FFFFFF" || color.hex == "#F9A825" ? Color.black : Color.white
                                                )
                                        }
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "paintpalette")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppConfig.subtleGray)
                                .frame(width: 24)
                            Text(L10n.carColor)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppConfig.darkText)
                            Spacer()
                            let colorHex = selectedVehicleColorHex
                            if let match = AppConfig.carColors.first(where: { $0.hex == colorHex }) {
                                Text(match.name)
                                    .font(.caption)
                                    .foregroundStyle(AppConfig.subtleGray)
                            }
                        }
                    }
                    .tint(AppConfig.darkText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppConfig.outlineVariant.opacity(0.35), lineWidth: 1)
                    )
                    .disabled(false)
                }
                .opacity(1)
            }
        }
    }

    // MARK: - Shortcuts & Favorite Section

    private var shortcutsSection: some View {
        settingsSection(title: "Shortcuts & Favorite", icon: "wand.and.stars", iconTint: AppConfig.warning) {
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
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Divider()

                // Favorite spot picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Favorite spot")
                        .font(.caption2.weight(.bold))
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
                        Text("From")
                            .font(.caption2.weight(.bold))
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .background(AppConfig.surfaceLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppConfig.outlineVariant.opacity(0.4), lineWidth: 1))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("To")
                            .font(.caption2.weight(.bold))
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
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
                            .foregroundStyle(AppConfig.darkText)
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

                Menu {
                    ForEach(CompanyBadge.allCases, id: \.rawValue) { badge in
                        Button {
                            selectedCompanyBadge = badge
                        } label: {
                            HStack {
                                Text(companyBadgeLabel(badge))
                                Spacer()
                                if selectedCompanyBadge == badge {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    settingsActionRow(
                        title: "\(L10n.companyBadge): \(companyBadgeLabel(selectedCompanyBadge))",
                        icon: "checkmark.seal.fill",
                        tint: AppConfig.warning,
                        textTint: AppConfig.darkText
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                Divider().overlay(AppConfig.separatorSoft)

                VStack(alignment: .leading, spacing: 8) {
                    inputField(
                        icon: "text.quote",
                        label: L10n.greetingName,
                        placeholder: L10n.greetingNameHint,
                        text: $bookingManager.preferredVocative,
                        capitalization: .words
                    )
                    Text(L10n.greetingNameHelp)
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray)
                        .padding(.horizontal, 4)
                }
                .padding(.vertical, 12)
                .opacity(1)

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
            settingsIconTile(icon: icon, tint: tint, size: 28, iconSize: 13)

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

    private func companyBadgeLabel(_ badge: CompanyBadge) -> String {
        switch badge {
        case .omega: return L10n.omegaLabel
        case .essilorLuxottica: return L10n.essilorLuxotticaLabel
        case .grandVision: return L10n.grandVisionLabel
        case .none: return L10n.noneLabel
        }
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
                Divider().overlay(AppConfig.separatorSoft)
                Button { showOnboarding = true } label: {
                    settingsActionRow(
                        title: "App Tutorial",
                        icon: "graduationcap.fill",
                        tint: AppConfig.darkText,
                        showsChevron: false
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
                        emphasizeDestructive: true,
                        showsChevron: false
                    )
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(AppConfig.spotOccupied)
                            .frame(width: 24)
                        Text(L10n.clearAllBookings)
                            .foregroundStyle(AppConfig.spotOccupied)
                        Spacer()
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
                            authManager.signOut()
                        } label: {
                            settingsActionRow(
                                title: L10n.signOut,
                                icon: "rectangle.portrait.and.arrow.right",
                                tint: AppConfig.subtleGray,
                                textTint: AppConfig.darkText,
                                showsChevron: false
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
                                emphasizeDestructive: true,
                                showsChevron: false
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Button {
                        authManager.signOut()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.body)
                            Text(L10n.signOut)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundStyle(AppConfig.darkText)
                        .padding(18)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .cardShadow()
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
                        }
                        .foregroundStyle(AppConfig.spotOccupied.opacity(0.7))
                        .padding(18)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .cardShadow()
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text(AppConfig.companyName)
                .font(SettingsType.footerBrand)
                .tracking(2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.4))
            Text("EL Parking v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
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
        // Build once and pass through type erasure to avoid repeated generic
        // closure re-evaluation during SwiftUI diffing.
        let sectionContent = AnyView(content())
        return settingsSection(
            title: title,
            icon: icon,
            iconTint: iconTint,
            content: sectionContent
        )
    }

    private func settingsSection(
        title: String,
        icon: String,
        iconTint: Color,
        content: AnyView
    ) -> some View {
        _ = icon
        _ = iconTint
        return VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppConfig.groupedCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func settingsIconTile(icon: String, tint: Color, size: CGFloat = 28, iconSize: CGFloat = 13) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(tint)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: iconSize + 2, height: iconSize + 2, alignment: .center)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func settingsActionRow(
        title: String,
        icon: String,
        tint: Color,
        textTint: Color? = nil,
        emphasizeDestructive: Bool = false,
        showsChevron: Bool = true
    ) -> some View {
        _ = emphasizeDestructive
        return HStack(spacing: SettingsSpace.md) {
            settingsIconTile(icon: icon, tint: tint, size: 28, iconSize: 13)
                .frame(width: 28, height: 28, alignment: .center)

            Text(title)
                .font(SettingsType.rowTitle)
                .foregroundStyle(textTint ?? AppConfig.darkText)

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(SettingsType.rowChevron)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 44)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(Color.clear)
    }

    private func makeModelPickerRow(
        icon: String,
        title: String,
        value: String,
        isPlaceholder: Bool,
        makerLogo: String? = nil
    ) -> some View {
        HStack(spacing: SettingsSpace.md) {
            settingsIconTile(icon: icon, tint: .gray, size: 28, iconSize: 13)
                .frame(width: 28, height: 28, alignment: .center)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
            Spacer()
            HStack(spacing: 8) {
                if let makerLogo, !isPlaceholder {
                    CarMakerLogoBadge(make: makerLogo, size: 19)
                }
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(isPlaceholder ? AppConfig.subtleGray : AppConfig.darkText)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppConfig.outlineVariant.opacity(0.35), lineWidth: 1))
    }

    private func iconPickerRow(
        title: String,
        value: String,
        isPlaceholder: Bool
    ) -> some View {
        HStack(spacing: SettingsSpace.md) {
            settingsIconTile(icon: "sparkles", tint: .gray, size: 28, iconSize: 13)
                .frame(width: 28, height: 28, alignment: .center)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(isPlaceholder ? AppConfig.subtleGray : AppConfig.darkText)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppConfig.outlineVariant.opacity(0.35), lineWidth: 1))
    }

    private func syncVehicleMakeModelFromDescription() {
        let parsed = CarData.splitMakeModel(bookingManager.carDescription)
        selectedVehicleMake = parsed.make
        selectedVehicleModel = parsed.model
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
            settingsIconTile(icon: icon, tint: .gray, size: 28, iconSize: 13)

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
            settingsIconTile(icon: icon, tint: .gray, size: 28, iconSize: 13)

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
                        .cardShadow()
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
                                    .foregroundStyle(AppConfig.darkText)
                                } else {
                                    Text(L10n.changePassword)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? AppConfig.darkText : AppConfig.surfaceHigh)
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
                                    .foregroundStyle(AppConfig.darkText)
                            }
                            .buttonStyle(ScaleButtonStyle())

                            if resetSent {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppConfig.darkText)
                                    Text(L10n.checkYourEmail)
                                        .font(.subheadline)
                                        .foregroundStyle(AppConfig.darkText)
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
                        .foregroundStyle(AppConfig.darkText)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.done) { pwdFocus = nil }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConfig.darkText)
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
                .foregroundStyle(AppConfig.darkText)
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
                    .font(.subheadline)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 14))
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

private enum NativeReminderInterval: String, CaseIterable {
    case thirtyMinutes = "30 minutes before"
    case oneHour = "1 hour before"
    case custom = "Custom..."
}

private struct ReminderIntervalPickerView: View {
    @Binding var selectedInterval: NativeReminderInterval
    let onSelect: (NativeReminderInterval) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(NativeReminderInterval.allCases, id: \.self) { interval in
                Button {
                    selectedInterval = interval
                    onSelect(interval)
                    dismiss()
                } label: {
                    HStack {
                        Text(interval.rawValue)
                            .foregroundStyle(AppConfig.darkText)
                        Spacer()
                        if selectedInterval == interval {
                            Image(systemName: "checkmark")
                                .font(.body.bold())
                                .foregroundStyle(AppConfig.darkText)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(AppConfig.groupedCardBg)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppConfig.groupedPageBg.ignoresSafeArea())
        .tint(AppConfig.darkText)
        .navigationTitle("Remind Me")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TextEditDetailView: View {
    let title: String
    @Binding var text: String
    var capitalization: TextInputAutocapitalization = .never
    var keyboardType: UIKeyboardType = .default

    @State private var inputBuffer: String = ""
    @Environment(\.dismiss) private var dismiss

    init(title: String, text: Binding<String>, capitalization: TextInputAutocapitalization = .never, keyboardType: UIKeyboardType = .default) {
        self.title = title
        self._text = text
        self.capitalization = capitalization
        self.keyboardType = keyboardType
        self._inputBuffer = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        Form {
            Section(header: Text("Edit \(title)")) {
                TextField("Enter \(title.lowercased())", text: $inputBuffer)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(capitalization)
                    .keyboardType(keyboardType)
                    .submitLabel(.done)
                    .onSubmit { saveAndExit() }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L10n.cancel) { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.done) { saveAndExit() }
                    .fontWeight(.bold)
                    .disabled(inputBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func saveAndExit() {
        text = inputBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(BookingManager())
        .environmentObject(AuthManager())
}
