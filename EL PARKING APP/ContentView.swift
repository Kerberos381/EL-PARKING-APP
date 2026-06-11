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
    @AppStorage("hasSeenFirstLaunchIntro") private var hasSeenFirstLaunchIntro = false
    @State private var biometricUnlocked     = true
    @State private var showBiometricPrompt   = false
    @State private var backgroundedAt: Date? = nil
    @State private var showWhatsNew          = false
    @State private var showFirstLaunchIntro  = false
    @State private var showOnboarding        = false
    @State private var whatsNewRelease: AppRelease? = nil
    @State private var didRunPostLoginFlow   = false
    @State private var selectedTab: MainTab = .home
    @State private var lastNonLoadingState: AuthState = .unauthenticated
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var launchTransition: Animation {
        reduceMotion ? .linear(duration: 0.25) : .smooth(duration: 0.55)
    }

    var body: some View {
        ZStack {
            authContent(for: stageState)
                .scaleEffect(authManager.authState == .loading ? 0.96 : 1.0)

            if authManager.authState == .loading {
                SplashView()
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 1.06))
                        )
                    )
            }
        }
        .animation(launchTransition, value: authManager.authState)
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
                biometricUnlocked = false
                didRunPostLoginFlow = false
            }
            if case .loading = newState {
                // Keep the previously rendered state beneath splash to avoid launch blink.
            } else {
                lastNonLoadingState = newState
            }
            if case .authenticated = newState {
                guard !didRunPostLoginFlow else { return }
                didRunPostLoginFlow = true
                // Avoid showing a confusing biometric lock screen immediately after
                // successful credential sign-in. Keep re-lock behavior on background timeout.
                biometricUnlocked = true
                if !hasAskedBiometrics,
                   KeychainManager.shared.canUseBiometrics,
                   KeychainManager.shared.hasSavedCredentials {
                    hasAskedBiometrics = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showBiometricPrompt = true
                    }
                }
                if !hasSeenFirstLaunchIntro {
                    hasSeenFirstLaunchIntro = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showFirstLaunchIntro = true
                    }
                } else if !hasSeenOnboarding {
                    hasSeenOnboarding = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showOnboarding = true
                    }
                } else {
                    checkWhatsNew()
                }
            }
        }
        .sheet(isPresented: $showFirstLaunchIntro, onDismiss: {
            if !hasSeenOnboarding {
                hasSeenOnboarding = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showOnboarding = true
                }
            } else {
                checkWhatsNew()
            }
        }) {
            WhatsNewView(release: AppReleaseNotes.firstLaunchIntro)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
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
        .onAppear {
            // Existing users who have already seen onboarding should not be forced
            // into the first-launch intro on upgrade.
            if hasSeenOnboarding && !hasSeenFirstLaunchIntro {
                hasSeenFirstLaunchIntro = true
            }
        }
    }

    // MARK: - Main App

    private var stageState: AuthState {
        if case .loading = authManager.authState {
            if let user = authManager.currentUser {
                if user.needsFinishRegistration { return .needsFinishRegistration(user) }
                return user.isActive ? .authenticated(user) : .pendingApproval
            }
            return lastNonLoadingState
        }
        return authManager.authState
    }

    @ViewBuilder
    private func authContent(for state: AuthState) -> some View {
        switch state {
        case .loading:
            LoginView()
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

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.home, systemImage: "house", value: MainTab.home) {
                HomeView(screenMode: .home)
            }

            Tab(L10n.parking, systemImage: "square.grid.3x3", value: MainTab.parking) {
                OverviewView()
            }

            Tab("Info", systemImage: "newspaper", value: MainTab.info) {
                HomeView(screenMode: .infoHub)
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
        .tint(AppConfig.darkText)
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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSettingsTab)) { _ in
            selectedTab = .settings
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
    case info
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
