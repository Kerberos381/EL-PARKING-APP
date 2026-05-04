import SwiftUI

struct SpotDetailSheet: View {
    let booking: Booking
    @EnvironmentObject private var bookingManager: BookingManager
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppConfig.accent)

                    Text(booking.spot)
                        .font(.title2.bold())

                    Text(booking.richDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                VStack(spacing: 12) {
                    detailRow(icon: "person.fill", label: "Booked by", value: booking.user)
                    detailRow(icon: "clock.fill", label: "Time", value: "\(booking.fromTime) – \(booking.toTime)")
                    detailRow(icon: "envelope.fill", label: "Email", value: booking.email)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppConfig.cardBg)
                )
                .padding(.horizontal)

                Spacer()
            }
            .background(AppConfig.pageBg)
            .navigationTitle("Spot Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppConfig.subtleGray)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(AppConfig.darkText)
            }

            Spacer()
        }
    }
}
