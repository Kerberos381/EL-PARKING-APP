// ContentView.swift
// EL PARKING Watch App
// This screen is never meant to be used — the complication is the UI.

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Manage bookings\non your iPhone")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
