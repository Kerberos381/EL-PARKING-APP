//
//  ParkingMapView.swift
//  EL PARKING APP
//
//  Parking lot layout map — shows physical positions of spots.
//
//  IMPLEMENTATION NOTE:
//  Replace the placeholder below with a ZStack containing:
//    1. Image("parking_layout") — an image of your actual parking lot
//    2. ForEach(spots) overlay — colored circles/pins positioned with .offset()
//       to match physical spot locations on the image
//  The spot positions are defined in AppConfig.spotMapPositions (add when ready).
//
//  TO ADD TO THE APP:
//  In OverviewView, add a toolbar button or a segment to switch between
//  Grid view and Map view.

import SwiftUI

struct ParkingMapView: View {
    @EnvironmentObject var bookingManager: BookingManager
    let selectedDate: Date

    // Map mode: which status to highlight
    @State private var highlightStatus: SpotMapFilter = .free

    private var spots: [ParkingSpot] { bookingManager.parkingSpots }

    var body: some View {
        ZStack {
            AppConfig.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter pills
                filterBar
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Map area
                mapArea

                // Legend
                legendBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SpotMapFilter.allCases, id: \.self) { filter in
                    let count = filterCount(filter)
                    Button {
                        guard highlightStatus != filter else { return }
                        Haptics.selection()
                        withAnimation(.standard) { highlightStatus = filter }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.caption.weight(.bold))
                                .accessibilityHidden(true)
                            Text(filter.label)
                            Text("\(count)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    (highlightStatus == filter ? AppConfig.onAccent : AppConfig.surfaceLow)
                                        .opacity(highlightStatus == filter ? 0.22 : 1.0)
                                )
                                .clipShape(Capsule())
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(highlightStatus == filter ? AppConfig.onAccent : AppConfig.subtleGray)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(highlightStatus == filter ? AppConfig.accent : AppConfig.cardBg)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(L10n.mapFilterAccessibility(label: filter.label, count: count))
                }
            }
        }
    }

    // MARK: - Map Area

    private var mapArea: some View {
        GeometryReader { geo in
            ZStack {
                // ── Background placeholder ─────────────────────────────────
                // TODO: Replace with Image("parking_layout").resizable().scaledToFit()
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppConfig.surfaceLow)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "map")
                                .font(.system(size: 52))
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.25))
                            Text(L10n.parkingLayoutMap)
                                .font(.headline)
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
                            Text(L10n.parkingLayoutMapHint)
                                .font(.caption)
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.35))
                                .multilineTextAlignment(.center)
                        }
                    )
                    .padding(.horizontal, 16)

                // ── Spot pins ─────────────────────────────────────────────
                // TODO: When image is added, replace with real positions from AppConfig.spotMapPositions
                // Example:
                // ForEach(spots) { spot in
                //     spotPin(spot)
                //         .position(AppConfig.spotMapPositions[spot.id] ?? CGPoint(x: 50, y: 50))
                // }
            }
        }
    }

    // MARK: - Spot Pin

    private func spotPin(_ spot: ParkingSpot) -> some View {
        let status = localSpotStatus(for: spot)
        return ZStack {
            Circle()
                .fill(pinColor(status))
                .frame(width: 36, height: 36)
            Text(spot.id)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .opacity(matchesFilter(status) ? 1.0 : 0.25)
        .accessibilityLabel(accessibilityLabel(for: spot, status: status))
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: 16) {
            legendItem(color: AppConfig.activeGreen,   label: L10n.free)
            legendItem(color: AppConfig.accent,         label: L10n.mine)
            legendItem(color: AppConfig.spotOccupied,  label: L10n.visitors)
            legendItem(color: AppConfig.subtleGray,     label: L10n.blocked)
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption).foregroundStyle(AppConfig.subtleGray)
        }
    }

    // MARK: - Helpers

    private enum MapSpotStatus {
        case free, mine, visitor, blocked
    }

    private func localSpotStatus(for spot: ParkingSpot) -> MapSpotStatus {
        if AppConfig.blockedSpotIDs.contains(spot.id) { return .blocked }
        if let booking = bookingManager.getBookingForSpotOnDate(spotLabel: spot.label, date: selectedDate) {
            return booking.email == bookingManager.currentUserEmail ? .mine : .visitor
        }
        return .free
    }

    private func pinColor(_ status: MapSpotStatus) -> Color {
        switch status {
        case .free:     return AppConfig.activeGreen
        case .mine:     return AppConfig.accent
        case .visitor:  return AppConfig.spotOccupied
        case .blocked:  return AppConfig.subtleGray
        }
    }

    private func matchesFilter(_ status: MapSpotStatus) -> Bool {
        switch highlightStatus {
        case .free:     return status == .free
        case .mine:     return status == .mine
        case .visitors: return status == .visitor
        case .blocked:  return status == .blocked
        }
    }

    private func filterCount(_ filter: SpotMapFilter) -> Int {
        spots.filter { matchesFilter(localSpotStatus(for: $0), filter: filter) }.count
    }

    private func matchesFilter(_ status: MapSpotStatus, filter: SpotMapFilter) -> Bool {
        switch filter {
        case .free:     return status == .free
        case .mine:     return status == .mine
        case .visitors: return status == .visitor
        case .blocked:  return status == .blocked
        }
    }

    private func accessibilityLabel(for spot: ParkingSpot, status: MapSpotStatus) -> String {
        let label: String
        switch status {
        case .free:
            label = L10n.mapStatusAvailable
        case .mine:
            label = L10n.mapStatusMine
        case .visitor:
            label = L10n.mapStatusVisitor
        case .blocked:
            label = L10n.mapStatusBlocked
        }
        return L10n.spotStatusAccessibility(spotID: spot.id, status: label)
    }
}

// MARK: - Filter Enum

enum SpotMapFilter: CaseIterable {
    case free, mine, visitors, blocked

    var label: String {
        switch self {
        case .free:     return L10n.free
        case .mine:     return L10n.mine
        case .visitors: return L10n.visitors
        case .blocked:  return L10n.blocked
        }
    }

    var icon: String {
        switch self {
        case .free:     return "checkmark.circle.fill"
        case .mine:     return "car.fill"
        case .visitors: return "person.2.fill"
        case .blocked:  return "slash.circle.fill"
        }
    }
}
