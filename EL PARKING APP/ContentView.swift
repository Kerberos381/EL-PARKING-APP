//
//  ContentView.swift
//  EL PARKING APP
//
//  Auth gate: shows LoginView, PendingApprovalView, or the main TabView.
//  Biometric lock gate when Face ID / Touch ID is enabled.
//  Prompts user to enable Face ID on very first login.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var authManager:   AuthManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject var langManager:   LanguageManager
    @ObservedObject private var lang = LanguageManager.shared

    @AppStorage("biometricLockEnabled")  private var biometricEnabled     = false
    @AppStorage("hasAskedBiometrics")    private var hasAskedBiometrics   = false
    @AppStorage("lastSeenVersion")       private var lastSeenVersion      = ""
    @AppStorage("hasSeenOnboarding")     private var hasSeenOnboarding    = false
    @State private var biometricUnlocked     = false
    @State private var showBiometricPrompt   = false
    @State private var backgroundedAt: Date? = nil
    @State private var showWhatsNew          = false
    @State private var showOnboarding        = false
    @State private var whatsNewRelease: AppRelease? = nil
    @State private var selectedTab: MainTab = .home
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                splashView

            case .unauthenticated:
                LoginView()

            case .pendingApproval:
                PendingApprovalView()

            case .needsFinishRegistration(let user):
                FinishRegistrationView(user: user)
                    .environmentObject(authManager)

            case .authenticated:
                if biometricEnabled && !biometricUnlocked {
                    BiometricLockView(isUnlocked: $biometricUnlocked)
                } else {
                    mainTabView
                }
            }
        }
        .animation(.standard, value: stateKey)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if biometricEnabled { backgroundedAt = Date() }
            case .active:
                if biometricEnabled, let t = backgroundedAt,
                   Date().timeIntervalSince(t) > 30 {
                    biometricUnlocked = false
                }
                backgroundedAt = nil
            default: break
            }
        }
        .onChange(of: authManager.authState) { oldState, newState in
            if case .unauthenticated = newState, case .authenticated = oldState {
                hasAskedBiometrics = false
            }
            if case .authenticated = newState {
                if !hasAskedBiometrics,
                   KeychainManager.shared.canUseBiometrics,
                   KeychainManager.shared.hasSavedCredentials {
                    hasAskedBiometrics = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showBiometricPrompt = true
                    }
                }
                if !hasSeenOnboarding {
                    hasSeenOnboarding = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showOnboarding = true
                    }
                } else {
                    checkWhatsNew()
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showWhatsNew) {
            if let release = whatsNewRelease {
                WhatsNewView(release: release)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .alert(L10n.useBiometricPrompt(KeychainManager.shared.biometricName), isPresented: $showBiometricPrompt) {
            Button(L10n.enableBiometricBtn(KeychainManager.shared.biometricName)) {
                biometricEnabled  = true
                biometricUnlocked = true
            }
            Button(L10n.notNow, role: .cancel) {}
        } message: {
            Text(L10n.signInInstantly(KeychainManager.shared.biometricName))
        }
    }

    // MARK: - Main App

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.home, systemImage: "house", value: MainTab.home) {
                HomeView()
            }

            Tab(L10n.parking, systemImage: "square.grid.3x3", value: MainTab.parking) {
                OverviewView()
            }

            if bookingManager.isAdmin {
                Tab(L10n.admin, systemImage: "shield.lefthalf.filled", value: MainTab.admin) {
                    AdminDashboardView()
                }
                .badge(authManager.pendingCount > 0 ? authManager.pendingCount : 0)
            }

            Tab(L10n.settings, systemImage: "gearshape", value: MainTab.settings) {
                SettingsView()
            }

        }
        .tint(AppConfig.accentFg)
        .tabBarMinimizeBehavior(.onScrollDown)
        .withToastOverlay()
        .onChange(of: deepLinkManager.pendingRoute) { _, route in
            guard let route else { return }
            switch route {
            case .adminDashboard:
                if bookingManager.isAdmin {
                    selectedTab = .admin
                } else {
                    selectedTab = .home
                }
                deepLinkManager.clear()
            default:
                selectedTab = .home
            }
        }
    }

    // MARK: - Splash

    private var splashView: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.055)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: AppConfig.accent.opacity(0.4), radius: 24, y: 0)

                ProgressView()
                    .tint(AppConfig.accentFg)
                    .scaleEffect(0.85)
            }
        }
    }

    // MARK: - State Key for Animation

    private var stateKey: String {
        switch authManager.authState {
        case .loading:                   return "loading"
        case .unauthenticated:           return "unauth"
        case .pendingApproval:           return "pending"
        case .needsFinishRegistration:   return "finishReg"
        case .authenticated:             return biometricUnlocked ? "auth" : "locked"
        }
    }

    // MARK: - What's New

    private func checkWhatsNew() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard currentVersion != lastSeenVersion else { return }
        lastSeenVersion = currentVersion

        guard let release = AppReleaseNotes.forCurrentVersion else { return }
        whatsNewRelease = release
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showWhatsNew = true
        }
    }
}

private enum MainTab: Hashable {
    case home
    case parking
    case admin
    case settings
}

#Preview {
    ContentView()
        .environmentObject(BookingManager())
        .environmentObject(AuthManager())
        .environmentObject(DeepLinkManager())
        .environmentObject(LanguageManager.shared)
}
