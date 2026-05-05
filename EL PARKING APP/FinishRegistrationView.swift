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
        VehicleMiniaturePreset.matching(description: car, carType: carType)
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
                                        Button(make) {
                                            selectedMake = make
                                            selectedModel = ""
                                            car = make
                                        }
                                    }
                                } label: {
                                    makeModelPickerRow(
                                        icon: "building.2.crop.circle",
                                        title: lang.language == .czech ? "Značka" : "Make",
                                        value: selectedMake.isEmpty ? (lang.language == .czech ? "Vyberte značku" : "Choose make") : selectedMake,
                                        isPlaceholder: selectedMake.isEmpty
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
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Text("VEHICLE ICON")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.1)
                                        .foregroundStyle(AppConfig.subtleGray)
                                }

                                Button {
                                    Haptics.selection()
                                    showVehiclePresetSheet = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppConfig.subtleGray)
                                        Text(selectedVehiclePreset?.title ?? "Choose Icon")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(AppConfig.darkText)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppConfig.subtleGray)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(AppConfig.surfaceLow)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }

                            VehicleMiniatureView(
                                carType: carType,
                                colorHex: selectedColor,
                                description: car
                            )
                            .frame(width: 118, height: 64)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(AppConfig.surfaceLow)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            DisclosureGroup(isExpanded: $showVehicleColorPicker) {
                                colorGridWithCustom(selected: $selectedColor)
                                    .padding(.top, 8)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "paintpalette")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Text(L10n.carColor)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppConfig.darkText)
                                    Spacer()
                                    colorNameLabel(for: selectedColor)
                                }
                            }
                            .tint(AppConfig.darkText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppConfig.surfaceLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                    .foregroundStyle(.orange)
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
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            Text(err).font(.subheadline).foregroundStyle(.red)
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
                                    .font(.system(size: 16, weight: .bold))
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
                    selectedPresetID: selectedVehiclePreset?.id
                ) { preset in
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

    private func makeModelPickerRow(icon: String, title: String, value: String, isPlaceholder: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 20)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(isPlaceholder ? AppConfig.subtleGray : AppConfig.darkText)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
        }
        .padding(14)
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
                                .font(.system(size: 11, weight: .bold))
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                content()
            }
            .padding(20)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
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
                    .font(.system(size: 15))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .appGlassField()
    }
}
