//
//  BookingSheet.swift
//  EL PARKING APP
//
//  Full-page booking flow with date pills, 3-col spot grid, toggle for others.
//

import SwiftUI
import MessageUI

// Retained outside the struct so it stays alive while Mail is open
private let _mailDelegate = MailComposeDelegate()
private class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    func mailComposeController(_ c: MFMailComposeViewController,
                               didFinishWith _: MFMailComposeResult,
                               error _: Error?) { c.dismiss(animated: true) }
}

struct BookingSheet: View {
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var lang = LanguageManager.shared

    let preselectedSpot: ParkingSpot?
    let preselectedTimeFrom: String?
    let preselectedTimeTo: String?
    let isForOthers: Bool
    let editingBooking: Booking?

    @State private var selectedSpot: ParkingSpot?
    @State private var bookingDate: Date
    @State private var bookingDateTo: Date      // admin range: end date
    @State private var timeFrom: String
    @State private var timeTo: String
    @State private var userName: String = ""
    @State private var userEmail: String = ""

    private enum PersonField: Hashable { case name, email }
    @FocusState private var personFocus: PersonField?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showShareOptions = false
    @AppStorage("shareDelegateNavGuide") private var includeNavGuide = true
    @State private var isSubmitting = false
    @State private var confirmVisualState: ConfirmVisualState = .idle
    @State private var isForOthersToggle: Bool
    @State private var showSpotPicker = false
    @State private var scrollToConfirmTrigger = false

    // Success animation state
    @State private var cardOffset: CGFloat = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOpacity: Double = 0
    @State private var bgOpacity: Double = 0
    @State private var actionsOpacity: Double = 0
    @State private var carParked = false
    @State private var isDismissing = false

    private enum ConfirmVisualState: Equatable {
        case idle
        case loading
        case success
        case failure
    }

    private var motionQuick: Animation {
        reduceMotion ? Animation.linear(duration: 0.01) : .easeInOut(duration: 0.16)
    }

    private var motionStandard: Animation {
        reduceMotion ? Animation.linear(duration: 0.01) : .easeInOut(duration: 0.18)
    }

    private var motionFade: Animation {
        reduceMotion ? Animation.linear(duration: 0.01) : .easeOut(duration: 0.14)
    }

    private var globalSystemSpring: Animation {
        reduceMotion ? Animation.linear(duration: 0.12) : .spring(response: 0.32, dampingFraction: 1.0)
    }

    private var successSnapSpring: Animation {
        reduceMotion ? Animation.linear(duration: 0.12) : .spring(response: 0.30, dampingFraction: 0.75)
    }

    private var isEditing: Bool { editingBooking != nil }
    private var hasPreselection: Bool { preselectedSpot != nil && editingBooking == nil }
    /// Admin range mode: only available when admin is booking for someone else (not editing)
    private var isAdminRangeMode: Bool { bookingManager.isAdmin && isForOthersToggle && !isEditing }

    /// Whether the selected spot is still available on the current date
    private var isSelectedSpotValid: Bool {
        guard let spot = selectedSpot else { return false }
        return bookingManager.isSpotAvailable(
            spotLabel: spot.label,
            on: bookingDate,
            timeFrom: timeFrom,
            timeTo: timeTo,
            excludingBookingID: editingBooking?.id
        )
    }

    /// Role-based booking window (matches firestore.rules bookingDateAllowedForActor):
    /// admin = unlimited, privileged = today..+3, standard user = today (tomorrow only after 18:00).
    private var maxAdvanceDays: Int {
        if bookingManager.isAdmin { return AppConfig.adminBookingMaxAdvanceDays }
        if bookingManager.isPrivileged { return AppConfig.othersBookingMaxAdvanceDays }
        return Calendar.current.component(.hour, from: Date()) >= 18 ? 1 : 0
    }

    private var maxDate: Date {
        Calendar.current.date(byAdding: .day, value: maxAdvanceDays, to: Date()) ?? Date()
    }

