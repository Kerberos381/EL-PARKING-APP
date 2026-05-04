//
//  ThemeManager.swift
//  EL PARKING APP
//
//  Manages app appearance (light/dark/system). Uses @AppStorage for persistence.
//

import SwiftUI

enum AppTheme: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// Cycles to the next theme
    var next: AppTheme {
        switch self {
        case .system: return .light
        case .light:  return .dark
        case .dark:   return .system
        }
    }
}

// MARK: - Theme Toggle Button (top-right corner)
// Quick toggle: light ↔ dark. The 3-option picker (System/Light/Dark) lives in Settings.

struct ThemeToggleButton: View {
    @AppStorage("appTheme") private var themeRaw: Int = 0
    @Environment(\.colorScheme) private var currentScheme

    private var isDark: Bool {
        currentScheme == .dark
    }

    var body: some View {
        Button {
            Haptics.selection()
            withAnimation(.standard) {
                themeRaw = isDark ? AppTheme.light.rawValue : AppTheme.dark.rawValue
            }
        } label: {
            Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
                .frame(width: 36, height: 36)
                .background(AppConfig.surfaceLow)
                .clipShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
