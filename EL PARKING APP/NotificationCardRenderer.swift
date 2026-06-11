//
//  NotificationCardRenderer.swift
//  EL PARKING APP
//
//  Renders an obsidian-style booking card as a PNG image for rich notifications.
//  Matches the hero card design from HomeView — no action buttons (those come from iOS).
//

import SwiftUI
import UIKit

struct NotificationCardRenderer {

    /// Render a booking card as a PNG image for notification attachment.
    @MainActor
    static func renderCard(for booking: Booking) -> Data? {
        let view = NotificationCardView(booking: booking)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        renderer.proposedSize = .init(width: 360, height: nil) // auto height

        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.pngData()
    }

    /// Save rendered card to temp directory and return the file URL.
    @MainActor
    static func renderCardToFile(for booking: Booking) -> URL? {
        guard let data = renderCard(for: booking) else { return nil }

        let fileName = "parking_notification_\(booking.id.uuidString).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to write notification card image: \(error)")
            return nil
        }
    }
}

// MARK: - Notification Card View (Obsidian Style — info only, no action buttons)

private struct NotificationCardView: View {
    let booking: Booking

    private let accentGreen = Color(red: 177/255, green: 248/255, blue: 0/255)
    private let obsidian = Color(red: 26/255, green: 28/255, blue: 30/255)

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: status + date
            HStack(spacing: 8) {
                Circle()
                    .fill(accentGreen)
                    .frame(width: 10, height: 10)
                    .overlay(
                        booking.isToday ?
                        Circle()
                            .stroke(accentGreen.opacity(0.35), lineWidth: 3)
                            .frame(width: 18, height: 18)
                        : nil
                    )

                Text(booking.isToday ? "ACTIVE NOW" : "UPCOMING")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(accentGreen)

                Spacer()

                Text("EL PARKING")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            // Main content: giant spot number + details
            HStack(alignment: .center, spacing: 18) {
                Text(booking.spotNumber)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(accentGreen)
                    .minimumScaleFactor(0.5)

                VStack(alignment: .leading, spacing: 8) {
                    // Date
                    Text(booking.naturalDate)
                        .font(.footnote.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.55))

                    // Time
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("\(booking.fromTime) – \(booking.toTime)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    // Location
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text(AppConfig.locationName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(obsidian)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
