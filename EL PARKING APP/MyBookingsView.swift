//
//  MyBookingsView.swift
//  EL PARKING APP
//
//  My Bookings screen.
//
//  Layout:
//  ┌─ My Bookings ──────────────────────────────────────────┐
//  │  Upcoming (own) — ranges collapsed to one card         │
//  │  Past (own)                                            │
//  ├─ Delegated Bookings ───────────────────────────────────│
//  │  Ranges for others, each collapsed to one card         │
//  │  Delegated past                                        │
//  └────────────────────────────────────────────────────────┘
//
//  All upcoming cards have Share + Edit (range or single) + Cancel.
//  Editing a range opens RangeEditSheet — saves all N days atomically.
//

import SwiftUI

// MARK: - BookingGroup

/// A single booking or a collapsed multi-day range sharing a groupID.
enum BookingGroup: Identifiable {
    case single(Booking)
    case range(bookings: [Booking], spot: String, startDate: Date, endDate: Date)

    var id: String {
        switch self {
        case .single(let b):
            return b.id.uuidString
        case .range(let bs, _, _, _):
            return "range_" + bs.map { $0.id.uuidString }.sorted().joined(separator: "_")
        }
    }

    var spotLabel: String {
        switch self {
        case .single(let b):         return b.spot
        case .range(_, let s, _, _): return s
        }
    }

    var spotNumber: String {
        spotLabel.replacingOccurrences(of: "Parking ", with: "")
    }

    /// First booking by date — used for time, user, email, createdBy, etc.
    var representativeBooking: Booking {
        switch self {
        case .single(let b):          return b
        case .range(let bs, _, _, _): return bs.sorted { $0.date < $1.date }.first!
        }
    }

    var rangeEndDate: Date? {
        switch self {
        case .single:                  return nil
        case .range(_, _, _, let end): return end
        }
    }

    var startDate: Date {
        switch self {
        case .single(let b):           return b.date
        case .range(_, _, let s, _):   return s
        }
    }

    var dayCount: Int {
        switch self {
        case .single:                 return 1
        case .range(let bs, _, _, _): return bs.count
        }
    }

    /// True if today falls anywhere inside the range (or equals the single day)
    var isActive: Bool {
        switch self {
        case .single(let b):          return b.isToday
        case .range(let bs, _, _, _): return bs.contains { Calendar.current.isDateInToday($0.date) }
        }
    }

    var isRange: Bool {
        if case .range = self { return true }
        return false
    }

    var fromTime:  String { representativeBooking.fromTime }
    var toTime:    String { representativeBooking.toTime }
    var user:      String { representativeBooking.user }
    var email:     String { representativeBooking.email }
    var createdBy: String { representativeBooking.createdBy }
}

// MARK: - MyBookingsView

