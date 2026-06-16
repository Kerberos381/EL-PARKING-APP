//
//  BookingShareCard.swift
//  EL PARKING APP
//
//  Renders a branded share card image and presents the system share sheet.
//  Supports single-day and multi-day range bookings.

import SwiftUI

// MARK: - Share Card View

struct BookingShareCardView: View {
    let booking: Booking
    /// End date of a multi-day range, nil for single-day bookings
    var rangeEndDate: Date? = nil

    private let cardBg   = Color(red: 26/255,  green: 28/255,  blue: 30/255)
    private let accent   = Color(red: 177/255, green: 248/255, blue: 0/255)
    private let onAccent = Color(red: 19/255,  green: 31/255,  blue: 0/255)

    /// The date label shown in the header — range "29 MAR – 1 APR" or single day "TODAY"
    private var dateLabel: String {
        if let end = rangeEndDate {
            let fmt = DateFormatter()
            fmt.dateFormat = "d MMM"
            fmt.locale = LanguageManager.shared.language == .czech
                ? Locale(identifier: "cs_CZ") : Locale(identifier: "en_GB")
            let startStr = fmt.string(from: booking.date).uppercased()
            let endStr   = fmt.string(from: end).uppercased()
            return "\(startStr) – \(endStr)"
        }
        return booking.naturalDate
    }

    /// Number of days for a range booking
    private var dayCount: Int? {
        guard let end = rangeEndDate else { return nil }
        let d = Calendar.current.dateComponents([.day], from: booking.date, to: end).day ?? 0
        return d > 0 ? d + 1 : nil
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "car")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(onAccent)
                    .frame(width: 28, height: 28)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("EL Parking")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                if let days = dayCount {
                    Text("\(days)d")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                }

                Text(dateLabel)
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(accent)
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPOT")
                        .font(.caption2.weight(.black))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.4))
                    Text(booking.spotNumber)
                        .font(.system(size: 76, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    infoCell("TIME", value: "\(booking.fromTime) – \(booking.toTime)")
                    infoCell("LOCATION", value: AppConfig.locationName)
                    if booking.isBookedByOther {
                        infoCell("FOR", value: booking.user)
                    }
                }
            }

            HStack {
                Text(AppConfig.companyName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.22))
                Spacer()
            }
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .raisedShadow()
    }

    private func infoCell(_ label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

// MARK: - Navigation Guide Share Card

/// A branded, shareable image of the photo route to the spot. Attached to
/// delegated-booking shares (email / iMessage) so the recipient can find
/// their way. Mirrors the dark/lime look of BookingShareCardView so the two
/// images read as a set.
struct NavigationGuideShareCardView: View {
    let spotNumber: String

    private static let photos = ["ParkingGarage1", "ParkingGarage2", "ParkingGarage3", "ParkingGarage4"]
    private let cardBg   = Color(red: 26/255,  green: 28/255,  blue: 30/255)
    private let accent   = Color(red: 177/255, green: 248/255, blue: 0/255)
    private let onAccent = Color(red: 19/255,  green: 31/255,  blue: 0/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: brand + title + spot
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(onAccent)
                    .frame(width: 28, height: 28)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text("EL Parking")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(L10n.delegateNavGuideTitle)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("SPOT")
                        .font(.system(size: 8, weight: .black)).tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                    Text(spotNumber)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
            }

            // 2x2 photo grid with numbered step badges
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { col in
                            let i = row * 2 + col
                            ZStack(alignment: .topLeading) {
                                Image(Self.photos[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 88)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                Text("\(i + 1)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(onAccent)
                                    .frame(width: 18, height: 18)
                                    .background(accent)
                                    .clipShape(Circle())
                                    .padding(6)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }

            Text(L10n.delegateNavGuideDesc)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                Text(AppConfig.locationName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Share Sheet Wrapper

struct BookingShareSheet: View {
    let booking: Booking
    /// End date of a multi-day range — passed in from SpotDetailSheet
    var rangeEndDate: Date? = nil
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Preview card — given generous horizontal inset
                    BookingShareCardView(booking: booking, rangeEndDate: rangeEndDate)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    VStack(spacing: 14) {
                        // Primary share button
                        Button {
                            Haptics.action()
                            presentSystemShare(items: buildShareItems())
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body.weight(.semibold))
                                Text(L10n.shareBooking)
                                    .font(.body.weight(.bold))
                            }
                            .foregroundStyle(AppConfig.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppConfig.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: AppConfig.accent.opacity(0.35), radius: 12, y: 4)
                        }
                        .buttonStyle(ScaleButtonStyle())

                        // Text-only share (Teams-friendly)
                        Button {
                            Haptics.action()
                            presentSystemShare(items: [buildPlainText()])
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope")
                                    .font(.subheadline)
                                Text(L10n.shareAsText)
                                    .font(.footnote.weight(.semibold))
                            }
                            .foregroundStyle(AppConfig.subtleGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppConfig.cardBg)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.shareTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .foregroundStyle(AppConfig.subtleGray)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppConfig.pageBg)
    }

    // MARK: - Helpers

    private func presentSystemShare(items: [Any]) {
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
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

    private func buildShareItems() -> [Any] {
        let renderer = ImageRenderer(content:
            BookingShareCardView(booking: booking, rangeEndDate: rangeEndDate)
                .frame(width: 360)
        )
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            return [image, buildPlainText()]
        }
        return [buildPlainText()]
    }

    private func buildPlainText() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        fmt.locale = LanguageManager.shared.language == .czech
            ? Locale(identifier: "cs_CZ") : Locale(identifier: "en_GB")

        let dateStr: String
        if let end = rangeEndDate {
            dateStr = "\(fmt.string(from: booking.date)) – \(fmt.string(from: end))"
        } else {
            dateStr = booking.naturalDate
        }

        var text = """
        🚗 Parking Spot \(booking.spotNumber)
        📅 \(dateStr)  •  \(booking.fromTime)-\(booking.toTime)
        📍 \(AppConfig.locationName)
        🗺️ \(AppConfig.googleMapsURL)
        """
        if booking.isBookedByOther {
            text += "\n👤 \(booking.user)"
        }
        return text
    }
}
