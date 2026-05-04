//
//  OnboardingView.swift
//  EL PARKING APP
//
//  Interactive first-login walkthrough with live UI previews.
//  Shows once ever on first authenticated login, then never again.
//

import SwiftUI

// MARK: - Internal Models

private enum SpotState { case free, taken, mine, blocked }

private struct PreviewSpot {
    let label: String
    let name: String
    let state: SpotState
    var accessible: Bool = false
}

private struct OnboardingPage {
    enum Kind { case welcome, home, grid, booking, reminders, widgets, bookingWindows, warnings, done }
    let kind: Kind
    let accentKey: String   // "accent" | "blue" | "green" | "orange"
    let title: String
    let subtitle: String
    let description: String
    let tip: String?
}

// MARK: - OnboardingView

struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @ObservedObject private var lang = LanguageManager.shared

    // ── Pages (computed so L10n is evaluated at render time) ───────────────
    private var pages: [OnboardingPage] {[
        OnboardingPage(
            kind: .welcome, accentKey: "accent",
            title: L10n.onboardingWelcomeTitle,
            subtitle: L10n.onboardingWelcomeSub,
            description: L10n.onboardingWelcomeDesc,
            tip: nil
        ),
        OnboardingPage(
            kind: .home, accentKey: "blue",
            title: L10n.onboardingHomeTitle,
            subtitle: L10n.onboardingHomeSub,
            description: L10n.onboardingHomeDesc,
            tip: nil
        ),
        OnboardingPage(
            kind: .grid, accentKey: "green",
            title: L10n.onboardingGridTitle,
            subtitle: L10n.onboardingGridSub,
            description: L10n.onboardingGridDesc,
            tip: L10n.onboardingGridTip
        ),
        OnboardingPage(
            kind: .booking, accentKey: "accent",
            title: L10n.onboardingBookTitle,
            subtitle: L10n.onboardingBookSub,
            description: L10n.onboardingBookDesc,
            tip: L10n.onboardingBookTip
        ),
        OnboardingPage(
            kind: .reminders, accentKey: "orange",
            title: L10n.onboardingRemTitle,
            subtitle: L10n.onboardingRemSub,
            description: L10n.onboardingRemDesc,
            tip: nil
        ),
        OnboardingPage(
            kind: .widgets, accentKey: "blue",
            title: L10n.onboardingWidgetsTitle,
            subtitle: L10n.onboardingWidgetsSub,
            description: L10n.onboardingWidgetsDesc,
            tip: L10n.onboardingWidgetsTip
        ),
        OnboardingPage(
            kind: .bookingWindows, accentKey: "blue",
            title: L10n.onboardingWindowsTitle,
            subtitle: L10n.onboardingWindowsSub,
            description: L10n.onboardingWindowsDesc,
            tip: L10n.onboardingWindowsTip
        ),
        OnboardingPage(
            kind: .warnings, accentKey: "orange",
            title: L10n.onboardingWarningsTitle,
            subtitle: L10n.onboardingWarningsSub,
            description: L10n.onboardingWarningsDesc,
            tip: L10n.onboardingWarningsTip
        ),
        OnboardingPage(
            kind: .done, accentKey: "green",
            title: L10n.onboardingDoneTitle,
            subtitle: L10n.onboardingDoneSub,
            description: L10n.onboardingDoneDesc,
            tip: nil
        ),
    ]}
    // ──────────────────────────────────────────────────────────────────────

    // MARK: Body

    var body: some View {
        ZStack {
            AppConfig.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {

                // Skip button (top-right, hidden on last page)
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(L10n.skip) { dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 48)

                // Page carousel
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { idx in
                        pageContent(pages[idx]).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Progress capsules
                HStack(spacing: 7) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? AppConfig.accent : AppConfig.surfaceHigh)
                            .frame(width: i == currentPage ? 22 : 7, height: 7)
                            .animation(.standard,
                                       value: currentPage)
                    }
                }
                .padding(.bottom, 22)

                // Next / Get Started
                Button {
                    if currentPage < pages.count - 1 { currentPage += 1 }
                    else { dismiss() }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? L10n.next : L10n.getStarted)
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(AppConfig.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(AppConfig.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Page Layout

    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 16) {
            // Live UI preview card
            previewCard(for: page.kind)
                .padding(.horizontal, 20)
                .padding(.top, 6)

            // Title + subtitle + description
            VStack(spacing: 10) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppConfig.darkText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(page.subtitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color(page.accentKey))

                Text(page.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppConfig.darkText.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 28)

            // Tip callout
            if let tip = page.tip {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color(page.accentKey))
                    Text(tip)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppConfig.darkText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(color(page.accentKey).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .stroke(color(page.accentKey).opacity(0.25), lineWidth: 1))
                .padding(.horizontal, 28)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Preview Card Router

    private func previewCard(for kind: OnboardingPage.Kind) -> some View {
        // AnyView used here so the switch branches all share the same type —
        // avoids deep _ConditionalContent nesting that can slow the compiler.
        switch kind {
        case .welcome:   AnyView(welcomePreview)
        case .home:      AnyView(homePreview)
        case .grid:      AnyView(gridPreview)
        case .booking:   AnyView(bookingPreview)
        case .reminders:      AnyView(remindersPreview)
        case .widgets:        AnyView(widgetsPreview)
        case .bookingWindows: AnyView(bookingWindowsPreview)
        case .warnings:       AnyView(warningsPreview)
        case .done:           AnyView(donePreview)
        }
    }

    // Shared card container
    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.28), radius: 18, y: 6)
            .overlay(RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    // MARK: ── Welcome Preview ──────────────────────────────────────────────

    private var welcomePreview: some View {
        card {
            VStack(spacing: 0) {
                // Mini top bar
                HStack(spacing: 7) {
                    Image(systemName: "parkingsign")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppConfig.accentFg)
                    Text("EL Parking")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                    Text("Hello, Alex!")
                        .font(.system(size: 11))
                        .foregroundStyle(AppConfig.subtleGray)
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
                Divider().overlay(Color.white.opacity(0.06))

                // Active booking row
                HStack(spacing: 12) {
                    spotBadge("63", color: AppConfig.accent, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TODAY").font(.system(size: 9, weight: .bold)).tracking(1)
                            .foregroundStyle(AppConfig.accentFg)
                        Text("09:00 – 17:00").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppConfig.darkText)
                        Text("Parking 63").font(.system(size: 11))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    Spacer()
                    statusPill("Active", color: green)
                }
                .padding(14)
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 14).padding(.top, 12)

                // Mini spots strip
                HStack(spacing: 5) {
                    ForEach(welcomeSpots, id: \.label) { miniCell($0) }
                }
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 14)
            }
        }
    }

    // MARK: ── Home Preview ─────────────────────────────────────────────────

    private var homePreview: some View {
        card {
            VStack(spacing: 0) {
                // Greeting header
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Good morning,").font(.system(size: 11))
                            .foregroundStyle(AppConfig.subtleGray)
                        Text("Alex 👋").font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppConfig.darkText)
                    }
                    Spacer()
                    Circle().fill(AppConfig.accent.opacity(0.18)).frame(width: 34, height: 34)
                        .overlay(Text("A").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppConfig.accentFg))
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

                // Active booking card
                sectionLabel("ACTIVE BOOKING").padding(.horizontal, 16)
                HStack(spacing: 12) {
                    spotBadge("63", color: AppConfig.accent, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Parking 63").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppConfig.darkText)
                        iconRow("clock.fill", "09:00 – 17:00")
                        iconRow("calendar",   "Thu, 28 Mar")
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.35))
                }
                .padding(12).background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 14).padding(.top, 6)

                // Upcoming row
                sectionLabel("UPCOMING").padding(.horizontal, 16).padding(.top, 10)
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8).fill(AppConfig.accent.opacity(0.15))
                        .frame(width: 34, height: 34)
                        .overlay(Text("P80").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppConfig.accentFg))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Parking 80").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppConfig.darkText)
                        Text("Fri, 29 Mar · 09:00 – 13:00").font(.system(size: 10))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(AppConfig.surfaceLow.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 14).padding(.top, 5).padding(.bottom, 16)
            }
        }
    }

    // MARK: ── Grid Preview ─────────────────────────────────────────────────

    private var gridPreview: some View {
        card {
            VStack(spacing: 0) {
                HStack {
                    Text("Parking").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                    HStack(spacing: 10) {
                        legendDot(green, "Free")
                        legendDot(red,   "Taken")
                        legendDot(AppConfig.accent, "Mine")
                    }
                }
                .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
                    spacing: 6
                ) {
                    ForEach(gridSpots, id: \.label) { gridCell($0) }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
            }
        }
    }

    // MARK: ── Booking Preview ──────────────────────────────────────────────

    private var bookingPreview: some View {
        card {
            VStack(spacing: 0) {
                // Sheet handle
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.14))
                    .frame(width: 36, height: 5).padding(.top, 10).padding(.bottom, 12)

                HStack {
                    Text("New Booking").font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                    Image(systemName: "xmark.circle.fill").font(.system(size: 15))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.35))
                }
                .padding(.horizontal, 16).padding(.bottom, 14)

                // Spot
                HStack(spacing: 12) {
                    spotBadge("63", color: AppConfig.accent, size: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Parking 63").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppConfig.darkText)
                        Text("Floor B · Available").font(.system(size: 11))
                            .foregroundStyle(green)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 12)

                // Date + Time
                VStack(spacing: 0) {
                    formRow("calendar", "Date", "Thu, 28 Mar")
                    Divider().overlay(Color.white.opacity(0.06))
                    HStack(spacing: 0) {
                        halfRow("clock", "From", "09:00")
                        Divider().frame(width: 1).overlay(Color.white.opacity(0.06))
                        halfRow("clock", "To", "17:00")
                    }
                }
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 16)

                // Book button
                HStack(spacing: 6) {
                    Text("Book Spot").font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppConfig.onAccent)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(AppConfig.accent)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 16)
            }
        }
    }

    // MARK: ── Reminders Preview ────────────────────────────────────────────

    private var remindersPreview: some View {
        card {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "bell.badge.fill").font(.system(size: 12))
                        .foregroundStyle(AppConfig.accentFg)
                    Text("Notifications").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

                // Toggle row
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 9).fill(AppConfig.accent).frame(width: 33, height: 33)
                        .overlay(Image(systemName: "bell.badge.fill").font(.system(size: 14))
                            .foregroundStyle(AppConfig.onAccent))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Booking Reminders").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppConfig.darkText)
                        Text("Notify before my booking starts").font(.system(size: 9))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    Spacer()
                    // Toggle pill (on)
                    ZStack {
                        RoundedRectangle(cornerRadius: 11).fill(AppConfig.accent)
                            .frame(width: 40, height: 24)
                        Circle().fill(AppConfig.onAccent).frame(width: 18, height: 18)
                            .offset(x: 8)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 10)

                // "Notify me" header
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppConfig.accentFg)
                    Text("NOTIFY ME").font(.system(size: 9, weight: .bold)).tracking(1.2)
                        .foregroundStyle(AppConfig.subtleGray)
                    Spacer()
                    Text("1 hour before").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppConfig.accentFg)
                }
                .padding(.horizontal, 16).padding(.bottom, 7)

                // 2×2 pill grid
                let pillLabels = ["30 min before", "1 hour before", "2 hours before", "3 hours before"]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(pillLabels, id: \.self) { label in
                        let sel = label == "1 hour before"
                        Text(label)
                            .font(.system(size: 11, weight: sel ? .bold : .medium))
                            .foregroundStyle(sel ? AppConfig.onAccent : AppConfig.darkText)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(sel ? AppConfig.accent : AppConfig.surfaceLow)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            }
        }
    }

    // MARK: ── Done Preview ─────────────────────────────────────────────────

    private var donePreview: some View {
        card {
            VStack(spacing: 0) {
                // Checkmark badge
                ZStack {
                    Circle().fill(green.opacity(0.13)).frame(width: 68, height: 68)
                    Circle().fill(green.opacity(0.08)).frame(width: 88, height: 88)
                    Image(systemName: "checkmark").font(.system(size: 26, weight: .bold))
                        .foregroundStyle(green)
                }
                .padding(.top, 20).padding(.bottom, 10)

                Text("Booking Confirmed!").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppConfig.darkText).padding(.bottom, 14)

                // Detail rows
                VStack(spacing: 0) {
                    confirmRow("parkingsign", "Spot",  "Parking 63")
                    Divider().overlay(Color.white.opacity(0.06))
                    confirmRow("calendar",    "Date",  "Thu, 28 Mar 2026")
                    Divider().overlay(Color.white.opacity(0.06))
                    confirmRow("clock.fill",  "Time",  "09:00 – 17:00")
                }
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
    }

    // MARK: ── Widgets Preview ──────────────────────────────────────────────

    private var widgetsPreview: some View {
        card {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 12))
                        .foregroundStyle(blue)
                    Text("Widgets")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                    statusPill("Home + Lock", color: blue)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

                HStack(spacing: 10) {
                    // Home Screen style card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Home Screen")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppConfig.subtleGray)
                        Text("P63")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(AppConfig.accentFg)
                        Text("09:00 – 17:00")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppConfig.darkText.opacity(0.75))
                        Capsule()
                            .fill(AppConfig.accent.opacity(0.35))
                            .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                    .padding(12)
                    .background(AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Lock Screen style cards
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppConfig.surfaceLow)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text("63")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(AppConfig.darkText)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lock Screen")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(AppConfig.subtleGray)
                                Text("TODAY · 09:00–17:00")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppConfig.darkText.opacity(0.8))
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(AppConfig.surfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        HStack(spacing: 6) {
                            Text("Press and hold Home or Lock Screen")
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(blue)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppConfig.subtleGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }

    // MARK: ── Booking Windows Preview ─────────────────────────────────────────

    private var bookingWindowsPreview: some View {
        card {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundStyle(blue)
                    Text("Booking Windows")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

                VStack(spacing: 8) {
                    windowRow(
                        icon: "person.fill",
                        role: "Standard",
                        window: "Today  +  Tomorrow after 18:00",
                        color: AppConfig.accent
                    )
                    windowRow(
                        icon: "star.fill",
                        role: "Privileged",
                        window: "Today through Today + 3 days",
                        color: blue
                    )
                    windowRow(
                        icon: "shield.fill",
                        role: "Admin",
                        window: "Any date",
                        color: Color(red: 0.55, green: 0.35, blue: 0.92)
                    )
                }
                .padding(.horizontal, 14).padding(.bottom, 16)
            }
        }
    }

    private func windowRow(icon: String, role: String, window: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(role).font(.system(size: 12, weight: .bold)).foregroundStyle(AppConfig.darkText)
                Text(window).font(.system(size: 10)).foregroundStyle(AppConfig.subtleGray)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13)).foregroundStyle(color.opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: ── Warnings Preview ────────────────────────────────────────────────

    private var warningsPreview: some View {
        card {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(orange)
                    Text("Warning System")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppConfig.darkText)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

                VStack(spacing: 7) {
                    warningRow(name: "John D.", strikes: 1, isSuspended: false)
                    warningRow(name: "Maria K.", strikes: 2, isSuspended: false)
                    warningRow(name: "Pavel N.", strikes: 3, isSuspended: true)
                }
                .padding(.horizontal, 14)

                // Legend
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9)).foregroundStyle(orange)
                        Text("Warning").font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "nosign")
                            .font(.system(size: 9)).foregroundStyle(red)
                        Text("Suspended").font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppConfig.subtleGray)
                    }
                    Spacer()
                    Text("3 warnings = 2 weeks")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                }
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 14)
            }
        }
    }

    private func warningRow(name: String, strikes: Int, isSuspended: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppConfig.surfaceLow)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppConfig.darkText)
                )
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppConfig.darkText)
            Spacer()
            if isSuspended {
                HStack(spacing: 4) {
                    Image(systemName: "nosign").font(.system(size: 10)).foregroundStyle(red)
                    Text("Suspended").font(.system(size: 10, weight: .semibold)).foregroundStyle(red)
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(red.opacity(0.12))
                .clipShape(Capsule())
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < strikes ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(i < strikes ? orange : AppConfig.subtleGray.opacity(0.3))
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    // MARK: - Spot Data

    private var welcomeSpots: [PreviewSpot] {[
        PreviewSpot(label: "P61", name: "",     state: .free),
        PreviewSpot(label: "P62", name: "Marc", state: .taken),
        PreviewSpot(label: "P63", name: "You",  state: .mine),
        PreviewSpot(label: "P64", name: "",     state: .free),
        PreviewSpot(label: "P65", name: "",     state: .blocked),
    ]}

    private var gridSpots: [PreviewSpot] {[
        PreviewSpot(label: "P61", name: "",     state: .free),
        PreviewSpot(label: "P62", name: "Marc", state: .taken),
        PreviewSpot(label: "P63", name: "You",  state: .mine),
        PreviewSpot(label: "P64", name: "",     state: .free),
        PreviewSpot(label: "P65", name: "Lisa", state: .taken),
        PreviewSpot(label: "P66", name: "",     state: .free),
        PreviewSpot(label: "P67", name: "",     state: .blocked),
        PreviewSpot(label: "P68", name: "",     state: .free),
        PreviewSpot(label: "P69", name: "Tom",  state: .taken),
        PreviewSpot(label: "P70", name: "",     state: .free, accessible: true),
        PreviewSpot(label: "P71", name: "Jun",  state: .taken),
        PreviewSpot(label: "P72", name: "",     state: .free),
        PreviewSpot(label: "P73", name: "",     state: .free),
        PreviewSpot(label: "P74", name: "Sara", state: .taken),
        PreviewSpot(label: "P75", name: "",     state: .free),
    ]}

    // MARK: - Reusable Sub-Views

    // Small spot badge (P + number stacked)
    private func spotBadge(_ number: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(color.opacity(0.18)).frame(width: size, height: size)
            VStack(spacing: 0) {
                Text("P").font(.system(size: size * 0.18, weight: .medium))
                    .foregroundStyle(color.opacity(0.7))
                Text(number).font(.system(size: size * 0.40, weight: .black))
                    .foregroundStyle(color)
            }
        }
    }

    // Strip cell for welcome page
    private func miniCell(_ s: PreviewSpot) -> some View {
        let c = spotColor(s.state)
        return VStack(spacing: 2) {
            Text(s.label).font(.system(size: 7, weight: .bold)).foregroundStyle(c)
            if !s.name.isEmpty {
                Text(s.name).font(.system(size: 6)).foregroundStyle(c.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity).frame(height: 34)
        .background(c.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7)
            .stroke(c.opacity(s.state == .blocked ? 0.3 : 0.6), lineWidth: 1))
    }

    // Full grid cell
    private func gridCell(_ s: PreviewSpot) -> some View {
        let c = spotColor(s.state)
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 1) {
                Text(s.label.replacingOccurrences(of: "P", with: ""))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(s.state == .blocked ? Color(white: 0.4) : .white)
                if !s.name.isEmpty {
                    Text(s.name).font(.system(size: 7)).foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(c.opacity(s.state == .blocked ? 0.12 : 0.22))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(c.opacity(s.state == .blocked ? 0.3 : 0.65), lineWidth: 1.5))

            if s.accessible {
                Image(systemName: "figure.roll")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .padding(3)
            }
        }
    }

    private func legendDot(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(c).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppConfig.subtleGray)
        }
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .bold)).tracking(1.2)
            .foregroundStyle(AppConfig.subtleGray).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 5)
    }

    private func iconRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10)).foregroundStyle(AppConfig.subtleGray)
    }

    private func formRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(AppConfig.subtleGray)
                .frame(width: 18)
            Text(label).font(.system(size: 11)).foregroundStyle(AppConfig.subtleGray)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundStyle(AppConfig.darkText)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func halfRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9)).foregroundStyle(AppConfig.subtleGray)
            Text(label).font(.system(size: 10)).foregroundStyle(AppConfig.subtleGray)
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(AppConfig.accentFg)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func confirmRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(AppConfig.accentFg)
                .frame(width: 18)
            Text(label).font(.system(size: 11)).foregroundStyle(AppConfig.subtleGray)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppConfig.darkText)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var green:  Color { Color(red: 0.22, green: 0.68, blue: 0.42) }
    private var red:    Color { Color(red: 0.85, green: 0.26, blue: 0.26) }
    private var blue:   Color { Color(red: 0.27, green: 0.55, blue: 0.93) }
    private var orange: Color { Color(red: 0.92, green: 0.58, blue: 0.16) }

    private func spotColor(_ state: SpotState) -> Color {
        switch state {
        case .free:    return green
        case .taken:   return red
        case .mine:    return AppConfig.accent
        case .blocked: return Color(white: 0.35)
        }
    }

    private func color(_ key: String) -> Color {
        switch key {
        case "green":  return green
        case "orange": return orange
        case "red":    return red
        case "blue":   return blue
        default:       return AppConfig.accent
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
