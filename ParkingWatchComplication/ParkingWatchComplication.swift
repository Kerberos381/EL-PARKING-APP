// ParkingWatchComplication.swift
// ParkingWatchComplication — Watch Widget Extension
//
// Reads booking data written by the Watch App (via WatchConnectivity) from
// the shared App Group "group.com.StivMalakjan.EL-PARKING-WATCH".

import WidgetKit
import SwiftUI

private let suiteName   = "group.com.StivMalakjan.EL-PARKING-WATCH"
private let accentGreen = Color(red: 177/255, green: 248/255, blue: 0/255)

// MARK: - Entry

struct WatchEntry: TimelineEntry {
    let date:     Date
    let spot:     String?
    let fromTime: String?
    let toTime:   String?
    let isToday:  Bool
}

// MARK: - Provider

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, spot: "A1", fromTime: "09:00", toTime: "18:00", isToday: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh at midnight so "TODAY" / "UPCOMING" label stays accurate.
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func currentEntry() -> WatchEntry {
        let d = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        return WatchEntry(
            date:     .now,
            spot:     d.string(forKey: "watch_spot"),
            fromTime: d.string(forKey: "watch_fromTime"),
            toTime:   d.string(forKey: "watch_toTime"),
            isToday:  d.bool(forKey: "watch_isToday")
        )
    }
}

// MARK: - Views

struct WatchComplicationView: View {
    var entry: WatchEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if let spot = entry.spot, let from = entry.fromTime, let to = entry.toTime {
                bookedView(spot: spot, from: from, to: to)
            } else {
                emptyView
            }
        }
    }

    @ViewBuilder
    private func bookedView(spot: String, from: String, to: String) -> some View {
        switch family {

        // ── Small circle on watch face ──────────────────────────────────────
        case .accessoryCircular:
            VStack(spacing: 1) {
                Text(shortSpot(spot))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(accentGreen)
                Text(from)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
            }

        // ── Wide rectangle (Modular / Infograph rows) ───────────────────────
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Circle()
                    .fill(accentGreen)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Spot \(shortSpot(spot))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(from) – \(to)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        // ── Inline (top of watch face) ──────────────────────────────────────
        case .accessoryInline:
            Text("Spot \(shortSpot(spot))  \(from)–\(to)")

        default:
            Text(shortSpot(spot))
                .foregroundColor(accentGreen)
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "car")
                .foregroundColor(.secondary)
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text("No booking")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("No parking booking")
        default:
            Image(systemName: "car")
        }
    }

    private func shortSpot(_ spot: String) -> String {
        spot.components(separatedBy: " ").last ?? spot
    }
}

// MARK: - Widget

@main
struct ParkingWatchComplication: Widget {
    let kind = "ParkingWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            WatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Parking")
        .description("Your next parking spot at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
