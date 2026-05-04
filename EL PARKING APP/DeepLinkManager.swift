//
//  DeepLinkManager.swift
//  EL PARKING APP
//
//  Small shared router for widget, notification, and quick-action entry points.
//

import Foundation
import Combine

enum DeepLinkRoute: Equatable, Identifiable {
    case book
    case edit(String)
    case cancel(String)
    case myBookings
    case navigate
    case adminDashboard

    var id: String {
        switch self {
        case .book:
            return "book"
        case .edit(let bookingID):
            return "edit-\(bookingID)"
        case .cancel(let bookingID):
            return "cancel-\(bookingID)"
        case .myBookings:
            return "myBookings"
        case .navigate:
            return "navigate"
        case .adminDashboard:
            return "adminDashboard"
        }
    }
}

@MainActor
final class DeepLinkManager: ObservableObject {
    @Published private(set) var pendingRoute: DeepLinkRoute?

    func navigate(to route: DeepLinkRoute) {
        pendingRoute = route
    }

    func handle(_ url: URL) {
        guard let route = parse(url) else { return }
        navigate(to: route)
    }

    func clear() {
        pendingRoute = nil
    }

    private func parse(_ url: URL) -> DeepLinkRoute? {
        let pathParts = url.pathComponents.filter { $0 != "/" }
        let action = (url.host ?? pathParts.first ?? "").lowercased()
        let value: String? = {
            if url.host == nil {
                return pathParts.dropFirst().first
            }
            return pathParts.first
        }()

        switch action {
        case "book":
            return .book
        case "edit":
            guard let value, !value.isEmpty else { return nil }
            return .edit(value)
        case "cancel":
            guard let value, !value.isEmpty else { return nil }
            return .cancel(value)
        case "mybookings", "my-bookings", "bookings":
            return .myBookings
        case "navigate", "directions":
            return .navigate
        case "admin", "admin-dashboard":
            return .adminDashboard
        default:
            return nil
        }
    }
}