    init(
        preselectedSpot: ParkingSpot? = nil,
        preselectedDate: Date? = nil,
        preselectedTimeFrom: String? = nil,
        preselectedTimeTo: String? = nil,
        isForOthers: Bool = false,
        editingBooking: Booking? = nil
    ) {
        self.preselectedSpot = preselectedSpot
        self.preselectedTimeFrom = preselectedTimeFrom
        self.preselectedTimeTo = preselectedTimeTo
        self.isForOthers = isForOthers
        self.editingBooking = editingBooking

        let editSpot = editingBooking.flatMap { b in AppConfig.allParkingSpots.first(where: { $0.label == b.spot }) }
        _selectedSpot = State(initialValue: editSpot ?? preselectedSpot)
        let defaultDate = editingBooking?.date ?? preselectedDate ?? Date.smartDefaultDate()
        _bookingDate   = State(initialValue: defaultDate)
        _bookingDateTo = State(initialValue: defaultDate)
        _timeFrom = State(initialValue: editingBooking?.fromTime ?? preselectedTimeFrom ?? AppConfig.defaultTimeFrom)
        _timeTo = State(initialValue: editingBooking?.toTime ?? preselectedTimeTo ?? AppConfig.defaultTimeTo)
        _isForOthersToggle = State(initialValue: isForOthers)

        if let editing = editingBooking, isForOthers {
            _userName = State(initialValue: editing.user)
            _userEmail = State(initialValue: editing.email)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // 1. Date selection first
                            dateSection

                            // Book for others toggle (privileged users) — placed
                            // right after the date so it's decided FIRST: it
                            // changes the allowed date range and spot pool.
                            if bookingManager.isPrivileged && !isEditing {
                                bookForOthersSection
                            }

                            // Person fields when booking for others
                            if isForOthersToggle {
                                personSection
                                delegateNavGuideCard
                            }

                            // 2. Time selection
                            timeSection

                            // 3. Spot selection (availability based on date + time)
                            spotSection

                            // Confirm button
                            confirmButton
                                .id("confirmButton")
                        }
                        .padding(.vertical)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: scrollToConfirmTrigger) { _, shouldScroll in
                        guard shouldScroll else { return }
                        withAnimation(.standard) {
                            proxy.scrollTo("confirmButton", anchor: .bottom)
                        }
                        scrollToConfirmTrigger = false
                    }
                }
            }
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundStyle(AppConfig.darkText)
                }
            }
            .alert(L10n.errorTitle, isPresented: $showingError) {
                Button(L10n.ok) {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Share booking", isPresented: $showShareOptions, titleVisibility: .visible) {
                Button("Share card") { shareRenderedCard() }
                Button("Share text only") { shareTextOnly() }
                Button(L10n.sendViaEmail) { openDelegationMailTo() }
                Button(L10n.done, role: .cancel) {}
            } message: {
                Text("Choose how you want to share the reservation details.")
            }
            .overlay {
                if showSuccess { successOverlay }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Spot Section

    private var availableCount: Int {
        bookableSpots.filter {
            bookingManager.isSpotAvailable(
                spotLabel: $0.label,
                on: bookingDate,
                timeFrom: timeFrom,
                timeTo: timeTo,
                excludingBookingID: editingBooking?.id
            )
        }.count
    }

    private var alternativeSuggestions: [BookingManager.BookingSuggestion] {
        let suggestions = bookingManager.bookingSuggestions(
            on: bookingDate,
            desiredFrom: timeFrom,
            desiredTo: timeTo,
            candidateSpots: bookableSpots,
            excludingBookingID: editingBooking?.id,
            limit: 4
        )
        // Keep user's selected time strict: only suggest spots that match the exact From/To slot.
        let exactTimeOnly = suggestions.filter(\.isExactTimeMatch)

        return exactTimeOnly
        .filter { suggestion in
            // Hide exact duplicate of the currently selected valid selection.
            !(selectedSpot?.id == suggestion.spot.id &&
              suggestion.fromTime == timeFrom &&
              suggestion.toTime == timeTo &&
              isSelectedSpotValid)
        }
    }

    private var shouldShowSuggestionSection: Bool {
        guard timeFrom < timeTo else { return false }
        if availableCount == 0 { return true } // fully booked for selected slot
        if selectedSpot != nil && !isSelectedSpotValid { return true } // selected spot conflict
        return false
    }

    /// Proactive nudging: show partially booked spots that are free for the same selected time.
    /// This helps keep completely free spots available for users who need longer/full-day windows.
    private var partialExactMatchSpots: [ParkingSpot] {
        guard timeFrom < timeTo else { return [] }
        return bookableSpots.filter { spot in
            guard spot.id != selectedSpot?.id else { return false }
            let isFreeForSelectedTime = bookingManager.isSpotAvailable(
                spotLabel: spot.label,
                on: bookingDate,
                timeFrom: timeFrom,
                timeTo: timeTo,
                excludingBookingID: editingBooking?.id
            )
            let hasPartialOccupancy = bookingManager.occupiedTimeRangesText(
                spotLabel: spot.label,
                on: bookingDate,
                excludingBookingID: editingBooking?.id
            ) != nil
            return isFreeForSelectedTime && hasPartialOccupancy
        }
    }

    @ViewBuilder
    private var spotSection: some View {
        // Preselected banner — stays visible even when the chosen date makes
        // the spot unavailable, so a quick-booked spot is never silently lost.
        if let spot = selectedSpot, hasPreselection && !showSpotPicker {
            HStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text(spot.id)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(AppConfig.darkText)
                    if spot.isAccessible {
                        Image(systemName: "figure.roll")
                            .font(.caption2)
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                }
                .frame(width: 72, height: 72)
                .background(isSelectedSpotValid
                    ? AppConfig.accent.opacity(0.2)
                    : AppConfig.warning.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(L10n.spot) \(spot.id)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppConfig.darkText)
                    if isSelectedSpotValid {
                        Text(L10n.availableOnSelectedDate)
                            .font(.caption)
                            .foregroundStyle(AppConfig.activeGreen)
                    } else {
                        Text(L10n.unavailableOnSelectedDate)
                            .font(.caption)
                            .foregroundStyle(AppConfig.warning)
                    }
                }

                Spacer()

                Button {
                    withAnimation { showSpotPicker = true }
                } label: {
                    Text(L10n.change)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppConfig.darkText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppConfig.darkText.opacity(0.07))
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(18)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .cardShadow()
            .padding(.horizontal)
        } else {
            // 3-column spot picker grid with availability header
            sectionCard(title: L10n.selectSpot, icon: "parkingsign") {
                // Availability summary
                HStack(spacing: 6) {
                    Circle()
                        .fill(availableCount > 0 ? AppConfig.activeGreen : AppConfig.spotOccupied)
                        .frame(width: 8, height: 8)
                    Text(L10n.spotsAvailableOf(availableCount, total: bookableSpots.count))
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray)
                    Spacer()
                }

                if !shouldShowSuggestionSection && !partialExactMatchSpots.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "leaf")
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                            Text(L10n.smartBookingTipTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppConfig.darkText)
                            Spacer()
                        }

                        Text(L10n.smartBookingTipBody)
                            .font(.caption2)
                            .foregroundStyle(AppConfig.subtleGray)

                        HStack(spacing: 8) {
                            ForEach(Array(partialExactMatchSpots.prefix(3))) { spot in
                                Button {
                                    withAnimation(.standard) {
                                        selectedSpot = spot
                                    }
                                    Haptics.selection()
                                    scrollToConfirmTrigger = true
                                } label: {
                                    Text(L10n.useSpot(spot.id))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppConfig.surfaceLow)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(AppConfig.surfaceLow.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
                }

                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(bookableSpots) { spot in
                        let available = bookingManager.isSpotAvailable(
                            spotLabel: spot.label,
                            on: bookingDate,
                            timeFrom: timeFrom,
                            timeTo: timeTo,
                            excludingBookingID: editingBooking?.id
                        )
                        let occupiedRanges = bookingManager.occupiedTimeRangesText(
                            spotLabel: spot.label,
                            on: bookingDate,
                            excludingBookingID: editingBooking?.id
                        )
                        let cellStatus: SpotCellStatus = {
                            if selectedSpot?.id == spot.id { return .selected }
                            if !available { return .occupied(name: nil, plate: nil) }
                            if occupiedRanges != nil { return .partial(name: nil, plate: nil, ranges: occupiedRanges) }
                            return .available
                        }()
                        UnifiedSpotCell(
                            spot: spot,
                            status: cellStatus,
                            mode: .compact,
                            spotGroupBadges: AppConfig.spotGroupBadges(
                                spotID: spot.id,
                                viewerCompany: bookingManager.currentUserCompany,
                                isAdmin: bookingManager.isAdmin
                            )
                        ) {
                            if available {
                                withAnimation(.standard) {
                                    selectedSpot = spot
                                    if hasPreselection { showSpotPicker = false }
                                }
                                scrollToConfirmTrigger = true
                            }
                        }
                    }
                }

                if shouldShowSuggestionSection && !alternativeSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb")
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                            Text(L10n.suggestedAlternatives)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppConfig.darkText)
                            Spacer()
                        }

                        ForEach(alternativeSuggestions) { suggestion in
                            Button {
                                withAnimation(.standard) {
                                    selectedSpot = suggestion.spot
                                    timeFrom = suggestion.fromTime
                                    timeTo = suggestion.toTime
                                }
                                Haptics.selection()
                                scrollToConfirmTrigger = true
                            } label: {
                                HStack(spacing: 10) {
                                    Text("#\(suggestion.spot.id)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                        .frame(minWidth: 40, alignment: .leading)

                                    Text("\(suggestion.fromTime) – \(suggestion.toTime)")
                                        .font(.subheadline)
                                        .foregroundStyle(AppConfig.darkText)

                                    Spacer()

                                    Text(suggestion.isExactTimeMatch ? L10n.sameTime : L10n.closestMatch)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppConfig.subtleGray)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppConfig.surfaceLow)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        Group {
            if isAdminRangeMode {
                adminDateRangeSection
            } else {
                regularDateSection
            }
        }
    }

    // Admin-only: two DatePickers for a multi-day range
    private var adminDateRangeSection: some View {
        selectorCard {
            VStack(alignment: .leading, spacing: 14) {
                selectorHeader(title: L10n.dateRange, icon: "calendar.badge.clock")

                VStack(spacing: 14) {
                    // From
                    HStack {
                        Text(L10n.from)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.subtleGray)
                            .frame(width: 44, alignment: .leading)
                        DatePicker("", selection: $bookingDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(AppConfig.accentFg)
                            .onChange(of: bookingDate) { _, newFrom in
                                // Keep dateTo >= dateFrom
                                if bookingDateTo < newFrom { bookingDateTo = newFrom }
                            }
                    }

                    Divider().overlay(AppConfig.outlineVariant)

                    // To
                    HStack {
                        Text(L10n.to)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.subtleGray)
                            .frame(width: 44, alignment: .leading)
                        DatePicker("", selection: $bookingDateTo,
                                   in: bookingDate...,
                                   displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(AppConfig.accentFg)
                    }
                }

                // Range summary badge
                let days = Calendar.current.dateComponents([.day], from: bookingDate, to: bookingDateTo).day ?? 0
                if days > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.caption)
                            .foregroundStyle(AppConfig.activeGreen)
                        Text(L10n.daysSummary(days + 1, from: bookingDate.formatNaturalShort(), to: bookingDateTo.formatNaturalShort()))
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.darkText)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // Standard single-day date pills
    private var regularDateSection: some View {
        selectorCard {
            VStack(alignment: .leading, spacing: 14) {
                selectorHeader(title: L10n.date, icon: "calendar")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let calendar = Calendar.current
                        let today = calendar.startOfDay(for: Date())
                        let days = maxAdvanceDays
                        ForEach(0..<min(days + 1, 8), id: \.self) { offset in
                            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                                quickDateButton(date: date, offset: offset)
                            }
                        }
                    }
                }
            }
        }
    }

    private func quickDateButton(date: Date, offset: Int) -> some View {
        let isSelected = Calendar.current.isDate(bookingDate, inSameDayAs: date)
        let innerWidth: CGFloat = 78
        let innerHeight: CGFloat = 58
        let pillRadius: CGFloat = 14
        let label: String = {
            switch offset {
            case 0: return L10n.today
            case 1: return L10n.tomorrow
            default: return date.formatNaturalShort()
            }
        }()

        return Button {
            withAnimation(.standard) {
                bookingDate   = date
                bookingDateTo = date
                if let spot = selectedSpot,
                   !bookingManager.isSpotAvailable(
                    spotLabel: spot.label,
                    on: date,
                    timeFrom: timeFrom,
                    timeTo: timeTo,
                    excludingBookingID: editingBooking?.id
                   ) {
                    selectedSpot = nil
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                    .fill(isSelected ? AppConfig.pillSelected : AppConfig.surfaceLow)
                    .frame(width: innerWidth, height: innerHeight)

                VStack(spacing: 3) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(.body, design: .rounded, weight: .bold))
                }
                .foregroundStyle(isSelected ? .white : AppConfig.subtleGray)
                .frame(width: innerWidth, height: innerHeight)
            }
            .shadow(color: .black.opacity(isSelected ? 0.10 : 0.03), radius: 5, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Time Section

    @State private var showTimePickers = false

    private var timeSection: some View {
        selectorCard {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.standard) { showTimePickers.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .foregroundStyle(AppConfig.subtleGray)

                        Text("\(timeFrom) – \(timeTo)")
                            .font(.headline)
                            .foregroundStyle(AppConfig.darkText)

                        Spacer()

                        Image(systemName: showTimePickers ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 50)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())

                if showTimePickers {
                    HStack(spacing: 12) {
                        // From picker
                        VStack(alignment: .center, spacing: 4) {
                            Text(L10n.from)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppConfig.subtleGray)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Menu {
                                ForEach(AppConfig.availableTimeSlots, id: \.self) { t in
                                    Button {
                                        timeFrom = t
                                    } label: {
                                        if t == timeFrom {
                                            Label(t, systemImage: "checkmark")
                                        } else {
                                            Text(t)
                                        }
                                    }
                                }
                            } label: {
                                ZStack {
                                    Text(timeFrom)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    HStack {
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppConfig.subtleGray)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 12)
                                .frame(minHeight: 50)
                                .contentShape(Rectangle())
                            }
                            .frame(maxWidth: .infinity)
                            .bookingMiniPill()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxWidth: .infinity)

                        VStack {
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                            Spacer(minLength: 0)
                        }
                        .frame(width: 20)
                        .padding(.top, 18)

                        // To picker
                        VStack(alignment: .center, spacing: 4) {
                            Text(L10n.to)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppConfig.subtleGray)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Menu {
                                ForEach(AppConfig.availableTimeSlots, id: \.self) { t in
                                    Button {
                                        timeTo = t
                                    } label: {
                                        if t == timeTo {
                                            Label(t, systemImage: "checkmark")
                                        } else {
                                            Text(t)
                                        }
                                    }
                                }
                            } label: {
                                ZStack {
                                    Text(timeTo)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppConfig.darkText)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    HStack {
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppConfig.subtleGray)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 12)
                                .frame(minHeight: 50)
                                .contentShape(Rectangle())
                            }
                            .frame(maxWidth: .infinity)
                            .bookingMiniPill()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let spot = selectedSpot,
                   let occupiedRanges = bookingManager.occupiedTimeRangesText(
                    spotLabel: spot.label,
                    on: bookingDate,
                    excludingBookingID: editingBooking?.id
                   ) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                            Text("Occupied: \(occupiedRanges)")
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray)
                                .lineLimit(2)
                            Spacer()
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(AppConfig.subtleGray)
                            Text("Free windows are still bookable. Pick From/To to reserve remaining time.")
                                .font(.caption2)
                                .foregroundStyle(AppConfig.subtleGray)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
    }

    // MARK: - Book for Others

    private var bookForOthersSection: some View {
        Button {
            withAnimation(.standard) { isForOthersToggle.toggle() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isForOthersToggle ? "person.2.fill" : "person.badge.plus")
                    .font(.title3)
                    .foregroundStyle(AppConfig.subtleGray)
                    .frame(width: 44, height: 44)
                    .background(AppConfig.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.delegateBooking)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppConfig.darkText)
                    Text(L10n.bookForOthersSublabel(AppConfig.othersBookingMaxAdvanceDays))
                        .font(.caption2)
                        .foregroundStyle(AppConfig.subtleGray)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isForOthersToggle ? AppConfig.darkText.opacity(0.22) : AppConfig.surfaceHigh)
                        .frame(width: 52, height: 32)
                    Circle()
                        .fill(isForOthersToggle ? AppConfig.darkText : AppConfig.cardBg)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                        .offset(x: isForOthersToggle ? 10 : -10)
                }
            }
            .padding(16)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                isForOthersToggle ?
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppConfig.separatorSoft, lineWidth: 1.5)
                : nil
            )
            .cardShadow()
            .animation(.standard, value: isForOthersToggle)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal)
    }

    // MARK: - Delegate Navigation Guide Card

    private var delegateNavGuideCard: some View {
        VStack(spacing: 10) {
            DelegateNavGuideCard()

            // Let the sender opt out of attaching the route photos.
            Toggle(isOn: $includeNavGuide.animation(.motionSelection)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.shareIncludeNavGuide)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppConfig.darkText)
                    Text(L10n.shareIncludeNavGuideHint)
                        .font(.caption2)
                        .foregroundStyle(AppConfig.subtleGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(AppConfig.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Renders the photo navigation guide as a share-ready image.
    private func renderNavGuideImage() -> UIImage? {
        let renderer = ImageRenderer(content:
            NavigationGuideShareCardView(spotNumber: syntheticBooking.spotNumber)
                .frame(width: 360)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3.0
        return renderer.uiImage
    }

    // MARK: - Person Fields

    private var personSection: some View {
        sectionCard(title: L10n.bookingFor, icon: "person") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "person")
                        .foregroundStyle(AppConfig.subtleGray)
                        .frame(width: 20)
                    TextField(L10n.fullName, text: $userName)
                        .focused($personFocus, equals: .name)
                        .textContentType(.name)
                        .autocorrectionDisabled(true)
                        .submitLabel(.next)
                }
                .padding()
                .contentShape(RoundedRectangle(cornerRadius: 14))
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 12) {
                    Image(systemName: "envelope")
                        .foregroundStyle(AppConfig.subtleGray)
                        .frame(width: 20)
                    TextField(L10n.email, text: $userEmail)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                        .focused($personFocus, equals: .email)
                        .submitLabel(.done)
                }
                .padding()
                .contentShape(RoundedRectangle(cornerRadius: 14))
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .onSubmit {
                switch personFocus {
                case .name:
                    personFocus = .email
                case .email:
                    personFocus = nil
                case .none:
                    break
                }
            }
        }
    }

    // MARK: - Confirm

    private var confirmButton: some View {
        let noSpot = selectedSpot == nil
        let canSubmit = isValid && !isSubmitting

        return Button {
            Task { await submitBooking() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(confirmButtonBackground(noSpot: noSpot))
                    .overlay {
                        if confirmVisualState == .loading && !reduceMotion {
                            NativeSystemShimmerView()
                        }
                    }

                ZStack {
                    HStack(spacing: 8) {
                        Image(systemName: confirmButtonIcon(noSpot: noSpot))
                            .font(.body.weight(.bold))
                        Text(confirmTitle(for: .idle, noSpot: noSpot))
                            .font(.body)
                            .fontWeight(.bold)
                    }
                    .opacity(confirmVisualState == .idle ? 1.0 : 0.0)
                    .scaleEffect(confirmVisualState == .idle ? 1.0 : 0.93)
                    .animation(globalSystemSpring, value: confirmVisualState)

                    ProgressView()
                        .tint(confirmButtonForeground(noSpot: noSpot))
                        .opacity(confirmVisualState == .loading ? 1.0 : 0.0)
                        .scaleEffect(confirmVisualState == .loading ? 1.0 : 0.7)
                        .animation(globalSystemSpring, value: confirmVisualState)

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3.weight(.bold))
                        Text(confirmTitle(for: .success, noSpot: noSpot))
                            .font(.body)
                            .fontWeight(.bold)
                    }
                    .opacity(confirmVisualState == .success ? 1.0 : 0.0)
                    .scaleEffect(confirmVisualState == .success ? 1.0 : 0.85)
                    .animation(successSnapSpring, value: confirmVisualState)

                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3.weight(.bold))
                        Text(confirmTitle(for: .failure, noSpot: noSpot))
                            .font(.body)
                            .fontWeight(.bold)
                    }
                    .opacity(confirmVisualState == .failure ? 1.0 : 0.0)
                    .scaleEffect(confirmVisualState == .failure ? 1.0 : 0.85)
                    .animation(successSnapSpring, value: confirmVisualState)
                }
                .foregroundStyle(confirmButtonForeground(noSpot: noSpot))
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(SystemMicroButtonStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : noSpot ? 0.8 : 0.5)
        .padding(.horizontal)
        .animation(globalSystemSpring, value: canSubmit)
    }

    private struct SystemMicroButtonStyle: ButtonStyle {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
                .animation(.spring(response: 0.20, dampingFraction: 0.85), value: configuration.isPressed)
        }
    }

    private struct NativeSystemShimmerView: View {
        @State private var phase: CGFloat = 0

        var body: some View {
            GeometryReader { proxy in
                let w = proxy.size.width
                LinearGradient(
                    colors: [.white.opacity(0.0), .white.opacity(0.18), .white.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: w * 0.35)
                .offset(x: -w + (phase * (w * 2)))
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1.0
                    }
                }
            }
            .clipShape(Capsule())
        }
    }

    private func confirmTitle(for state: ConfirmVisualState, noSpot: Bool) -> String {
        switch state {
        case .success:
            return isEditing ? L10n.bookingUpdated : L10n.bookingConfirmed
        case .failure:
            return L10n.tryAgain
        case .loading:
            return L10n.saving
        case .idle:
            return isEditing ? L10n.save : noSpot ? L10n.selectASpotAbove : L10n.confirmBooking
        }
    }

    // MARK: - Helpers

    private func confirmButtonIcon(noSpot: Bool) -> String {
        if isEditing { return "checkmark.circle.fill" }
        return noSpot ? "parkingsign" : "checkmark.circle.fill"
    }

    private func confirmButtonForeground(noSpot: Bool) -> Color {
        if noSpot || confirmVisualState == .idle && !isValid {
            return AppConfig.subtleGray
        }
        return AppConfig.onAccent
    }

    private func confirmButtonBackground(noSpot: Bool) -> Color {
        switch confirmVisualState {
        case .success:
            return AppConfig.activeGreen
        case .failure:
            return AppConfig.spotOccupied
        case .loading:
            return AppConfig.accent.opacity(0.9)
        case .idle:
            return noSpot ? AppConfig.surfaceHigh : AppConfig.accent
        }
    }

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppConfig.surfaceHigh)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppConfig.subtleGray)
                }
                .frame(width: 28, height: 28)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppConfig.darkText)
            }
            content()
        }
        .padding(18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .cardShadow()
        .padding(.horizontal)
    }

    private func selectorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(18)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .cardShadow()
        .padding(.horizontal)
    }

    private func selectorHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppConfig.surfaceHigh)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .frame(width: 28, height: 28)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppConfig.darkText)
        }
    }

    private var sheetTitle: String {
        if isEditing { return L10n.editBooking }
        return isForOthersToggle ? L10n.bookForOthers : L10n.newBooking
    }

    private var bookableSpots: [ParkingSpot] {
        bookingManager.parkingSpots.filter {
            !AppConfig.blockedSpotIDs.contains($0.id)
                && AppConfig.spotVisible(spotID: $0.id,
                                         company: bookingManager.currentUserCompany,
                                         isAdmin: bookingManager.isAdmin,
                                         bookingDate: bookingDate)
        }
    }

    private var isValid: Bool {
        guard selectedSpot != nil, isSelectedSpotValid else { return false }
        if isForOthersToggle {
            let targetEmail = normalizedEmail(userEmail)
            return !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !targetEmail.isEmpty &&
                timeFrom < timeTo
        }
        return timeFrom < timeTo
    }

    // MARK: - Submit

    private func submitBooking() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let submitStartedAt = Date()
        withAnimation(motionQuick) { confirmVisualState = .loading }

        guard let spot = selectedSpot else {
            errorMessage = L10n.pleaseSelectSpot
            showingError = true
            await showFailureState()
            return
        }

        let calendar = Calendar.current
        let advanceDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: bookingDate)).day ?? 0

        if advanceDays > maxAdvanceDays {
            errorMessage = bookingManager.isPrivileged
                ? L10n.tooFarInAdvance(maxAdvanceDays)
                : L10n.bookingWindowStandardError
            showingError = true
            await showFailureState()
            return
        }

        if timeFrom >= timeTo {
            errorMessage = L10n.endTimeAfterStart
            showingError = true
            await showFailureState()
            return
        }

        do {
            if let editing = editingBooking {
                try await bookingManager.updateBooking(
                    bookingID: editing.id,
                    newSpotLabel: spot.label,
                    newDate: bookingDate,
                    newTimeFrom: timeFrom,
                    newTimeTo: timeTo
                )
            } else {
                let email = isForOthersToggle ? normalizedEmail(userEmail) : normalizedEmail(bookingManager.currentUserEmail)
                let name = isForOthersToggle ? userName.trimmingCharacters(in: .whitespacesAndNewlines) : bookingManager.currentUserName

                if isForOthersToggle && email == normalizedEmail(bookingManager.currentUserEmail) {
                    errorMessage = L10n.selfDelegationNotAllowed
                    showingError = true
                    return
                }

                try await bookingManager.createBooking(
                    spotID: spot.id,
                    spotLabel: spot.label,
                    userEmail: email,
                    userName: name,
                    dateFrom: bookingDate,
                    dateTo: bookingDateTo,   // single day = same as bookingDate; admin range = end date
                    timeFrom: timeFrom,
                    timeTo: timeTo
                )
            }

            await ensureMinimumLoadingTime(since: submitStartedAt)
            withAnimation(motionStandard) { confirmVisualState = .success }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 220 : 420))
            // Success haptic fires from the overlay choreography, timed to the car settling.
            withAnimation(.emphasis) { showSuccess = true }

            // Stay on success overlay — user must tap "Got it!" to dismiss.
        } catch {
            let msg = error.localizedDescription
            errorMessage = msg
            showingError = true
            ToastManager.shared.show(msg, style: .error)
            await ensureMinimumLoadingTime(since: submitStartedAt)
            await showFailureState()
        }
    }

    @MainActor
    private func showFailureState() async {
        withAnimation(motionQuick) { confirmVisualState = .failure }
        Haptics.notify(.error)
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 220 : 460))
        withAnimation(motionQuick) { confirmVisualState = .idle }
    }

    private func ensureMinimumLoadingTime(since start: Date) async {
        let elapsed = Date().timeIntervalSince(start)
        let minDuration: TimeInterval = reduceMotion ? 0.16 : 0.30
        if elapsed < minDuration {
            let remaining = minDuration - elapsed
            try? await Task.sleep(for: .seconds(remaining))
        }
    }

    private func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.55 * bgOpacity)
                .ignoresSafeArea()
                .onTapGesture {} // absorb taps

            VStack(spacing: 24) {
                Spacer()

                // ── Raised booking card ────────────────────────────────────
                confirmationCard
                    .scaleEffect(cardScale)
                    .offset(y: cardOffset)
                    .opacity(cardOpacity)

                // ── Actions ────────────────────────────────────────────────
                VStack(spacing: 12) {
                    if isForOthersToggle && !isEditing {
                        // Delegated booking — share actions
                        Button { showShareOptions = true } label: {
                            Label(L10n.shareBooking, systemImage: "square.and.arrow.up")
                                .font(.body).fontWeight(.semibold)
                                .foregroundStyle(AppConfig.onAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(AppConfig.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Button { openDelegationMailTo() } label: {
                            Label(L10n.sendViaEmail, systemImage: "envelope")
                                .font(.body).fontWeight(.semibold)
                                .foregroundStyle(AppConfig.darkText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(AppConfig.surfaceHigh)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    Button { landCard() } label: {
                        Text(L10n.done)
                            .font(.body.bold())
                            .foregroundStyle(isForOthersToggle && !isEditing ? AppConfig.darkText : AppConfig.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isForOthersToggle && !isEditing ? AppConfig.surfaceHigh : AppConfig.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .opacity(actionsOpacity)
                .padding(.horizontal, 24)

                Spacer().frame(height: 12)
            }
        }
        .onAppear {
            guard !isDismissing else { return }
            // Reset
            cardOffset = 380
            cardScale = 1.0
            cardOpacity = 0
            bgOpacity = 0
            actionsOpacity = 0
            carParked = false

            // 1. Background fades in
            withAnimation(motionFade) { bgOpacity = 1 }

            // 2. Restrained entrance (Linear-like): no bounce, slight rise/fade.
            withAnimation((reduceMotion ? Animation.linear(duration: 0.01) : .easeOut(duration: 0.22)).delay(reduceMotion ? 0 : 0.02)) {
                cardOffset = -22
                cardScale = 1.0
                cardOpacity = 1
            }

            // 3. Actions appear sooner so the whole confirmation feels instant
            withAnimation((reduceMotion ? Animation.linear(duration: 0.01) : .easeOut(duration: 0.14)).delay(reduceMotion ? 0 : 0.12)) {
                actionsOpacity = 1
            }

            // 4. The car drives into the spot; haptic thunk as it settles.
            if parkedVehicleUser != nil {
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.25).delay(0.15)) { carParked = true }
                    Haptics.notify(.success)
                } else {
                    withAnimation(.spring(duration: 0.9, bounce: 0.12).delay(0.40)) { carParked = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                        Haptics.parked()
                    }
                }
            } else {
                Haptics.notify(.success)
            }
        }
        .transition(.opacity)
    }

    /// The booker's own vehicle, shown driving into the confirmed spot.
    /// Hidden for delegated bookings, admin range bookings, and users with no
    /// vehicle visual on file.
    private var parkedVehicleUser: AppUser? {
        guard !isForOthersToggle, !isAdminRangeMode,
              let user = authManager.currentUser,
              !user.vehicleMiniaturePresetID.isEmpty || !user.carDescription.isEmpty
        else { return nil }
        return user
    }

    /// The parking ticket card shown in the success overlay.
    private var confirmationCard: some View {
        VStack(spacing: 0) {
            // ── Header band ────────────────────────────────────────────────
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppConfig.activeGreen)
                        .symbolEffect(.bounce, value: showSuccess)
                    Text(isEditing ? L10n.bookingUpdated : L10n.bookingConfirmed)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppConfig.activeGreen)
                }
                Spacer()
                Text("EL PARKING")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(AppConfig.surfaceHigh)

            // ── Body ───────────────────────────────────────────────────────
            VStack(spacing: 20) {
                // Giant spot number
                if !isAdminRangeMode, let spot = selectedSpot {
                    Text(spot.id)
                        .font(.system(size: 88, weight: .black, design: .rounded))
                        .foregroundStyle(AppConfig.accent)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }

                // The user's own car drives into the spot
                if let vehicleUser = parkedVehicleUser {
                    VehicleMiniatureView(
                        carType: vehicleUser.carType,
                        colorHex: vehicleUser.carColor,
                        description: vehicleUser.carDescription,
                        presetID: vehicleUser.vehicleMiniaturePresetID.isEmpty
                            ? nil : vehicleUser.vehicleMiniaturePresetID,
                        useFastRendering: true
                    )
                    .frame(width: 150, height: 84)
                    // Rasterize so the slide animates as one cheap texture.
                    .drawingGroup()
                    // Starts beyond the card's right edge (clipped away), then drives in leftward.
                    .offset(x: carParked || reduceMotion ? 0 : 360)
                    .opacity(reduceMotion ? (carParked ? 1 : 0) : 1)
                    .accessibilityHidden(true)
                }

                // Ticket perforation line
                HStack(spacing: 5) {
                    ForEach(0..<22, id: \.self) { _ in
                        Circle()
                            .fill(AppConfig.outlineVariant)
                            .frame(width: 4, height: 4)
                    }
                }

                // Date / Time row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DATE")
                            .font(.caption2.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(AppConfig.subtleGray)
                        if isAdminRangeMode,
                           Calendar.current.dateComponents([.day], from: bookingDate, to: bookingDateTo).day ?? 0 > 0 {
                            Text("\(bookingDate.formatNaturalShort()) – \(bookingDateTo.formatNaturalShort())")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppConfig.darkText)
                        } else {
                            Text(bookingDate.formatNaturalShort())
                                .font(.subheadline.bold())
                                .foregroundStyle(AppConfig.darkText)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("TIME")
                            .font(.caption2.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(AppConfig.subtleGray)
                        Text("\(timeFrom) – \(timeTo)")
                            .font(.system(.subheadline, design: .monospaced, weight: .bold))
                            .foregroundStyle(AppConfig.darkText)
                    }
                }
            }
            .padding(24)
            .background(AppConfig.cardBg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .modalShadow()
        .padding(.horizontal, 24)
    }

    /// Animates the card landing into My Bookings, then dismisses.
    private func landCard() {
        isDismissing = true
        Haptics.action()

        // Actions disappear immediately
        withAnimation(.quick) { actionsOpacity = 0 }

        // Card flies down and shrinks — like it's landing in the list
        withAnimation((reduceMotion ? Animation.linear(duration: 0.01) : .easeIn(duration: 0.18)).delay(reduceMotion ? 0 : 0.01)) {
            cardOffset = 700
            cardScale = 1.0
            cardOpacity = 0
        }
        withAnimation((reduceMotion ? Animation.linear(duration: 0.01) : .easeOut(duration: 0.10)).delay(reduceMotion ? 0 : 0.01)) { bgOpacity = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.23)) {
            deepLinkManager.navigate(to: .myBookings)
            dismiss()
        }
    }

    // MARK: - Delegation Share Helpers

    /// Synthetic Booking built from current form state — used only for card rendering.
    private var syntheticBooking: Booking {
        Booking(
            id:        UUID(),
            title:     "Reservation for \(userName)",
            spot:      selectedSpot?.label ?? "",
            user:      userName,
            email:     userEmail,
            date:      bookingDate,
            fromTime:  timeFrom,
            toTime:    timeTo,
            createdBy: bookingManager.currentUserEmail,
            groupID:   nil
        )
    }

    private var delegationShareText: String {
        L10n.delegatedBookingShareBody(
            name: userName,
            spot: selectedSpot?.id ?? "",
            date: bookingDate.formatNaturalShort(),
            timeFrom: timeFrom,
            timeTo: timeTo,
            rangeEndDate: isAdminRangeMode ? bookingDateTo.formatNaturalShort() : nil
        )
    }

    /// Renders the branded card as a UIImage and presents the system share sheet.
    private func shareRenderedCard() {
        let renderer = ImageRenderer(content:
            BookingShareCardView(
                booking: syntheticBooking,
                rangeEndDate: isAdminRangeMode ? bookingDateTo : nil
            )
            .frame(width: 360)
            .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3.0
        var items: [Any] = []
        if let img = renderer.uiImage { items.append(img) }
        if includeNavGuide, let navImg = renderNavGuideImage() { items.append(navImg) }
        items.append(delegationShareText)
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        av.overrideUserInterfaceStyle = .light
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        // iPad requires an anchor for UIActivityViewController or it crashes on present.
        if let pop = av.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(av, animated: true)
    }

    private func shareTextOnly() {
        let av = UIActivityViewController(activityItems: [delegationShareText], applicationActivities: nil)
        av.overrideUserInterfaceStyle = .light
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        // iPad requires an anchor for UIActivityViewController or it crashes on present.
        if let pop = av.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(av, animated: true)
    }

    /// Opens the native Mail composer with the card image attached inline.
    /// Falls back to mailto: URL if Mail is not configured on the device.
    private func openDelegationMailTo() {
        guard MFMailComposeViewController.canSendMail() else {
            // Fallback: plain mailto: link
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "+&=#")
            let sub  = L10n.delegatedBookingEmailSubject
                .addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            let body = delegationShareText
                .addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            if let url = URL(string: "mailto:\(userEmail)?subject=\(sub)&body=\(body)") {
                UIApplication.shared.open(url)
            }
            return
        }

        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = _mailDelegate
        composer.setToRecipients([userEmail])
        composer.setSubject(L10n.delegatedBookingEmailSubject)
        composer.setMessageBody(delegationShareText, isHTML: false)

        // Render the branded card and attach it as a PNG
        let renderer = ImageRenderer(content:
            BookingShareCardView(
                booking: syntheticBooking,
                rangeEndDate: isAdminRangeMode ? bookingDateTo : nil
            )
            .frame(width: 360)
            .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3.0
        if let img = renderer.uiImage, let data = img.pngData() {
            composer.addAttachmentData(data, mimeType: "image/png", fileName: "parking-booking.png")
        }
        if includeNavGuide, let navImg = renderNavGuideImage(), let navData = navImg.pngData() {
            composer.addAttachmentData(navData, mimeType: "image/png", fileName: "how-to-find-your-spot.png")
        }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(composer, animated: true)
    }
}

// MARK: - Glass-like Card Chrome (SDK-compatible)

private struct BookingCardChrome: ViewModifier {
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    func body(content: Content) -> some View {
        if !AppConfig.enableBookingPremiumGlass {
            content
                .padding(verticalPadding)
                .padding(.horizontal, horizontalPadding)
                .background(AppConfig.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .cardShadow()
                .padding(.horizontal)
        } else {
            // Real Liquid Glass — replaces the previous hand-painted
            // material + sheen + rim imitation.
            content
                .padding(verticalPadding)
                .padding(.horizontal, horizontalPadding)
                .glassEffect(
                    .frosted,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .padding(.horizontal)
        }
    }
}

private struct BookingMiniPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppConfig.darkText.opacity(0.07))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppConfig.outlineVariant.opacity(0.25), lineWidth: 1)
            )
    }
}

