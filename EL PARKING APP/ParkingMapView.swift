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
    @State private var highlightStatus: SpotMapFilter = .all

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
                    Button {
                        guard highlightStatus != filter else { return }
                        Haptics.selection()
                        withAnimation(.standard) { highlightStatus = filter }
                    } label: {
                        Text(filter.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(highlightStatus == filter ? AppConfig.onAccent : AppConfig.subtleGray)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(highlightStatus == filter ? AppConfig.accent : AppConfig.cardBg)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
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
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppConfig.surfaceLow)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "map")
                                .font(.system(size: 52))
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.25))
                            Text("Parking Layout Map")
                                .font(.headline)
                                .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
                            Text("Add a floor plan image in ParkingMapView.swift\nand position spots with .offset(x:y:)")
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
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .opacity(highlightStatus == .all || matchesFilter(status) ? 1.0 : 0.3)
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: 16) {
            legendItem(color: AppConfig.activeGreen,   label: L10n.free)
            legendItem(color: AppConfig.spotOccupied,  label: L10n.taken)
            legendItem(color: AppConfig.accent,         label: "Mine")
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
        case free, mine, taken, blocked
    }

    private func localSpotStatus(for spot: ParkingSpot) -> MapSpotStatus {
        if AppConfig.blockedSpotIDs.contains(spot.id) { return .blocked }
        if let booking = bookingManager.getBookingForSpotOnDate(spotLabel: spot.label, date: selectedDate) {
            return booking.email == bookingManager.currentUserEmail ? .mine : .taken
        }
        return .free
    }

    private func pinColor(_ status: MapSpotStatus) -> Color {
        switch status {
        case .free:     return AppConfig.activeGreen
        case .mine:     return AppConfig.accent
        case .taken:    return AppConfig.spotOccupied
        case .blocked:  return AppConfig.subtleGray
        }
    }

    private func matchesFilter(_ status: MapSpotStatus) -> Bool {
        switch highlightStatus {
        case .all:     return true
        case .free:    return status == .free
        case .taken:   return status == .taken || status == .mine
        case .blocked: return status == .blocked
        }
    }
}

// MARK: - Filter Enum

enum SpotMapFilter: CaseIterable {
    case all, free, taken, blocked
    var label: String {
        switch self {
        case .all:     return "All"
        case .free:    return L10n.free
        case .taken:   return L10n.taken
        case .blocked: return L10n.blocked
        }
    }
}
