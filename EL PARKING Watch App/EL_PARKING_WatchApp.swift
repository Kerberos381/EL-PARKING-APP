// EL_PARKING_WatchApp.swift
// EL PARKING Watch App

import SwiftUI

@main
struct EL_PARKING_WatchApp: App {
    // Activating the store on launch starts the WCSession.
    @StateObject private var store = WatchBookingStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
