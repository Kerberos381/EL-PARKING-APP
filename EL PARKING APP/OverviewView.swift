//
//  OverviewView.swift
//  EL PARKING APP
//
//  Parking overview with editorial header, date pills, 2-col grid, admin features.
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var authManager:   AuthManager
    @ObservedObject private var lang = LanguageManager.shared
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @Namespace private var datePillSelectionNS
    @State private var bookingToCancel: Booking?
    @State private var showCancelAlert = false
    @State private var spotBookingDetail: Booking?
    @State private var preselectedSpot: ParkingSpot?
    @State private var showAdminCancelAlert = false
    @State private var adminCancelTarget: Booking?
    @State private var showProtectedAdminAlert = false
    @State private var showCancelErrorAlert = false
    @State private var cancelErrorMessage = ""
    @State private var notifyAfterCancel: Booking?
    @State private var showNotifyPrompt = false
    @State private var activeFilter: SpotStatus? = nil
    /// Comma-separated favourite spot IDs persisted to UserDefaults
    @AppStorage("favouriteSpotIDs") private var favouriteSpotIDsStr: String = ""

    private var isAdmin: Bool { bookingManager.isAdmin }

    private var favouriteSpotIDs: Set<String> {
        Set(favouriteSpotIDsStr.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private func toggleFavourite(_ spotID: String) {
        var ids = favouriteSpotIDs
        if ids.contains(spotID) { ids.remove(spotID) } else { ids.insert(spotID) }
        favouriteSpotIDsStr = ids.joined(separator: ",")
    }

    /// All bookings for the selected date (used for stats and grid)
    private var allBookingsForDate: [Booking] {
        bookingManager.getBookingsForDate(selectedDate)
    }

    /// Bookings list: admin sees all, regular user sees own
    private var visibleBookings: [Booking] {
        if isAdmin {
            return allBookingsForDate
        } else {
            return allBookingsForDate.filter { $0.email == bookingManager.currentUserEmail }
        }
    }

    /// Bookings grouped by spot label for selected day, sorted by time.
    private var dayBookingsBySpot: [String: [Booking]] {
        Dictionary(grouping: allBookingsForDate, by: \.spot).mapValues { items in
            items.sorted {
                if $0.fromTime == $1.fromTime { return $0.toTime < $1.toTime }
                return $0.fromTime < $1.fromTime
            }
        }
    }

    /// Fast lookup map to avoid repeated user searches in booking rows/cells.
    private var usersByEmailLowercased: [String: AppUser] {
        Dictionary(uniqueKeysWithValues: authManager.allUsers.map { ($0.email.lowercased(), $0) })
    }

    /// Spot status computed once per render pass.
    private var spotStatusByID: [String: SpotStatus] {
        var result: [String: SpotStatus] = [:]
        let mineEmail = bookingManager.currentUserEmail

        for spot in bookingManager.parkingSpots {
            if AppConfig.blockedSpotIDs.contains(spot.id) {
                result[spot.id] = .blocked
                continue
            }

            let dayBookings = dayBookingsBySpot[spot.label] ?? []
            guard !dayBookings.isEmpty else {
                result[spot.id] = .available
                continue
            }

            let hasMine = dayBookings.contains { $0.email == mineEmail }
            let hasOthers = dayBookings.contains { $0.email != mineEmail }

            if hasMine && !hasOthers {
                result[spot.id] = .mine
            } else {
                result[spot.id] = isFullyOccupied(dayBookings) ? .occupied : .partial
            }
        }

        return result
    }

    /// Spots filtered by active filter, with favourites sorted to top
    /// Spots the current user may see for the selected date (company policy).
    private var visibleSpots: [ParkingSpot] {
        bookingManager.parkingSpots.filter {
            AppConfig.spotVisible(spotID: $0.id,
                                  company: bookingManager.currentUserCompany,
                                  isAdmin: bookingManager.isAdmin,
                                  bookingDate: selectedDate)
        }
    }

    private var filteredSpots: [ParkingSpot] {
        let base: [ParkingSpot]
        if let filter = activeFilter {
            base = visibleSpots.filter { spot in
                let status = spotStatusByID[spot.id] ?? .available
                if filter == .occupied {
                    return status == .occupied || status == .mine || status == .partial
                }
                return status == filter
            }
        } else {
            base = visibleSpots
        }
        // Favourites float to the top; original order preserved within each group
        let favs = favouriteSpotIDs
        return base.sorted { a, b in
            let aFav = favs.contains(a.id)
            let bFav = favs.contains(b.id)
            if aFav != bFav { return aFav }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Editorial header
                        editorialHeader

                        // Date pills
                        datePills

                        // Stats bar (tappable filters)
                        statsBar

                        // Spot grid (2-col)
                        spotGrid

                        // Bookings list (admin-enhanced)
                        bookingsList

                        // Legend
                        legendBar
                    }
                    .padding(.bottom, 100)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .refreshable {
                    Haptics.selection()
                    await bookingManager.refreshData()
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $spotBookingDetail) { booking in
                SpotDetailSheet(booking: booking)
                    .environmentObject(bookingManager)
                    .environmentObject(authManager)
            }
            .fullScreenCover(item: $preselectedSpot) { spot in
                BookingSheet(
                    preselectedSpot: spot,
                    preselectedDate: selectedDate,
                    isForOthers: false
                )
            }
            .confirmationDialog(L10n.cancelBooking, isPresented: $showCancelAlert, titleVisibility: .visible) {
                Button(L10n.cancelBooking, role: .destructive) {
                    if let booking = bookingToCancel {
                        Haptics.destructive()
                        Task { await performCancellation(of: booking) }
                    }
                }
                Button(L10n.keep, role: .cancel) {}
            } message: {
                if let booking = bookingToCancel {
                    Text(L10n.cancelOwnBookingAlert(user: booking.user, spot: booking.spotNumber, date: booking.naturalDate))
                }
            }
            .confirmationDialog(
                L10n.notifyUserTitle,
                isPresented: $showNotifyPrompt,
                titleVisibility: .visible,
                presenting: notifyAfterCancel
            ) { booking in
                let phone = cancelledUserPhone(booking)
                let body = CancelNotify.body(
                    spot: booking.spotNumber, date: booking.naturalDate, reason: ""
                )
                if !phone.isEmpty {
                    Button(L10n.notifyViaMessage) {
                        CancelNotify.sendMessage(to: phone, body: body)
                    }
                }
                Button(L10n.notifyViaEmail) {
                    CancelNotify.sendEmail(
                        to: booking.email,
                        subject: L10n.bookingCancelledSubject,
                        body: body
                    )
                }
                Button(L10n.notifyLater, role: .cancel) {}
            } message: { booking in
                Text(L10n.notifyUserMessage(booking.user))
            }
            .confirmationDialog(L10n.adminCancelBooking, isPresented: $showAdminCancelAlert, titleVisibility: .visible) {
                Button(L10n.cancelAndNotify, role: .destructive) {
                    if let booking = adminCancelTarget {
                        Haptics.destructive()
                        Task { await performAdminCancellation(of: booking) }
                    }
                }
                Button(L10n.keep, role: .cancel) {}
            } message: {
                if let booking = adminCancelTarget {
                    Text(L10n.cancelBookingAdminAlert(name: booking.user, spot: booking.spotNumber))
                }
            }
            .alert(L10n.adminBookingProtectedTitle, isPresented: $showProtectedAdminAlert) {
                Button(L10n.close, role: .cancel) {}
            } message: {
                Text(L10n.adminBookingProtectedMessage)
            }
            .alert(L10n.cancelBookingFailed, isPresented: $showCancelErrorAlert) {
                Button(L10n.close, role: .cancel) {}
            } message: {
                Text(cancelErrorMessage)
            }
        }
    }

    // MARK: - Editorial Header

    private var editorialHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.executiveMobility)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppConfig.subtleGray)

                Text(L10n.parkingDot)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundStyle(AppConfig.darkText)
                    .minimumScaleFactor(0.6)
            }

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
                .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: - Date Pills (Horizontal Scroll)

    private var datePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                ForEach(0..<14, id: \.self) { offset in
                    if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                        datePill(date: date, offset: offset)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func datePill(date: Date, offset: Int) -> some View {
        let isSelected = Calendar.current.isDate(selectedDate, inSameDayAs: date)
        let isToday = offset == 0
        let dayNum = Calendar.current.component(.day, from: date)
        let innerWidth: CGFloat = 56
        let innerHeight: CGFloat = 64
        let pillRadius: CGFloat = 16
        let dayName: String = {
            if isToday { return L10n.today }
            return date.formatShortDayOfWeek()
        }()

        return Button {
            Haptics.selection()
            withAnimation(.standard) {
                selectedDate = date
                activeFilter = nil
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                    .fill(AppConfig.cardBg)
                    .frame(width: innerWidth, height: innerHeight)

                // Selected background is one shared shape that slides between pills.
                if isSelected {
                    RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                        .fill(AppConfig.pillSelected)
                        .matchedGeometryEffect(id: "datePillSelection", in: datePillSelectionNS)
                        .frame(width: innerWidth, height: innerHeight)
                }

                VStack(spacing: 4) {
                    Text(dayName)
                        .font(.caption.weight(.semibold))
                    Text("\(dayNum)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                }
                .foregroundStyle(isSelected ? .white : AppConfig.darkText)
                .frame(width: innerWidth, height: innerHeight)
            }
            .shadow(color: .black.opacity(isSelected ? 0.15 : 0.04), radius: 6, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Stats Bar (Tappable Filters)

    private var statsBar: some View {
        // Adjacent glass shapes must share one container to blend correctly.
        GlassEffectContainer {
            HStack(spacing: 8) {
                let pool = visibleSpots
                let bookedKeys = Set(allBookingsForDate.map { bookingManager.normalizedSpotKey($0.spot) })
                let blocked = pool.filter { AppConfig.blockedSpotIDs.contains($0.id) }.count
                let booked = pool.filter { bookedKeys.contains(bookingManager.normalizedSpotKey($0.label)) }.count
                let free = max(0, pool.count - booked - blocked)

                filterPill(value: "\(free)", label: L10n.free, color: AppConfig.spotAvailable, filter: .available)
                filterPill(value: "\(booked)", label: L10n.booked, color: AppConfig.spotOccupied, filter: .occupied)
                filterPill(value: "\(blocked)", label: L10n.blocked, color: AppConfig.spotBlocked, filter: .blocked)
            }
        }
        .padding(.horizontal)
    }

    private func filterPill(value: String, label: String, color: Color, filter: SpotStatus) -> some View {
        let isActive = activeFilter == filter
        return Button {
            Haptics.selection()
            withAnimation(.standard) {
                activeFilter = isActive ? nil : filter
            }
        } label: {
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.motionStandard, value: value)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActive ? AppConfig.darkText : AppConfig.subtleGray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(.frosted, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                isActive ?
                RoundedRectangle(cornerRadius: 24)
                    .stroke(color.opacity(0.5), lineWidth: 2)
                : nil
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Spot Grid (2-column, tall cells)

    private var spotGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredSpots) { spot in
                let cellStatus = cellStatusForSpot(spot)
                UnifiedSpotCell(
                    spot: spot,
                    status: cellStatus,
                    mode: .full,
                    spotGroupBadges: AppConfig.spotGroupBadges(
                        spotID: spot.id,
                        viewerCompany: bookingManager.currentUserCompany,
                        isAdmin: bookingManager.isAdmin
                    ),
                    isFavourite: favouriteSpotIDs.contains(spot.id),
                    onFavouriteTap: { toggleFavourite(spot.id) }
                ) {
                    handleSpotTap(spot, status: spotStatusByID[spot.id] ?? .available)
                }
            }
        }
        .padding(.horizontal)
        .animation(.standard, value: activeFilter)
    }

    /// Convert SpotStatus + admin context into SpotCellStatus
    private func cellStatusForSpot(_ spot: ParkingSpot) -> SpotCellStatus {
        let status = spotStatus(for: spot)
        let dayBookings = dayBookingsBySpot[spot.label] ?? []
        let booking = dayBookings.first
        switch status {
        case .available: return .available
        case .mine:      return .mine
        case .blocked:   return .blocked
        case .partial:
            let name = booking?.user
            let plate: String?
            if isAdmin, let b = booking {
                let appUser = usersByEmailLowercased[b.email.lowercased()]
                let p = appUser?.registrationPlate ?? ""
                plate = p.isEmpty ? nil : p
            } else {
                plate = nil
            }
            return .partial(
                name: name,
                plate: plate,
                ranges: occupiedRangesText(for: dayBookings)
            )
        case .occupied:
            let name: String?
            let plate: String?
            if let b = booking {
                let me = bookingManager.currentUserEmail
                if b.createdBy == me && b.email != me {
                    name = "For \(b.user)"         // full name of who I booked for
                } else {
                    name = b.user                  // full name of whoever has this spot
                }
                if isAdmin {
                    let appUser = usersByEmailLowercased[b.email.lowercased()]
                    let p = appUser?.registrationPlate ?? ""
                    plate = p.isEmpty ? nil : p
                } else {
                    plate = nil
                }
            } else {
                name = nil; plate = nil
            }
            return .occupied(name: name, plate: plate)
        }
    }

    // MARK: - Bookings List (Admin-enhanced)

    private var bookingsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(AppConfig.subtleGray)
                Text(isAdmin ? L10n.allBookings : L10n.bookings)
                    .font(.headline)
                    .foregroundStyle(AppConfig.darkText)
                Spacer()
                Text("\(visibleBookings.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppConfig.subtleGray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppConfig.subtleGray.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            if visibleBookings.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "car.side")
                            .font(.title3)
                            .foregroundStyle(AppConfig.subtleGray.opacity(0.3))
                        Text(L10n.noBookingsDay)
                            .font(.subheadline)
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(visibleBookings) { booking in
                    adminBookingRow(booking)
                }
            }
        }
        .padding(.horizontal)
    }

    private func adminBookingRow(_ booking: Booking) -> some View {
        let isMine = booking.email == bookingManager.currentUserEmail
        let isProtectedAdminBooking = isProtectedAdminBooking(booking)
        let canCancel = bookingManager.canCancelBooking(booking)

        let card = HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isMine ? AppConfig.accent.opacity(0.2) : AppConfig.surfaceHigh)
                    .frame(width: 40, height: 40)
                Text(userInitials(booking.user))
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(isMine ? AppConfig.darkText : AppConfig.subtleGray)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(booking.user)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.darkText)
                        .lineLimit(1)

                    if isMine {
                        Text(L10n.you)
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppConfig.darkText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppConfig.surfaceLow)
                            .overlay(Capsule().stroke(AppConfig.separatorSoft, lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text("\(booking.fromTime) – \(booking.toTime)")
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(AppConfig.subtleGray)

                    if isAdmin {
                        let appUser = usersByEmailLowercased[booking.email.lowercased()]
                        let plate = appUser?.registrationPlate ?? ""
                        if !plate.isEmpty {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.4))
                            Text(plate)
                                .font(.system(.caption2, design: .monospaced).weight(.medium))
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.65))
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Text(booking.spotNumber)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(AppConfig.darkText)
                .frame(width: 44, height: 44)
                .background(isMine ? AppConfig.surfaceHigh : AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            Haptics.selection()
            spotBookingDetail = booking
        }

        return Group {
            if canCancel {
                card.swipeToCancel(cornerRadius: 16) {
                    if isProtectedAdminBooking {
                        Haptics.impact(.rigid)
                        showProtectedAdminAlert = true
                    } else if isAdmin && booking.email != bookingManager.currentUserEmail {
                        Haptics.impact(.medium)
                        adminCancelTarget = booking
                        showAdminCancelAlert = true
                    } else {
                        Haptics.destructive()
                        bookingToCancel = booking
                        showCancelAlert = true
                    }
                }
            } else {
                card
            }
        }
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: 14) {
            legendItem(color: AppConfig.spotAvailable, label: L10n.free)
            legendItem(color: AppConfig.spotOccupied, label: L10n.taken)
            legendItem(color: AppConfig.surfaceHigh, label: "Partial")
            legendItem(color: AppConfig.spotMine, label: L10n.yours)
            legendItem(color: AppConfig.spotBlocked, label: L10n.blocked)
            // Accessibility legend item
            HStack(spacing: 4) {
                Image(systemName: "figure.roll")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 1.0))
                Text(L10n.accessible)
                    .foregroundStyle(AppConfig.subtleGray)
            }
            Spacer()
        }
        .font(.caption2)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundStyle(AppConfig.subtleGray)
        }
    }

    private func isProtectedAdminBooking(_ booking: Booking) -> Bool {
        guard booking.email.caseInsensitiveCompare(bookingManager.currentUserEmail) != .orderedSame else {
            return false
        }

        return usersByEmailLowercased[booking.email.lowercased()]?.isAdmin == true
    }

    private func performAdminCancellation(of booking: Booking) async {
        let error = await bookingManager.adminCancelBooking(booking)
        if error == nil {
            Haptics.notify(.success)
            // Offer instant out-of-band notification (Message / Email).
            notifyAfterCancel = booking
            showNotifyPrompt = true
        }
        presentCancellationErrorIfNeeded(error)
    }

    private func cancelledUserPhone(_ booking: Booking) -> String {
        usersByEmailLowercased[booking.email.lowercased()]?.phone ?? ""
    }

    private func performCancellation(of booking: Booking) async {
        let error = await bookingManager.cancelBooking(booking)
        if error == nil {
            Haptics.notify(.success)
        }
        presentCancellationErrorIfNeeded(error)
    }

    @MainActor
    private func presentCancellationErrorIfNeeded(_ error: String?) {
        guard let error, !error.isEmpty else { return }
        Haptics.notify(.error)
        cancelErrorMessage = error
        showCancelErrorAlert = true
    }

    // MARK: - Helpers

    enum SpotStatus: Equatable {
        case available, partial, occupied, mine, blocked
    }

    private func spotStatus(for spot: ParkingSpot) -> SpotStatus {
        spotStatusByID[spot.id] ?? .available
    }

    private func handleSpotTap(_ spot: ParkingSpot, status: SpotStatus) {
        guard status != .blocked else { return }
        Haptics.selection()

        // Partial occupancy should stay bookable: open BookingSheet so users can
        // pick a free interval instead of being forced into detail-only view.
        if status == .partial {
            preselectedSpot = spot
            return
        }

        // Always do a live lookup at tap time — overrides the displayed cell status.
        // This fixes the race where the grid rendered before Firestore loaded,
        // so a booked spot briefly appeared free and would wrongly open BookingSheet.
        if let existingBooking = (dayBookingsBySpot[spot.label] ?? []).first {
            spotBookingDetail = existingBooking
        } else {
            preselectedSpot = spot
        }
    }

    private func occupiedRangesText(for dayBookings: [Booking]) -> String? {
        guard !dayBookings.isEmpty else { return nil }
        let merged = mergedIntervals(from: dayBookings.map { (from: $0.fromTime, to: $0.toTime) })
        return merged.map { "\($0.from)-\($0.to)" }.joined(separator: ", ")
    }

    private func isFullyOccupied(_ dayBookings: [Booking]) -> Bool {
        guard !dayBookings.isEmpty else { return false }
        let merged = mergedIntervals(from: dayBookings.map { (from: $0.fromTime, to: $0.toTime) })
        guard let first = merged.first else { return false }
        return first.from <= AppConfig.defaultTimeFrom &&
            first.to >= AppConfig.fullDayOccupiedCutoffTime &&
            merged.count == 1
    }

    private func mergedIntervals(from ranges: [(from: String, to: String)]) -> [(from: String, to: String)] {
        let sorted = ranges.sorted {
            if $0.from == $1.from { return $0.to < $1.to }
            return $0.from < $1.from
        }
        guard var current = sorted.first else { return [] }
        var merged: [(from: String, to: String)] = []

        for next in sorted.dropFirst() {
            if next.from <= current.to {
                if next.to > current.to { current.to = next.to }
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)
        return merged
    }

    private func userInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

}

#Preview {
    OverviewView()
        .environmentObject(BookingManager())
        .environmentObject(AuthManager())
}
