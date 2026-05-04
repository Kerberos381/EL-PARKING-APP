//
//  VehicleCustomColorButton.swift
//  EL PARKING APP
//
//  Explicit custom vehicle color picker. Avoids relying on an invisible
//  ColorPicker overlay, which can fail to open on device.
//

import SwiftUI

struct VehicleCustomColorButton: View {
    @Binding var selectedHex: String
    @Binding var pickerColor: Color

    var size: CGFloat
    var selectedStrokeWidth: CGFloat = 2.5
    var checkmarkSize: CGFloat = 10
    var plusSize: CGFloat = 15
    var unselectedStroke: Color = Color.white.opacity(0.15)

    @State private var showingPicker = false

    private var isCustomSelected: Bool {
        guard let normalized = selectedHex.normalizedHexColor else { return false }
        return !AppConfig.carColors.map(\.hex).contains(normalized)
    }

    var body: some View {
        Button {
            if isCustomSelected {
                pickerColor = Color(hex: selectedHex.normalizedHexColor ?? selectedHex)
            }
            showingPicker = true
        } label: {
            swatch
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                VStack(spacing: 22) {
                    Text(L10n.carColorCustom)
                        .font(.headline)
                        .foregroundStyle(AppConfig.darkText)
                        .padding(.top, 8)

                    ColorPicker(L10n.carColor, selection: $pickerColor, supportsOpacity: false)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(AppConfig.surfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)

                    VStack(spacing: 10) {
                        Circle()
                            .fill(pickerColor)
                            .frame(width: 72, height: 72)
                            .overlay(Circle().stroke(AppConfig.separatorSoft, lineWidth: 1))
                        Text(pickerColor.hexString(fallback: selectedHex))
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                    }

                    Spacer()
                }
                .background(AppConfig.pageBg.ignoresSafeArea())
                .navigationTitle(L10n.carColor)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.done) {
                            selectedHex = pickerColor.hexString(fallback: selectedHex)
                            showingPicker = false
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConfig.accentFg)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.cancel) {
                            showingPicker = false
                        }
                        .foregroundStyle(AppConfig.subtleGray)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var swatch: some View {
        ZStack {
            if isCustomSelected {
                Circle()
                    .fill(Color(hex: selectedHex.normalizedHexColor ?? selectedHex))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(AppConfig.accentFg, lineWidth: selectedStrokeWidth))
                Image(systemName: "checkmark")
                    .font(.system(size: checkmarkSize, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                        center: .center
                    ))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(unselectedStroke, lineWidth: 1))
                Text("+")
                    .font(.system(size: plusSize, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .accessibilityLabel(L10n.carColorCustom)
    }
}
