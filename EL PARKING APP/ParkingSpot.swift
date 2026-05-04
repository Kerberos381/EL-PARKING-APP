//
//  ParkingSpot.swift
//  ParkKing
//
//  Created on 2026-03-24.
//

import Foundation

/// Represents a numbered parking spot in the Karlín office parking lot.
struct ParkingSpot: Identifiable, Hashable, Codable {
    let id: String          // e.g. "63", "80"
    let label: String       // e.g. "Parking 63", "Parking 80"
    var isAccessible: Bool = false  // ♿ wheelchair accessible flag

    /// Display label including ♿ symbol if accessible
    var displayLabel: String {
        isAccessible ? "\(label) ♿" : label
    }

    /// Short label like "P63" for compact display
    var shortLabel: String {
        label.replacingOccurrences(of: "Parking ", with: "P")
    }
}
