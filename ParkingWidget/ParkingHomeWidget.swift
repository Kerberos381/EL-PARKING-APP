//
//  ParkingHomeWidget.swift
//  ParkingWidget
//
//  Home screen widget in 3 sizes: small, medium, large.
//  Two themes: dark (obsidian) and light (white card).
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Design Tokens (palette-aware)

/// The main app mirrors its "appPalette" setting into the shared app group
/// so widgets can follow the user's Default/Calm choice.
private var widgetIsCalm: Bool {
    (UserDefaults(suiteName: "group.com.StivMalakjan.EL-PARKING-APP") ?? .standard)
        .integer(forKey: "appPalette") == 1
}

private var accentGreen: Color {
    widgetIsCalm
        ? Color(red: 127/255, green: 160/255, blue: 140/255)   // sage
        : Color(red: 177/255, green: 248/255, blue:   0/255)
}
private var onAccent: Color {
    widgetIsCalm ? .white : Color(red: 19/255, green: 31/255, blue: 0/255)
}
private var obsidian: Color {
    widgetIsCalm
        ? Color(red: 34/255, green: 40/255, blue: 31/255)      // forest
        : Color(red: 26/255, green: 28/255, blue: 30/255)
}
private var dangerRed: Color {
    widgetIsCalm
        ? Color(red: 192/255, green: 112/255, blue: 79/255)    // clay
        : Color(red: 186/255, green: 26/255, blue: 26/255)
}
/// Positive/confirming green used on light surfaces.
private var positiveGreen: Color {
    widgetIsCalm
        ? Color(red: 68/255, green: 115/255, blue: 94/255)     // pine
        : Color(red: 75/255, green: 155/255, blue: 0/255)
}

/// Adaptive background: obsidian/forest in dark mode, light grey/paper in light.
private var widgetAdaptiveBg: Color {
    let calm = widgetIsCalm
    return Color(UIColor { tc in
        if tc.userInterfaceStyle == .dark {
            return calm
                ? UIColor(red: 29/255, green: 28/255, blue: 26/255, alpha: 1)
                : UIColor(red: 26/255, green: 28/255, blue: 30/255, alpha: 1)
        }
        return calm
            ? UIColor(red: 244/255, green: 244/255, blue: 241/255, alpha: 1)
            : UIColor(red: 245/255, green: 247/255, blue: 250/255, alpha: 1)
    })
}

private var widgetLightContainerBg: Color {
    widgetIsCalm
        ? Color(red: 244/255, green: 244/255, blue: 241/255)
        : Color(red: 245/255, green: 247/255, blue: 250/255)
}

// MARK: - Theme

struct WidgetColors {
    let primary:    Color   // spot number + status dot
    let statusText: Color   // "ACTIVE / UPCOMING" label
    let textMain:   Color   // primary text
    let textSub:    Color   // secondary text (time, name)
    let textFaint:  Color   // tertiary / labels
    let iconTint:   Color   // row icons
    let pillBg:     Color   // Navigate / Edit button bg
    let pillFg:     Color   // Navigate / Edit button fg
    let sectionBg:  Color   // detail card background
    let trackBg:    Color   // capacity bar track
    let brandLabel: Color   // "EL PARKING" watermark

    func dotFill(active: Bool) -> Color { active ? primary : primary.opacity(0.5) }

    static let dark = WidgetColors(
        primary:    accentGreen,
        statusText: accentGreen.opacity(0.8),
        textMain:   .white.opacity(0.85),
        textSub:    .white.opacity(0.7),
        textFaint:  .white.opacity(0.5),
        iconTint:   .white.opacity(0.4),
        pillBg:     .white.opacity(0.12),
        pillFg:     .white,
        sectionBg:  .white.opacity(0.06),
        trackBg:    .white.opacity(0.08),
        brandLabel: .white.opacity(0.3)
    )

    static let light = WidgetColors(
        primary:    positiveGreen,
        statusText: positiveGreen,
        textMain:   obsidian,
        textSub:    obsidian.opacity(0.65),
        textFaint:  obsidian.opacity(0.42),
        iconTint:   obsidian.opacity(0.3),
        pillBg:     obsidian.opacity(0.07),
        pillFg:     obsidian,
        sectionBg:  obsidian.opacity(0.05),
        trackBg:    obsidian.opacity(0.08),
        brandLabel: obsidian.opacity(0.22)
    )

    static let accented = WidgetColors(
        primary: .white,
        statusText: .white,
        textMain: .white,
        textSub: .white.opacity(0.86),
        textFaint: .white.opacity(0.72),
        iconTint: .white.opacity(0.62),
        pillBg: .white.opacity(0.18),
        pillFg: .white,
        sectionBg: .white.opacity(0.12),
        trackBg: .white.opacity(0.16),
        brandLabel: .white.opacity(0.55)
    )
}

