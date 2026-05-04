//
//  AdminSpotsView.swift
//  EL PARKING APP
//
//  Admin view: block/unblock spots individually or in bulk, toggle accessibility.
//

import SwiftUI

struct AdminSpotsView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @ObservedObject private var lang = LanguageManager.shared

    @State private var bulkMode    = false
    @State private var selectedIDs = Set<String>()
    @State private var isInitialLoading = true

    private var spots:      [ParkingSpot] { bookingManager.parkingSpots }
    private var blockedIDs: Set<String>   { AppConfig.blockedSpotIDs }
    private var shouldShowLoadingSkeleton: Bool { isInitialLoading && spots.isEmpty }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppConfig.pageBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if shouldShowLoadingSkeleton {
                        loadingSkeleton
                    } else {
                        statsRow
                        spotsGrid
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, bulkMode ? 110 : 40)
            }
            .refreshable {
                Haptics.selection()
                await bookingManager.refreshData()
            }

            if bulkMode {
                bulkActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(L10n.spotManagement)
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard isInitialLoading else { return }
            await bookingManager.refreshData()
            withAnimation(.standard) { isInitialLoading = false }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(bulkMode ? L10n.done : L10n.select) {
                    Haptics.action()
                    withAnimation(.standard) {
                        bulkMode.toggle()
                        selectedIDs.removeAll()
                    }
                }
                .foregroundStyle(AppConfig.darkText)
                .fontWeight(.semibold)
            }
        }
        .animation(.standard, value: bulkMode)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statPill(value: "\(spots.count)",
                     label: L10n.total,
                     color: AppConfig.subtleGray)
            statPill(value: "\(blockedIDs.count)",
                     label: L10n.blocked,
                     color: AppConfig.spotOccupied)
            statPill(value: "\(spots.filter { $0.isAccessible }.count)",
                     label: L10n.accessible,
                     color: .blue)
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppConfig.subtleGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Spots Grid

    private var spotsGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(spots) { spot in
                spotCard(spot)
            }
        }
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 4) {
                        SkeletonBlock(height: 24, cornerRadius: 10)
                            .frame(width: 42)
                        SkeletonBlock(height: 11, cornerRadius: 6)
                            .frame(width: 52)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .tertiarySystemFill).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shimmering(active: true)
                }
            }

            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<18, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(height: 95)
                        .shimmering(active: true)
                }
            }
        }
    }

    @ViewBuilder
    private func spotCard(_ spot: ParkingSpot) -> some View {
        let isBlocked  = blockedIDs.contains(spot.id)
        let isSelected = selectedIDs.contains(spot.id)

        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: AppConfig.radius16)
                .fill(isBlocked ? AppConfig.spotOccupied.opacity(0.12) : AppConfig.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppConfig.radius16)
                        .stroke(
                            isBlocked
                                ? AppConfig.spotOccupied.opacity(0.35)
                                : (isSelected ? AppConfig.accent : AppConfig.accent.opacity(0.25)),
                            lineWidth: isSelected ? 2.5 : 1.5
                        )
                )
                .frame(height: 95)

            // Spot number + status
            VStack(spacing: 3) {
                Text(spot.id)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(isBlocked ? AppConfig.spotOccupied : AppConfig.darkText)

                if isBlocked {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text(L10n.blockedBadge)
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundStyle(AppConfig.spotOccupied)
                }
            }

            // Bulk select circle — top-left
            if bulkMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? AppConfig.accent : AppConfig.subtleGray.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(7)
            }

            // Accessibility toggle — top-right
            VStack {
                HStack {
                    Spacer()
                    Button {
                        guard !bulkMode else { return }
                        Haptics.action()
                        bookingManager.updateSpot(id: spot.id, isAccessible: !spot.isAccessible)
                    } label: {
                        Image(systemName: "figure.roll")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(spot.isAccessible ? Color.blue : AppConfig.subtleGray.opacity(0.25))
                            .frame(width: 44, height: 44)
                            .background(spot.isAccessible ? Color.blue.opacity(0.12) : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                Spacer()
            }
            .padding(4)
        }
        .contentShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .onTapGesture {
            Haptics.selection()
            withAnimation(.standard) {
                if bulkMode {
                    if selectedIDs.contains(spot.id) {
                        selectedIDs.remove(spot.id)
                    } else {
                        selectedIDs.insert(spot.id)
                    }
                } else {
                    bookingManager.updateSpot(id: spot.id, isBlocked: !isBlocked)
                }
            }
        }
        .animation(.standard, value: isBlocked)
        .animation(.standard, value: isSelected)
    }

    // MARK: - Bulk Action Bar

    private var bulkActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {

                Button {
                    Haptics.action()
                    withAnimation {
                        if selectedIDs.count == spots.count {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(spots.map { $0.id })
                        }
                    }
                } label: {
                    Text(selectedIDs.count == spots.count ? L10n.deselectAll : L10n.selectAll)
                        .font(.subheadline)
                        .foregroundStyle(AppConfig.subtleGray)
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()

                Button {
                    Haptics.action()
                    for id in selectedIDs { bookingManager.updateSpot(id: id, isBlocked: false) }
                    withAnimation(.standard) { selectedIDs.removeAll(); bulkMode = false }
                } label: {
                    Text(L10n.unblock)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(selectedIDs.isEmpty ? AppConfig.subtleGray : AppConfig.darkText)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background((selectedIDs.isEmpty ? AppConfig.subtleGray : AppConfig.darkText).opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(selectedIDs.isEmpty)

                Button {
                    Haptics.action()
                    for id in selectedIDs { bookingManager.updateSpot(id: id, isBlocked: true) }
                    withAnimation(.standard) { selectedIDs.removeAll(); bulkMode = false }
                } label: {
                    Text(L10n.blockSelected(selectedIDs.count))
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(selectedIDs.isEmpty ? AppConfig.subtleGray.opacity(0.3) : AppConfig.spotOccupied)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    NavigationStack {
        AdminSpotsView()
            .environmentObject(BookingManager())
    }
}