private extension View {
    func bookingMiniPill() -> some View {
        modifier(BookingMiniPillModifier())
    }
}

// MARK: - Cancel Success Overlay

struct CancelSuccessOverlay: View {
    let spotNumber: String
    let date: String
    let timeFrom: String
    let timeTo: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cardOffset: CGFloat = 380
    @State private var cardScale: CGFloat = 0.78
    @State private var cardOpacity: Double = 0
    @State private var bgOpacity: Double = 0
    @State private var didDismiss = false

    private var motionStandard: Animation {
        reduceMotion ? Animation.linear(duration: 0.01) : .easeInOut(duration: 0.18)
    }

    private var motionFade: Animation {
        reduceMotion ? Animation.linear(duration: 0.01) : .easeOut(duration: 0.14)
    }

    var body: some View {
        ZStack {
            // Solid page background — completely hides the underlying view
            // so the user never sees the booking disappear from the list.
            AppConfig.pageBg
                .opacity(bgOpacity)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 0) {
                Spacer()

                cancelCard
                    .scaleEffect(cardScale)
                    .offset(y: cardOffset)
                    .opacity(cardOpacity)

                // Space reserved for the Done/Undo toast that appears below
                Spacer().frame(height: 180)
            }
        }
        .onAppear {
            cardOffset = 380; cardScale = 1.0; cardOpacity = 0; bgOpacity = 0
            didDismiss = false

            withAnimation(motionFade) { bgOpacity = 1 }
            withAnimation((reduceMotion ? Animation.linear(duration: 0.01) : .easeOut(duration: 0.22)).delay(reduceMotion ? 0 : 0.02)) {
                cardOffset = -18; cardScale = 1.0; cardOpacity = 1
            }
            Task {
                try? await Task.sleep(for: .seconds(reduceMotion ? 1.0 : 1.8))
                if !didDismiss {
                    dismissCard()
                }
            }
        }
        // Both "Done" and "Undo" on the toast dismiss this overlay
        .onReceive(NotificationCenter.default.publisher(for: .cancelOverlayDismiss)) { _ in
            dismissCard()
        }
        .transition(.opacity)
    }

    private var cancelCard: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppConfig.spotOccupied)
                    Text("Booking Cancelled")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppConfig.spotOccupied)
                }
                Spacer()
                Text("EL PARKING")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(AppConfig.spotOccupied.opacity(0.18))

            // ── Body ──────────────────────────────────────────────────────
            VStack(spacing: 20) {
                // Spot number ghosted behind a big X
                ZStack {
                    Text(spotNumber)
                        .font(.system(size: 88, weight: .black, design: .rounded))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.18))

                    Image(systemName: "xmark")
                        .font(.system(size: 70, weight: .black))
                        .foregroundStyle(AppConfig.spotOccupied)
                }

                // Ticket perforation
                HStack(spacing: 5) {
                    ForEach(0..<22, id: \.self) { _ in
                        Circle()
                            .fill(AppConfig.outlineVariant)
                            .frame(width: 4, height: 4)
                    }
                }

                // Date / Time — struck through
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DATE")
                            .font(.caption2.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(AppConfig.subtleGray)
                        Text(date)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppConfig.darkText)
                            .strikethrough(true, color: AppConfig.subtleGray)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("TIME")
                            .font(.caption2.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(AppConfig.subtleGray)
                        Text("\(timeFrom) – \(timeTo)")
                            .font(.system(.subheadline, design: .monospaced, weight: .bold))
                            .foregroundStyle(AppConfig.darkText)
                            .strikethrough(true, color: AppConfig.subtleGray)
                    }
                }
            }
            .padding(24)
            .background(AppConfig.cardBg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .modalShadow()
        .padding(.horizontal, 24)
    }

    private func dismissCard() {
        guard !didDismiss else { return }
        Haptics.action()
        didDismiss = true
        withAnimation(motionStandard) {
            bgOpacity = 0
            cardOpacity = 0
            cardScale = 1.0
            cardOffset = 28
        }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 130))
            onDismiss()
        }
    }
}

