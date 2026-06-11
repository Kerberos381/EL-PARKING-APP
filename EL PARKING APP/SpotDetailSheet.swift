//
//  SpotDetailSheet.swift
//  EL PARKING APP
//
//  Detail sheet: shows who booked, when it was made, context banner, and share button.
//
//  PRESENTATION NOTE:
//  This view is always presented as a .sheet from OverviewView or MyBookingsView.
//  Because iOS/SwiftUI cannot reliably stack a second .sheet or .fullScreenCover
//  on top of a view that is itself inside a .sheet, both the Edit and Share flows
//  are presented via UIKit (UIHostingController / UIActivityViewController) instead.
//  This bypasses the SwiftUI sheet hierarchy entirely and works at all depths.
//

import SwiftUI

@MainActor
struct SpotDetailSheet: View {
    let booking: Booking
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var authManager:    AuthManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared

    @State private var showCancelDialog = false

    private var isAdmin:   Bool { bookingManager.isAdmin }
    private var canModify: Bool { bookingManager.canEditBooking(booking) }
    private var isMine:    Bool { booking.email    == bookingManager.currentUserEmail }
    private var iCreated:  Bool { booking.createdBy == bookingManager.currentUserEmail }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Spot number ──────────────────────────────────────────
                    VStack(spacing: 6) {
                        Text("Spot")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(AppConfig.subtleGray)
                        Text(booking.spotNumber)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(AppConfig.darkText)
                    }
                    .padding(.top, 20)

                    // ── Context banner ───────────────────────────────────────
                    contextBanner

                    if let vehicleUser = bookedVehicleUser, hasVehicleInfo(vehicleUser) {
                        vehicleDetailCard(for: vehicleUser)
                    }

                    // ── Booking details card ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 18) {
                        detailRow(icon: "person",
                                  label: L10n.name,
                                  value: booking.user)
                        detailRow(icon: "envelope",
                                  label: L10n.email,
                                  value: booking.email)
                        detailRow(icon: "calendar",
                                  label: L10n.date,
                                  value: booking.richDate)
                        detailRow(icon: "clock",
                                  label: L10n.time,
                                  value: "\(booking.fromTime) – \(booking.toTime)")
                        detailRow(icon: "clock.badge.checkmark",
                                  label: L10n.bookedOn,
                                  value: booking.createdAt.formatted(date: .abbreviated, time: .shortened))

