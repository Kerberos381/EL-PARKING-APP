//
//  HomeView.swift
//  EL PARKING APP
//
//  Home screen: greeting, hero booking, book button, garage status, news bento, my bookings link.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    enum ScreenMode {
        case home
        case infoHub
    }

    private enum HomeFeedFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case announcements = "Announcements"
        case info = "Info"
    }

    @EnvironmentObject var bookingManager:       BookingManager
    @EnvironmentObject var authManager:          AuthManager
    @EnvironmentObject var announcementsManager: AnnouncementsManager
    @EnvironmentObject var deepLinkManager:      DeepLinkManager
    @EnvironmentObject var infoManager:          InfoManager
    @Environment(\.openURL) private var openURL
    @ObservedObject private var lang = LanguageManager.shared
    @State private var showingBookingSheet  = false
    @Namespace private var homeZoomNS
    @State private var selectedDate         = Date.smartDefaultDate()
    @State private var bookingToEdit:         Booking?
    @State private var bookingToCancel:       Booking?
    @State private var showCancelAlert        = false
    @State private var navigateToMyBookings  = false
    @State private var showCancelSuccess      = false
    @State private var cancelledBooking: (spotNumber: String, date: String, from: String, to: String)?
    @State private var heroVisible            = false
    @State private var didPrefetchLikelyNextScreens = false
    @State private var expandedAnnouncementIDs: Set<String> = []
    @State private var selectedAnnouncement: Announcement?
    @State private var selectedInfoItem: InfoItem?
    @State private var selectedHomeFeedFilter: HomeFeedFilter = .all
    @State private var lastAnnouncementsRefreshAt = Date()
    @AppStorage("readAnnouncementIDs") private var readAnnouncementIDsRaw = ""
    @AppStorage("homeStyle") private var homeStyleRaw: String = "roomy"
    @AppStorage("favouriteSpotIDs") private var favouriteSpotIDsStr: String = ""
    @State private var favoriteSpotForBooking: ParkingSpot?
    @State private var tilesVisible = false
    private let screenMode: ScreenMode

    init(screenMode: ScreenMode = .home) {
        self.screenMode = screenMode
    }

    private var todayBooking: Booking? {
        bookingManager.getTodayBooking(for: bookingManager.currentUserEmail)
    }

    private var nextUpcoming: Booking? {
        bookingManager.getNextUpcomingBooking(for: bookingManager.currentUserEmail)
    }

    private var displayedBooking: Booking? {
        todayBooking ?? nextUpcoming
    }

    private var readAnnouncementIDs: Set<String> {
        Set(readAnnouncementIDsRaw.split(separator: ",").map(String.init))
    }

    private var hasUpcomingOrActiveBooking: Bool {
        if let booking = displayedBooking { return !booking.isPast }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            if screenMode == .home {
                                // News lives in the Info tab for everyone now;
                                // home is bookings + vehicle only.
                                // The big greeting is a design staple — same in both layouts.
                                HStack(alignment: .top) {
                                    Text(L10n.helloGreeting(
                                        bookingManager.currentFirstName,
                                        preferredVocative: bookingManager.preferredVocative
                                    ))
                                        .font(.system(size: 56, weight: .bold, design: .default))
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .foregroundStyle(AppConfig.darkText)

                                    Spacer()

                                    Color.clear
                                        .frame(width: 44, height: 44)
                                        .padding(.top, 8)
                                }
                                .padding(.horizontal)

                                heroSection
                                    .id("home_hero")
                                    .offset(y: heroVisible ? 0 : 28)
                                    .opacity(heroVisible ? 1 : 0)

                                if homeStyleRaw == "compact" {
                                    compactTileRow
                                } else {
                                    HStack(spacing: 10) {
                                        myBookingsQuickButton
                                            .id("home_my_bookings")
                                        if hasUpcomingOrActiveBooking {
                                            bookSpotQuickButton
                                                .id("home_book")
                                        }
                                    }
                                    .padding(.horizontal)
                                }

                                vehicleCard

                                // Footer logo
                                footerLogo
                            } else {
                                infoHubScreen
                            }
                        }
                        .padding(.bottom, 100)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .refreshable {
                        await refreshData()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if screenMode == .home {
                    withAnimation(.motionSheet.delay(0.1)) {
                        heroVisible = true
                    }
                    tilesVisible = true
                }
                if !didPrefetchLikelyNextScreens {
                    didPrefetchLikelyNextScreens = true
                    Task(priority: .utility) { await prefetchLikelyNextScreens() }
                }
            }
            .navigationDestination(isPresented: $navigateToMyBookings) {
                MyBookingsView()
            }
            .fullScreenCover(item: $favoriteSpotForBooking) { spot in
                BookingSheet(
                    preselectedSpot: spot,
                    preselectedDate: bestQuickBookDate(for: spot),
                    isForOthers: false
                )
                .navigationTransition(.zoom(sourceID: "home-quick-spot", in: homeZoomNS))
            }
            .fullScreenCover(isPresented: $showingBookingSheet) {
                BookingSheet(
                    preselectedSpot: nil,
                    isForOthers: false
                )
                .navigationTransition(.zoom(sourceID: "home-book-tile", in: homeZoomNS))
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
            .fullScreenCover(item: $bookingToEdit) { booking in
                BookingSheet(
                    preselectedSpot: AppConfig.allParkingSpots.first(where: { $0.label == booking.spot }),
                    isForOthers: booking.email != bookingManager.currentUserEmail,
                    editingBooking: booking
                )
            }
            .sheet(item: AppConfig.enableHomeAnnouncementDetailSheet ? $selectedAnnouncement : .constant(nil)) { item in
                announcementDetailSheet(item)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(24)
                    .interactiveDismissDisabled(false)
            }
            .sheet(item: AppConfig.enableHomeInfoDetailSheet ? $selectedInfoItem : .constant(nil)) { item in
                infoDetailSheet(item)
            }
            .task(id: deepLinkTaskID) {
                processPendingDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                ToastManager.shared.performUndo()
            }
            .onReceive(NotificationCenter.default.publisher(for: .triggerBookingSheet)) { _ in
                showingBookingSheet = true
            }
        }
    }

    private func refreshData() async {
        async let bookingsRefresh: Void = bookingManager.refreshData()
        async let announcementsRefresh: Void = announcementsManager.refresh()
        async let infoRefresh: Void = infoManager.refresh()
        _ = await (bookingsRefresh, announcementsRefresh, infoRefresh)
        lastAnnouncementsRefreshAt = Date()
    }

    private func confirmCancelFromHome() {
        guard let booking = bookingToCancel else { return }
        showCancelAlert = false
        Haptics.destructive()
        let info = (spotNumber: booking.spotNumber, date: booking.naturalDate, from: booking.fromTime, to: booking.toTime)
        Task {
            let error = await bookingManager.cancelBooking(booking)
            if error == nil {
                Haptics.notify(.success)
                cancelledBooking = info
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { showCancelSuccess = true }
                ToastManager.shared.showUndo(
                    message: "Spot \(booking.spotNumber) cancelled"
                ) {
                    Task {
                        try? await bookingManager.createBooking(
                            spotID: booking.spotNumber, spotLabel: booking.spot,
                            userEmail: booking.email, userName: booking.user,
                            dateFrom: booking.date, dateTo: booking.date,
                            timeFrom: booking.fromTime, timeTo: booking.toTime
                        )
                    }
                }
            } else {
                Haptics.notify(.error)
            }
        }
    }

    private func prefetchLikelyNextScreens() async {
        // Warm data commonly needed after Home: bookings list + announcement/info sections.
        await refreshData()
    }

    private var deepLinkTaskID: String {
        "\(deepLinkManager.pendingRoute?.id ?? "none"):\(bookingManager.bookings.count)"
    }

    private func processPendingDeepLink() {
        guard let route = deepLinkManager.pendingRoute else { return }

        switch route {
        case .book:
            showingBookingSheet = true
            deepLinkManager.clear()

        case .edit(let bookingID):
            guard let booking = bookingManager.bookingByID(bookingID) else {
                clearUnavailableRouteIfNeeded()
                return
            }
            bookingToEdit = booking
            deepLinkManager.clear()

        case .cancel(let bookingID):
            guard let booking = bookingManager.bookingByID(bookingID) else {
                clearUnavailableRouteIfNeeded()
                return
            }
            bookingToCancel = booking
            showCancelAlert = true
            deepLinkManager.clear()

        case .myBookings:
            navigateToMyBookings = true
            deepLinkManager.clear()

        case .navigate:
            if let url = URL(string: AppConfig.googleMapsURL) {
                openURL(url)
            }
            deepLinkManager.clear()

        case .adminDashboard:
            deepLinkManager.clear()
        }
    }

    private func clearUnavailableRouteIfNeeded() {
        guard !bookingManager.currentUserEmail.isEmpty else { return }
        guard !bookingManager.bookings.isEmpty else { return }
        deepLinkManager.clear()
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        if let booking = displayedBooking, !booking.isPast {
            heroCard(booking)
        } else {
            invitingEmptyHero
        }
    }

    /// Empty-state hero: the user's own car waiting in a dashed parking bay,
    /// inviting the first booking of the day.
    private var invitingEmptyHero: some View {
        VStack(spacing: 0) {
            Group {
                if let user = authManager.currentUser,
                   !user.carDescription.isEmpty || !user.vehicleMiniaturePresetID.isEmpty {
                    VehicleMiniatureView(
                        carType: user.carType,
                        colorHex: user.carColor,
                        description: user.carDescription,
                        presetID: user.vehicleMiniaturePresetID.isEmpty
                            ? nil : user.vehicleMiniaturePresetID
                    )
                    .frame(width: 180, height: 100)
                } else {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 180, height: 100)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(.white.opacity(0.18))
            )
            .padding(.top, 26)
            .accessibilityHidden(true)

            Text(L10n.emptyHeroTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
                .padding(.horizontal, 20)

            Text(L10n.spotsAvailable(freeSpotsToday))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 4)

            Button {
                Haptics.selection()
                showingBookingSheet = true
            } label: {
                Text(L10n.bookASpot)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppConfig.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppConfig.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(AppConfig.obsidian)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .cardShadow()
        .padding(.horizontal)
    }

    // MARK: - Hero Card (Dark Obsidian — both today and upcoming)

    private func heroCard(_ booking: Booking) -> some View {
        let isActive = booking.isToday
        return VStack(spacing: 0) {
            // Status bar
            HStack(spacing: 8) {
                if isActive {
                    PulsingDot(color: AppConfig.accent)
                } else {
                    Circle()
                        .fill(AppConfig.accentFg.opacity(0.55))
                        .frame(width: 12, height: 12)
                }

                Text(isActive ? L10n.activeNow : L10n.upcoming)
                    .font(.caption.bold())
                    .foregroundStyle(AppConfig.accentFg)

                Spacer()

                Text(booking.richDate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Giant spot number
            HStack(alignment: .center, spacing: 20) {
                Text(booking.spotNumber)
                    .font(.system(size: 72, weight: .black, design: .rounded).monospacedDigit())
                    // Calm: soft translucent white reads better on the forest card.
                    .foregroundStyle(AppConfig.isCalmPalette
                        ? AnyShapeStyle(Color.white.opacity(0.88))
                        : AnyShapeStyle(AppConfig.accentFg))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.motionStandard, value: booking.spotNumber)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(booking.fromTime) – \(booking.toTime)")
                            .font(.headline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(AppConfig.locationName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    if booking.isBookedByOther {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.caption2)
                            Text("\(L10n.bookedBy) \(booking.createdBy)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            // Glass pill action buttons — real Liquid Glass over the obsidian card
            GlassEffectContainer {
            HStack(spacing: 12) {
                if let url = URL(string: AppConfig.googleMapsURL) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "location")
                            Text(L10n.navigate)
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .glassEffect(.frosted.interactive(), in: Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button {
                    Haptics.selection()
                    bookingToEdit = booking
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text(L10n.edit)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .glassEffect(.frosted.interactive(), in: Capsule())
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    Haptics.selection()
                    bookingToCancel = booking
                    showCancelAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text(L10n.cancel)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .glassEffect(.regular.tint(AppConfig.spotOccupied.opacity(0.35)).interactive(), in: Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .confirmationDialog(L10n.cancelBooking, isPresented: $showCancelAlert, titleVisibility: .visible) {
                    Button(L10n.cancelBooking, role: .destructive) {
                        confirmCancelFromHome()
                    }
                    Button(L10n.keep, role: .cancel) {}
                } message: {
                    if let booking = bookingToCancel {
                        Text(L10n.cancelSpotOnDate(spot: booking.spotShortCode, date: booking.naturalDate))
                    }
                }
            }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .background(AppConfig.obsidian)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .cardShadow()
        .squishyCard()
        .padding(.horizontal)
    }

    private var freeSpotsToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return bookingManager.availableSpotsCount(on: today)
    }


    // MARK: - Compact Home (pill style)

    private var firstFavoriteSpot: ParkingSpot? {
        let ids = favouriteSpotIDsStr.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        guard let first = ids.first else { return nil }
        return bookingManager.parkingSpots.first { $0.id == first }
    }

    /// Most recently booked spot by the current user (favorite fallback).
    private var lastBookedSpot: ParkingSpot? {
        let mine = bookingManager.bookings
            .filter { $0.email == bookingManager.currentUserEmail }
            .sorted { $0.date > $1.date }
        guard let last = mine.first else { return nil }
        return bookingManager.parkingSpots.first {
            bookingManager.normalizedSpotKey($0.label) == bookingManager.normalizedSpotKey(last.spot)
        }
    }

    private var quickSpotTarget: (spot: ParkingSpot, isFavorite: Bool)? {
        if let fav = firstFavoriteSpot { return (fav, true) }
        if let last = lastBookedSpot { return (last, false) }
        return nil
    }

    /// Prefer the first sensible date where the quick-booked spot is free:
    /// the sheet's default date, else the following day. Falls back to the
    /// default (the banner then shows the unavailable state inline).
    private func bestQuickBookDate(for spot: ParkingSpot) -> Date {
        let base = Date.smartDefaultDate()
        let candidates = [base, Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base]
        for date in candidates {
            if bookingManager.isSpotAvailable(spotLabel: spot.label, on: date) {
                return date
            }
        }
        return base
    }

    private func isSpotFreeToday(_ spot: ParkingSpot) -> Bool {
        let todays = bookingManager.getBookingsForDate(Date())
        let key = bookingManager.normalizedSpotKey(spot.label)
        return !todays.contains { bookingManager.normalizedSpotKey($0.spot) == key }
    }

    private var compactTileRow: some View {
        HStack(spacing: 10) {
            // Big accent tile — Book a Spot (n free)
            Button {
                Haptics.selection()
                showingBookingSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.bookASpot)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppConfig.onAccent)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(L10n.freeCount(freeSpotsToday))
                        .font(.subheadline)
                        .foregroundStyle(AppConfig.onAccent.opacity(0.85))
                        .contentTransition(.numericText())
                    Spacer()
                    HStack {
                        Spacer()
                        circleArrow(on: .white, tint: AppConfig.obsidian)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                .background(AppConfig.accent)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(BouncyTileStyle())
            .modifier(cascadeIn(0))
            .matchedTransitionSource(id: "home-book-tile", in: homeZoomNS)

            VStack(spacing: 10) {
                smallTile(title: L10n.myBookings) {
                    navigateToMyBookings = true
                }
                .modifier(cascadeIn(1))
                smallTile(
                    title: quickSpotTarget.map {
                        "\($0.isFavorite ? L10n.favoriteShort : L10n.lastShort) \($0.spot.id)"
                    } ?? L10n.favoriteShort
                ) {
                    if let target = quickSpotTarget {
                        if !isSpotFreeToday(target.spot) {
                            ToastManager.shared.show(
                                L10n.spotTakenToday(target.spot.id), style: .warning
                            )
                        }
                        favoriteSpotForBooking = target.spot
                    } else {
                        showingBookingSheet = true
                    }
                }
                .modifier(cascadeIn(2))
                .matchedTransitionSource(id: "home-quick-spot", in: homeZoomNS)
            }
        }
        .padding(.horizontal)
    }

    private func smallTile(title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 61, alignment: .leading)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(BouncyTileStyle())
    }

    /// Staggered entrance for home tiles — rise + fade with a small spring.
    private func cascadeIn(_ index: Int) -> some ViewModifier {
        CascadeIn(visible: tilesVisible, index: index)
    }

    private func circleArrow(on background: Color, tint: Color) -> some View {
        Image(systemName: "arrow.up.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(background)
            .clipShape(Circle())
    }

    // MARK: - Your Vehicle card

    private var hasVehicleOnFile: Bool {
        guard let user = authManager.currentUser else { return false }
        return !user.carDescription.isEmpty || !user.vehicleMiniaturePresetID.isEmpty
    }

    private var vehicleCard: some View {
        Button {
            Haptics.selection()
            NotificationCenter.default.post(name: .navigateToSettingsTab, object: nil)
        } label: {
            HStack(spacing: 14) {
                Group {
                    if hasVehicleOnFile, let user = authManager.currentUser {
                        VehicleMiniatureView(
                            carType: user.carType,
                            colorHex: user.carColor,
                            description: user.carDescription,
                            presetID: user.vehicleMiniaturePresetID.isEmpty
                                ? nil : user.vehicleMiniaturePresetID,
                            useFastRendering: true
                        )
                    } else {
                        Image(systemName: "car.side.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .frame(width: 184, height: 110)
                // Parallax: the car drifts gently against scroll for depth.
                .visualEffect { content, proxy in
                    let y = proxy.frame(in: .scrollView).minY
                    return content.offset(y: max(-8, min(8, -y * 0.05)))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(hasVehicleOnFile ? L10n.yourVehicle : L10n.addYourVehicle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                    if hasVehicleOnFile, let user = authManager.currentUser {
                        Text(user.carDescription.isEmpty ? user.carType : user.carDescription)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        if !user.registrationPlate.isEmpty {
                            Text(user.registrationPlate)
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }

                Spacer()

                circleArrow(on: .white.opacity(0.18), tint: .white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(AppConfig.obsidian)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .cardShadow()
        }
        .buttonStyle(.plain)
        .squishyCard()
        .modifier(cascadeIn(3))
        .padding(.horizontal)
        .accessibilityLabel(L10n.yourVehicle)
    }

    // MARK: - Home Quick Actions

    private var myBookingsQuickButton: some View {
        Button {
            Haptics.selection()
            navigateToMyBookings = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.accentFg)
                Text(L10n.myBookings)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(AppConfig.cardBg)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppConfig.separatorSoft, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var bookSpotQuickButton: some View {
        Button {
            Haptics.selection()
            showingBookingSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "car")
                    .font(.subheadline.weight(.semibold))
                Text(L10n.bookWithCount(freeSpotsToday))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(AppConfig.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(AppConfig.accent)
            .clipShape(Capsule())
            .shadow(color: AppConfig.accent.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Home News + Info Hub

    private var pinnedAnnouncements: [Announcement] {
        announcementsManager.activeAnnouncements
            .filter { $0.isPinned }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var nonPinnedAnnouncements: [Announcement] {
        announcementsManager.activeAnnouncements
            .filter { !$0.isPinned }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedInfoItems: [InfoItem] {
        infoManager.items.sorted { $0.createdAt > $1.createdAt }
    }

    private var allAnnouncementsNewest: [Announcement] {
        announcementsManager.activeAnnouncements.sorted { $0.createdAt > $1.createdAt }
    }




    private var homeNewsAndInfoHub: some View {
        if !bookingManager.isAdmin {
            return AnyView(nonAdminPinnedHomeSection)
        }

        let hasAnything = !pinnedAnnouncements.isEmpty
            || !nonPinnedAnnouncements.isEmpty
            || !sortedInfoItems.isEmpty

        // Single merged feed: pinned first, then updates, then info cards.
        return AnyView(VStack(spacing: 14) {
            if !pinnedAnnouncements.isEmpty {
                announcementsGroupedView(items: pinnedAnnouncements)
                    .id("home_announcements_pinned")
            }

            if !nonPinnedAnnouncements.isEmpty {
                announcementsGroupedView(items: nonPinnedAnnouncements)
                    .id("home_announcements_updates")
            }

            if !sortedInfoItems.isEmpty {
                infoSectionAppleStyle(items: sortedInfoItems)
                    .id("home_info_updates")
            }

            if !hasAnything {
                announcementsEmptyState
            }
        })
    }

    private var nonAdminPinnedHomeSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "pin.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                Text("Pinned")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
                Spacer()
            }
            .padding(.horizontal)

            if pinnedAnnouncements.isEmpty {
                AppEmptyStateCard(
                    icon: "pin",
                    title: "Pinned Updates",
                    subtitle: "No pinned news right now"
                )
                .padding(.horizontal)
            } else {
                announcementsGroupedView(items: pinnedAnnouncements)
                    .id("home_announcements_pinned_only")
            }
        }
    }

    private var infoHubScreen: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                Text("Info")
                    .font(.system(size: 46, weight: .bold, design: .default))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(AppConfig.darkText)
                Spacer()
            }
            .padding(.horizontal)

            nonAdminInfoHubFeed
        }
    }

    private var filteredInfoHubAnnouncements: [Announcement] {
        switch selectedHomeFeedFilter {
        case .all, .announcements:
            return allAnnouncementsNewest
        case .unread:
            return allAnnouncementsNewest.filter { !isAnnouncementRead($0) }
        case .info:
            return []
        }
    }

    private var filteredInfoHubInfoItems: [InfoItem] {
        switch selectedHomeFeedFilter {
        case .all, .info:
            return sortedInfoItems
        case .unread, .announcements:
            return []
        }
    }

    private var nonAdminInfoHubFeed: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([HomeFeedFilter.all, .unread, .announcements, .info], id: \.self) { filter in
                        Button {
                            Haptics.selection()
                            withAnimation(.quick) { selectedHomeFeedFilter = filter }
                        } label: {
                            Text(filter.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedHomeFeedFilter == filter ? AppConfig.darkText : AppConfig.subtleGray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(selectedHomeFeedFilter == filter ? AppConfig.cardBg : AppConfig.surfaceLow)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedHomeFeedFilter == filter ? AppConfig.separatorStrong : AppConfig.separatorSoft, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            if !filteredInfoHubAnnouncements.isEmpty {
                announcementsGroupedView(items: filteredInfoHubAnnouncements)
                    .id("info_tab_announcements")
            }

            if !filteredInfoHubInfoItems.isEmpty {
                infoSectionAppleStyle(items: filteredInfoHubInfoItems)
                    .id("info_tab_info_cards")
            }

            if filteredInfoHubAnnouncements.isEmpty && filteredInfoHubInfoItems.isEmpty {
                announcementsEmptyState
            }
        }
    }

    // MARK: - Announcements Section

    private var announcementsPrioritySection: some View {
        let items = announcementsManager.activeAnnouncements
        return announcementsGroupedView(items: items)
            .id("home_announcements")
            .animation(AppConfig.enableHomeMotionConsistency ? .quick : .standard,
                       value: items.map(\.id).joined(separator: "|"))
    }

    private var announcementsSection: some View {
        announcementsGroupedView(items: announcementsManager.activeAnnouncements)
    }

    @ViewBuilder
    private func announcementsGroupedView(items: [Announcement]) -> some View {
        if AppConfig.enableHomeAppleAnnouncementsStyle {
            announcementsTodayStyleView(items: items)
        } else {
            // ── Legacy list style (revert: set enableHomeAppleAnnouncementsStyle = false) ──
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "bell.badge")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.subtleGray)
                    Text(L10n.announcements)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                    let unread = unreadAnnouncementCount
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppConfig.darkText.opacity(0.78))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AppConfig.surfaceLow)
                            .clipShape(Capsule())
                    }
                }
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        announcementRow(item)
                        if idx < items.count - 1 { Divider().padding(.leading, 58) }
                    }
                }
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
        }
    }

    private func announcementRow(_ item: Announcement) -> some View {
        HStack(spacing: 12) {
            // Emoji tile
            Text(item.emoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(item.isPinned ? AppConfig.separatorStrong : Color.clear, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if item.isPinned {
                        Circle()
                            .fill(AppConfig.subtleGray.opacity(0.6))
                            .frame(width: 4, height: 4)
                    }
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppConfig.darkText)
                        .lineLimit(1)
                    if isAnnouncementNew(item) {
                        Text("new")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray.opacity(0.75))
                    }
                }
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray)
                        .lineLimit(2)
                }
                Text(item.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 6) {
                if !isAnnouncementRead(item) {
                    Circle()
                        .fill(AppConfig.subtleGray.opacity(0.7))
                        .frame(width: 6, height: 6)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture {
            markAnnouncementRead(item)
            if AppConfig.enableHomeAnnouncementDetailSheet {
                Haptics.selection()
                selectedAnnouncement = item
            }
        }
    }

    // MARK: - Hero Style Announcements (Option B — Apple News "For You" pattern)

    @ViewBuilder
    private func announcementsHeroStyleView(items: [Announcement]) -> some View {
        if items.isEmpty {
            announcementsEmptyState
        } else {
            VStack(alignment: .leading, spacing: 10) {
                // Section header
                HStack(spacing: 7) {
                    Image(systemName: "bell.badge")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.subtleGray)
                    Text(L10n.announcements)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                    let unread = unreadAnnouncementCount
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppConfig.darkText.opacity(0.78))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AppConfig.surfaceLow)
                            .clipShape(Capsule())
                    }
                }

                // Hero card — first announcement
                let hero = items[0]
                announcementHeroCard(hero)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        markAnnouncementRead(hero)
                        if AppConfig.enableHomeAnnouncementDetailSheet {
                            Haptics.selection()
                            selectedAnnouncement = hero
                        }
                    }

                // Compact rows for the remaining items
                if items.count > 1 {
                    VStack(spacing: 0) {
                        ForEach(Array(items.dropFirst().enumerated()), id: \.element.id) { idx, item in
                            announcementCompactRow(item)
                            if idx < items.count - 2 { Divider().padding(.leading, 58) }
                        }
                    }
                    .background(AppConfig.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
        }
    }

    private func announcementHeroCard(_ item: Announcement) -> some View {
        let isRead = isAnnouncementRead(item)
        let isNew  = isAnnouncementNew(item)
        return VStack(alignment: .leading, spacing: 12) {
            // Top row: emoji tile + status badges + relative time + unread dot
            HStack(alignment: .top, spacing: 12) {
                Text(item.emoji)
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(item.isPinned ? AppConfig.separatorStrong : AppConfig.separatorSoft, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if isNew && !isRead {
                            Text("NEW")
                                .font(.caption2.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(AppConfig.onAccent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppConfig.accent)
                                .clipShape(Capsule())
                        }
                        if item.isPinned {
                            Label("Pinned", systemImage: "pin.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppConfig.subtleGray)
                        }
                    }
                    Text(item.createdAt.relativeTime())
                        .font(.caption2)
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                }

                Spacer()

                if !isRead {
                    Circle()
                        .fill(AppConfig.accentFg)
                        .frame(width: 9, height: 9)
                        .padding(.top, 4)
                }
            }

            // Title
            Text(item.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppConfig.darkText)
                .lineLimit(2)

            // Body preview
            if !item.body.isEmpty {
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(AppConfig.subtleGray)
                    .lineLimit(3)
                    .lineSpacing(1)
            }

            // Footer: author + read more
            HStack {
                Text(item.createdBy)
                    .font(.caption2)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.45))
                Spacer()
                HStack(spacing: 3) {
                    Text("Read more")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
            }
        }
        .padding(18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(item.isPinned ? AppConfig.separatorStrong : AppConfig.separatorSoft, lineWidth: 1)
        )
        .cardShadow()
        .opacity(isRead ? 0.72 : 1.0)
        .animation(.standard, value: isRead)
    }

    /// Compact row used for non-hero items in the hero style — relative time + accent unread dot.
    private func announcementCompactRow(_ item: Announcement) -> some View {
        let isRead = isAnnouncementRead(item)
        return HStack(spacing: 12) {
            Text(item.emoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(item.isPinned ? AppConfig.separatorStrong : Color.clear, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppConfig.darkText)
                    .lineLimit(1)
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray)
                        .lineLimit(1)
                }
                Text(item.createdAt.relativeTime())
                    .font(.caption2)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 6) {
                if !isRead {
                    Circle()
                        .fill(AppConfig.accentFg)
                        .frame(width: 6, height: 6)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .opacity(isRead ? 0.72 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            markAnnouncementRead(item)
            if AppConfig.enableHomeAnnouncementDetailSheet {
                Haptics.selection()
                selectedAnnouncement = item
            }
        }
        .animation(.standard, value: isRead)
    }

    private var unreadAnnouncementCount: Int {
        announcementsManager.activeAnnouncements.filter { !isAnnouncementRead($0) }.count
    }

    private func isAnnouncementRead(_ item: Announcement) -> Bool {
        readAnnouncementIDs.contains(item.id)
    }

    private func isAnnouncementNew(_ item: Announcement) -> Bool {
        item.createdAt > Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date.distantPast
    }

    private func markAnnouncementRead(_ item: Announcement) {
        var ids = readAnnouncementIDs
        ids.insert(item.id)
        readAnnouncementIDsRaw = ids.sorted().joined(separator: ",")
    }



    private var announcementsEmptyState: some View {
        AppEmptyStateCard(
            icon: "megaphone",
            title: L10n.announcements,
            subtitle: "No new updates",
            footnote: "Last sync \(lastAnnouncementsRefreshAt.formatted(date: .omitted, time: .shortened))"
        )
        .id("home_announcements")
        .padding(.horizontal)
    }

    // MARK: - Today Style Announcements (App Store "Today" pattern)

    @ViewBuilder
    private func announcementsTodayStyleView(items: [Announcement]) -> some View {
        if items.isEmpty {
            announcementsEmptyState
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // Date header — like the App Store "Today" tab
                VStack(alignment: .leading, spacing: 2) {
                    Text(todayDateString.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(AppConfig.subtleGray)
                    HStack {
                        Text(L10n.announcements)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppConfig.darkText)
                        Spacer()
                        let unread = unreadAnnouncementCount
                        if unread > 0 {
                            Text("\(unread) new")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppConfig.accentFg)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)

                // Cards
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    let isFirst = idx == 0
                    todayCard(item, isHero: isFirst)
                        .feedCardScrollTransition()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            markAnnouncementRead(item)
                            if AppConfig.enableHomeAnnouncementDetailSheet {
                                Haptics.selection()
                                selectedAnnouncement = item
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func todayCard(_ item: Announcement, isHero: Bool) -> some View {
        let isRead = isAnnouncementRead(item)
        let isNew = isAnnouncementNew(item)
        let gradient = todayCardGradient(for: item)
        let isImageBacked = item.imageURL != nil || announcementInlineImage(item) != nil
        let useLightText = announcementUsesLightText(for: item, isImageBacked: isImageBacked)
        let primaryTextColor: Color = useLightText ? .white : .black
        let secondaryTextColor: Color = useLightText ? .white.opacity(0.85) : .black.opacity(0.82)
        let tertiaryTextColor: Color = useLightText ? .white.opacity(0.68) : .black.opacity(0.65)
        let metaTextColor: Color = useLightText ? .white.opacity(0.56) : .black.opacity(0.56)
        let overlayColors: [Color] = isImageBacked
            ? [.clear, .black.opacity(0.22), .black.opacity(0.74)]
            : (useLightText ? [.clear, .black.opacity(0.55)] : [.clear, .white.opacity(0.60)])

        return VStack(alignment: .leading, spacing: 0) {
            if isHero {
                // Hero card — tall with gradient background or image
                ZStack(alignment: .bottomLeading) {
                    if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                Color.black
                                    .frame(height: 260)
                                    .overlay { img.resizable().scaledToFill() }
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(gradient)
                                    .frame(height: 260)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                    } else if let inlineImage = announcementInlineImage(item) {
                        Color.black
                            .frame(height: 260)
                            .overlay {
                                Image(uiImage: inlineImage)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(gradient)
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .overlay(alignment: .topTrailing) {
                                Text(item.emoji)
                                    .font(.system(size: 80))
                                    .opacity(0.25)
                                    .rotationEffect(.degrees(-12))
                                    .offset(x: -20, y: 20)
                            }
                    }

                    // Content overlay
                    VStack(alignment: .leading, spacing: 8) {
                        if isNew && !isRead {
                            Text("NEW")
                                .font(.caption2.weight(.heavy))
                                .tracking(1.5)
                                .foregroundStyle(primaryTextColor.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(useLightText ? .white.opacity(0.2) : .black.opacity(0.12))
                                .clipShape(Capsule())
                        } else if item.isPinned {
                            Label("PINNED", systemImage: "pin.fill")
                                .font(.caption2.weight(.heavy))
                                .tracking(1)
                                .foregroundStyle(tertiaryTextColor)
                        }

                        Text(item.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(3)

                        if !item.body.isEmpty {
                            Text(item.body)
                                .font(.subheadline)
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(2)
                                .lineSpacing(1)
                        }

                        HStack {
                            Text(item.createdBy)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(tertiaryTextColor)
                            Spacer()
                            Text(item.createdAt.relativeTime())
                                .font(.caption)
                                .foregroundStyle(metaTextColor)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(TextReadabilityUnderlay(enabled: isImageBacked))
                    .background(
                        LinearGradient(
                            colors: overlayColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .cardShadow()
                .padding(.horizontal)

            } else {
                // Compact card — shorter, side-by-side layout
                HStack(spacing: 14) {
                    // Emoji / image accent block
                    if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .background(Color.black)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(gradient)
                                    Text(item.emoji).font(.title)
                                }
                            }
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if let inlineImage = announcementInlineImage(item) {
                        Image(uiImage: inlineImage)
                            .resizable()
                            .scaledToFill()
                            .background(Color.black)
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(gradient)
                            Text(item.emoji)
                                .font(.title)
                        }
                        .frame(width: 70, height: 70)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if isNew && !isRead {
                            Text("NEW")
                                .font(.caption2.weight(.heavy))
                                .tracking(1)
                                .foregroundStyle(AppConfig.accentFg)
                        }
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(AppConfig.darkText)
                            .lineLimit(2)
                        Text(item.body.isEmpty ? item.createdBy : item.body)
                            .font(.caption)
                            .foregroundStyle(AppConfig.subtleGray)
                            .lineLimit(1)
                        Text(item.createdAt.relativeTime())
                            .font(.caption2)
                            .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
                    }

                    Spacer()

                    if !isRead {
                        Circle()
                            .fill(AppConfig.accentFg)
                            .frame(width: 8, height: 8)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .cardShadow()
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isRead && !isImageBacked ? 0.78 : 1.0)
        .animation(.standard, value: isRead)
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private func todayCardGradient(for item: Announcement) -> LinearGradient {
        if let hex = item.backgroundColorHex {
            let base = Color(hex: hex)
            return LinearGradient(colors: [base, base.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        let calm = AppConfig.isCalmPalette
        let colors: [Color] = switch item.emoji {
        case "🔧", "⚙️", "🛠️":
            calm ? [Color(red: 0.24, green: 0.24, blue: 0.22), Color(red: 0.36, green: 0.35, blue: 0.32)]
                 : [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.35, green: 0.35, blue: 0.5)]
        case "⚠️", "🚨", "❗":
            calm ? [Color(red: 0.62, green: 0.36, blue: 0.26), Color(red: 0.75, green: 0.47, blue: 0.34)]
                 : [Color(red: 0.85, green: 0.3, blue: 0.2), Color(red: 0.95, green: 0.5, blue: 0.3)]
        case "🎉", "🥳", "✨", "🎊":
            calm ? [Color(red: 0.42, green: 0.33, blue: 0.45), Color(red: 0.55, green: 0.44, blue: 0.58)]
                 : [Color(red: 0.55, green: 0.2, blue: 0.8), Color(red: 0.75, green: 0.35, blue: 0.95)]
        case "📋", "📌", "📝":
            calm ? [Color(red: 0.29, green: 0.37, blue: 0.43), Color(red: 0.40, green: 0.50, blue: 0.58)]
                 : [Color(red: 0.15, green: 0.4, blue: 0.7), Color(red: 0.25, green: 0.55, blue: 0.85)]
        case "🅿️", "🚗", "🚙":
            calm ? [Color(red: 0.22, green: 0.33, blue: 0.28), Color(red: 0.32, green: 0.45, blue: 0.39)]
                 : [Color(red: 0.1, green: 0.5, blue: 0.4), Color(red: 0.2, green: 0.65, blue: 0.55)]
        case "💡", "🔔":
            calm ? [Color(red: 0.66, green: 0.52, blue: 0.29), Color(red: 0.76, green: 0.62, blue: 0.39)]
                 : [Color(red: 0.9, green: 0.65, blue: 0.1), Color(red: 0.95, green: 0.75, blue: 0.3)]
        default:
            calm ? [Color(red: 0.22, green: 0.23, blue: 0.21), Color(red: 0.33, green: 0.34, blue: 0.31)]
                 : [Color(red: 0.15, green: 0.15, blue: 0.25), Color(red: 0.3, green: 0.3, blue: 0.45)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func announcementUsesLightText(for item: Announcement, isImageBacked: Bool) -> Bool {
        let mode = AnnouncementTextColorMode(rawValue: item.textColorMode) ?? .auto
        switch mode {
        case .light:
            return true
        case .dark:
            return false
        case .auto:
            if isImageBacked {
                return true
            }
            if let hex = item.backgroundColorHex, !hex.isEmpty {
                return !isLightHexColor(hex)
            }
            return true
        }
    }

    private func isLightHexColor(_ hex: String) -> Bool {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let expanded: String
        if cleaned.count == 3 {
            expanded = cleaned.map { "\($0)\($0)" }.joined()
        } else {
            expanded = cleaned
        }

        guard expanded.count >= 6, let value = Int(expanded.prefix(6), radix: 16) else {
            return false
        }

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.60
    }

    private func announcementDetailSheet(_ item: Announcement) -> some View {
        let gradient = todayCardGradient(for: item)
        let isImageBacked = item.imageURL != nil || announcementInlineImage(item) != nil
        let useLightText = announcementUsesLightText(for: item, isImageBacked: isImageBacked)
        let primaryTextColor: Color = useLightText ? .white : .black
        let secondaryTextColor: Color = useLightText ? .white.opacity(0.82) : .black.opacity(0.78)
        let badgeTextColor: Color = useLightText ? .white.opacity(0.76) : .black.opacity(0.72)
        let headerOverlayColors: [Color] = isImageBacked
            ? [.clear, .black.opacity(0.20), .black.opacity(0.72)]
            : (useLightText ? [.clear, .clear, .black.opacity(0.50)] : [.clear, .clear, .white.opacity(0.60)])
        return GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                AppConfig.pageBg
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero header — gradient/image with title and metadata
                        ZStack(alignment: .bottomLeading) {
                            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        Color.black
                                            .frame(height: 340)
                                            .overlay { img.resizable().scaledToFill() }
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(gradient)
                                            .frame(height: 340)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 340)
                                .clipped()
                            } else if let inlineImage = announcementInlineImage(item) {
                                Color.black
                                    .frame(height: 340)
                                    .overlay {
                                        Image(uiImage: inlineImage)
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(gradient)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 340)
                                    .overlay {
                                        Text(item.emoji)
                                            .font(.system(size: 160))
                                            .opacity(0.15)
                                            .rotationEffect(.degrees(-15))
                                            .offset(x: 40, y: -30)
                                    }
                                    .clipped()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                if item.isPinned {
                                    Text("PINNED")
                                        .font(.caption2.weight(.heavy))
                                        .tracking(1.5)
                                        .foregroundStyle(badgeTextColor)
                                }

                                Text(item.title)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(primaryTextColor)

                                Text(item.createdBy)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(secondaryTextColor)
                                    .lineLimit(1)
                            }
                            .padding(24)
                            .padding(.bottom, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(TextReadabilityUnderlay(enabled: isImageBacked))
                            .background(
                                LinearGradient(
                                    colors: headerOverlayColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }

                        // Article body
                        VStack(alignment: .leading, spacing: 20) {
                            // Author + date row
                            HStack(spacing: 12) {
                                Text(item.emoji)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(AppConfig.surfaceLow)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.createdBy)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                    Text(item.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(AppConfig.subtleGray)
                                }

                                Spacer()

                                HStack(spacing: 12) {
                                    ShareLink(item: "\(item.title)\n\n\(item.body)") {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppConfig.accentFg)
                                            .frame(width: 36, height: 36)
                                            .background(AppConfig.surfaceLow)
                                            .clipShape(Circle())
                                    }
                                    if bookingManager.isAdmin {
                                        Button {
                                            Haptics.selection()
                                            Task { await announcementsManager.togglePinned(item) }
                                        } label: {
                                            Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppConfig.subtleGray)
                                                .frame(width: 36, height: 36)
                                                .background(AppConfig.surfaceLow)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }

                            Divider()

                            if !item.body.isEmpty {
                                Text(item.body)
                                    .font(.body)
                                    .foregroundStyle(AppConfig.darkText)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if !item.fields.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(item.fields.enumerated()), id: \.element.id) { idx, field in
                                        infoFieldRow(field)
                                        if idx < item.fields.count - 1 {
                                            Divider().padding(.leading, 52)
                                        }
                                    }
                                }
                                .background(AppConfig.cardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 12))
                    }
                }
                .background(AppConfig.pageBg)

                Button {
                    selectedAnnouncement = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.heavy))
                        .foregroundStyle(Color(white: 0.6))
                        .frame(width: 42, height: 42)
                        .background(Color(white: 0.19))
                        .clipShape(Circle())
                }
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                .padding(.trailing, 18)
                .padding(.top, 14)
            }
        }
        .onAppear { markAnnouncementRead(item) }
    }

    // MARK: - Info Section (admin-managed bento grid)

    private func infoSectionAppleStyle(items: [InfoItem]) -> some View {
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayDateString.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(AppConfig.subtleGray)
                Text(L10n.info)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppConfig.darkText)
            }
            .padding(.horizontal)

            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                infoTodayStyleCard(item, isHero: idx == 0)
                    .feedCardScrollTransition()
            }
        }
    }

    private func infoTodayStyleCard(_ item: InfoItem, isHero: Bool) -> some View {
        let hasDetails = AppConfig.enableHomeInfoDetailSheet
        let gradient = infoCardGradient(for: item)
        let isImageBacked = item.imageURL != nil || infoInlineImage(item) != nil

        return VStack(alignment: .leading, spacing: 0) {
            if isHero {
                ZStack(alignment: .bottomLeading) {
                    if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                Color.black
                                    .frame(height: 220)
                                    .overlay { img.resizable().scaledToFill() }
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(gradient)
                                    .frame(height: 220)
                            }
                        }
                    } else if let inlineImage = infoInlineImage(item) {
                        Color.black
                            .frame(height: 220)
                            .overlay {
                                Image(uiImage: inlineImage)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(gradient)
                            .frame(height: 220)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 84, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.18))
                                    .padding(16)
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if !item.body.isEmpty {
                            Text(item.body)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(3)
                        }

                        HStack {
                            Text(item.createdAt.relativeTime())
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                            Spacer()
                            if hasDetails && AppConfig.enableHomeInfoDetailSheet {
                                HStack(spacing: 4) {
                                    Text("Open")
                                        .font(.caption.weight(.semibold))
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(TextReadabilityUnderlay(enabled: isImageBacked))
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .cardShadow()
                .padding(.horizontal)
            } else {
                HStack(spacing: 14) {
                    if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .background(Color.black)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(gradient)
                                    Image(systemName: item.icon)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.92))
                                }
                            }
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if let inlineImage = infoInlineImage(item) {
                        Image(uiImage: inlineImage)
                            .resizable()
                            .scaledToFill()
                            .background(Color.black)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(gradient)
                                .frame(width: 70, height: 70)
                            Image(systemName: item.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(AppConfig.darkText)
                            .lineLimit(2)
                        if !item.body.isEmpty {
                            Text(item.body)
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                                .lineLimit(2)
                        }
                        Text(item.createdAt.relativeTime())
                            .font(.caption2)
                            .foregroundStyle(AppConfig.subtleGray.opacity(0.55))
                    }

                    Spacer()

                    if hasDetails && AppConfig.enableHomeInfoDetailSheet {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray.opacity(0.38))
                    }
                }
                .padding(14)
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .cardShadow()
                .padding(.horizontal)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard AppConfig.enableHomeInfoDetailSheet else { return }
            Haptics.selection()
            selectedInfoItem = item
        }
    }

    private func infoCardGradient(for item: InfoItem) -> LinearGradient {
        let palette: [[Color]] = AppConfig.isCalmPalette
        ? [
            [Color(red: 0.27, green: 0.34, blue: 0.41), Color(red: 0.37, green: 0.46, blue: 0.54)],
            [Color(red: 0.24, green: 0.36, blue: 0.31), Color(red: 0.33, green: 0.47, blue: 0.41)],
            [Color(red: 0.40, green: 0.33, blue: 0.43), Color(red: 0.51, green: 0.43, blue: 0.54)],
            [Color(red: 0.55, green: 0.37, blue: 0.28), Color(red: 0.67, green: 0.47, blue: 0.37)],
            [Color(red: 0.25, green: 0.25, blue: 0.23), Color(red: 0.36, green: 0.36, blue: 0.33)]
        ]
        : [
            [Color(red: 0.18, green: 0.25, blue: 0.45), Color(red: 0.25, green: 0.42, blue: 0.68)],
            [Color(red: 0.17, green: 0.42, blue: 0.36), Color(red: 0.25, green: 0.62, blue: 0.5)],
            [Color(red: 0.48, green: 0.24, blue: 0.62), Color(red: 0.65, green: 0.35, blue: 0.82)],
            [Color(red: 0.56, green: 0.28, blue: 0.2), Color(red: 0.76, green: 0.44, blue: 0.3)],
            [Color(red: 0.22, green: 0.22, blue: 0.3), Color(red: 0.36, green: 0.36, blue: 0.5)]
        ]

        let key = "\(item.title)|\(item.icon)"
        let idx = abs(key.hashValue) % palette.count
        let colors = palette[idx]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                Text(L10n.info)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
            }
            .padding(.horizontal)

            // Bento grid: items in pairs (2 per row), last lone item is full-width
            let items = infoManager.items
            VStack(spacing: 12) {
                let pairs = stride(from: 0, to: items.count, by: 2).map {
                    Array(items[$0..<min($0 + 2, items.count)])
                }
                ForEach(pairs.indices, id: \.self) { rowIdx in
                    HStack(spacing: 12) {
                        ForEach(pairs[rowIdx]) { item in
                            infoCard(item)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func infoCard(_ item: InfoItem) -> some View {
        let hasDetails = AppConfig.enableHomeInfoDetailSheet
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(AppConfig.accent.opacity(0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: item.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppConfig.accentFg)
                }
                Spacer()
                if hasDetails && AppConfig.enableHomeInfoDetailSheet {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.35))
                }
            }

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.darkText)

            if !item.body.isEmpty {
                Text(item.body)
                    .font(.caption)
                    .foregroundStyle(AppConfig.subtleGray)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            guard AppConfig.enableHomeInfoDetailSheet else { return }
            Haptics.selection()
            selectedInfoItem = item
        }
    }

    private func canOpenInfoDetail(_ item: InfoItem) -> Bool {
        _ = item
        return AppConfig.enableHomeInfoDetailSheet
    }

    private func infoDetailSheet(_ item: InfoItem) -> some View {
        let gradient = infoCardGradient(for: item)
        let isImageBacked = item.imageURL != nil || infoInlineImage(item) != nil
        return GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                AppConfig.pageBg
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero header — mirrors announcement detail style
                        ZStack(alignment: .bottomLeading) {
                            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        Color.black
                                            .frame(height: 340)
                                            .overlay { img.resizable().scaledToFill() }
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(gradient)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 340)
                                    }
                                }
                            } else if let inlineImage = infoInlineImage(item) {
                                Color.black
                                    .frame(height: 340)
                                    .overlay {
                                        Image(uiImage: inlineImage)
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(gradient)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 340)
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 150, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.14))
                                            .rotationEffect(.degrees(-10))
                                            .offset(x: 28, y: -10)
                                    }
                                    .clipped()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("INFO")
                                    .font(.caption2.weight(.heavy))
                                    .tracking(1.5)
                                    .foregroundStyle(.white.opacity(0.76))

                                Text(item.title)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.white)

                                Text(item.createdAt.relativeTime())
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .lineLimit(1)
                            }
                            .padding(24)
                            .padding(.bottom, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(TextReadabilityUnderlay(enabled: isImageBacked))
                            .background(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.20), .black.opacity(0.66)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }

                        // Article body
                        VStack(alignment: .leading, spacing: 20) {
                            // Meta + actions row (same pattern as announcements)
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppConfig.surfaceLow)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: item.icon)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(AppConfig.accentFg)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.info)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                    Text(item.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(AppConfig.subtleGray)
                                }

                                Spacer()

                                ShareLink(item: "\(item.title)\n\n\(item.body)") {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppConfig.accentFg)
                                        .frame(width: 36, height: 36)
                                        .background(AppConfig.surfaceLow)
                                        .clipShape(Circle())
                                }
                            }

                            Divider()

                            if !item.body.isEmpty {
                                Text(item.body)
                                    .font(.body)
                                    .foregroundStyle(AppConfig.darkText)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if !item.fields.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(item.fields.enumerated()), id: \.element.id) { idx, field in
                                        infoFieldRow(field)
                                        if idx < item.fields.count - 1 {
                                            Divider().padding(.leading, 52)
                                        }
                                    }
                                }
                                .background(AppConfig.cardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            if !item.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(item.details)
                                    .font(.body)
                                    .foregroundStyle(AppConfig.darkText)
                                    .lineSpacing(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(AppConfig.cardBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppConfig.separatorSoft, lineWidth: 1))
                            }

                            if let url = URL(string: item.linkURL), !item.linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button {
                                    Haptics.selection()
                                    openURL(url)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.right.square")
                                        Text(item.linkTitle.isEmpty ? "Open link" : item.linkTitle)
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppConfig.onAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppConfig.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 12))
                    }
                }
                .background(AppConfig.pageBg)

                Button {
                    selectedInfoItem = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.heavy))
                        .foregroundStyle(Color(white: 0.6))
                        .frame(width: 42, height: 42)
                        .background(Color(white: 0.19))
                        .clipShape(Circle())
                }
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                .padding(.trailing, 18)
                .padding(.top, 14)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func infoFieldRow(_ field: ContactField) -> some View {
        let actionURL: URL? = {
            let v = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            switch field.type {
            case .phone:   return URL(string: "tel:\(v.filter { !$0.isWhitespace })")
            case .email:   return URL(string: "mailto:\(v)")
            case .website: return URL(string: v.hasPrefix("http") ? v : "https://\(v)")
            default:       return nil
            }
        }()

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppConfig.accent.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: field.type.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.accentFg)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(field.displayLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                Text(field.value)
                    .font(.subheadline)
                    .foregroundStyle(actionURL != nil ? AppConfig.accentFg : AppConfig.darkText)
            }

            Spacer()

            if actionURL != nil {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = actionURL {
                Haptics.selection()
                openURL(url)
            }
        }
    }

    private func announcementInlineImage(_ item: Announcement) -> UIImage? {
        #if canImport(UIKit)
        guard let base64 = item.imageBase64,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
        #else
        return nil
        #endif
    }

    private func infoInlineImage(_ item: InfoItem) -> UIImage? {
        #if canImport(UIKit)
        guard let base64 = item.imageBase64,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
        #else
        return nil
        #endif
    }

    // MARK: - Footer Logo

    private var footerLogo: some View {
        VStack(spacing: 4) {
            Text("EL Parking")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.45))

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") · \(AppConfig.companyName)")
                .font(.caption2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.3))
        }
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pulsing Dot

