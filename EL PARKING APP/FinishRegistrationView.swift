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
    @State private var pickerColor    = Color.red
    @State private var carSuggestions: [String] = []
    @State private var newPassword      = ""
    @State private var confirmPassword  = ""
    @State private var showPassword     = false
    @State private var showConfirmPwd   = false
    @State private var isLoading        = false
    @State private var errorMsg: String? = nil

    private enum Field: Hashable { case plate, car, newPassword, confirmPassword }
    @FocusState private var focusedField: Field?

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
                                     onSubmit: { focusedField = .car })

                            // Car make + model with suggestions
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 12) {
                                    Image(systemName: "car.side")
                                        .foregroundStyle(AppConfig.subtleGray)
                                        .frame(width: 20)
                                    TextField(L10n.carInputPlaceholder, text: $car)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled()
                                        .foregroundStyle(AppConfig.darkText)
                                        .focused($focusedField, equals: .car)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .newPassword }
                                        .onChange(of: car) { _, val in
                                            withAnimation(.quick) {
                                                carSuggestions = CarData.filter(val)
                                            }
                                        }
                                }
                                .padding(14)
                                .appGlassField()

                                if !carSuggestions.isEmpty {
                                    suggestionsDropdown(suggestions: carSuggestions) { pick in
                                        car = pick
                                        carSuggestions = []
                                    }
                                    .padding(.top, 4)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .animation(.quick, value: carSuggestions.isEmpty)

                            // Body type chips
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "car.2")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Text(L10n.carBodyType.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundStyle(AppConfig.subtleGray)
                                }
                                bodyTypeChips(selected: $carType)
                            }

                            VehicleMiniatureView(
                                carType: carType,
                                colorHex: selectedColor,
                                description: car
                            )
                            .frame(width: 82, height: 46)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 2)

                            // Color picker
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "paintpalette")
                                        .foregroundStyle(AppConfig.subtleGray)
                                        .frame(width: 20)
                                    Text(L10n.carColor)
                                        .font(.subheadline)
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Spacer()
                                    colorNameLabel(for: selectedColor)
                                }
                                colorGridWithCustom(selected: $selectedColor, pickerColor: $pickerColor)
                            }
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

    @ViewBuilder
    private func suggestionsDropdown(suggestions: [String], onSelect: @escaping (String) -> Void) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, suggestion in
                Button {
                    withAnimation(.quick) { onSelect(suggestion) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(AppConfig.subtleGray)
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(AppConfig.darkText)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(ScaleButtonStyle())
                if idx < suggestions.count - 1 {
                    Divider().padding(.horizontal, 14)
                }
            }
        }
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    @ViewBuilder
    private func colorGridWithCustom(selected: Binding<String>, pickerColor: Binding<Color>) -> some View {
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

            VehicleCustomColorButton(
                selectedHex: selected,
                pickerColor: pickerColor,
                size: 38,
                checkmarkSize: 11,
                plusSize: 16
            )
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
        } else if !hex.isEmpty {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(L10n.carColorCustom)
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
