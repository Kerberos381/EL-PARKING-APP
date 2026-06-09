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

    private enum HomeFeedTab: String, CaseIterable {
        case pinned = "Pinned"
        case updates = "Updates"
    }

    private enum HomeFeedFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case announcements = "Announcements"
        case info = "Info"
    }

    @EnvironmentObject var bookingManager:       BookingManager
    @EnvironmentObject var announcementsManager: AnnouncementsManager
    @EnvironmentObject var deepLinkManager:      DeepLinkManager
    @EnvironmentObject var infoManager:          InfoManager
    @Environment(\.openURL) private var openURL
    @ObservedObject private var lang = LanguageManager.shared
    @State private var showingBookingSheet  = false
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
    @State private var selectedHomeFeedTab: HomeFeedTab = .pinned
    @State private var selectedHomeFeedFilter: HomeFeedFilter = .all
    @State private var showWidgetGuideSheet = false
    @State private var lastAnnouncementsRefreshAt = Date()
    @State private var widgetTeaserDragOffset: CGFloat = 0
    @AppStorage("readAnnouncementIDs") private var readAnnouncementIDsRaw = ""
    @AppStorage("homeWidgetTeaserDismissed") private var homeWidgetTeaserDismissed = false
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
                                // Greeting + theme toggle
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

                                // Hero Booking Card
                                heroSection
                                    .id("home_hero")
                                    .offset(y: heroVisible ? 0 : 28)
                                    .opacity(heroVisible ? 1 : 0)

                                // Compact quick actions + availability bar
                                VStack(spacing: 8) {
                                    HStack(spacing: 10) {
                                        myBookingsQuickButton
                                            .id("home_my_bookings")
                                        if !(AppConfig.enableHomePremiumEmptyStates && !hasUpcomingOrActiveBooking) {
                                            bookSpotQuickButton
                                                .id("home_book")
                                        }
                                    }
                                    .padding(.horizontal)

                                    garageStatusBar
                                        .id("home_garage")
                                }

                                // Widget teaser handoff
                                if AppConfig.enableHomeWidgetTeaserCard && !homeWidgetTeaserDismissed {
                                    widgetTeaserCard
                                        .id("home_widget_teaser")
                                }

                                homeNewsAndInfoHub

                                // Footer logo
                                footerLogo
                            } else {
                                infoHubScreen
                            }
                        }
                        .padding(.bottom, 100)
                    }
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
                }
                if !didPrefetchLikelyNextScreens {
                    didPrefetchLikelyNextScreens = true
                    Task(priority: .utility) { await prefetchLikelyNextScreens() }
                }
            }
            .navigationDestination(isPresented: $navigateToMyBookings) {
                MyBookingsView()
            }
            .fullScreenCover(isPresented: $showingBookingSheet) {
                BookingSheet(
                    preselectedSpot: nil,
                    isForOthers: false
                )
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
            .sheet(isPresented: $showWidgetGuideSheet) {
                widgetGuideSheet
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
            if AppConfig.enableHomePremiumEmptyStates {
                premiumHomeEmptyState
            } else {
                AppEmptyStateCard(
                    icon: "car.side.fill",
                    title: L10n.noBooking,
                    subtitle: L10n.bookFromBelow,
                    actionTitle: L10n.bookASpot,
                    actionIcon: "plus"
                ) {
                    showingBookingSheet = true
                }
                .padding(.horizontal)
            }
        }
    }

    private var premiumHomeEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "parkingsign.circle")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(AppConfig.accentFg.opacity(0.75))
                .padding(.top, 6)

            Text("No booking yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppConfig.darkText)

            Text("Reserve your first parking spot for today in one tap.")
                .font(.subheadline)
                .foregroundStyle(AppConfig.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button {
                Haptics.selection()
                showingBookingSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "car")
                    Text(L10n.bookASpot)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppConfig.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppConfig.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 14)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 16, y: 4)
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
                    .tracking(2)
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
                    .foregroundStyle(AppConfig.accentFg)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

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

            // Glass pill action buttons
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
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
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
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
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
                    .background(AppConfig.spotOccupied.opacity(0.30))
                    .clipShape(Capsule())
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
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .background(AppConfig.obsidian)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal)
    }

    // MARK: - Garage Status Bar

    private var garageStatusBar: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let total = max(1, bookingManager.parkingSpots.count - AppConfig.blockedSpotIDs.count)
        let free  = bookingManager.availableSpotsCount(on: today)
        let ratio = min(1.0, max(0.0, Double(free) / Double(total)))
        let barColor: Color = ratio > 0.5 ? AppConfig.activeGreen : (ratio > 0.2 ? .orange : AppConfig.spotOccupied)

        return VStack(spacing: 6) {
            HStack(alignment: .center) {
                Text("Spots available today")
                    .font(.caption2)
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                Spacer()
                Text("\(free)/\(total)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(barColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: free)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppConfig.subtleGray.opacity(0.10))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(6, geo.size.width * ratio))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: ratio)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
    }

    // MARK: - Home Quick Actions

    private var myBookingsQuickButton: some View {
        Button {
            Haptics.selection()
            navigateToMyBookings = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.bookASpot)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
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

    private var filteredPinnedAnnouncements: [Announcement] {
        let base = pinnedAnnouncements
        switch selectedHomeFeedFilter {
        case .all, .announcements:
            return base
        case .unread:
            return base.filter { !isAnnouncementRead($0) }
        case .info:
            return []
        }
    }

    private var filteredUpdatesAnnouncements: [Announcement] {
        let base = nonPinnedAnnouncements
        switch selectedHomeFeedFilter {
        case .all, .announcements:
            return base
        case .unread:
            return base.filter { !isAnnouncementRead($0) }
        case .info:
            return []
        }
    }

    private var filteredUpdatesInfoItems: [InfoItem] {
        let base = sortedInfoItems
        switch selectedHomeFeedFilter {
        case .all, .info:
            return base
        case .unread, .announcements:
            return []
        }
    }

    private var homeNewsAndInfoHub: some View {
        if !bookingManager.isAdmin {
            return AnyView(nonAdminPinnedHomeSection)
        }

        let hasPinned = !pinnedAnnouncements.isEmpty
        let hasUpdates = !nonPinnedAnnouncements.isEmpty || !infoManager.items.isEmpty

        return AnyView(VStack(spacing: 14) {
            HStack(spacing: 0) {
                ForEach(HomeFeedTab.allCases, id: \.self) { tab in
                    Button {
                        Haptics.selection()
                        withAnimation(.quick) { selectedHomeFeedTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedHomeFeedTab == tab ? AppConfig.darkText : AppConfig.subtleGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedHomeFeedTab == tab ? AppConfig.cardBg : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled((tab == .pinned && !hasPinned) || (tab == .updates && !hasUpdates))
                    .opacity((tab == .pinned && !hasPinned) || (tab == .updates && !hasUpdates) ? 0.45 : 1)
                }
            }
            .padding(4)
            .background(AppConfig.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal)

            if selectedHomeFeedTab == .pinned {
                if !filteredPinnedAnnouncements.isEmpty {
                    announcementsGroupedView(items: filteredPinnedAnnouncements)
                        .id("home_announcements_pinned")
                } else {
                    AppEmptyStateCard(
                        icon: "pin",
                        title: "Pinned Updates",
                        subtitle: "No pinned news right now"
                    )
                    .padding(.horizontal)
                }
            } else {
                if !filteredUpdatesAnnouncements.isEmpty {
                    announcementsGroupedView(items: filteredUpdatesAnnouncements)
                        .id("home_announcements_updates")
                }

                if !filteredUpdatesInfoItems.isEmpty {
                    infoSectionAppleStyle(items: filteredUpdatesInfoItems)
                        .id("home_info_updates")
                }

                if filteredUpdatesAnnouncements.isEmpty && filteredUpdatesInfoItems.isEmpty {
                    announcementsEmptyState
                }
            }
        }
        .onAppear {
            selectedHomeFeedFilter = .all
            if selectedHomeFeedTab == .pinned && !hasPinned && hasUpdates {
                selectedHomeFeedTab = .updates
            } else if selectedHomeFeedTab == .updates && !hasUpdates && hasPinned {
                selectedHomeFeedTab = .pinned
            }
        }
        .onChange(of: announcementsManager.activeAnnouncements.count) { _, _ in
            selectedHomeFeedFilter = .all
            if selectedHomeFeedTab == .pinned && !hasPinned && hasUpdates {
                selectedHomeFeedTab = .updates
            } else if selectedHomeFeedTab == .updates && !hasUpdates && hasPinned {
                selectedHomeFeedTab = .pinned
            }
        }
        .onChange(of: infoManager.items.count) { _, _ in
            selectedHomeFeedFilter = .all
            if selectedHomeFeedTab == .pinned && !hasPinned && hasUpdates {
                selectedHomeFeedTab = .updates
            } else if selectedHomeFeedTab == .updates && !hasUpdates && hasPinned {
                selectedHomeFeedTab = .pinned
            }
        }
        .onChange(of: selectedHomeFeedTab) { _, _ in
            selectedHomeFeedFilter = .all
        }
        )
    }

    private var nonAdminPinnedHomeSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 14, weight: .semibold))
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

            if bookingManager.isAdmin {
                homeNewsAndInfoHub
            } else {
                nonAdminInfoHubFeed
            }
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
                        .font(.system(size: 15, weight: .semibold))
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
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppConfig.separatorSoft, lineWidth: 1))
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
                        .font(.system(size: 15, weight: .semibold))
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
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppConfig.separatorSoft, lineWidth: 1))
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
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
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
                .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
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
                                .font(.system(size: 9, weight: .heavy))
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
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppConfig.separatorSoft, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
        let colors: [Color] = switch item.emoji {
        case "🔧", "⚙️", "🛠️":
            [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.35, green: 0.35, blue: 0.5)]
        case "⚠️", "🚨", "❗":
            [Color(red: 0.85, green: 0.3, blue: 0.2), Color(red: 0.95, green: 0.5, blue: 0.3)]
        case "🎉", "🥳", "✨", "🎊":
            [Color(red: 0.55, green: 0.2, blue: 0.8), Color(red: 0.75, green: 0.35, blue: 0.95)]
        case "📋", "📌", "📝":
            [Color(red: 0.15, green: 0.4, blue: 0.7), Color(red: 0.25, green: 0.55, blue: 0.85)]
        case "🅿️", "🚗", "🚙":
            [Color(red: 0.1, green: 0.5, blue: 0.4), Color(red: 0.2, green: 0.65, blue: 0.55)]
        case "💡", "🔔":
            [Color(red: 0.9, green: 0.65, blue: 0.1), Color(red: 0.95, green: 0.75, blue: 0.3)]
        default:
            [Color(red: 0.15, green: 0.15, blue: 0.25), Color(red: 0.3, green: 0.3, blue: 0.45)]
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

    private var widgetTeaserCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group")
                        .foregroundStyle(AppConfig.accentFg)
                    Text("Add Widget")
                        .font(.headline)
                        .foregroundStyle(AppConfig.darkText)
                }
                Spacer()
            }

            Text("Pin EL Parking on Home or Lock Screen for quick spot and time glance.")
                .font(.subheadline)
                .foregroundStyle(AppConfig.subtleGray)

            Button {
                Haptics.selection()
                showWidgetGuideSheet = true
            } label: {
                Text("How to add")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppConfig.surfaceLow)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Text("Swipe left or right to dismiss")
                .font(.caption2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.8))
        }
        .padding(16)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.025), radius: 6, y: 2)
        .offset(x: widgetTeaserDragOffset)
        .opacity(max(0.2, 1 - abs(widgetTeaserDragOffset) / 260))
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    widgetTeaserDragOffset = value.translation.width
                }
                .onEnded { value in
                    let shouldDismiss = abs(value.translation.width) > 90 || abs(value.predictedEndTranslation.width) > 140
                    if shouldDismiss {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.2)) {
                            widgetTeaserDragOffset = value.translation.width > 0 ? 420 : -420
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            homeWidgetTeaserDismissed = true
                            widgetTeaserDragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            widgetTeaserDragOffset = 0
                        }
                    }
                }
        )
        .padding(.horizontal)
    }

    private var widgetGuideSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add EL Parking Widget")
                    .font(.title3.bold())
                Text("1. Press and hold Home Screen or Lock Screen.\n2. Tap + in the top corner.\n3. Search for EL Parking.\n4. Pick your preferred size and add.")
                    .font(.body)
                    .foregroundStyle(AppConfig.subtleGray)
                Spacer()
            }
            .padding()
            .navigationTitle("Widget Guide")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func announcementDetailSheet(_ item: Announcement) -> some View {
        let gradient = todayCardGradient(for: item)
        let isImageBacked = item.imageURL != nil || announcementInlineImage(item) != nil
        let useLightText = announcementUsesLightText(for: item, isImageBacked: isImageBacked)
        let primaryTextColor: Color = useLightText ? .white : .black
        let secondaryTextColor: Color = useLightText ? .white.opacity(0.82) : .black.opacity(0.78)
        let badgeTextColor: Color = useLightText ? .white.opacity(0.76) : .black.opacity(0.72)
        let closeIconColor: Color = useLightText ? .white.opacity(0.86) : .black.opacity(0.86)
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
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppConfig.separatorSoft, lineWidth: 1))
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
                        .font(.system(size: 16, weight: .heavy))
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
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppConfig.separatorSoft.opacity(0.45), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
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
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppConfig.separatorSoft, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
        let palette: [[Color]] = [
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
                    .font(.system(size: 15, weight: .semibold))
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
                        .font(.system(size: 16, weight: .semibold))
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
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppConfig.separatorSoft, lineWidth: 1)
        )
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
                                        .font(.system(size: 18, weight: .semibold))
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
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppConfig.separatorSoft, lineWidth: 1))
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
                                    .clipShape(Capsule())
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
                        .font(.system(size: 16, weight: .heavy))
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
                    .font(.system(size: 14, weight: .semibold))
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
        VStack(spacing: 8) {
            Text(AppConfig.companyName)
                .font(.system(size: 14, weight: .bold, design: .default))
                .tracking(2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.5))

            Text("EL Parking v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption2)
                .foregroundStyle(AppConfig.subtleGray.opacity(0.3))
        }
        .padding(.vertical, 16)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.quick, value: configuration.isPressed)
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
        .environmentObject(AnnouncementsManager())
        .environmentObject(DeepLinkManager())
        .environmentObject(InfoManager())
}
