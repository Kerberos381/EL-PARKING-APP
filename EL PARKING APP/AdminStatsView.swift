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
    @State private var availabilityDate = Calendar.current.startOfDay(for: Date())

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

    private var availabilityBookings: [Booking] {
        let calendar = Calendar.current
        return statsBookings.filter { calendar.isDate($0.date, inSameDayAs: availabilityDate) }
    }

    private var availabilityWeekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: availabilityDate)?.start
            ?? calendar.startOfDay(for: availabilityDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var timelineStartMinutes: Int { minutes(from: AppConfig.defaultTimeFrom) }
    private var timelineEndMinutes: Int { minutes(from: AppConfig.defaultTimeTo) }
    private var timelineDurationMinutes: Int { max(60, timelineEndMinutes - timelineStartMinutes) }
    private var timelineWidth: CGFloat { 640 }
    private var timelineHourTicks: [Int] {
        let startHour = timelineStartMinutes / 60
        let endHour = Int(ceil(Double(timelineEndMinutes) / 60.0))
        return Array(startHour...max(startHour, endHour))
    }

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
                        availabilityTimelineSection
                        dayOfWeekChart
                        topSpotsChart
                        suspensionStatsSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .refreshable {
                    await loadStats()
                    Haptics.refreshCompleted()
                }
            }
        }
        .navigationTitle(L10n.bookingStatistics)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadStats() }
        .alert(L10n.deleteOldBookingsQuestion, isPresented: $showDeleteExpiredConfirmation) {
            Button(L10n.delete, role: .destructive) {
                Haptics.destructive()
                Task { await runExpiredCleanup() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteExpiredBookingsMessage(AppConfig.bookingRetentionDays))
        }
    }

    private var loadingSkeleton: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    SkeletonBlock(height: 11, cornerRadius: 6)
                        .frame(width: 120, alignment: .leading)
                    Spacer()
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppConfig.tertiaryFillBg)
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
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                                    .fill(AppConfig.tertiaryFillBg)
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
                .clipShape(RoundedRectangle(cornerRadius: 16))

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
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .font(.title3.weight(.semibold))
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
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppConfig.spotOccupied)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isDeletingExpired || isBackfillingTTL)
                .accessibilityLabel(L10n.deleteExpiredBookingsAccessibility(AppConfig.bookingRetentionDays))

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
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isBackfillingTTL || isDeletingExpired)
                .accessibilityLabel(L10n.backfillBookingTTL)
                .accessibilityHint(L10n.backfillBookingTTLHint)
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
        backfillStatusMessage = L10n.ttlBackfillStatus(scanned: result.scanned, updated: result.updated, skipped: result.skipped)
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
        backfillStatusMessage = L10n.cleanupStatus(scanned: result.scanned, deleted: result.deleted, skipped: result.skipped)
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
                color: AppConfig.infoTint
            )
            summaryCard(
                value: String(format: "%.0f%%", avgDailyOccupancy),
                label: L10n.avgOccupancy,
                icon: "parkingsign.circle.fill",
                color: AppConfig.darkText
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .cardShadow()
    }

    // MARK: - Availability Timeline

    private var availabilityTimelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundStyle(AppConfig.darkText)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.weekAvailability)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppConfig.darkText)
                    Text(availabilityDate.formatNaturalShort())
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        shiftAvailabilityDate(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 32, height: 32)
                    }
                    Button {
                        availabilityDate = Calendar.current.startOfDay(for: Date())
                    } label: {
                        Image(systemName: "calendar")
                            .frame(width: 32, height: 32)
                    }
                    Button {
                        shiftAvailabilityDate(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 32, height: 32)
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AppConfig.darkText)
                .buttonStyle(ScaleButtonStyle())
            }

            weekPicker

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(L10n.spot)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppConfig.subtleGray)
                            .frame(width: 52, alignment: .leading)
                        timelineHeader
                    }

                    ForEach(bookingManager.parkingSpots) { spot in
                        HStack(spacing: 10) {
                            Text("P\(spot.id)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppConfig.darkText)
                                .frame(width: 52, alignment: .leading)

                            timelineRow(for: spot)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .cardShadow()
    }

    private var weekPicker: some View {
        HStack(spacing: 8) {
            ForEach(availabilityWeekDays, id: \.self) { date in
                let selected = Calendar.current.isDate(date, inSameDayAs: availabilityDate)
                let dayBookings = statsBookings.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count
                Button {
                    availabilityDate = Calendar.current.startOfDay(for: date)
                    Haptics.selection()
                } label: {
                    VStack(spacing: 3) {
                        Text(weekdaySymbol(for: date))
                            .font(.caption2.weight(.bold))
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(.subheadline, design: .rounded, weight: .black))
                        Text("\(dayBookings)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(selected ? AppConfig.onAccent.opacity(0.75) : AppConfig.subtleGray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(selected ? AppConfig.onAccent : AppConfig.darkText)
                    .background(selected ? AppConfig.accent : AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(L10n.dayBookingsAccessibility(date: date.formatNaturalShort(), count: dayBookings))
            }
        }
    }

    private var timelineHeader: some View {
        ZStack(alignment: .leading) {
            ForEach(timelineHourTicks, id: \.self) { hour in
                let x = position(for: hour * 60)
                Text(String(format: "%02d", hour))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppConfig.subtleGray)
                    .frame(width: 32, alignment: .leading)
                    .offset(x: min(max(0, x - 2), timelineWidth - 32))
            }
        }
        .frame(width: timelineWidth, height: 18, alignment: .leading)
    }

    private func shiftAvailabilityDate(by days: Int) {
        availabilityDate = Calendar.current.date(byAdding: .day, value: days, to: availabilityDate) ?? availabilityDate
        Haptics.selection()
    }

    private func timelineRow(for spot: ParkingSpot) -> some View {
        let blocked = AppConfig.blockedSpotIDs.contains(spot.id)
        let bookings = availabilityBookings.filter {
            bookingManager.normalizedSpotKey($0.spot) == bookingManager.normalizedSpotKey(spot.label)
        }

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(blocked ? AppConfig.surfaceHigh : AppConfig.activeGreen.opacity(0.12))
                .frame(width: timelineWidth, height: 34)

            ForEach(timelineHourTicks, id: \.self) { hour in
                Rectangle()
                    .fill(AppConfig.separatorSoft)
                    .frame(width: 1, height: 34)
                    .offset(x: position(for: hour * 60))
            }

            if blocked {
                HStack(spacing: 6) {
                    Image(systemName: "slash.circle.fill")
                    Text(L10n.blocked)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .padding(.horizontal, 10)
            } else {
                ForEach(bookings) { booking in
                    bookingBar(booking)
                }
            }
        }
        .frame(width: timelineWidth, height: 34, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timelineRowAccessibilityLabel(spot: spot, bookings: bookings, blocked: blocked))
    }

    private func bookingBar(_ booking: Booking) -> some View {
        let start = max(timelineStartMinutes, minutes(from: booking.fromTime))
        let end = min(timelineEndMinutes, minutes(from: booking.toTime))
        let width = max(34, position(for: end) - position(for: start))
        let isMine = booking.email == bookingManager.currentUserEmail

        return HStack(spacing: 5) {
            Text(booking.firstName)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(booking.fromTime)-\(booking.toTime)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(isMine ? AppConfig.onAccent : .white)
        .padding(.horizontal, 8)
        .frame(width: width, height: 28, alignment: .leading)
        .background(isMine ? AppConfig.accent : AppConfig.spotOccupied)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .offset(x: position(for: start), y: 0)
        .accessibilityLabel(L10n.bookingTimeAccessibility(name: booking.firstName, from: booking.fromTime, to: booking.toTime))
    }

    private func position(for minutes: Int) -> CGFloat {
        let clamped = min(max(minutes, timelineStartMinutes), timelineEndMinutes)
        return CGFloat(clamped - timelineStartMinutes) / CGFloat(timelineDurationMinutes) * timelineWidth
    }

    private func minutes(from time: String) -> Int {
        let parts = time.split(separator: ":")
        let hour = Int(parts.first ?? "") ?? 0
        let minute = Int(parts.dropFirst().first ?? "") ?? 0
        return hour * 60 + minute
    }

    private func weekdaySymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func timelineRowAccessibilityLabel(spot: ParkingSpot, bookings: [Booking], blocked: Bool) -> String {
        if blocked { return L10n.spotStatusAccessibility(spotID: spot.id, status: L10n.mapStatusBlocked) }
        guard !bookings.isEmpty else { return L10n.spotStatusAccessibility(spotID: spot.id, status: L10n.availableAllDay) }
        let bookingText = bookings
            .map { L10n.bookingTimeAccessibility(name: $0.firstName, from: $0.fromTime, to: $0.toTime) }
            .joined(separator: ", ")
        return L10n.spotStatusAccessibility(spotID: spot.id, status: bookingText)
    }

    // MARK: - Day of Week Chart

    private var dayOfWeekChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(AppConfig.darkText)
                Text(L10n.bookingsByDay)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
            }

            let data     = dayOfWeekData
            let maxCount = data.map(\.count).max() ?? 1
            let peak     = data.map(\.count).max() ?? 0

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(data, id: \.day) { item in
                    VStack(spacing: 6) {
                        Text(item.count > 0 ? "\(item.count)" : "")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppConfig.darkText)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                item.count == peak && peak > 0
                                    ? AppConfig.accent
                                    : AppConfig.accent.opacity(0.3)
                            )
                            .frame(height: max(4, CGFloat(item.count) / CGFloat(max(1, maxCount)) * 96))

                        Text(item.day)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 136)
        }
        .padding(16)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .cardShadow()
    }

    // MARK: - Top Spots Chart

    private var topSpotsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "star")
                    .foregroundStyle(AppConfig.darkText)
                Text(L10n.mostBookedSpots)
                    .font(.title3.weight(.semibold))
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
                                .font(.system(.caption, design: .rounded, weight: .black))
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
                                .font(.system(.footnote, design: .rounded, weight: .bold).monospacedDigit())
                                .foregroundStyle(AppConfig.darkText)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .cardShadow()
    }

    // MARK: - Suspension Stats Section

    private var suspensionStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppConfig.warning)
                Text(L10n.warningTracker)
                    .textCase(nil)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
            }

            // Quick summary pills
            HStack(spacing: 10) {
                suspensionPill(value: totalActiveStrikes,  label: L10n.activeWarnings, color: AppConfig.warning)
                suspensionPill(value: currentlySuspended,  label: L10n.suspendedNow,   color: AppConfig.spotOccupied)
                suspensionPill(value: lifetimeSuspensions, label: L10n.totalBans,      color: AppConfig.subtleGray)
            }

            if usersWithStrikeHistory.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(AppConfig.activeGreen)
                    Text(L10n.noWarningsIssued)
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
                                                  ? (user.strikes == 3 ? AppConfig.spotOccupied : AppConfig.warning)
                                                  : AppConfig.surfaceHigh)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                if user.suspensionCount > 0 {
                                    Text(L10n.suspendedTimes(user.suspensionCount))
                                        .font(.caption2.weight(.semibold))
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
        .padding(16)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .cardShadow()
    }

    private func suspensionPill(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(value > 0 ? color : AppConfig.subtleGray)
            Text(label)
                .font(.caption2.weight(.semibold))
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
