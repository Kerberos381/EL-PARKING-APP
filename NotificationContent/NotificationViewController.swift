//
//  NotificationViewController.swift
//  NotificationContent
//
//  Custom Notification Content Extension — full obsidian card design
//  with embedded action buttons (Keep, Edit, Cancel).
//  Replaces the default iOS notification expanded view.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import SwiftUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private var hostingController: UIHostingController<NotificationContentView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let bookingID = content.userInfo["bookingID"] as? String ?? ""

        // Extract info from notification content
        let title = content.title        // "Spot 72"
        let subtitle = content.subtitle  // "TODAY · 07:00 – 18:00"
        let body = content.body          // location

        // Parse spot number from title
        let spotNumber = title.replacingOccurrences(of: "Spot ", with: "")

        // Parse date and time from subtitle
        let parts = subtitle.components(separatedBy: " · ")
        let dateLabel = parts.first ?? "TODAY"
        let timeRange = parts.count > 1 ? parts[1] : "07:00 – 18:00"

        let upperDateLabel = dateLabel.uppercased()
        let isTodayFromLabel = upperDateLabel == "TODAY" || upperDateLabel == "DNES"
        let isToday = (content.userInfo["isToday"] as? Bool) ?? isTodayFromLabel

        let viewModel = NotificationContentViewModel(
            spotNumber: spotNumber,
            dateLabel: dateLabel,
            timeRange: timeRange,
            location: body,
            bookingID: bookingID,
            isToday: isToday
        )

        let contentView = NotificationContentView(
            viewModel: viewModel,
            onKeep: { [weak self] in
                self?.extensionContext?.dismissNotificationContentExtension()
            },
            onEdit: { [weak self] in
                self?.extensionContext?.performNotificationDefaultAction()
            },
            onCancel: { [weak self] in
                self?.extensionContext?.performNotificationDefaultAction()
            }
        )

        let hosting = UIHostingController(rootView: contentView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hosting.didMove(toParent: self)
        hostingController = hosting

        // Set preferred content size for the notification
        preferredContentSize = CGSize(width: view.bounds.width, height: 220)
    }

    // Handle action button taps from the system (fallback)
    func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        switch response.actionIdentifier {
        case "ACTION_KEEP":
            completion(.dismiss)
        case "ACTION_EDIT":
            completion(.dismissAndForwardAction)
        case "ACTION_CANCEL":
            completion(.dismissAndForwardAction)
        default:
            completion(.dismiss)
        }
    }
}

// MARK: - View Model

struct NotificationContentViewModel {
    let spotNumber: String
    let dateLabel: String
    let timeRange: String
    let location: String
    let bookingID: String
    let isToday: Bool
}

// MARK: - SwiftUI Content View (Obsidian Card)

struct NotificationContentView: View {
    let viewModel: NotificationContentViewModel
    let onKeep: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void

    private let accentGreen = Color(red: 177/255, green: 248/255, blue: 0/255)
    private let onAccent = Color(red: 19/255, green: 31/255, blue: 0/255)
    private let obsidian = Color(red: 26/255, green: 28/255, blue: 30/255)
    private let dangerRed = Color(red: 186/255, green: 26/255, blue: 26/255)

    var body: some View {
        VStack(spacing: 0) {
            // Top: status indicator + branding
            HStack(spacing: 8) {
                Circle()
                    .fill(accentGreen)
                    .frame(width: 10, height: 10)
                    .overlay {
                        if viewModel.isToday {
                            Circle()
                                .stroke(accentGreen.opacity(0.35), lineWidth: 3)
                                .frame(width: 18, height: 18)
                        }
                    }

                Text(viewModel.isToday ? "ACTIVE NOW" : "UPCOMING")
                    .font(.system(size: 10, weight: .bold))
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
            .padding(.bottom, 10)

            // Center: spot number + details
            HStack(alignment: .center, spacing: 16) {
                Text(viewModel.spotNumber)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(accentGreen)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.dateLabel)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))

                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(viewModel.timeRange)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(viewModel.location)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Bottom: embedded action buttons (glass pill style)
            HStack(spacing: 10) {
                Button(action: onKeep) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Keep")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(accentGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(accentGreen.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(accentGreen.opacity(0.2), lineWidth: 1))
                }

                Button(action: onEdit) {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                        Text("Edit")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                }

                Button(action: onCancel) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Cancel")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(dangerRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(dangerRed.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(dangerRed.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .background(obsidian)
    }
}
