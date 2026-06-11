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
    @State private var detailSpot: ParkingSpot?
    @State private var gridShakeOffset: CGFloat = 0

    private var spots:      [ParkingSpot] { bookingManager.parkingSpots }
    private var blockedIDs: Set<String>   { AppConfig.blockedSpotIDs }
    private var shouldShowLoadingSkeleton: Bool { isInitialLoading && spots.isEmpty }
    private var showsBulkBar: Bool { bulkMode && !selectedIDs.isEmpty }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppConfig.pageBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if shouldShowLoadingSkeleton {
                        loadingSkeleton
                    } else {
                        overlineRow
                        statsRow
                        spotsGrid
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, bulkMode ? 110 : 40)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable {
                await bookingManager.refreshData()
                Haptics.refreshCompleted()
            }

            if bulkMode {
                bulkActionBar
                    .opacity(showsBulkBar ? 1 : 0)
                    .allowsHitTesting(showsBulkBar)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
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
                    bulkMode.toggle()
                    selectedIDs.removeAll()
                }
                .foregroundStyle(AppConfig.darkText)
                .fontWeight(.semibold)
            }
        }
        .sheet(item: $detailSpot) { spot in
            spotDetailSheet(spot)
        }
    }

    // MARK: - Overline

    private var overlineRow: some View {
        Text("EL PARK \u{00B7} ADMIN")
            .font(.caption.weight(.semibold))
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(AppConfig.subtleGray.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 14) {
            compactStat(value: "\(spots.count)", label: L10n.total, dot: AppConfig.subtleGray.opacity(0.75))
            compactStat(value: "\(blockedIDs.count)", label: L10n.blocked, dot: AppConfig.spotOccupied)
            compactStat(value: "\(spots.filter { $0.isAccessible }.count)", label: L10n.accessible, dot: AppConfig.infoTint)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func compactStat(value: String, label: String, dot: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
            Text(value)
                .font(.body.weight(.bold))
                .foregroundStyle(AppConfig.darkText)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.9))
        }
    }

    // MARK: - Spots Grid

    private var spotsGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(spots) { spot in
                spotCard(spot)
            }
        }
        .offset(x: gridShakeOffset)
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
                    .background(AppConfig.tertiaryFillBg.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shimmering(active: true)
                }
            }

            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<18, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: AppConfig.radius16, style: .continuous)
                        .fill(AppConfig.tertiaryFillBg)
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
        let isAccessible = spot.isAccessible && !isBlocked
        let numberColor: Color = isBlocked ? AppConfig.spotOccupied : (isAccessible ? .blue : AppConfig.darkText)
        let cardFill: Color = isBlocked
            ? AppConfig.spotOccupied.opacity(0.04)
            : (isAccessible ? AppConfig.infoTint.opacity(0.09) : AppConfig.cardBg)

        ZStack {
            RoundedRectangle(cornerRadius: AppConfig.radius16)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppConfig.radius16)
                        .strokeBorder(
                            isSelected ? AppConfig.infoTint : AppConfig.separatorSoft.opacity(0.65),
                            lineWidth: isSelected ? 2.5 : 0.8
                        )
                )
                .frame(height: 95)

            if isBlocked {
                RoundedRectangle(cornerRadius: AppConfig.radius16)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, AppConfig.spotOccupied.opacity(0.08), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(spot.id)
                .font(.system(size: 40, weight: .black, design: .default))
                .monospacedDigit()
                .kerning(-0.8)
                .foregroundStyle(numberColor)

            if isBlocked {
                stripeOverlay
            }

            if isBlocked {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppConfig.spotOccupied)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            } else if isAccessible {
                accessibleCornerBadge
            }

            selectCircle(selected: isSelected)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
                .opacity(bulkMode ? 1 : 0)
        }
        .contentShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .onTapGesture {
            Haptics.selection()
            if bulkMode {
                if selectedIDs.contains(spot.id) {
                    selectedIDs.remove(spot.id)
                } else {
                    let selectingBlocked = blockedIDs.contains(spot.id)
                    let hasBlockedSelected = selectedIDs.contains { blockedIDs.contains($0) }
                    let hasUnblockedSelected = selectedIDs.contains { !blockedIDs.contains($0) }
                    let isMixingTypes = (selectingBlocked && hasUnblockedSelected) || (!selectingBlocked && hasBlockedSelected)
                    if isMixingTypes {
                        triggerInvalidSelectionFeedback()
                        return
                    }
                    selectedIDs.insert(spot.id)
                }
            } else {
                detailSpot = spot
            }
        }
        .animation(.standard, value: isBlocked)
        .animation(.standard, value: isSelected)
    }

    private var stripeOverlay: some View {
        RoundedRectangle(cornerRadius: AppConfig.radius16)
            .strokeBorder(style: StrokeStyle(lineWidth: 10))
            .foregroundStyle(Color.clear)
            .background(
                GeometryReader { geo in
                    Path { path in
                        let step: CGFloat = 14
                        let w = geo.size.width
                        let h = geo.size.height
                        var x: CGFloat = -h
                        while x < w {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x + h, y: h))
                            x += step
                        }
                    }
                    .stroke(AppConfig.spotOccupied.opacity(0.12), lineWidth: 6)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
    }

    private var accessibleCornerBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppConfig.infoTint)
                .frame(width: 34, height: 34)
            Image(systemName: "figure.roll")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .offset(x: -2, y: 2)
    }

    private func selectCircle(selected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(selected ? AppConfig.infoTint : Color.white.opacity(0.95))
                .frame(width: 22, height: 22)
            Circle()
                .stroke(selected ? AppConfig.infoTint : Color.black.opacity(0.18), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if selected {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Bulk Action Bar

    private var bulkActionBar: some View {
        let selectedBlockedCount = selectedIDs.filter { blockedIDs.contains($0) }.count
        let hasBlockedSelection = selectedBlockedCount > 0

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedIDs.count) selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Apply an action to all")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .frame(minWidth: 86, alignment: .leading)

            Spacer(minLength: 0)

            if hasBlockedSelection {
                Button {
                    Haptics.action()
                    for id in selectedIDs {
                        bookingManager.updateSpot(id: id, isBlocked: false)
                    }
                    Haptics.notify(.success)
                    withAnimation(.standard) { selectedIDs.removeAll() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open")
                            .font(.footnote.weight(.semibold))
                        Text("Unblock")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(minWidth: 96, minHeight: 48)
                    .padding(.horizontal, 10)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Button {
                    Haptics.action()
                    for id in selectedIDs {
                        bookingManager.updateSpot(id: id, isAccessible: true)
                    }
                    Haptics.notify(.success)
                    withAnimation(.standard) { selectedIDs.removeAll() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.roll")
                            .font(.footnote.weight(.semibold))
                        Text("Accessible")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(minWidth: 104, minHeight: 48)
                    .padding(.horizontal, 10)
                    .foregroundStyle(.white)
                    .background(Color.blue.opacity(0.32))
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Button {
                guard !selectedIDs.isEmpty else { return }
                Haptics.destructive()
                for id in selectedIDs {
                    bookingManager.updateSpot(id: id, isBlocked: true)
                }
                withAnimation(.standard) { selectedIDs.removeAll() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "nosign")
                        .font(.footnote.weight(.semibold))
                    Text("Block")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                .frame(minWidth: 88, minHeight: 48)
                .padding(.horizontal, 10)
                .foregroundStyle(.white.opacity(selectedIDs.isEmpty ? 0.45 : 1.0))
                .background(AppConfig.spotOccupied.opacity(selectedIDs.isEmpty ? 0.16 : 0.32))
                .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(height: 94)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.6)
        )
    }

    private func triggerInvalidSelectionFeedback() {
        Haptics.notify(.error)
        ToastManager.shared.show("Select only blocked or unblocked spots.", style: .warning, duration: 2.0)
        withAnimation(.easeInOut(duration: 0.06).repeatCount(3, autoreverses: true)) {
            gridShakeOffset = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            gridShakeOffset = 0
        }
    }

    // MARK: - Spot Detail

    private func spotDetailSheet(_ spot: ParkingSpot) -> some View {
        let isBlocked = blockedIDs.contains(spot.id)
        let isAccessible = spot.isAccessible && !isBlocked

        return VStack(spacing: 14) {
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack(alignment: .center) {
                Text(spot.id)
                    .font(.system(size: 44, weight: .black))
                    .monospacedDigit()
                Spacer()
                Text(isBlocked ? L10n.blocked : (isAccessible ? L10n.accessible : L10n.available))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isBlocked ? AppConfig.spotOccupied : (isAccessible ? .blue : AppConfig.subtleGray)).opacity(0.15))
                    .foregroundStyle(isBlocked ? AppConfig.spotOccupied : (isAccessible ? .blue : AppConfig.subtleGray))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                actionRow(
                    title: isBlocked ? "Unblock Spot" : "Block Spot",
                    subtitle: isBlocked ? "Put spot back in rotation" : "Take spot out of rotation",
                    icon: isBlocked ? "lock.open.fill" : "nosign",
                    tint: isBlocked ? AppConfig.darkText : AppConfig.spotOccupied
                ) {
                    bookingManager.updateSpot(id: spot.id, isBlocked: !isBlocked)
                    detailSpot = nil
                }

                actionRow(
                    title: isAccessible ? "Remove Accessibility" : "Mark Accessible",
                    subtitle: isAccessible ? "Remove wheelchair designation" : "Add wheelchair designation",
                    icon: "figure.roll",
                    tint: .blue
                ) {
                    bookingManager.updateSpot(id: spot.id, isAccessible: !spot.isAccessible)
                    detailSpot = nil
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .background(AppConfig.pageBg.ignoresSafeArea())
    }

    private func actionRow(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.darkText)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppConfig.subtleGray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    NavigationStack {
        AdminSpotsView()
            .environmentObject(BookingManager())
    }
}