// MARK: - Delegate Navigation Guide Card

private struct DelegateNavGuideCard: View {

    private static let photos = ["ParkingGarage1", "ParkingGarage2", "ParkingGarage3", "ParkingGarage4"]
    @State private var photoIndex = 0

    var body: some View {
        HStack(spacing: 0) {
            // Photo side
            ZStack {
                ForEach(0..<Self.photos.count, id: \.self) { i in
                    Image(Self.photos[i])
                        .resizable()
                        .scaledToFill()
                        .opacity(photoIndex == i ? 1 : 0)
                }
                // Blue chevron badge matching real-world arrows
                Image(systemName: "chevron.up.2")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            }
            .frame(width: 110)
            .clipped()

            // Text side
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppConfig.accentFg)
                    Text(L10n.delegateNavGuideTitle)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppConfig.darkText)
                }

                Text(L10n.delegateNavGuideDesc)
                    .font(.caption)
                    .foregroundStyle(AppConfig.subtleGray)
                    .fixedSize(horizontal: false, vertical: true)

                // Photo dots
                HStack(spacing: 4) {
                    ForEach(0..<Self.photos.count, id: \.self) { i in
                        Capsule()
                            .fill(photoIndex == i ? AppConfig.accentFg : AppConfig.subtleGray.opacity(0.3))
                            .frame(width: photoIndex == i ? 14 : 5, height: 5)
                            .animation(.motionSelection, value: photoIndex)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 110)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow()
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.8)) {
                    photoIndex = (photoIndex + 1) % Self.photos.count
                }
            }
        }
    }
}

#Preview {
    BookingSheet(isForOthers: false)
        .environmentObject(BookingManager())
}
