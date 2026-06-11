//
//  FinishRegistrationView.swift
//  EL PARKING APP
//
//  Shown when an admin-created user logs in for the first time.
//  They set their vehicle info, pick a car color, and optionally a new password.
//

import SwiftUI

struct FinishRegistrationView: View {
    let user: AppUser
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var lang = LanguageManager.shared

    @State private var plate          = ""
    @State private var car            = ""
    @State private var carType        = ""
    @State private var selectedColor  = AppConfig.carColors[0].hex
    @State private var selectedMake   = ""
    @State private var selectedModel  = ""
    @State private var selectedPresetID: String = ""
    @State private var showVehiclePresetSheet = false
    @State private var showVehicleColorPicker = false
    @State private var newPassword      = ""
    @State private var confirmPassword  = ""
    @State private var showPassword     = false
    @State private var showConfirmPwd   = false
    @State private var isLoading        = false
    @State private var errorMsg: String? = nil

    private enum Field: Hashable { case plate, newPassword, confirmPassword }
    @FocusState private var focusedField: Field?

    private var selectedVehiclePreset: VehicleMiniaturePreset? {
        if !selectedPresetID.isEmpty {
            return VehicleMiniaturePreset.all.first { $0.id == selectedPresetID }
        }
        return VehicleMiniaturePreset.matching(description: car, carType: carType)
    }