/// Animated "live" indicator: a solid dot with two expanding rings that
/// fade out in staggered sequence, creating a sonar / heartbeat effect.
/// Use `size` to scale the dot — default 12 for hero card, 9 for list cards.
struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 12

    @State private var ring1 = false
    @State private var ring2 = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(ring2 ? 0 : 0.30), lineWidth: 1.5)
                .frame(width: size, height: size)
                .scaleEffect(ring2 ? 2.8 : 1.0)
            Circle()
                .stroke(color.opacity(ring1 ? 0 : 0.50), lineWidth: 2)
                .frame(width: size, height: size)
                .scaleEffect(ring1 ? 2.8 : 1.0)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                ring1 = true
            }
            withAnimation(.easeOut(duration: 1.8).delay(0.55).repeatForever(autoreverses: false)) {
                ring2 = true
            }
        }
    }
}



// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            // Press-down must feel instant; only the release springs back.
            .animation(
                configuration.isPressed
                    ? .snappy(duration: 0.15, extraBounce: 0.0)
                    : .snappy(duration: 0.32, extraBounce: 0.12),
                value: configuration.isPressed
            )
    }
}

private struct TextReadabilityUnderlay: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.30))
                )
        } else {
            content
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(BookingManager())
        .environmentObject(AuthManager())
        .environmentObject(AnnouncementsManager())
        .environmentObject(DeepLinkManager())
        .environmentObject(InfoManager())
}


// MARK: - Cascade Entrance

private struct CascadeIn: ViewModifier {
    let visible: Bool
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 14)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(duration: 0.45, bounce: 0.24).delay(0.15 + Double(index) * 0.04),
                value: visible
            )
    }
}
