//
//  AdminStatsView.swift
//  EL PARKING APP
//
//  30-day booking statistics for admins:
//  total bookings, unique users, avg daily occupancy,
//  bookings by day of week, and most-booked spots.
//

import SwiftUI
import FirebaseFirestore

struct AdminStatsView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var lang = LanguageManager.shared

    @State private var statsBookings: [Booking] = []
    @State private var isLoading = true
    @State private var isBackfillingTTL = false
    @State private var isDeletingExpired = false
    @State private var backfillStatusMessage: String?
    @State private var showDeleteExpiredConfirmation = false

    private let db = Firestore.firestore()

    // MARK: - Computed Stats

    private var totalBookings: Int { statsBookings.count }

    private var uniqueUsers: Int {
        Set(statsBookings.map { $0.email }).count
    }

    private var avgDailyOccupancy: Double {
        guard !statsBookings.isEmpty else { return 0 }
        let calendar = Calendar.current
        let grouped  = Dictionary(grouping: statsBookings) { calendar.startOfDay(for: $0.date) }
        let totalSpots = Double(max(1, bookingManager.parkingSpots.count))
        let daily = grouped.values.map { Double($0.count) / totalSpots * 100 }
        return daily.reduce(0, +) / Double(max(1, daily.count))
    }

    /// Top 5 spots by booking count
    private var mostBookedSpots: [(spot: String, count: Int)] {
        Dictionary(grouping: statsBookings) { $0.spot }
            .map { (spot: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    /// Mon–Sun booking counts
    private var dayOfWeekData: [(day: String, count: Int)] {
        let calendar = Calendar.current
        let days = L10n.weekDays
        var counts = Array(repeating: 0, count: 7)
        for booking in statsBookings {
            // Calendar.weekday: Sun=1 … Sat=7 → remap to Mon=0 … Sun=6
            let wd = calendar.component(.weekday, from: booking.date)
            let idx = (wd + 5) % 7
            if idx < 7 { counts[idx] += 1 }
        }
        return days.enumerated().map { (day: $1, count: counts[$0]) }
    }

    /// Users with any strike history, sorted by total suspensions then active strikes.
    private var usersWithStrikeHistory: [AppUser] {
        authManager.allUsers
            .filter { $0.strikes > 0 || $0.suspensionCount > 0 }
            .sorted {
                if $0.suspensionCount != $1.suspensionCount { return $0.suspensionCount > $1.suspensionCount }
                return $0.strikes > $1.strikes
            }
    }

    private var totalActiveStrikes: Int { authManager.allUsers.reduce(0) { $0 + $1.strikes } }
    private var currentlySuspended: Int { authManager.allUsers.filter { $0.isSuspended && $0.suspendedAt != nil }.count }
    private var lifetimeSuspensions: Int { authManager.allUsers.reduce(0) { $0 + $1.suspensionCount } }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppConfig.pageBg.ignoresSafeArea()

            if isLoading {
                loadingSkeleton
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        statsHeader
                        if let backfillStatusMessage {
                            Text(backfillStatusMessage)
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        summaryCards
                        dayOfWeekChart
                        topSpotsChart
                        suspensionStatsSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    Haptics.selection()
                    await loadStats()
                }
            }
        }
        .navigationTitle(L10n.bookingStatistics)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadStats() }
        .alert("Delete old bookings?", isPresented: $showDeleteExpiredConfirmation) {
            Button("Delete", role: .destructive) {
                Haptics.destructive()
                Task { await runExpiredCleanup() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete bookings older than \(AppConfig.bookingRetentionDays) days.")
        }
    }

    private var loadingSkeleton: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    SkeletonBlock(height: 11, cornerRadius: 6)
                        .frame(width: 120, alignment: .leading)
                    Spacer()
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(width: 36, height: 36)
                        .shimmering(active: true)
                }
                .padding(.top, 8)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(spacing: 10) {
                            SkeletonBlock(height: 22, cornerRadius: 11)
                                .frame(width: 22)
                            SkeletonBlock(height: 30, cornerRadius: 10)
                                .frame(width: 80)
                            SkeletonBlock(height: 11, cornerRadius: 6)
                                .frame(width: 92)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        SkeletonBlock(height: 16, cornerRadius: 8).frame(width: 16)
                        SkeletonBlock(height: 16, cornerRadius: 8).frame(width: 140, alignment: .leading)
                    }
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array([46, 72, 58, 96, 64, 82, 54].enumerated()), id: \.offset) { _, barHeight in
                            VStack(spacing: 6) {
                                SkeletonBlock(height: 10, cornerRadius: 5).frame(width: 14)
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(uiColor: .tertiarySystemFill))
                                    .frame(height: CGFloat(barHeight))
                                    .shimmering(active: true)
                                SkeletonBlock(height: 10, cornerRadius: 5).frame(width: 14)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 136)
                }
                .padding(18)
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        SkeletonBlock(height: 16, cornerRadius: 8).frame(width: 16)
                        SkeletonBlock(height: 16, cornerRadius: 8).frame(width: 130, alignment: .leading)
                    }
                    VStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            HStack(spacing: 12) {
                                SkeletonBlock(height: 28, cornerRadius: 14).frame(width: 28)
                                SkeletonBlock(height: 14, cornerRadius: 7).frame(width: 80)
                                SkeletonBlock(height: 8, cornerRadius: 4).frame(maxWidth: .infinity)
                                SkeletonBlock(height: 13, cornerRadius: 6).frame(width: 24)
                            }
                        }
                    }
                }
                .padding(18)
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Load

    private func loadStats() async {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        do {
            let snapshot = try await db.collection("bookings").getDocuments()
            let docs = snapshot.documents.map { (data: $0.data(), id: $0.documentID) }
            let loaded = await Task.detached(priority: .userInitiated) {
                docs.compactMap { Booking.fromFirestore($0.data, documentID: $0.id) }
                    .filter { $0.date >= thirtyDaysAgo }
            }.value
            await MainActor.run {
                statsBookings = loaded
                isLoading     = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Header

    private var statsHeader: some View {
        HStack {
            Text(L10n.last30Days)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(3)
                .foregroundStyle(AppConfig.subtleGray)
            Spacer()
            HStack(spacing: 10) {
                Button {
                    showDeleteExpiredConfirmation = true
                } label: {
                    if isDeletingExpired {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 44, height: 44)
                    } else {
                        ZStack {
                            Circle()
                                .fill(AppConfig.spotOccupied.opacity(0.16))
                                .frame(width: 44, height: 44)
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppConfig.spotOccupied)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isDeletingExpired || isBackfillingTTL)
                .accessibilityLabel("Delete bookings older than \(AppConfig.bookingRetentionDays) days")

                Button {
                    Task { await runTTLBackfill() }
                } label: {
                    if isBackfillingTTL {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 44, height: 44)
                    } else {
                        ZStack {
                            Circle()
                                .fill(AppConfig.surfaceHigh)
                                .frame(width: 44, height: 44)
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isBackfillingTTL || isDeletingExpired)
                .accessibilityLabel("Backfill booking TTL")
                .accessibilityHint("Recomputes retention metadata for existing bookings.")
            }
        }
        .padding(.top, 8)
    }

    @MainActor
    private func runTTLBackfill() async {
        guard !isBackfillingTTL else { return }
        isBackfillingTTL = true
        Haptics.selection()
        let result = await bookingManager.backfillMissingBookingTTL()
        backfillStatusMessage = "TTL backfill: scanned \(result.scanned), updated \(result.updated), skipped \(result.skipped)."
        if result.updated > 0 {
            Haptics.notify(.success)
        } else {
            Haptics.selection()
        }
        isBackfillingTTL = false
    }

    @MainActor
    private func runExpiredCleanup() async {
        guard !isDeletingExpired else { return }
        isDeletingExpired = true
        Haptics.selection()
        let result = await bookingManager.hardDeleteExpiredBookings()
        backfillStatusMessage = "Cleanup: scanned \(result.scanned), deleted \(result.deleted), skipped \(result.skipped)."
        if result.deleted > 0 {
            Haptics.notify(.success)
        } else {
            Haptics.selection()
        }
        await loadStats()
        isDeletingExpired = false
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            summaryCard(
                value: "\(totalBookings)",
                label: L10n.totalBookingsStat,
                icon: "calendar.badge.checkmark",
                color: AppConfig.activeGreen
            )
            summaryCard(
                value: "\(uniqueUsers)",
                label: L10n.activeUsersStat,
                icon: "person.2.fill",
                color: .blue
            )
            summaryCard(
                value: String(format: "%.0f%%", avgDailyOccupancy),
                label: L10n.avgOccupancy,
                icon: "parkingsign.circle.fill",
                color: AppConfig.accentFg
            )
            summaryCard(
                value: "\(bookingManager.parkingSpots.count)",
                label: L10n.totalSpots,
                icon: "square.grid.2x2.fill",
                color: AppConfig.subtleGray
            )
        }
    }

    private func summaryCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(AppConfig.darkText)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    // MARK: - Day of Week Chart

    private var dayOfWeekChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(AppConfig.accentFg)
                Text(L10n.bookingsByDay)
                    .font(.headline)
                    .foregroundStyle(AppConfig.darkText)
            }

            let data     = dayOfWeekData
            let maxCount = data.map(\.count).max() ?? 1
            let peak     = data.map(\.count).max() ?? 0

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(data, id: \.day) { item in
                    VStack(spacing: 6) {
                        Text(item.count > 0 ? "\(item.count)" : "")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .foregroundStyle(AppConfig.darkText)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                item.count == peak && peak > 0
                                    ? AppConfig.accent
                                    : AppConfig.accent.opacity(0.3)
                            )
                            .frame(height: max(4, CGFloat(item.count) / CGFloat(max(1, maxCount)) * 96))

                        Text(item.day)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 136)
        }
        .padding(18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    // MARK: - Top Spots Chart

    private var topSpotsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "star")
                    .foregroundStyle(AppConfig.accentFg)
                Text(L10n.mostBookedSpots)
                    .font(.headline)
                    .foregroundStyle(AppConfig.darkText)
            }

            if mostBookedSpots.isEmpty {
                Text(L10n.noBookingData)
                    .font(.subheadline)
                    .foregroundStyle(AppConfig.subtleGray)
            } else {
                let topCount = mostBookedSpots.first?.count ?? 1
                VStack(spacing: 12) {
                    ForEach(Array(mostBookedSpots.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            // Rank badge
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(index == 0 ? AppConfig.onAccent : AppConfig.subtleGray)
                                .frame(width: 28, height: 28)
                                .background(index == 0 ? AppConfig.accent : AppConfig.surfaceHigh)
                                .clipShape(Circle())

                            // Spot label
                            Text(item.spot)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppConfig.darkText)
                                .frame(minWidth: 80, alignment: .leading)

                            // Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppConfig.surfaceLow)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(index == 0 ? AppConfig.accent : AppConfig.accent.opacity(0.45))
                                        .frame(
                                            width: geo.size.width * CGFloat(item.count) / CGFloat(max(1, topCount))
                                        )
                                }
                            }
                            .frame(height: 8)

                            // Count
                            Text("\(item.count)")
                                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(AppConfig.darkText)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    // MARK: - Suspension Stats Section

    private var suspensionStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Warning Tracker")
                    .textCase(nil)
                    .font(.headline)
                    .foregroundStyle(AppConfig.darkText)
            }

            // Quick summary pills
            HStack(spacing: 10) {
                suspensionPill(value: totalActiveStrikes,  label: "Active\nWarnings", color: .orange)
                suspensionPill(value: currentlySuspended,  label: "Suspended\nNow",   color: AppConfig.spotOccupied)
                suspensionPill(value: lifetimeSuspensions, label: "Total\nBans",       color: AppConfig.subtleGray)
            }

            if usersWithStrikeHistory.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(AppConfig.activeGreen)
                    Text("No warnings issued. All clean.")
                        .font(.subheadline).foregroundStyle(AppConfig.subtleGray)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(usersWithStrikeHistory) { user in
                        HStack(spacing: 12) {
                            UserAvatarView(user: user, size: 36, showStroke: false)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppConfig.darkText)
                                    .lineLimit(1)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(AppConfig.subtleGray)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                // Active strikes dots
                                HStack(spacing: 3) {
                                    ForEach(1...3, id: \.self) { i in
                                        Circle()
                                            .fill(i <= user.strikes
                                                  ? (user.strikes == 3 ? AppConfig.spotOccupied : .orange)
                                                  : AppConfig.surfaceHigh)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                if user.suspensionCount > 0 {
                                    Text("\(user.suspensionCount)× suspended")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(AppConfig.spotOccupied)
                                }
                            }
                        }
                        .padding(12)
                        .background(user.isSuspended
                            ? AppConfig.spotOccupied.opacity(0.06)
                            : AppConfig.surfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    private func suspensionPill(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(value > 0 ? color : AppConfig.subtleGray)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(value > 0 ? color.opacity(0.08) : AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        AdminStatsView()
            .environmentObject(BookingManager())
            .environmentObject(AuthManager())
    }
}