    var body: some View {
        ZStack {
            AppConfig.pageBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(AppConfig.accent.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(AppConfig.darkText)
                        }
                        .padding(.top, 48)

                        Text(L10n.finishRegistration)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppConfig.darkText)

                        Text(L10n.accountCreatedByAdmin)
                            .font(.subheadline)
                            .foregroundStyle(AppConfig.subtleGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Vehicle card
                    sectionCard(title: L10n.vehicle, icon: "car.fill") {
                        VStack(spacing: 14) {

                            // Registration plate
                            inputRow(icon: "rectangle.and.text.magnifyingglass",
                                     placeholder: L10n.platePlaceholder,
                                     text: $plate, capitalization: .characters,
                                     focusField: .plate, submitLabel: .next,
                                     onSubmit: { focusedField = .newPassword })

                            // Car make + model
                            VStack(spacing: 8) {
                                Menu {
                                    ForEach(CarData.makes, id: \.self) { make in
                                        Button {
                                            selectedMake = make
                                            selectedModel = ""
                                            car = make
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
                                        title: lang.language == .czech ? "Značka" : "Make",
                                        value: selectedMake.isEmpty ? (lang.language == .czech ? "Vyberte značku" : "Choose make") : selectedMake,
                                        isPlaceholder: selectedMake.isEmpty,
                                        makerLogo: selectedMake.isEmpty ? nil : selectedMake
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())

                                Menu {
                                    if selectedMake.isEmpty {
                                        Button(lang.language == .czech ? "Nejprve vyberte značku" : "Select make first") {}
                                            .disabled(true)
                                    } else {
                                        ForEach(CarData.models(for: selectedMake), id: \.self) { model in
                                            Button(model) {
                                                selectedModel = model
                                                car = CarData.compose(make: selectedMake, model: model)
                                            }
                                        }
                                    }
                                } label: {
                                    makeModelPickerRow(
                                        icon: "car.side",
                                        title: lang.language == .czech ? "Model" : "Model",
                                        value: selectedModel.isEmpty ? (lang.language == .czech ? "Vyberte model" : "Choose model") : selectedModel,
                                        isPlaceholder: selectedModel.isEmpty
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "car.side")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Text("Vehicle icon")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(AppConfig.subtleGray)
                                }

                                Button {
                                    Haptics.selection()
                                    showVehiclePresetSheet = true
                                } label: {
                                    iconPickerRow(
                                        title: lang.language == .czech ? "Ikona" : "Icon",
                                        value: selectedVehiclePreset?.title ?? "Choose Icon",
                                        isPlaceholder: selectedVehiclePreset == nil
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }

                            VehicleMiniatureView(
                                carType: carType,
                                colorHex: selectedColor,
                                description: car,
                                presetID: selectedPresetID.isEmpty ? nil : selectedPresetID
                            )
                            .frame(width: 148, height: 82)
                            .frame(maxWidth: .infinity, alignment: .center)

                            DisclosureGroup(isExpanded: $showVehicleColorPicker) {
                                colorGridWithCustom(selected: $selectedColor)
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
                                    colorNameLabel(for: selectedColor)
                                }
                            }
                            .tint(AppConfig.darkText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .appGlassField()
                        }
                    }

                    // Password card — mandatory, must be confirmed
                    sectionCard(title: L10n.setNewPassword, icon: "lock.fill") {
                        VStack(spacing: 12) {
                            pwdRow(placeholder: L10n.setNewPassword,
                                   text: $newPassword, showSecure: $showPassword,
                                   focusField: .newPassword, submitLabel: .next,
                                   onSubmit: { focusedField = .confirmPassword })

                            pwdRow(placeholder: L10n.confirmPasswordLabel,
                                   text: $confirmPassword, showSecure: $showConfirmPwd,
                                   focusField: .confirmPassword, submitLabel: .go,
                                   onSubmit: { if isFormValid { submitRegistration() } })

                            // Inline hints
                            if !newPassword.isEmpty && newPassword.count < 6 {
                                Label(L10n.passwordTooShortHint, systemImage: "exclamationmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(AppConfig.warning)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            } else if !confirmPassword.isEmpty && newPassword != confirmPassword {
                                Label(L10n.passwordsDoNotMatch, systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppConfig.spotOccupied)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            } else if newPassword.count >= 6 && newPassword == confirmPassword {
                                Label(isCzech ? "Hesla se shodují" : "Passwords match",
                                      systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppConfig.activeGreen)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.quick, value: newPassword)
                        .animation(.quick, value: confirmPassword)
                    }

                    // Error
                    if let err = errorMsg {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(AppConfig.danger)
                            Text(err).font(.subheadline).foregroundStyle(AppConfig.danger)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    // CTA
                    Button { submitRegistration() } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isFormValid ? AppConfig.accent : AppConfig.accent.opacity(0.4))
                            if isLoading {
                                ProgressView().tint(.black).scaleEffect(0.9)
                            } else {
                                Text(L10n.completeRegistration)
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(height: 54)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 48)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .sheet(isPresented: $showVehiclePresetSheet) {
                VehicleMiniaturePresetPickerSheet(
                    title: "Choose Vehicle Icon",
                    selectedColorHex: selectedColor,
                    selectedPresetID: selectedVehiclePreset?.id,
                    selectedMake: selectedMake,
                    selectedModel: selectedModel
                ) { preset in
                    selectedPresetID = preset.id
                    car = preset.searchDescription
                    carType = ""
                    syncMakeModelFromCar()
                }
            }
            .onAppear {
                if plate.isEmpty { plate = user.registrationPlate }
                if car.isEmpty { car = user.carDescription }
                if carType.isEmpty { carType = user.carType }
                if AppConfig.carColors.contains(where: { $0.hex == user.carColor }) {
                    selectedColor = user.carColor
                }
                syncMakeModelFromCar()
            }
        }
    }

    // MARK: - Logic

    private var isFormValid: Bool {
        !plate.trimmingCharacters(in: .whitespaces).isEmpty &&
        !car.trimmingCharacters(in: .whitespaces).isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }

    private var isCzech: Bool { LanguageManager.shared.language == .czech }

    private func submitRegistration() {
        isLoading = true
        errorMsg  = nil
        Task {
            await authManager.finishRegistration(
                plate:       plate,
                car:         car,
                color:       selectedColor,
                carType:     carType,
                vehicleMiniaturePresetID: selectedPresetID,
                newPassword: newPassword
            )
            await MainActor.run {
                isLoading = false
                errorMsg = authManager.errorMessage
                if errorMsg == nil {
                    Haptics.notify(.success)
                } else {
                    Haptics.notify(.error)
                }
            }
        }
    }

    // MARK: - Shared Vehicle Sub-views

    @ViewBuilder
    private func bodyTypeChips(selected: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CarBodyType.allCases) { bodyType in
                    let isSelected = selected.wrappedValue == bodyType.rawValue
                    Button {
                        Haptics.selection()
                        withAnimation(.quick) {
                            selected.wrappedValue = isSelected ? "" : bodyType.rawValue
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: bodyType.icon)
                                .font(.caption.weight(.semibold))
                            Text(bodyType.label)
                                .font(.footnote.weight(.semibold))
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

    private func makeModelPickerRow(
        icon: String,
        title: String,
        value: String,
        isPlaceholder: Bool,
        makerLogo: String? = nil
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 24)
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
        .appGlassField()
    }

    private func iconPickerRow(
        title: String,
        value: String,
        isPlaceholder: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 24)
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
        .appGlassField()
    }

    private func syncMakeModelFromCar() {
        let parsed = CarData.splitMakeModel(car)
        selectedMake = parsed.make
        selectedModel = parsed.model
    }

    @ViewBuilder
    private func colorGridWithCustom(selected: Binding<String>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 8) {
            ForEach(AppConfig.carColors, id: \.hex) { color in
                let isSelected = selected.wrappedValue == color.hex
                Button {
                    withAnimation(.quick) { selected.wrappedValue = color.hex }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: color.hex))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle().stroke(
                                    isSelected ? AppConfig.accentFg : Color.white.opacity(0.15),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                            )
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    color.hex == "#FFFFFF" || color.hex == "#F9A825" ? Color.black : Color.white
                                )
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }

        }
    }

    @ViewBuilder
    private func colorNameLabel(for hex: String) -> some View {
        if let match = AppConfig.carColors.first(where: { $0.hex == hex }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(match.name)
                    .font(.caption)
                    .foregroundStyle(AppConfig.subtleGray)
            }
        }
    }

    // MARK: - Input Components

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                content()
            }
            .padding(20)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .cardShadow()
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func inputRow(icon: String, placeholder: String, text: Binding<String>,
                          capitalization: TextInputAutocapitalization = .sentences,
                          focusField: Field? = nil,
                          submitLabel: SubmitLabel = .return,
                          onSubmit: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 20)
            if let field = focusField {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppConfig.darkText)
                    .focused($focusedField, equals: field)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppConfig.darkText)
            }
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .appGlassField()
    }

    @ViewBuilder
    private func pwdRow(placeholder: String, text: Binding<String>, showSecure: Binding<Bool>,
                        focusField: Field? = nil,
                        submitLabel: SubmitLabel = .return,
                        onSubmit: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 20)
            if showSecure.wrappedValue {
                if let field = focusField {
                    TextField(placeholder, text: text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(AppConfig.darkText)
                        .focused($focusedField, equals: field)
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
                } else {
                    TextField(placeholder, text: text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(AppConfig.darkText)
                }
            } else {
                if let field = focusField {
                    SecureField(placeholder, text: text)
                        .foregroundStyle(AppConfig.darkText)
                        .focused($focusedField, equals: field)
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
                } else {
                    SecureField(placeholder, text: text)
                        .foregroundStyle(AppConfig.darkText)
                }
            }
            Button { showSecure.wrappedValue.toggle() } label: {
                Image(systemName: showSecure.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(AppConfig.subtleGray)
                    .font(.subheadline)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .appGlassField()
    }
}