private struct AccentGroupModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.widgetAccentable()
        } else {
            content
        }
    }
}

private extension View {
    func accentGroup(_ enabled: Bool) -> some View {
        modifier(AccentGroupModifier(enabled: enabled))
    }
}

// MARK: - Widget Data

struct ParkingEntry: TimelineEntry {
    let date: Date
    let booking: WidgetBooking?
    let availableCount: Int
    let totalCount: Int
    let userName: String
    let vehiclePlate: String
    let vehicleDescription: String
    let vehicleColor: String
    let vehicleType: String
    var vehicleMiniatureData: Data? = nil

    var vehicleMiniatureImage: Image? {
        guard let data = vehicleMiniatureData,
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    var vehicleIcon: String {
        switch vehicleType {
        case "van":      return "bus.fill"
        case "electric": return "bolt.car.fill"
        case "other":    return "ellipsis.circle.fill"
        default:         return "car.fill"
        }
    }

    var vehicleSideIcon: String {
        switch vehicleType {
        case "van":      return "bus.fill"
        case "electric": return "bolt.car.fill"
        case "other":    return "ellipsis.circle.fill"
        default:         return "car.side.fill"
        }
    }
}

struct WidgetBooking: Codable {
    let id: String
    let spotNumber: String
    let spotLabel: String
    let userName: String
    let fromTime: String
    let toTime: String
    let bookingDate: Date
    let isToday: Bool

    var naturalDate: String {
        let cal = Calendar.current
        // Detect device language — widget can't access LanguageManager
        let isCzech = Locale.current.language.languageCode?.identifier == "cs"
        if isToday { return isCzech ? "DNES" : "TODAY" }
        if cal.isDateInTomorrow(bookingDate) { return isCzech ? "ZÍTRA" : "TOMORROW" }
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.locale = .current   // follows device language automatically
        return f.string(from: bookingDate).uppercased()
    }
}

// MARK: - Timeline Provider

struct ParkingTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParkingEntry {
        ParkingEntry(
            date: .now,
            booking: WidgetBooking(
                id: "preview", spotNumber: "63", spotLabel: "P63",
                userName: "Stiv", fromTime: "07:00", toTime: "18:00",
                bookingDate: .now, isToday: true
            ),
            availableCount: 8,
            totalCount: 15,
            userName: "Stiv",
            vehiclePlate: "1AFL374",
            vehicleDescription: "Škoda Octavia RS",
            vehicleColor: "White",
            vehicleType: "combi"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ParkingEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParkingEntry>) -> Void) {
        let entry = loadEntry()
        let interval = entry.booking?.isToday == true ? 5 : 15
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: interval, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> ParkingEntry {
        let defaults = UserDefaults(suiteName: "group.com.StivMalakjan.EL-PARKING-APP")
            ?? UserDefaults.standard

        var booking: WidgetBooking?
        if let data = defaults.data(forKey: "widgetNextBooking"),
           let decoded = try? JSONDecoder().decode(WidgetBooking.self, from: data) {
            booking = decoded
        }

        let available = defaults.integer(forKey: "widgetAvailableCount")
        let total     = defaults.integer(forKey: "widgetTotalCount")
        let userName  = defaults.string(forKey: "widgetUserName") ?? ""
        let plate     = defaults.string(forKey: "widgetVehiclePlate") ?? ""
        let vehicle   = defaults.string(forKey: "widgetVehicleDescription") ?? ""
        let color     = defaults.string(forKey: "widgetVehicleColor") ?? ""
        let carType   = defaults.string(forKey: "widgetCarType") ?? ""

        var miniatureData: Data?
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.StivMalakjan.EL-PARKING-APP"
        ) {
            let fileURL = containerURL.appendingPathComponent("vehicleMiniature.png")
            miniatureData = try? Data(contentsOf: fileURL)
        }

        return ParkingEntry(
            date: .now,
            booking: booking,
            availableCount: available > 0 ? available : 8,
            totalCount:     total     > 0 ? total     : 15,
            userName: userName,
            vehiclePlate: plate,
            vehicleDescription: vehicle,
            vehicleColor: color,
            vehicleType: carType,
            vehicleMiniatureData: miniatureData
        )
    }
}

// MARK: - App Intents

struct WidgetBookFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Book favorite"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard let url = URL(string: "elparking://book") else { return .result() }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

struct WidgetCancelTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Cancel today"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard let url = URL(string: "elparking://mybookings") else { return .result() }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

