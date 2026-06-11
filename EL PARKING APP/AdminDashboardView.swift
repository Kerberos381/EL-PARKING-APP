//
//  AdminDashboardView.swift
//  EL PARKING APP
//
//  Root view for the admin-only tab.
//  Contains user management and a placeholder for future admin sections.
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var authManager:           AuthManager
    @EnvironmentObject var bookingManager:        BookingManager
    @EnvironmentObject var announcementsManager:  AnnouncementsManager
    @EnvironmentObject var infoManager:           InfoManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var lang = LanguageManager.shared

    @State private var showCreateUser      = false
    @State private var showBulkImport      = false
    @State private var lastRefreshed       = Date()
    @State private var activationsVisible  = false
    @State private var quickFilterRoute: QuickFilterRoute?
    @State private var didPrefetchAdminData = false
    @State private var showPurgeConfirm     = false
    @State private var purgeResult: Int?
    @State private var isPurging            = false

    private enum QuickFilterRoute: String, Identifiable {
        case active
        case pending
        case suspended

        var id: String { rawValue }

        var userStatus: UserStatus {
            switch self {
            case .active: return .active
            case .pending: return .pending
            case .suspended: return .suspended
            }
        }
    }

    /// Calm palette: all tiles become forest ink so color stays scarce.
    private func tileColor(_ standard: Color) -> Color {
        AppConfig.isCalmPalette ? AppConfig.obsidian : standard
    }

    private var userCounts: (total: Int, pending: Int, active: Int, suspended: Int, awaitingSetup: Int) {
        authManager.allUsers.reduce(into: (0, 0, 0, 0, 0)) { result, user in
            result.total += 1
            if user.isPending { result.pending += 1 }
            if user.isActive { result.active += 1 }
            if user.isSuspended { result.suspended += 1 }
            if user.needsFinishRegistration { result.awaitingSetup += 1 }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.groupedPageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Pending alert banner ──────────────────────────────
                        if userCounts.pending > 0 {
                            pendingAlertBanner
                        }

                        // ── Quick stats ──────────────────────────────────────
                        statsGroupedCard

                        // ── Users section ─────────────────────────────────────
                        groupedSection(header: L10n.adminSectionUsers) {
                            NavigationLink {
                                AdminUsersView()
                                    .environmentObject(authManager)
                                    .environmentObject(bookingManager)
                            } label: {
                                rowLabel(icon: "person.2.fill",
                                         iconColor: tileColor(.blue),
                                         title: L10n.userManagement,
                                         subtitle: L10n.adminRowUsers,
                                         badge: userCounts.pending)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            Divider().padding(.leading, 56)
                            Button { showCreateUser = true } label: {
                                rowLabel(icon: "person.badge.plus",
                                         iconColor: tileColor(AppConfig.darkText),
                                         iconForeground: AppConfig.isCalmPalette ? .white : .black,
                                         title: L10n.adminCreateUser,
                                         subtitle: L10n.adminRowNewUser,
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            Divider().padding(.leading, 56)
                            Button { showBulkImport = true } label: {
                                rowLabel(icon: "tray.and.arrow.down.fill",
                                         iconColor: tileColor(.cyan),
                                         title: L10n.bulkImport,
                                         subtitle: L10n.adminRowCSVImport,
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // ── Content section ────────────────────────────────────
                        groupedSection(header: L10n.adminSectionContent) {
                            NavigationLink {
                                AdminSpotsView()
                                    .environmentObject(bookingManager)
                            } label: {
                                rowLabel(icon: "parkingsign.circle.fill",
                                         iconColor: tileColor(AppConfig.warning),
                                         title: L10n.spotManagement,
                                         subtitle: L10n.adminRowSpots,
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            Divider().padding(.leading, 56)
                            NavigationLink {
                                AdminAnnouncementsView()
                                    .environmentObject(authManager)
                                    .environmentObject(announcementsManager)
                            } label: {
                                rowLabel(icon: "megaphone.fill",
                                         iconColor: tileColor(.pink),
                                         title: L10n.announcements,
                                         subtitle: L10n.adminRowPosts,
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            Divider().padding(.leading, 56)
                            NavigationLink {
                                AdminInfoView()
                                    .environmentObject(infoManager)
                            } label: {
                                rowLabel(icon: "info.circle.fill",
                                         iconColor: tileColor(.purple),
                                         title: L10n.infoCards,
                                         subtitle: L10n.adminRowCards,
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // ── Analytics section ──────────────────────────────────
                        groupedSection(header: L10n.adminSectionAnalytics) {
                            NavigationLink {
                                AdminStatsView()
                                    .environmentObject(bookingManager)
                            } label: {
                                rowLabel(icon: "chart.bar.fill",
                                         iconColor: tileColor(.red),
                                         title: L10n.bookingStatistics,
                                         subtitle: L10n.adminRowTrends,
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // ── Maintenance section ───────────────────────────────
                        groupedSection(header: L10n.adminSectionMaintenance) {
                            Button {
                                Haptics.selection()
                                showPurgeConfirm = true
                            } label: {
                                rowLabel(icon: "trash.slash.fill",
                                         iconColor: tileColor(AppConfig.warning),
                                         title: "Purge Orphaned Bookings",
                                         subtitle: isPurging ? L10n.adminPurgeDeleting : L10n.adminRowCleanup,
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // ── Recent Activations ────────────────────────────────
                        recentActivationsSection

                        // ── Last refreshed footer ────────────────────────────
                        lastRefreshedFooter

                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .refreshable {
                    await refreshDashboard()
                    Haptics.refreshCompleted()
                }
            }
            .navigationTitle(L10n.dashboard)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCreateUser) {
                AdminCreateUserView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showBulkImport) {
                AdminBulkImportView()
                    .environmentObject(authManager)
            }
            .navigationDestination(item: $quickFilterRoute) { route in
                AdminUsersView(initialFilter: route.userStatus)
                    .environmentObject(authManager)
                    .environmentObject(bookingManager)
            }
            .alert("Purge Orphaned Bookings", isPresented: $showPurgeConfirm) {
                Button("Purge", role: .destructive) {
                    isPurging = true
                    purgeResult = nil
                    Task {
                        let count = await bookingManager.purgeOrphanedBookings()
                        isPurging = false
                        purgeResult = count
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all booking documents that fail to parse (empty email, missing fields, etc.).")
            }
        }
        .onAppear {
            if !didPrefetchAdminData {
                didPrefetchAdminData = true
                Task(priority: .utility) { await refreshDashboard() }
            }
        }
    }

    // MARK: - Recent Activations

    private var recentActivatedUsers: [AppUser] {
        authManager.allUsers
            .filter { $0.activatedAt != nil && !$0.needsFinishRegistration }
            .sorted { ($0.activatedAt ?? .distantPast) > ($1.activatedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    private var recentActivationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                Text(L10n.recentActivations)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .padding(.horizontal, 4)

            if authManager.isLoading && recentActivatedUsers.isEmpty {
                recentActivationsSkeleton
            } else if recentActivatedUsers.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.slash")
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
                    Text(L10n.noRecentActivations)
                        .font(.subheadline)
                        .foregroundStyle(AppConfig.subtleGray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppConfig.groupedCardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentActivatedUsers.enumerated()), id: \.element.uid) { idx, user in
                        HStack(spacing: 12) {
                            UserAvatarView(user: user, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(AppConfig.darkText)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(AppConfig.subtleGray)
                            }
                            Spacer()
                            if let date = user.activatedAt {
                                Text(date.formatted(.relative(presentation: .named)))
                                    .font(.caption2)
                                    .foregroundStyle(AppConfig.subtleGray)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .opacity(activationsVisible ? 1 : 0)
                        .offset(y: activationsVisible ? 0 : 6)
                        .animation(
                            reduceMotion ? .none : .easeOut(duration: 0.3).delay(Double(idx) * 0.04),
                            value: activationsVisible
                        )

                        if idx < recentActivatedUsers.count - 1 {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
                .background(AppConfig.groupedCardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous))
                .onAppear  { activationsVisible = true  }
                .onDisappear { activationsVisible = false }
            }
        }
    }

    private var recentActivationsSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { idx in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppConfig.tertiaryFillBg)
                        .frame(width: 38, height: 38)
                        .shimmering(active: true)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(height: 13, cornerRadius: 6)
                            .frame(maxWidth: 110, alignment: .leading)
                        SkeletonBlock(height: 11, cornerRadius: 6)
                            .frame(maxWidth: 170, alignment: .leading)
                    }
                    Spacer()
                    SkeletonBlock(height: 11, cornerRadius: 6)
                        .frame(width: 56)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if idx < 2 {
                    Divider().padding(.leading, 66)
                }
            }
        }
        .background(AppConfig.groupedCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous))
    }

    // MARK: - Last refreshed footer

    private var lastRefreshedFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.clockwise")
                .font(.caption2.weight(.semibold))
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                Text(L10n.lastRefreshed(lastRefreshed.formatted(.relative(presentation: .named))))
            }
            .font(.caption.weight(.medium))
        }
        .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Stats Cards

    private var statsGroupedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.adminSectionOverview)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .padding(.horizontal, 4)

            // Equal-width glass stat cards, matching the Overview screen's
            // filter pills. One tap goes straight to the filtered user list.
            GlassEffectContainer {
                HStack(spacing: 8) {
                    quickStatCard(value: userCounts.pending,
                                  label: L10n.pending,
                                  color: AppConfig.warning,
                                  filter: .pending)
                    quickStatCard(value: userCounts.active,
                                  label: L10n.activeFilter,
                                  color: AppConfig.activeGreen,
                                  filter: .active)
                    quickStatCard(value: userCounts.suspended,
                                  label: L10n.suspended,
                                  color: AppConfig.spotOccupied,
                                  filter: .suspended)
                }
            }
        }
    }

    private func routeForFilter(_ filter: UserStatus) -> QuickFilterRoute {
        switch filter {
        case .active: return .active
        case .pending: return .pending
        case .suspended: return .suspended
        }
    }

    private func quickStatCard(
        value: Int,
        label: String,
        color: Color,
        filter: UserStatus
    ) -> some View {
        Button {
            Haptics.selection()
            quickFilterRoute = routeForFilter(filter)
        } label: {
            VStack(spacing: 3) {
                Text("\(value)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(.frosted.interactive(), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityHint("Opens users filtered by \(label.lowercased()) status")
    }

    // MARK: - Pending Alert Banner

    private var pendingAlertBanner: some View {
        NavigationLink {
            AdminUsersView()
                .environmentObject(authManager)
                .environmentObject(bookingManager)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppConfig.warning.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.badge.clock.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppConfig.warning)
                        .symbolEffect(.breathe, options: .repeating, isActive: !reduceMotion)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(userCounts.pending) \(L10n.pending)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.warning)
                    Text(pendingSubtitle)
                        .font(.caption)
                        .foregroundStyle(AppConfig.warning.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.warning.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .background(AppConfig.groupedCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous)
                    .stroke(AppConfig.warning.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityHint("Opens pending user approvals")
    }

    // MARK: - Grouped Section

    private func groupedSection<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(header)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .padding(.horizontal, 8)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(AppConfig.groupedCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .containerShape(.rect(cornerRadius: 16))
        }
        .feedCardScrollTransition()
    }

    private func rowLabel(
        icon: String,
        iconColor: Color,
        iconForeground: Color = .white,
        title: String,
        subtitle: String,
        badge: Int
    ) -> some View {
        HStack(spacing: 12) {
            appleSettingsIcon(icon: icon, tint: iconColor, iconForeground: iconForeground)
                .frame(width: 28, height: 28, alignment: .center)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.darkText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)
            Spacer()
            if badge > 0 {
                Text(badge > 9 ? "9+" : "\(badge)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppConfig.warning)
                    .clipShape(Capsule())
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? .none : .motionConfirm, value: badge)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppConfig.subtleGray)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    private func appleSettingsIcon(
        icon: String,
        tint: Color,
        iconForeground: Color = .white,
        size: CGFloat = 28,
        iconSize: CGFloat = 13
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(tint)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconForeground)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Helpers

    private var pendingSubtitle: String {
        L10n.adminPendingSubtitle(total: userCounts.total, pending: userCounts.pending)
    }

    private func refreshDashboard() async {
        async let usersRefresh: Void = authManager.fetchAllUsers()
        async let bookingsRefresh: Void = bookingManager.refreshData()
        async let announcementsRefresh: Void = announcementsManager.refresh()
        async let infoRefresh: Void = infoManager.refresh()

        _ = await (usersRefresh, bookingsRefresh, announcementsRefresh, infoRefresh)
        await MainActor.run { lastRefreshed = Date() }
    }

}

#Preview {
    AdminDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(BookingManager())
        .environmentObject(AnnouncementsManager())
        .environmentObject(InfoManager())
}