                        if booking.isBookedByOther {
                            detailRow(icon: "person.crop.circle.badge.plus",
                                      label: L10n.bookedByLabel,
                                      value: creatorDisplayName)
                        }
                    }
                    .padding(20)
                    .background(AppConfig.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .cardShadow()

                    // ── Share button ─────────────────────────────────────────
                    Button {
                        Haptics.selection()
                        openShareSheet()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                            Text(L10n.share)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(AppConfig.darkText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppConfig.outlineVariant, lineWidth: 1))
                        .cardShadow()
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // ── Admin / owner actions ────────────────────────────────
                    if canModify {
                        actionsCard
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(AppConfig.pageBg.ignoresSafeArea())
            .navigationTitle(L10n.bookingDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) {
                        Haptics.selection()
                        dismiss()
                    }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConfig.darkText)
                }
            }
            .confirmationDialog(
                isAdmin && booking.email != bookingManager.currentUserEmail
                    ? L10n.adminCancelBooking
                    : L10n.cancelBooking,
                isPresented: $showCancelDialog,
                titleVisibility: .visible
            ) {
                Button(
                    isAdmin && booking.email != bookingManager.currentUserEmail
                        ? L10n.cancelAndNotify
                        : L10n.cancelBooking,
                    role: .destructive
                ) {
                    Haptics.destructive()
                    deleteBooking()
                }
                Button(L10n.keep, role: .cancel) {}
            } message: {
                Text(L10n.cancelBookingAlert(name: booking.user, spot: booking.spotNumber, date: booking.naturalDate))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - UIKit Presentation
    // SwiftUI cannot reliably present a sheet/fullScreenCover from inside an
    // already-presented sheet. We walk up to the topmost UIViewController and
    // present directly from there — this always works regardless of depth.

    private func openShareSheet() {
        // Compute range end date if this is part of a multi-day group
        let rangeEnd = bookingManager.rangeFor(booking)?.end
        let shareView = BookingShareSheet(booking: booking, rangeEndDate: rangeEnd)
        presentViaUIKit(shareView, style: .pageSheet)
    }

    private func openEditSheet() {
        let editView = AnyView(
            BookingSheet(
                preselectedSpot: AppConfig.allParkingSpots.first(where: { $0.label == booking.spot }),
                isForOthers: booking.isBookedByOther || bookingManager.isAdmin,
                editingBooking: booking
            )
            .environmentObject(bookingManager)
            .environmentObject(authManager)
        )
        presentViaUIKit(editView, style: .fullScreen)
    }

    private func presentViaUIKit(_ view: some View, style: UIModalPresentationStyle) {
        let hosting = UIHostingController(rootView: AnyView(view))
        hosting.modalPresentationStyle = style
        if style == .pageSheet, let sheet = hosting.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(hosting, animated: true)
    }

    // MARK: - Context Banner

    private var contextBanner: some View {
        let (icon, text, color) = bannerContent
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(AppConfig.darkText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.18), lineWidth: 1))
    }

    private var bannerContent: (icon: String, text: String, color: Color) {
        if isMine && iCreated {
            return ("car.fill", L10n.youBookedForYourself, .secondary)
        } else if !isMine && iCreated {
            return ("person.fill.badge.plus", L10n.youBookedFor(booking.user), .blue)
        } else if isMine && !iCreated {
            return ("gift", L10n.bookedForYouBy(creatorDisplayName), AppConfig.warning)
        } else {
            return ("person.2.fill", L10n.personBookedFor(creator: creatorDisplayName, bookedFor: booking.user), AppConfig.subtleGray)
        }
    }

    // MARK: - Vehicle Detail

    private func vehicleDetailCard(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(vehicleTitle)
                    .font(.headline)
                    .foregroundStyle(AppConfig.darkText)
                Spacer()
                if !user.registrationPlate.isEmpty {
                    Text(user.registrationPlate)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(AppConfig.darkText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppConfig.surfaceLow)
                        .clipShape(Capsule())
                }
            }

            VehicleMiniatureView(
                carType: user.carType,
                colorHex: user.carColor,
                description: user.carDescription,
                presetID: user.vehicleMiniaturePresetID.isEmpty ? nil : user.vehicleMiniaturePresetID
            )
            .frame(width: 176, height: 98)
            .frame(maxWidth: .infinity, alignment: .center)

            let summary = vehicleSummary(for: user)
            if !summary.isEmpty {
                Text(summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.subtleGray)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .cardShadow()
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Text(isAdmin ? L10n.adminActions : L10n.manageBooking)
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(AppConfig.darkText)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                actionRow(icon: "pencil.circle",
                          label: L10n.editBooking,
                          color: .secondary) {
                    openEditSheet()
                }

                actionRow(icon: "trash.circle",
                          label: L10n.cancelBooking,
                          color: AppConfig.spotOccupied) {
                    showCancelDialog = true
                }
            }
        }
        .padding(20)
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
    }

    private func actionRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.action()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(label)
                    .font(.body).fontWeight(.semibold)
                    .foregroundStyle(AppConfig.darkText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(AppConfig.subtleGray)
            }
            .padding(16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1.5))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Detail Row

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3).fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(AppConfig.subtleGray)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Text(value)
                    .font(.body).fontWeight(.semibold)
                    .foregroundStyle(AppConfig.darkText)
                    .lineLimit(2)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private var creatorDisplayName: String {
        if let found = authManager.allUsers.first(where: { $0.email == booking.createdBy }) {
            return found.displayName
        }
        return booking.createdBy.components(separatedBy: "@").first ?? booking.createdBy
    }

    private var bookedVehicleUser: AppUser? {
        let email = booking.email.lowercased()
        if authManager.currentUser?.email.lowercased() == email {
            return authManager.currentUser
        }
        return authManager.allUsers.first { $0.email.lowercased() == email }
    }

    private var vehicleTitle: String {
        lang.language == .czech ? "Vozidlo" : "Vehicle"
    }

    private func hasVehicleInfo(_ user: AppUser) -> Bool {
        !user.registrationPlate.isEmpty ||
        !user.carDescription.isEmpty ||
        !user.carColor.isEmpty ||
        !user.carType.isEmpty
    }

    private func vehicleSummary(for user: AppUser) -> String {
        var details = [String]()
        if !user.carDescription.isEmpty { details.append(user.carDescription) }
        if let type = CarBodyType(rawValue: user.carType) { details.append(type.label) }
        if let colorName = AppConfig.carColors.first(where: { $0.hex == user.carColor })?.name {
            details.append(colorName)
        }
        return details.joined(separator: "  ·  ")
    }

    private func deleteBooking() {
        Task {
            let error: String?
            if isAdmin && booking.email != bookingManager.currentUserEmail {
                error = await bookingManager.adminCancelBooking(booking)
            } else {
                error = await bookingManager.cancelBooking(booking)
            }
            if error == nil {
                Haptics.notify(.success)
                dismiss()
            } else {
                Haptics.notify(.error)
            }
        }
    }

}

#Preview {
    SpotDetailSheet(
        booking: Booking(
            id: UUID(),
            title: "Reservation for Jana Novak",
            spot: "Parking 80",
            user: "Jana Novak",
            email: "jana@example.com",
            date: Date(),
            fromTime: "08:00",
            toTime: "17:00",
            createdBy: "stiv.malakjan@ext.essilor.com",
            createdAt: Date()
        )
    )
    .environmentObject(BookingManager())
    .environmentObject(AuthManager())
}