struct WidgetNavigateIntent: AppIntent {
    static var title: LocalizedStringResource = "Navigate to parking"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard let url = URL(string: "maps://?daddr=50.097098416842265,14.459462896988791&dirflg=d") else {
            return .result()
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

// MARK: - Widget Definitions

struct ParkingHomeWidget: Widget {
    let kind = "ParkingHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkingTimelineProvider()) { entry in
            ParkingWidgetEntryView(entry: entry)
                .containerBackground(widgetAdaptiveBg, for: .widget)
        }
        .configurationDisplayName("EL Parking")
        .description("Your upcoming parking spot at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ParkingHomeWidgetLight: Widget {
    let kind = "ParkingHomeWidgetLight"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkingTimelineProvider()) { entry in
            ParkingWidgetEntryView(entry: entry)
                .environment(\.colorScheme, .light)
                .containerBackground(widgetLightContainerBg, for: .widget)
        }
        .configurationDisplayName("EL Parking (Light)")
        .description("Your upcoming parking spot — light style.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Card Widget (iOS-style square card)

struct ParkingTimelineCardWidget: Widget {
    let kind = "ParkingTimelineCardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkingTimelineProvider()) { entry in
            ParkingTimelineCardEntryView(entry: entry)
                .containerBackground(widgetAdaptiveBg, for: .widget)
        }
        .configurationDisplayName("EL Parking Timeline")
        .description("Timeline-style glance card for your next parking booking.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ParkingTimelineCardEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: ParkingEntry

    private var isDark: Bool { colorScheme == .dark }
    private var isAccented: Bool { renderingMode == .accented }
    private var primaryActionBackground: Color { isAccented ? .white.opacity(0.2) : accentGreen }
    private var primaryActionForeground: Color { isAccented ? .white : onAccent }

    private var titleColor: Color { isDark ? .white.opacity(0.95) : obsidian }
    private var subtitleColor: Color { isDark ? .white.opacity(0.72) : obsidian.opacity(0.7) }
    private var faintTrack: Color { isDark ? .white.opacity(0.2) : obsidian.opacity(0.16) }
    private var strongTrack: Color { isDark ? .white.opacity(0.95) : (widgetIsCalm ? Color(red: 0.75, green: 0.44, blue: 0.31) : Color(red: 0.95, green: 0.3, blue: 0.12)) }
    private var bubbleFg: Color { .white }

    var body: some View {
        Group {
            if let booking = entry.booking {
                switch family {
                case .systemMedium:
                    timelineMedium(for: booking)
                default:
                    timelineSmall(for: booking)
                }
            } else {
                switch family {
                case .systemMedium:
                    emptyMedium
                default:
                    emptySmall
                }
            }
        }
        .widgetURL(URL(string: "elparking://home"))
    }

    private func timelineSmall(for booking: WidgetBooking) -> some View {
        let now = Date()
        let window = bookingTimeWindow(for: booking)
        let progress = bookingProgress(window: window, now: now)
        let timeBadge = bookingBadge(window: window, now: now)
        let locationTitle = "Rohanské nábřeží"

        return VStack(alignment: .leading, spacing: 7) {
            Text(locationTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(titleColor)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(faintTrack)
                        .frame(height: 4)
                    Capsule()
                        .fill(strongTrack)
                        .frame(width: max(8, geo.size.width * progress), height: 4)
                    Circle()
                        .fill(strongTrack)
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, min(geo.size.width - 8, geo.size.width * progress - 4)))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 12)

            Spacer(minLength: 1)

            Text(now, style: .time)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: 6) {
                Text("Spot \(booking.spotNumber)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                Spacer()
                Text(timeBadge.text)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(bubbleFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(timeBadge.color)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
    }

    private func timelineMedium(for booking: WidgetBooking) -> some View {
        let now = Date()
        let window = bookingTimeWindow(for: booking)
        let progress = bookingProgress(window: window, now: now)
        let timeBadge = bookingBadge(window: window, now: now)
        let locationTitle = "Rohanské nábřeží"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(locationTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                    Text("\(booking.naturalDate) · Spot \(booking.spotNumber) · \(booking.fromTime)-\(booking.toTime)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(faintTrack)
                        .frame(height: 4)
                    Capsule()
                        .fill(strongTrack)
                        .frame(width: max(8, geo.size.width * progress), height: 4)
                    Circle()
                        .fill(strongTrack)
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, min(geo.size.width - 8, geo.size.width * progress - 4)))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            Spacer(minLength: 2)

            Text(now, style: .time)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack {
                Text(booking.isToday ? "Today booking" : "Upcoming booking")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                Spacer()
                Text(timeBadge.text)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(bubbleFg)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(timeBadge.color)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
    }

    private var emptySmall: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EL Parking")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(titleColor)
            Text("No active booking")
                .font(.system(size: 12))
                .foregroundStyle(subtitleColor)
            Spacer()
            Text("\(entry.availableCount) spots free")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isDark ? accentGreen : positiveGreen)
            Button(intent: WidgetBookFavoriteIntent()) {
                Text("Book favorite")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primaryActionForeground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(primaryActionBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    private var emptyMedium: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EL Parking")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(titleColor)
            Text("No active booking")
                .font(.system(size: 14))
                .foregroundStyle(subtitleColor)
            Spacer()
            HStack {
                Text("\(entry.availableCount) / \(entry.totalCount) spots free")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDark ? accentGreen : positiveGreen)
                Spacer()
                Button(intent: WidgetBookFavoriteIntent()) {
                    Text("Book favorite")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(primaryActionForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(primaryActionBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    private func bookingTimeWindow(for booking: WidgetBooking) -> (start: Date, end: Date)? {
        guard
            let start = bookingDateTime(day: booking.bookingDate, clock: booking.fromTime),
            let end = bookingDateTime(day: booking.bookingDate, clock: booking.toTime)
        else { return nil }
        return (start, end)
    }

    private func bookingDateTime(day: Date, clock: String) -> Date? {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps)
    }

    private func bookingProgress(window: (start: Date, end: Date)?, now: Date) -> CGFloat {
        guard let window else { return 0.0 }
        let duration = window.end.timeIntervalSince(window.start)
        guard duration > 0 else { return 0.0 }
        let elapsed = now.timeIntervalSince(window.start)
        return CGFloat(min(1, max(0, elapsed / duration)))
    }

    private func bookingBadge(window: (start: Date, end: Date)?, now: Date) -> (text: String, color: Color) {
        guard let window else { return ("--", Color.gray.opacity(0.5)) }

        if now < window.start {
            let hours = max(1, Int(ceil(window.start.timeIntervalSince(now) / 3600)))
            return ("+\(hours)H", widgetIsCalm ? Color(red: 0.42, green: 0.58, blue: 0.47) : Color(red: 0.2, green: 0.78, blue: 0.3))
        }
        if now <= window.end {
            let hours = max(1, Int(ceil(window.end.timeIntervalSince(now) / 3600)))
            return ("-\(hours)H", widgetIsCalm ? Color(red: 0.75, green: 0.44, blue: 0.31) : Color(red: 0.95, green: 0.32, blue: 0.12))
        }
        return ("Done", Color.gray.opacity(0.55))
    }
}

// MARK: - Entry View (routes to size-specific views)

struct ParkingWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetRenderingMode) var renderingMode
    let entry: ParkingEntry

    var isAccentedRendering: Bool { renderingMode == .accented }
    var colors: WidgetColors {
        if isAccentedRendering { return .accented }
        return colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry,  colors: colors, isAccented: isAccentedRendering)
        case .systemMedium: MediumWidgetView(entry: entry, colors: colors, isAccented: isAccentedRendering)
        case .systemLarge:  LargeWidgetView(entry: entry,  colors: colors, isAccented: isAccentedRendering)
        default:            SmallWidgetView(entry: entry,  colors: colors, isAccented: isAccentedRendering)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: ParkingEntry
    let colors: WidgetColors
    let isAccented: Bool

    private var primaryActionBackground: Color { isAccented ? .white.opacity(0.2) : accentGreen }
    private var primaryActionForeground: Color { isAccented ? .white : onAccent }

    var body: some View {
        if let booking = entry.booking {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(booking.isToday ? "ACTIVE" : "UPCOMING")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(colors.statusText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colors.sectionBg)
                        .clipShape(Capsule())
                        .accentGroup(isAccented)
                    Spacer()
                    Text(booking.naturalDate)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(colors.textFaint)
                }

                Spacer(minLength: 0)

                Text(booking.spotNumber)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(colors.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accentGroup(isAccented)

                Text("\(booking.fromTime) – \(booking.toTime)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.textSub)
                    .lineLimit(1)

                Text("Spot \(booking.spotNumber)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(colors.textFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("EL Parking")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(colors.textMain)

                Spacer()

                Text("No booking")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(colors.textMain)

                HStack(spacing: 5) {
                    Image(systemName: "parkingsign.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(entry.availableCount) free")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(colors.primary.opacity(0.8))

                Button(intent: WidgetBookFavoriteIntent()) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        Text("Book favorite")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(onAccent)
                    .foregroundStyle(primaryActionForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(primaryActionBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: ParkingEntry
    let colors: WidgetColors
    let isAccented: Bool

    private var primaryActionBackground: Color { isAccented ? .white.opacity(0.2) : accentGreen }
    private var primaryActionForeground: Color { isAccented ? .white : onAccent }

    var body: some View {
        if let booking = entry.booking {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(booking.isToday ? "ACTIVE" : "UPCOMING")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(colors.statusText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colors.sectionBg)
                        .clipShape(Capsule())
                        .accentGroup(isAccented)

                    Text(booking.spotNumber)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(colors.primary)
                        .minimumScaleFactor(0.55)
                        .accentGroup(isAccented)

                    Text("\(booking.fromTime) – \(booking.toTime)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colors.textSub)

                    Text(booking.userName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(colors.textFaint)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Availability")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(colors.textFaint)

                    Text("\(entry.availableCount) / \(entry.totalCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(colors.textMain)

                    availabilityBar
                        .frame(height: 6)

                    Spacer(minLength: 0)

                    Button(intent: WidgetNavigateIntent()) {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Navigate")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(colors.pillFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(colors.pillBg)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.sectionBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        } else {
            noBookingView
        }
    }

    private var noBookingView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EL Parking")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(colors.textMain)

                Text("No booking today")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(colors.textMain)

                Text("\(entry.availableCount) of \(entry.totalCount) spots free")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colors.primary.opacity(0.75))
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Availability")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(colors.textFaint)
                availabilityBar
                    .frame(height: 6)
                Button(intent: WidgetBookFavoriteIntent()) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Book favorite").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(onAccent)
                    .foregroundStyle(primaryActionForeground)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(primaryActionBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(colors.sectionBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var availabilityBar: some View {
        GeometryReader { geo in
            let usedRatio = entry.totalCount > 0
                ? CGFloat(entry.totalCount - entry.availableCount) / CGFloat(entry.totalCount)
                : 0
            ZStack(alignment: .leading) {
                Capsule().fill(colors.trackBg)
                Capsule()
                    .fill(colors.primary.opacity(0.65))
                    .frame(width: geo.size.width * usedRatio)
            }
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: ParkingEntry
    let colors: WidgetColors
    let isAccented: Bool

    private var primaryActionBackground: Color { isAccented ? .white.opacity(0.2) : accentGreen }
    private var primaryActionForeground: Color { isAccented ? .white : onAccent }

    var body: some View {
        if let booking = entry.booking {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors.dotFill(active: booking.isToday))
                            .frame(width: 8, height: 8)
                        Text(booking.isToday ? "ACTIVE NOW" : "UPCOMING")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(colors.statusText)
                            .accentGroup(isAccented)
                    }
                    Spacer()
                    Text("EL PARKING")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(colors.brandLabel)
                }

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(booking.spotNumber)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(colors.primary)
                        .minimumScaleFactor(0.5)
                        .accentGroup(isAccented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(booking.naturalDate)
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(colors.textFaint)

                        Text("\(booking.fromTime) – \(booking.toTime)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(colors.textSub)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(colors.iconTint)
                            .frame(width: 16)
                        Text(booking.userName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(colors.textSub)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(colors.iconTint)
                            .frame(width: 16)
                        Text("Rohanské nábřeží 721/39, Praha")
                            .font(.system(size: 12))
                            .foregroundStyle(colors.textFaint)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(colors.iconTint)
                            .frame(width: 16)
                        Text("EssilorLuxottica")
                            .font(.system(size: 12))
                            .foregroundStyle(colors.textFaint)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.sectionBg)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 0) {
                    Text("\(entry.availableCount)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(colors.primary)
                    Text(" / \(entry.totalCount) spots available")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colors.textFaint)

                    Spacer()

                    GeometryReader { geo in
                        let ratio = entry.totalCount > 0
                            ? CGFloat(entry.totalCount - entry.availableCount) / CGFloat(entry.totalCount)
                            : 0
                        ZStack(alignment: .leading) {
                            Capsule().fill(colors.trackBg)
                            Capsule()
                                .fill(colors.primary.opacity(0.6))
                                .frame(width: geo.size.width * ratio)
                        }
                    }
                    .frame(width: 60, height: 6)
                }
                .padding(.vertical, 4)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button(intent: WidgetNavigateIntent()) {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill").font(.system(size: 10))
                            Text("Navigate").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(colors.pillFg)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(colors.pillBg)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Link(destination: URL(string: "elparking://edit/\(booking.id)")!) {
                        HStack(spacing: 5) {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 10))
                            Text("Edit").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(colors.pillFg)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(colors.pillBg)
                        .clipShape(Capsule())
                    }

                    Link(destination: URL(string: "elparking://cancel/\(booking.id)")!) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                            Text("Cancel")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(dangerRed)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(dangerRed.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }
        } else {
            noBookingView
        }
    }

    private var noBookingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EL PARKING")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(colors.brandLabel)
                Spacer()
            }

            Text("EL Parking")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(colors.textMain)

            Spacer()

            Text("No Upcoming\nBooking")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(colors.textMain)
                .lineSpacing(2)

            Text("\(entry.availableCount) of \(entry.totalCount) spots currently available")
                .font(.system(size: 13))
                .foregroundStyle(colors.primary.opacity(0.65))

            Spacer()

            Button(intent: WidgetBookFavoriteIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                    Text("Book favorite").font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(onAccent)
                .foregroundStyle(primaryActionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(primaryActionBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Vehicle Identity Widget

struct ParkingVehicleIdentityWidget: Widget {
    let kind = "ParkingVehicleIdentityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkingTimelineProvider()) { entry in
            ParkingVehicleIdentityEntryView(entry: entry)
                .containerBackground(widgetAdaptiveBg, for: .widget)
        }
        .configurationDisplayName("My Vehicle")
        .description("Show your car maker badge, model, plate, and next parking slot.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ParkingVehicleIdentityEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: ParkingEntry

    private var isDark: Bool { colorScheme == .dark }
    private var isAccented: Bool { renderingMode == .accented }
    private var colors: WidgetColors {
        if isAccented { return .accented }
        return isDark ? .dark : .light
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium: mediumBody
            default:            smallBody
            }
        }
        .widgetURL(URL(string: "elparking://home"))
    }

    // MARK: - Small

    private var smallBody: some View {
        Group {
            if let booking = entry.booking {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(booking.isToday ? "ACTIVE" : "UPCOMING")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(colors.statusText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colors.sectionBg)
                            .clipShape(Capsule())
                            .accentGroup(isAccented)
                        Spacer()
                        Text(booking.naturalDate)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(colors.textFaint)
                    }

                    Spacer(minLength: 0)

                    Text(booking.spotNumber)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(colors.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .accentGroup(isAccented)

                    Text("\(booking.fromTime) – \(booking.toTime)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colors.textSub)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let img = entry.vehicleMiniatureImage {
                            img.resizable().scaledToFit()
                                .frame(width: 36, height: 20)
                        } else {
                            Image(systemName: entry.vehicleSideIcon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(colors.iconTint)
                        }
                        if !entry.vehiclePlate.isEmpty {
                            Text(entry.vehiclePlate)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(colors.textFaint)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                emptySmallBody
            }
        }
    }

    private var emptySmallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EL Parking")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(colors.textMain)

            Spacer()

            Text("No booking")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(colors.textMain)

            HStack(spacing: 5) {
                Image(systemName: "parkingsign.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(entry.availableCount) free")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(colors.primary.opacity(0.8))

            HStack(spacing: 6) {
                if let img = entry.vehicleMiniatureImage {
                    img.resizable().scaledToFit()
                        .frame(width: 40, height: 22)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.vehicleDescription.isEmpty ? "My Vehicle" : entry.vehicleDescription)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(colors.textSub)
                        .lineLimit(1)
                    if !entry.vehiclePlate.isEmpty {
                        Text(entry.vehiclePlate)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(colors.textMain)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Medium

    private var mediumBody: some View {
        Group {
            if let booking = entry.booking {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(booking.isToday ? "ACTIVE" : "UPCOMING")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(colors.statusText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colors.sectionBg)
                            .clipShape(Capsule())
                            .accentGroup(isAccented)

                        Text(booking.spotNumber)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(colors.primary)
                            .minimumScaleFactor(0.55)
                            .accentGroup(isAccented)

                        Text("\(booking.fromTime) – \(booking.toTime)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(colors.textSub)

                        Text(booking.userName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(colors.textFaint)
                            .lineLimit(1)
                    }

                    VStack(spacing: 8) {
                        Spacer(minLength: 0)

                        if let img = entry.vehicleMiniatureImage {
                            img.resizable().scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        } else {
                            Image(systemName: entry.vehicleSideIcon)
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(colors.textSub)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }

                        VStack(spacing: 2) {
                            Text(entry.vehicleDescription.isEmpty ? "My Vehicle" : entry.vehicleDescription)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(colors.textSub)
                                .lineLimit(1)
                            if !entry.vehiclePlate.isEmpty {
                                Text(entry.vehiclePlate)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(colors.textMain)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(colors.sectionBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                emptyMediumBody
            }
        }
    }

    private var emptyMediumBody: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EL Parking")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(colors.textMain)

                Text("No booking today")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(colors.textMain)

                Text("\(entry.availableCount) of \(entry.totalCount) spots free")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colors.primary.opacity(0.75))
            }

            Spacer()

            VStack(spacing: 8) {
                Spacer(minLength: 0)

                if let img = entry.vehicleMiniatureImage {
                    img.resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                } else {
                    Image(systemName: entry.vehicleSideIcon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(colors.textSub)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }

                VStack(spacing: 2) {
                    Text(entry.vehicleDescription.isEmpty ? "My Vehicle" : entry.vehicleDescription)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(colors.textSub)
                        .lineLimit(1)
                    if !entry.vehiclePlate.isEmpty {
                        Text(entry.vehiclePlate)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(colors.textMain)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(colors.sectionBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct WidgetMakerBadge: View {
    let make: String
    var size: CGFloat

    private var initialText: String {
        let clean = make.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "•" }
        switch clean {
        case "Škoda": return "Š"
        case "BMW": return "BMW"
        case "MINI": return "MINI"
        case "Tesla": return "T"
        case "Volkswagen": return "VW"
        case "Mercedes-Benz": return "MB"
        default:
            let tokens = clean.split(whereSeparator: { $0.isWhitespace || $0 == "-" }).map(String.init)
            if tokens.count >= 2 {
                return "\(tokens[0].prefix(1).uppercased())\(tokens[1].prefix(1).uppercased())"
            }
            return String(clean.prefix(2)).uppercased()
        }
    }

    private var gradientColors: [Color] {
        switch make {
        case "Škoda": return [Color(red: 0.11, green: 0.42, blue: 0.23), Color(red: 0.18, green: 0.58, blue: 0.31)]
        case "BMW": return [Color(red: 0.06, green: 0.11, blue: 0.18), Color(red: 0.17, green: 0.31, blue: 0.54)]
        case "Tesla": return [Color(red: 0.44, green: 0.07, blue: 0.16), Color(red: 0.72, green: 0.10, blue: 0.24)]
        case "Audi": return [Color(red: 0.16, green: 0.16, blue: 0.16), Color(red: 0.30, green: 0.30, blue: 0.30)]
        case "Volkswagen": return [Color(red: 0.05, green: 0.16, blue: 0.34), Color(red: 0.11, green: 0.31, blue: 0.60)]
        default: return [Color(red: 0.28, green: 0.33, blue: 0.40), Color(red: 0.42, green: 0.47, blue: 0.56)]
        }
    }

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(initialText)
                    .font(.system(size: max(7, size * 0.37), weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8)
            )
    }
}

private func splitWidgetMakeModel(_ description: String) -> (make: String, model: String) {
    let value = description.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return ("", "") }

    let knownMakes = [
        "Škoda", "Hyundai", "Toyota", "Volkswagen", "Kia", "Dacia",
        "Ford", "Mercedes-Benz", "Renault", "BMW", "Audi", "Volvo",
        "Tesla", "MG", "Nissan", "Peugeot", "MINI", "Subaru", "Porsche", "Honda",
        "Opel", "Mazda", "Citroën", "Seat"
    ]

    let folded = value.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    for make in knownMakes {
        let foldedMake = make.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if folded == foldedMake {
            return (make, "")
        }
        if folded.hasPrefix(foldedMake + " ") {
            let modelStart = value.index(value.startIndex, offsetBy: min(value.count, make.count))
            let model = String(value[modelStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (make, model)
        }
    }

    return ("", value)
}

private func colorForVehicle(raw: String) -> Color? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("#") else { return nil }
    let hex = String(trimmed.dropFirst())
    guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
    let r = Double((value >> 16) & 0xFF) / 255.0
    let g = Double((value >> 8) & 0xFF) / 255.0
    let b = Double(value & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
}

// MARK: - Previews (Dark)

#Preview("Small – Dark", as: .systemSmall) {
    ParkingHomeWidget()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "Škoda Octavia RS",
                 vehicleColor: "White",
                 vehicleType: "combi")
}

#Preview("Medium – Dark", as: .systemMedium) {
    ParkingHomeWidget()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "MALAKJAN Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "BMW 3 Series",
                 vehicleColor: "Black",
                 vehicleType: "sedan")
}

#Preview("Large – Dark", as: .systemLarge) {
    ParkingHomeWidget()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "MALAKJAN Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "Volvo EX30",
                 vehicleColor: "Moss Yellow",
                 vehicleType: "electric")
}

// MARK: - Previews (Light)

#Preview("Small – Light", as: .systemSmall) {
    ParkingHomeWidgetLight()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "Škoda Octavia RS",
                 vehicleColor: "White",
                 vehicleType: "combi")
}

#Preview("Medium – Light", as: .systemMedium) {
    ParkingHomeWidgetLight()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "MALAKJAN Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "Tesla Model 3",
                 vehicleColor: "White",
                 vehicleType: "combi")
}

#Preview("Large – Light", as: .systemLarge) {
    ParkingHomeWidgetLight()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "MALAKJAN Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "MINI Countryman",
                 vehicleColor: "Green",
                 vehicleType: "hatchback")
}

#Preview("Vehicle – Small", as: .systemSmall) {
    ParkingVehicleIdentityWidget()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv Malakjan",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "Škoda Octavia RS",
                 vehicleColor: "#2D7D46",
                 vehicleType: "combi")
}

#Preview("Vehicle – Medium", as: .systemMedium) {
    ParkingVehicleIdentityWidget()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "75", spotLabel: "P75",
                                        userName: "Stiv", fromTime: "09:00", toTime: "17:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 10, totalCount: 15,
                 userName: "Stiv Malakjan",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "BMW 3 Series",
                 vehicleColor: "#111111",
                 vehicleType: "sedan")
}

// MARK: - Lock Screen: Widget Definition

struct ParkingLockWidget: Widget {
    let kind = "ParkingLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkingTimelineProvider()) { entry in
            ParkingLockEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("EL Parking – Lock Screen")
        .description("Quick glance at your parking spot from the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Lock Screen: Entry View

struct ParkingLockEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ParkingEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    LockCircularView(entry: entry)
        case .accessoryRectangular: LockRectangularView(entry: entry)
        case .accessoryInline:      LockInlineView(entry: entry)
        default:                    LockCircularView(entry: entry)
        }
    }
}

// MARK: - Lock Screen: Circular (spot number + status ring)

struct LockCircularView: View {
    let entry: ParkingEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let booking = entry.booking {
                VStack(spacing: 0) {
                    Text(booking.isToday ? "NOW" : "NEXT")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .opacity(0.7)
                    Text(booking.spotNumber)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "parkingsign")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(entry.availableCount)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text("free")
                        .font(.system(size: 7, weight: .semibold))
                        .opacity(0.7)
                }
            }
        }
    }
}

// MARK: - Lock Screen: Rectangular (spot + date + time)

struct LockRectangularView: View {
    let entry: ParkingEntry

    var body: some View {
        if let booking = entry.booking {
            HStack(alignment: .center, spacing: 10) {
                // Giant spot number — no fixed width, fills what it needs
                Text(booking.spotNumber)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .fixedSize()

                // Vertical divider
                Rectangle()
                    .frame(width: 1.5, height: 36)
                    .opacity(0.25)

                // Details column
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .frame(width: 5, height: 5)
                            .opacity(booking.isToday ? 1.0 : 0.45)
                        Text(booking.isToday ? "ACTIVE" : "UPCOMING")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.2)
                            .lineLimit(1)
                    }
                    Text(booking.naturalDate)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    Text("\(booking.fromTime)–\(booking.toTime)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "parkingsign.circle.fill")
                    .font(.system(size: 30))

                VStack(alignment: .leading, spacing: 3) {
                    Text("No Booking")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(entry.availableCount) of \(entry.totalCount) spots free")
                        .font(.system(size: 11))
                        .opacity(0.7)
                    Button(intent: WidgetBookFavoriteIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Book favorite")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Lock Screen: Inline (single row)

struct LockInlineView: View {
    let entry: ParkingEntry

    var body: some View {
        if let booking = entry.booking {
            Label {
                Text("Spot \(booking.spotNumber)  \(booking.naturalDate)  \(booking.fromTime)–\(booking.toTime)")
            } icon: {
                Image(systemName: booking.isToday ? "checkmark.circle.fill" : "clock")
            }
        } else {
            Label {
                Text("\(entry.availableCount) spots free · Book now")
            } icon: {
                Image(systemName: "parkingsign")
            }
        }
    }
}

// MARK: - Lock Screen Previews

#Preview("Lock – Circular", as: .accessoryCircular) {
    ParkingLockWidget()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "Škoda Octavia RS",
                 vehicleColor: "White",
                 vehicleType: "combi")
}

#Preview("Lock – Rectangular", as: .accessoryRectangular) {
    ParkingLockWidget()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "Škoda Octavia RS Combi",
                 vehicleColor: "Mamba Green",
                 vehicleType: "combi")
}

#Preview("Lock – Inline", as: .accessoryInline) {
    ParkingLockWidget()
} timeline: {
    ParkingEntry(date: .now,
                 booking: WidgetBooking(id: "1", spotNumber: "63", spotLabel: "P63",
                                        userName: "Stiv", fromTime: "07:00", toTime: "18:00",
                                        bookingDate: .now, isToday: true),
                 availableCount: 8, totalCount: 15,
                 userName: "Stiv",
                 vehiclePlate: "1AFL374",
                 vehicleDescription: "BMW 3 Series",
                 vehicleColor: "Black",
                 vehicleType: "sedan")
}
