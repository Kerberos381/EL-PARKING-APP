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
    @State private var selectedQuickStat: UserStatus = .pending
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

    // Palette for hash-based avatars (colorblind-friendly spread)
    private static let avatarPalette: [Color] = [
        Color(red: 0.20, green: 0.65, blue: 0.40),   // green
        Color(red: 0.25, green: 0.50, blue: 0.90),   // blue
        Color(red: 0.90, green: 0.55, blue: 0.15),   // orange
        Color(red: 0.70, green: 0.30, blue: 0.85),   // purple
        Color(red: 0.95, green: 0.40, blue: 0.55),   // pink
        Color(red: 0.30, green: 0.70, blue: 0.75),   // teal
        Color(red: 0.80, green: 0.35, blue: 0.30)    // coral
    ]

    fileprivate static func avatarColor(for uid: String) -> Color {
        var hash = 5381
        for ch in uid.unicodeScalars { hash = ((hash << 5) &+ hash) &+ Int(ch.value) }
        return avatarPalette[abs(hash) % avatarPalette.count]
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
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Pending alert banner ──────────────────────────────
                        if userCounts.pending > 0 {
                            pendingAlertBanner
                        }

                        // ── Quick stats ──────────────────────────────────────
                        statsGroupedCard

                        // ── Users section ─────────────────────────────────────
                        groupedSection(header: "Users") {
                            NavigationLink {
                                AdminUsersView()
                                    .environmentObject(authManager)
                                    .environmentObject(bookingManager)
                            } label: {
                                rowLabel(icon: "person.2.fill",
                                         iconColor: .blue,
                                         title: L10n.userManagement,
                                         subtitle: "Users",
                                         badge: userCounts.pending)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            Divider().padding(.leading, 56)
                            Button { showCreateUser = true } label: {
                                rowLabel(icon: "person.badge.plus",
                                         iconColor: AppConfig.darkText,
                                         iconForeground: .black,
                                         title: L10n.adminCreateUser,
                                         subtitle: "New User",
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            Divider().padding(.leading, 56)
                            Button { showBulkImport = true } label: {
                                rowLabel(icon: "tray.and.arrow.down.fill",
                                         iconColor: .cyan,
                                         title: L10n.bulkImport,
                                         subtitle: "CSV Import",
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // ── Content section ────────────────────────────────────
                        groupedSection(header: "Content") {
                            NavigationLink {
                                AdminSpotsView()
                                    .environmentObject(bookingManager)
                            } label: {
                                rowLabel(icon: "parkingsign.circle.fill",
                                         iconColor: .orange,
                                         title: L10n.spotManagement,
                                         subtitle: "Spots",
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
                                         iconColor: .pink,
                                         title: L10n.announcements,
                                         subtitle: "Posts",
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            Divider().padding(.leading, 56)
                            NavigationLink {
                                AdminInfoView()
                                    .environmentObject(infoManager)
                            } label: {
                                rowLabel(icon: "info.circle.fill",
                                         iconColor: .purple,
                                         title: L10n.infoCards,
                                         subtitle: "Cards",
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // ── Analytics section ──────────────────────────────────
                        groupedSection(header: "Analytics") {
                            NavigationLink {
                                AdminStatsView()
                                    .environmentObject(bookingManager)
                            } label: {
                                rowLabel(icon: "chart.bar.fill",
                                         iconColor: .red,
                                         title: L10n.bookingStatistics,
                                         subtitle: "Trends",
                                         badge: 0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // ── Maintenance section ───────────────────────────────
                        groupedSection(header: "Maintenance") {
                            Button {
                                Haptics.selection()
                                showPurgeConfirm = true
                            } label: {
                                rowLabel(icon: "trash.slash.fill",
                                         iconColor: .orange,
                                         title: "Purge Orphaned Bookings",
                                         subtitle: isPurging ? "Deleting…" : "Cleanup",
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
                    Haptics.selection()
                    await refreshDashboard()
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
            selectedQuickStat = .pending
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                Text(L10n.recentActivations)
                    .font(.system(size: 19, weight: .semibold))
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
                .background(Color(uiColor: .secondarySystemGroupedBackground))
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
                .background(Color(uiColor: .secondarySystemGroupedBackground))
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
                        .fill(Color(uiColor: .tertiarySystemFill))
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous))
    }

    // MARK: - Last refreshed footer

    private var lastRefreshedFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10, weight: .semibold))
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                Text(L10n.lastRefreshed(lastRefreshed.formatted(.relative(presentation: .named))))
            }
            .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(AppConfig.subtleGray.opacity(0.7))
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Stats Cards

    private var statsGroupedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .padding(.horizontal, 4)

            GeometryReader { proxy in
                let spacing: CGFloat = 8
                let available = max(0, proxy.size.width - spacing * 2)

                HStack(spacing: spacing) {
                    mailStyleQuickStat(icon: "clock.fill",
                                       title: L10n.pending,
                                       count: userCounts.pending,
                                       filter: .pending,
                                       width: quickStatWidth(for: .pending, availableWidth: available),
                                       pulse: userCounts.pending > 0)
                    mailStyleQuickStat(icon: "person.fill.checkmark",
                                       title: L10n.activeFilter,
                                       count: userCounts.active,
                                       filter: .active,
                                       width: quickStatWidth(for: .active, availableWidth: available))
                    mailStyleQuickStat(icon: "person.fill.xmark",
                                       title: L10n.suspended,
                                       count: userCounts.suspended,
                                       filter: .suspended,
                                       width: quickStatWidth(for: .suspended, availableWidth: available))
                }
            }
            .frame(height: 46)
            .animation(reduceMotion ? .none : .quick, value: selectedQuickStat)
        }
    }

    private func routeForFilter(_ filter: UserStatus) -> QuickFilterRoute {
        switch filter {
        case .active: return .active
        case .pending: return .pending
        case .suspended: return .suspended
        }
    }

    private func quickStatWidth(for filter: UserStatus, availableWidth: CGFloat) -> CGFloat {
        let selectedWeight: CGFloat = 1.15
        let unselectedWeight: CGFloat = 0.925
        let totalWeight: CGFloat = selectedWeight + unselectedWeight + unselectedWeight
        let weight = selectedQuickStat == filter ? selectedWeight : unselectedWeight
        return availableWidth * (weight / totalWeight)
    }

    private func handleQuickStatTap(_ filter: UserStatus) {
        if selectedQuickStat == filter {
            quickFilterRoute = routeForFilter(filter)
        } else {
            Haptics.selection()
            withAnimation(reduceMotion ? .none : .quick) {
                selectedQuickStat = filter
            }
        }
    }

    private func mailStyleQuickStat(
        icon: String,
        title: String,
        count: Int,
        filter: UserStatus,
        width: CGFloat,
        pulse: Bool = false
    ) -> some View {
        let isSelected = selectedQuickStat == filter
        let isPending = filter == .pending
        let iconColor: Color = {
            switch filter {
            case .suspended:
                return Color(red: 0.73, green: 0.37, blue: 0.37) // softer red
            case .pending:
                return .orange.opacity(0.9)
            case .active:
                return AppConfig.subtleGray
            }
        }()

        return Button {
            handleQuickStatTap(filter)
        } label: {
            HStack(spacing: isSelected ? 6 : 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.breathe, options: .repeating, isActive: pulse && !reduceMotion)

                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isSelected ? AppConfig.darkText : AppConfig.subtleGray)
                    .lineLimit(1)
                if isPending {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.orange)
                        .clipShape(Capsule())
                        .contentTransition(.numericText())
                } else {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppConfig.subtleGray)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 10)
            .frame(width: width, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(isSelected ? Color(uiColor: .quaternaryLabel) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue("\(count)")
        .accessibilityHint("Filters users by \(title.lowercased()) status")
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
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.badge.clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                        .symbolEffect(.breathe, options: .repeating, isActive: !reduceMotion)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(userCounts.pending) \(L10n.pending)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(pendingSubtitle)
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
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
                .tracking(1.0)
                .foregroundStyle(AppConfig.subtleGray)
                .padding(.horizontal, 8)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppConfig.separatorSoft.opacity(0.35), lineWidth: 0.5)
            )
            .containerShape(.rect(cornerRadius: 20))
        }
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange)
                    .clipShape(Capsule())
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

    private var createUserSubtitle: String {
        return L10n.adminCreateUserCardSubtitle(userCounts.awaitingSetup)
    }

    private var pendingSubtitle: String {
        L10n.adminPendingSubtitle(total: userCounts.total, pending: userCounts.pending)
    }

    private var spotSubtitle: String {
        L10n.adminSpotSubtitle(blocked: AppConfig.blockedSpotIDs.count, total: bookingManager.parkingSpots.count)
    }

    private var announcementSubtitle: String {
        L10n.adminAnnouncementSubtitle(announcementsManager.activeAnnouncements.count)
    }

    private var infoSubtitle: String {
        L10n.adminInfoSubtitle(infoManager.items.count)
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