struct MyBookingsView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @ObservedObject private var lang = LanguageManager.shared

    @State private var bookingToCancel:        Booking?
    @State private var cancelGroupBookings:    [Booking]?
    @State private var showingCancelAlert      = false
    @State private var showingGroupCancelAlert = false
    @State private var showCancelSuccess       = false
    @State private var cancelledBooking: (spotNumber: String, date: String, from: String, to: String)?
    @State private var bookingToEdit:          Booking?   // single edit via sheet(item:)
    @State private var showingDelegated        = false    // segmented tab: false = mine, true = for others

    private var myEmail: String { bookingManager.currentUserEmail }
    private var normalizedMyEmail: String { normalizeEmail(myEmail) }

    // MARK: - Computed lists

    private var myUpcoming: [BookingGroup] {
        let today = Calendar.current.startOfDay(for: Date())
        let mine  = bookingManager.bookings
            .filter { normalizeEmail($0.email) == normalizedMyEmail && $0.date >= today }
            .sorted { $0.date < $1.date }
        return collapseIntoGroups(mine)
    }

    private var myPast: [BookingGroup] {
        let today = Calendar.current.startOfDay(for: Date())
        let past  = bookingManager.bookings
            .filter { normalizeEmail($0.email) == normalizedMyEmail && $0.date < today }
            .sorted { $0.date > $1.date }
        return collapseIntoGroups(Array(past.prefix(20)))
    }

    private var delegatedUpcoming: [BookingGroup] {
        let today  = Calendar.current.startOfDay(for: Date())
        let others = bookingManager.bookings
            .filter {
                normalizeEmail($0.createdBy) == normalizedMyEmail &&
                normalizeEmail($0.email) != normalizedMyEmail &&
                $0.date >= today
            }
            .sorted { $0.date < $1.date }
        return collapseIntoGroups(others)
    }

    private var delegatedPast: [BookingGroup] {
        let today = Calendar.current.startOfDay(for: Date())
        let past  = bookingManager.bookings
            .filter {
                normalizeEmail($0.createdBy) == normalizedMyEmail &&
                normalizeEmail($0.email) != normalizedMyEmail &&
                $0.date < today
            }
            .sorted { $0.date > $1.date }
        return collapseIntoGroups(Array(past.prefix(10)))
    }

    /// Collapse bookings that share a groupID into a single .range entry.
    private func collapseIntoGroups(_ bookings: [Booking]) -> [BookingGroup] {
        var groups:      [BookingGroup] = []
        var seenGroups = Set<UUID>()

        for booking in bookings {
            if let gid = booking.groupID {
                guard !seenGroups.contains(gid) else { continue }
                seenGroups.insert(gid)
                let siblings = bookings
                    .filter { $0.groupID == gid }
                    .sorted { $0.date < $1.date }
                if siblings.count > 1,
                   let first = siblings.first?.date,
                   let last  = siblings.last?.date {
                    groups.append(.range(bookings: siblings, spot: booking.spot,
                                        startDate: first, endDate: last))
                } else {
                    groups.append(.single(booking))
                }
            } else {
                groups.append(.single(booking))
            }
        }
        return groups
    }

    private func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                        // ── Segmented toggle ──────────────────────────────
                        segmentedToggle

                        if !showingDelegated {
                            // ── My upcoming ───────────────────────────────
                            if myUpcoming.isEmpty {
                                emptyState
                            } else {
                                ForEach(myUpcoming) { group in
                                    upcomingCard(group, cardBg: AppConfig.obsidian)
                                        .padding(.horizontal)
                                        .swipeToCancel { triggerCancel(group) }
                                        .contextMenu {
                                            Button { openShare(group) } label: {
                                                Label(L10n.share, systemImage: "square.and.arrow.up")
                                            }
                                            Button { openEdit(group) } label: {
                                                Label(L10n.edit, systemImage: "pencil")
                                            }
                                            Divider()
                                            Button(role: .destructive) { triggerCancel(group) } label: {
                                                Label(group.isRange ? L10n.cancelAll : L10n.cancel,
                                                      systemImage: "xmark.circle")
                                            }
                                        }
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .opacity.combined(with: .scale(scale: 0.96))
                                        ))
                                }
                            }

                            // ── My past ───────────────────────────────────
                            if !myPast.isEmpty {
                sectionHeader(title: L10n.past,
                                              icon: "checkmark.circle",
                                              count: myPast.count,
                                              color: AppConfig.subtleGray)
                                ForEach(myPast) { group in
                                    pastCard(group)
                                        .padding(.horizontal)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal:   .opacity.combined(with: .scale(scale: 0.96))
                                        ))
                                }
                            }

                        } else {
                            // ── Delegated upcoming ────────────────────────
                            if delegatedUpcoming.isEmpty && delegatedPast.isEmpty {
                                delegatedEmptyState
                            } else {
                                ForEach(delegatedUpcoming) { group in
                                    upcomingCard(group,
                                                 cardBg: Color(red: 0.05, green: 0.09, blue: 0.26))
                                        .padding(.horizontal)
                                        .contextMenu {
                                            Button { openShare(group) } label: {
                                                Label(L10n.share, systemImage: "square.and.arrow.up")
                                            }
                                            Button { openEdit(group) } label: {
                                                Label(L10n.edit, systemImage: "pencil")
                                            }
                                            Divider()
                                            Button(role: .destructive) { triggerCancel(group) } label: {
                                                Label(group.isRange ? L10n.cancelAll : L10n.cancel,
                                                      systemImage: "xmark.circle")
                                            }
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                                // ── Delegated past ─────────────────────────
                                if !delegatedPast.isEmpty {
                                    sectionHeader(title: L10n.past,
                                                  icon: "person.badge.plus",
                                                  count: delegatedPast.count,
                                                  color: Color(red: 0.45, green: 0.74, blue: 1.0).opacity(0.8))
                                    ForEach(delegatedPast) { group in
                                        pastCard(group)
                                            .padding(.horizontal)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }
                        }

                    Spacer().frame(height: 80)
                }
            }
            .padding(.vertical)
            .animation(.standard, value: bookingManager.bookings.count)
        }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle(L10n.myBookings)
            .navigationBarTitleDisplayMode(.large)
            // Single-booking edit — item-based avoids blank-sheet race
            .sheet(item: $bookingToEdit) { booking in
                BookingSheet(
                    preselectedSpot: AppConfig.allParkingSpots
                        .first(where: { $0.label == booking.spot }),
                    isForOthers: booking.email != myEmail,
                    editingBooking: booking
                )
                .environmentObject(bookingManager)
            }
            .confirmationDialog(L10n.cancelBooking, isPresented: $showingCancelAlert, titleVisibility: .visible) {
                Button(L10n.cancelBooking, role: .destructive) {
                    if let b = bookingToCancel {
                        let info = (spotNumber: b.spotNumber, date: b.naturalDate,
                                    from: b.fromTime, to: b.toTime)
                        Task {
                            let error = await bookingManager.cancelBooking(b)
                            if error == nil {
                                Haptics.notify(.success)
                                cancelledBooking = info
                                withAnimation(.easeIn(duration: 0.2)) { showCancelSuccess = true }
                                ToastManager.shared.showUndo(
                                    message: "Spot \(b.spotNumber) cancelled"
                                ) {
                                    Task {
                                        try? await bookingManager.createBooking(
                                            spotID: b.spotNumber, spotLabel: b.spot,
                                            userEmail: b.email, userName: b.user,
                                            dateFrom: b.date, dateTo: b.date,
                                            timeFrom: b.fromTime, timeTo: b.toTime
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                Button(L10n.keep, role: .cancel) {}
            } message: {
                if let b = bookingToCancel {
                    Text(L10n.cancelSingleMessage(spot: b.spotNumber, date: b.naturalDate))
                }
            }
            .overlay {
                if showCancelSuccess, let info = cancelledBooking {
                    CancelSuccessOverlay(
                        spotNumber: info.spotNumber,
                        date: info.date,
                        timeFrom: info.from,
                        timeTo: info.to
                    ) {
                        showCancelSuccess = false
                    }
                }
            }
            .confirmationDialog(L10n.cancelEntireRange, isPresented: $showingGroupCancelAlert, titleVisibility: .visible) {
                Button(L10n.cancelAllDays, role: .destructive) {
                    if let group = cancelGroupBookings {
                        Task { for b in group { await bookingManager.cancelBooking(b) } }
                    }
                }
                Button(L10n.keep, role: .cancel) {}
            } message: {
                if let group = cancelGroupBookings,
                   let first = group.sorted(by: { $0.date < $1.date }).first,
                   let last  = group.sorted(by: { $0.date < $1.date }).last {
                    Text(L10n.cancelRangeMessage(count: group.count, name: first.user,
                                                  spot: first.spotNumber,
                                                  from: first.date.formatNaturalShort(),
                                                  to: last.date.formatNaturalShort()))
                }
            }
                .refreshable {
                    await bookingManager.refreshData()
                }
                .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                    ToastManager.shared.performUndo()
                }
        }
    }

    // MARK: - Section header

    private func sectionHeader(title: String, icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title)
                .font(.headline).foregroundStyle(AppConfig.darkText)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppConfig.subtleGray)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(AppConfig.subtleGray.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Segmented Toggle

    private var segmentedToggle: some View {
        let blueAccent = Color(red: 0.45, green: 0.74, blue: 1.0)
        let delegatedTotal = delegatedUpcoming.count + delegatedPast.count

        return HStack(spacing: 0) {
            // Mine tab
            Button {
                if showingDelegated { Haptics.selection() }
                withAnimation(.standard) { showingDelegated = false }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "car").font(.system(size: 12))
                    Text(L10n.myBookings)
                        .font(.system(size: 14, weight: .semibold))
                    if !showingDelegated && !myUpcoming.isEmpty {
                        Text("\(myUpcoming.count)")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppConfig.onAccent.opacity(0.25))
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(!showingDelegated ? AppConfig.onAccent : AppConfig.subtleGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(!showingDelegated ? AppConfig.accent : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            // For Others tab
            Button {
                if !showingDelegated { Haptics.selection() }
                withAnimation(.standard) { showingDelegated = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2").font(.system(size: 12))
                    Text(L10n.delegatedBookings)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if showingDelegated && delegatedTotal > 0 {
                        Text("\(delegatedTotal)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(red: 19/255, green: 31/255, blue: 0/255).opacity(0.25))
                            .clipShape(Capsule())
                    } else if !showingDelegated && delegatedTotal > 0 {
                        Text("\(delegatedTotal)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(blueAccent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(blueAccent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(showingDelegated ? AppConfig.onAccent : AppConfig.subtleGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(showingDelegated ? AppConfig.accent : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(4)
        .background(AppConfig.surfaceHigh)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Delegated empty state

    private var delegatedEmptyState: some View {
        AppEmptyStateCard(
            icon: "person.2.fill",
            title: L10n.spotsBookedForOthers,
            subtitle: L10n.delegateBooking
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Upcoming card

    private func upcomingCard(_ group: BookingGroup, cardBg: Color) -> some View {
        let booking    = group.representativeBooking
        let isForOther = booking.createdBy == myEmail && booking.email != myEmail
        let isBookedForMe = booking.email == myEmail && booking.createdBy != myEmail

        // Accent colour: green for own, cornflower-blue for delegated
        let accentColor: Color = isForOther ? Color(red: 0.45, green: 0.74, blue: 1.0) : AppConfig.accentFg

        return VStack(spacing: 0) {

            // ── Status bar ───────────────────────────────────────────────
            HStack(spacing: 8) {

                if isForOther {
                    // Delegation indicator — name right in the status bar
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(accentColor)
                    Text("FOR \(booking.user.uppercased())")
                        .font(.system(size: 10, weight: .bold)).tracking(1.5)
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                } else {
                    // Own booking dot + status label
                    if group.isActive {
                        PulsingDot(color: AppConfig.accent, size: 9)
                    } else {
                        Circle()
                            .fill(AppConfig.accent)
                            .frame(width: 9, height: 9)
                    }
                    if group.isActive {
                        Text(L10n.activeNow)
                            .font(.system(size: 10, weight: .bold)).tracking(2)
                            .foregroundStyle(AppConfig.accentFg)
                    } else if group.isRange {
                        Text(L10n.rangeNDays(group.dayCount))
                            .font(.system(size: 10, weight: .bold)).tracking(1.5)
                            .foregroundStyle(Color.blue.opacity(0.85))
                    } else {
                        Text(L10n.upcoming)
                            .font(.system(size: 10, weight: .bold)).tracking(2)
                            .foregroundStyle(AppConfig.accentFg)
                    }
                }

                Spacer()

                // Date chip
                if let end = group.rangeEndDate {
                    HStack(spacing: 4) {
                        Text(group.startDate.formatNaturalShort())
                        Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold))
                        Text(end.formatNaturalShort())
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                } else {
                    Text(booking.richDate)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // ── Spot + details ───────────────────────────────────────────
            HStack(alignment: .center, spacing: 16) {
                Text(group.spotNumber)
                    .font(.system(size: 52, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(accentColor)
                    .minimumScaleFactor(0.5).lineLimit(1)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                        Text("\(group.fromTime) – \(group.toTime)")
                            .font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(.white)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle").font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                        Text(AppConfig.locationName)
                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    if isForOther {
                        // Show recipient's email
                        HStack(spacing: 5) {
                            Image(systemName: "envelope").font(.system(size: 9))
                                .foregroundStyle(accentColor.opacity(0.7))
                            Text(booking.email)
                                .font(.caption).foregroundStyle(accentColor.opacity(0.85))
                                .lineLimit(1).minimumScaleFactor(0.75)
                        }
                    } else if isBookedForMe {
                        delegationBadge(icon: "gift", label: L10n.bookedForYou, color: .orange)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            // ── Day strip (range only) ───────────────────────────────────
            if case .range(let bs, _, _, _) = group {
                dayStrip(bs)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
            }

            // ── Actions ──────────────────────────────────────────────────
            HStack(spacing: 8) {
                actionButton(icon: "square.and.arrow.up", label: L10n.share,
                             style: .ghost) { openShare(group) }
                actionButton(icon: "pencil", label: L10n.edit,
                             style: .ghost) { openEdit(group) }
                actionButton(icon: "xmark",
                             label: group.isRange ? L10n.cancelAll : L10n.cancel,
                             style: .danger) { triggerCancel(group) }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            Group {
                if isForOther {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.35), lineWidth: 1.5)
                }
            }
        )
        .shadow(color: isForOther
                ? Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.12)
                : Color.black.opacity(0.08),
                radius: 12, y: 4)
    }

    // MARK: - Action button helper

    private enum ActionButtonStyle { case ghost, danger }

    private func actionButton(icon: String, label: String,
                               style: ActionButtonStyle,
                               action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(style == .danger
                        ? AppConfig.spotOccupied.opacity(0.30)
                        : .white.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Day strip

    private func dayStrip(_ bookings: [Booking]) -> some View {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "d"
        let weekFmt = DateFormatter()
        weekFmt.dateFormat = "EEE"
        weekFmt.locale = LanguageManager.shared.language == .czech
            ? Locale(identifier: "cs_CZ") : Locale(identifier: "en_GB")
        let today = Calendar.current.startOfDay(for: Date())

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(bookings) { b in
                    let isPast   = b.date < today
                    let isActive = Calendar.current.isDateInToday(b.date)
                    VStack(spacing: 1) {
                        Text(dayFmt.string(from: b.date))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                isActive ? AppConfig.onAccent
                                : isPast  ? .white.opacity(0.25)
                                :           .white.opacity(0.85)
                            )
                        Text(weekFmt.string(from: b.date).uppercased())
                            .font(.system(size: 8, weight: .semibold)).tracking(0.3)
                            .foregroundStyle(
                                isActive ? AppConfig.onAccent.opacity(0.7)
                                : isPast  ? .white.opacity(0.15)
                                :           .white.opacity(0.35)
                            )
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        isActive ? AppConfig.accent
                        : isPast  ? Color.white.opacity(0.05)
                        :           Color.white.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
    }

    // MARK: - Past card

    private func pastCard(_ group: BookingGroup) -> some View {
        let booking    = group.representativeBooking
        let isForOther = booking.createdBy == myEmail && booking.email != myEmail

        let blueAccent = Color(red: 0.45, green: 0.74, blue: 1.0)

        return HStack(spacing: 14) {
            // Spot badge — blue tint for delegated
            Text(group.spotNumber)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(isForOther ? blueAccent.opacity(0.8) : AppConfig.subtleGray)
                .frame(width: 50, height: 50)
                .background(isForOther
                            ? Color(red: 0.05, green: 0.09, blue: 0.26)
                            : AppConfig.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                if let end = group.rangeEndDate {
                    Text("\(group.startDate.formatNaturalShort()) – \(end.formatNaturalShort())")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(AppConfig.subtleGray)
                    Text("\(group.dayCount) days · \(booking.fromTime)–\(booking.toTime)")
                        .font(.caption.monospacedDigit()).foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                } else {
                    Text(booking.richDate)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(AppConfig.subtleGray)
                    HStack(spacing: 5) {
                        Image(systemName: "clock").font(.caption2)
                        Text("\(booking.fromTime)–\(booking.toTime)").font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                }
                if isForOther {
                    HStack(spacing: 5) {
                        Image(systemName: "person.badge.plus").font(.system(size: 9))
                        Text(booking.user)
                            .font(.caption).fontWeight(.semibold)
                    }
                    .foregroundStyle(blueAccent.opacity(0.8))
                }
            }

            Spacer()

            Image(systemName: isForOther
                  ? "person.badge.plus"
                  : group.isRange ? "calendar.badge.checkmark" : "checkmark.circle")
                .font(.body)
                .foregroundStyle(isForOther
                                 ? blueAccent.opacity(0.4)
                                 : group.isRange ? Color.blue.opacity(0.3) : AppConfig.subtleGray.opacity(0.3))
        }
        .padding(16)
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            Group {
                if isForOther {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(blueAccent.opacity(0.2), lineWidth: 1)
                }
            }
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateCard()
    }

    // MARK: - Swipe to cancel modifier

}

// MARK: - EmptyStateCard

private struct EmptyStateCard: View {
    var body: some View {
        AppEmptyStateCard(
            icon: "car.side",
            title: L10n.noUpcomingBookings,
            subtitle: "The lot is wide open — grab your spot!",
            actionTitle: "Book a Spot",
            actionIcon: "plus"
        ) {
            NotificationCenter.default.post(name: .triggerBookingSheet, object: nil)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - SwipeToCancelModifier

private struct SwipeToCancelModifier: ViewModifier {
    let onCancel: () -> Void
    @State private var offset: CGFloat = 0
    @State private var activated = false
    private let threshold: CGFloat = 72

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Red reveal background
            RoundedRectangle(cornerRadius: 20)
                .fill(AppConfig.spotOccupied)
                .overlay(alignment: .trailing) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.trailing, 22)
                }
                .opacity(offset < -8 ? 1 : 0)

            content
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppConfig.spotOccupied.opacity(activated ? 0.15 : 0))
                        .allowsHitTesting(false)
                )
                .scaleEffect(activated ? 0.97 : 1.0, anchor: .leading)
                .animation(.quick, value: activated)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .onChanged { v in
                            let h = v.translation.width
                            let vert = abs(v.translation.height)
                            guard h < 0, abs(h) > vert * 1.1 else { return }
                            offset = max(h * 0.65, -120)
                            if !activated && offset < -threshold {
                                activated = true
                                Haptics.selection()
                            }
                        }
                        .onEnded { v in
                            if v.translation.width < -threshold {
                                withAnimation(.standard) {
                                    offset = -500
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                    offset = 0; activated = false; onCancel()
                                }
                            } else {
                                withAnimation(.standard) {
                                    offset = 0; activated = false
                                }
                            }
                        }
                )
        }
    }
}

extension View {
    func swipeToCancel(action: @escaping () -> Void) -> some View {
        modifier(SwipeToCancelModifier(onCancel: action))
    }
}

// MARK: - (MyBookingsView continued)

extension MyBookingsView {
    // MARK: - Delegation badge

    private func delegationBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func triggerCancel(_ group: BookingGroup) {
        switch group {
        case .single(let b):
            bookingToCancel = b
            showingCancelAlert = true
        case .range(let bs, _, _, _):
            cancelGroupBookings = bs
            showingGroupCancelAlert = true
        }
    }

    private func openEdit(_ group: BookingGroup) {
        switch group {
        case .single(let b):
            // Single booking — use the standard sheet(item:) flow
            bookingToEdit = b
        case .range(let bs, let spot, let start, let end):
            // Range booking — present RangeEditSheet via UIKit to avoid nested-sheet blank bug
            let booking = group.representativeBooking
            let editView = RangeEditSheet(
                groupBookings: bs,
                spot: spot,
                startDate: start,
                endDate: end,
                timeFrom: booking.fromTime,
                timeTo:   booking.toTime,
                personName:  booking.user,
                personEmail: booking.email
            )
            .environmentObject(bookingManager)
            presentViaUIKit(editView)
        }
    }

    private func openShare(_ group: BookingGroup) {
        let shareView = BookingShareSheet(
            booking: group.representativeBooking,
            rangeEndDate: group.rangeEndDate
        )
        presentViaUIKit(shareView, detents: [.medium(), .large()])
    }

    private func presentViaUIKit(_ view: some View,
                                  style: UIModalPresentationStyle = .pageSheet,
                                  detents: [UISheetPresentationController.Detent] = [.large()]) {
        let hosting = UIHostingController(rootView: AnyView(view))
        hosting.modalPresentationStyle = style
        if let sheet = hosting.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
        }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(hosting, animated: true)
    }
}

// MARK: - RangeEditSheet

/// Edit a multi-day range booking: change spot, dates, or time for every day at once.
/// On Save: cancels all existing bookings in the range, then recreates with new params.
struct RangeEditSheet: View {
    @EnvironmentObject var bookingManager: BookingManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared

    let groupBookings: [Booking]
    let spot:          String

    // Editable state
    @State var startDate:   Date
    @State var endDate:     Date
    @State var timeFrom:    String
    @State var timeTo:      String
    let personName:  String
    let personEmail: String

    @State private var selectedSpot: ParkingSpot?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess  = false

    private var dayCount: Int {
        (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Person info ──────────────────────────────────
                        HStack(spacing: 14) {
                            Image(systemName: "person")
                                .font(.title3)
                                .foregroundStyle(AppConfig.accentFg)
                                .frame(width: 44, height: 44)
                                .background(AppConfig.accent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(personName)
                                    .font(.headline).foregroundStyle(AppConfig.darkText)
                                Text(personEmail)
                                    .font(.caption).foregroundStyle(AppConfig.subtleGray)
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)

                        // ── Spot ─────────────────────────────────────────
                        sectionCard(title: L10n.spot, icon: "car.fill") {
                            Menu {
                                ForEach(bookingManager.parkingSpots
                                    .filter { !AppConfig.blockedSpotIDs.contains($0.id) }) { sp in
                                    Button(sp.label) { selectedSpot = sp }
                                }
                            } label: {
                                HStack {
                                    Text(selectedSpot?.label ?? spot)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption).foregroundStyle(AppConfig.subtleGray)
                                }
                                .padding(14)
                                .background(AppConfig.surfaceLow)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        // ── Date range ───────────────────────────────────
                        sectionCard(title: L10n.dateRange, icon: "calendar.badge.clock") {
                            VStack(spacing: 14) {
                                HStack {
                                    Text(L10n.from)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(AppConfig.subtleGray).frame(width: 44, alignment: .leading)
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.compact).tint(AppConfig.accentFg)
                                        .onChange(of: startDate) { _, v in if endDate < v { endDate = v } }
                                }
                                Divider().overlay(AppConfig.outlineVariant)
                                HStack {
                                    Text(L10n.to)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(AppConfig.subtleGray).frame(width: 44, alignment: .leading)
                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .datePickerStyle(.compact).tint(AppConfig.accentFg)
                                }

                                // Summary
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.checkmark").font(.caption)
                                        .foregroundStyle(AppConfig.accentFg)
                                    Text("\(dayCount) days · \(startDate.formatNaturalShort()) → \(endDate.formatNaturalShort())")
                                        .font(.caption).fontWeight(.semibold).foregroundStyle(AppConfig.darkText)
                                    Spacer()
                                }
                                .padding(10)
                                .background(AppConfig.accent.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        // ── Time ─────────────────────────────────────────
                        sectionCard(title: L10n.time, icon: "clock.fill") {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.from).font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Picker("From", selection: $timeFrom) {
                                        ForEach(AppConfig.availableTimeSlots, id: \.self) { t in
                                            Text(t).tag(t)
                                        }
                                    }
                                    .pickerStyle(.menu).tint(AppConfig.darkText)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(AppConfig.surfaceLow)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                Image(systemName: "arrow.right").font(.caption)
                                    .foregroundStyle(AppConfig.subtleGray)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.to).font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Picker("To", selection: $timeTo) {
                                        ForEach(AppConfig.availableTimeSlots, id: \.self) { t in
                                            Text(t).tag(t)
                                        }
                                    }
                                    .pickerStyle(.menu).tint(AppConfig.darkText)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(AppConfig.surfaceLow)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        // ── Error ────────────────────────────────────────
                        if let err = errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(err).font(.subheadline).foregroundStyle(AppConfig.darkText)
                            }
                            .padding(14)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // ── Save ─────────────────────────────────────────
                        Button {
                            Task { await saveChanges() }
                        } label: {
                            HStack(spacing: 10) {
                                if isSubmitting {
                                    ProgressView().tint(AppConfig.onAccent).scaleEffect(0.85)
                                } else {
                                    Image(systemName: "checkmark.circle.fill").font(.title3)
                                }
                                Text(isSubmitting ? L10n.saving : L10n.saveAllDays(dayCount))
                                    .font(.body.weight(.bold))
                            }
                            .foregroundStyle(timeFrom < timeTo ? AppConfig.onAccent : AppConfig.subtleGray)
                            .frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(timeFrom < timeTo ? AppConfig.accent : AppConfig.surfaceHigh)
                            .clipShape(Capsule())
                        }
                        .disabled(timeFrom >= timeTo || isSubmitting)
                        .buttonStyle(ScaleButtonStyle())

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                }

                // Success overlay
                if showSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64)).foregroundStyle(AppConfig.activeGreen)
                        Text(L10n.rangeUpdated)
                            .font(.title2).fontWeight(.bold).foregroundStyle(AppConfig.darkText)
                        Text(L10n.daysRebooked(dayCount))
                            .font(.subheadline).foregroundStyle(AppConfig.subtleGray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .transition(.opacity)
                }
            }
            .navigationTitle(L10n.editRange)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundStyle(AppConfig.darkText)
                }
            }
        }
        .onAppear {
            selectedSpot = AppConfig.allParkingSpots.first(where: { $0.label == spot })
        }
    }

    // MARK: - Save

    private func saveChanges() async {
        guard timeFrom < timeTo else { return }
        isSubmitting = true
        errorMessage = nil

        guard let newSpot = selectedSpot ?? AppConfig.allParkingSpots.first(where: { $0.label == spot }) else {
            errorMessage = L10n.pleaseSelectSpot
            isSubmitting = false
            return
        }

        do {
            // 1. Cancel all existing bookings in this range
            for b in groupBookings {
                await bookingManager.cancelBooking(b)
            }
            // 2. Recreate with new params (range, spot, time)
            try await bookingManager.createBooking(
                spotID:    newSpot.id,
                spotLabel: newSpot.label,
                userEmail: personEmail,
                userName:  personName,
                dateFrom:  startDate,
                dateTo:    endDate,
                timeFrom:  timeFrom,
                timeTo:    timeTo
            )

            withAnimation(.emphasis) { showSuccess = true }
            Haptics.notify(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }

        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }

    // MARK: - Section card helper

    private func sectionCard<Content: View>(title: String, icon: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(AppConfig.accentFg)
                Text(title).font(.headline).foregroundStyle(AppConfig.darkText)
            }
            content()
        }
        .padding(18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
    }
}

#Preview {
    MyBookingsView()
        .environmentObject(BookingManager())
}
