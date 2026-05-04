//
//  ContentView.swift
//  EL PARKING APP
//
//  Created by Stiv Malakjan on 26.03.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                loadingView

            case .unauthenticated:
                LoginView()

            case .pendingApproval:
                PendingApprovalView()

            case .needsFinishRegistration(let user):
                FinishRegistrationView(user: user)

            case .authenticated(let user):
                AuthenticatedRootView(user: user)
            }
        }
        .animation(.quick, value: authStateKey)
    }

    private var authStateKey: String {
        switch authManager.authState {
        case .loading:
            return "loading"
        case .unauthenticated:
            return "unauthenticated"
        case .pendingApproval:
            return "pendingApproval"
        case .needsFinishRegistration(let user):
            return "needsFinishRegistration-\(user.uid)"
        case .authenticated(let user):
            return "authenticated-\(user.uid)-\(user.role.rawValue)"
        }
    }

    private var loadingView: some View {
        ZStack {
            AppConfig.pageBg.ignoresSafeArea()
            ProgressView()
                .tint(AppConfig.accentFg)
                .scaleEffect(1.15)
        }
    }
}

private enum AppTab: Hashable {
    case home
    case parking
    case admin
    case settings
}

private struct AuthenticatedRootView: View {
    let user: AppUser

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var bookingManager: BookingManager
    @EnvironmentObject private var deepLinkManager: DeepLinkManager

    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(L10n.home, systemImage: "house.fill")
                }
                .tag(AppTab.home)

            OverviewView()
                .tabItem {
                    Label(L10n.parking, systemImage: "square.grid.3x3.fill")
                }
                .tag(AppTab.parking)

            if user.isAdmin {
                AdminDashboardView()
                    .tabItem {
                        Label(L10n.admin, systemImage: "shield.fill")
                    }
                    .badge(authManager.pendingCount)
                    .tag(AppTab.admin)
            }

            SettingsView()
                .tabItem {
                    Label(L10n.settings, systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(AppConfig.accentFg)
        .onReceive(deepLinkManager.$pendingRoute) { route in
            routePendingTab(route)
        }
        .onChange(of: user.isAdmin) { _, isAdmin in
            if !isAdmin && selectedTab == .admin {
                selectedTab = .home
            }
        }
        .onAppear {
            if user.isActive {
                bookingManager.configureForUser(
                    email: user.email,
                    name: user.displayName,
                    uid: user.uid,
                    role: user.role,
                    plate: user.registrationPlate,
                    car: user.carDescription,
                    color: user.carColor,
                    carType: user.carType
                )
            }
        }
    }

    private func routePendingTab(_ route: DeepLinkRoute?) {
        guard let route else { return }
        switch route {
        case .adminDashboard:
            if user.isAdmin {
                selectedTab = .admin
                deepLinkManager.clear()
            }
        case .book, .edit, .cancel, .myBookings, .navigate:
            selectedTab = .home
        }
    }
}
