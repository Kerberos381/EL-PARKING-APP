//
//  OnboardingView.swift
//  EL PARKING APP
//
//  First-login walkthrough, shown once ever on first authenticated login.
//  Three pages in the standard Apple welcome-screen template: large centered
//  title, plain accent-tinted feature rows, page dots, one Continue button.
//

import SwiftUI

struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var photoIndex = 0
    // Local preview choices — applied when onboarding closes so the palette
    // rebuild doesn't tear the sheet down mid-flow.
    @State private var previewCalm = UserDefaults.standard.object(forKey: "appPalette") == nil
        ? true
        : UserDefaults.standard.integer(forKey: "appPalette") == 1
    @ObservedObject private var lang = LanguageManager.shared

    private static let garagePhotos = ["ParkingGarage1", "ParkingGarage2", "ParkingGarage3", "ParkingGarage4"]

    private enum PageKind {
        case garage
        case features(title: String, showsIcon: Bool, rows: [(icon: String, title: String, description: String)])
        case personalize(title: String)
    }

    // Computed so L10n is evaluated at render time (language switching).
    private var pages: [PageKind] {[
        .garage,
        .features(
            title: L10n.onboardingWelcomeTitle,
            showsIcon: true,
            rows: [
                ("house.fill",         L10n.onboardingHomeTitle,  L10n.onboardingHomeDesc),
                ("square.grid.3x3.fill", L10n.onboardingGridTitle, L10n.onboardingGridDesc),
                ("calendar.badge.plus", L10n.onboardingBookTitle, L10n.onboardingBookDesc),
            ]
        ),
        .features(
            title: L10n.onboardingPage2Title,
            showsIcon: false,
            rows: [
                ("bell.badge.fill",       L10n.onboardingRemTitle,     L10n.onboardingRemDesc),
                ("rectangle.3.group.fill", L10n.onboardingWidgetsTitle, L10n.onboardingWidgetsDesc),
                ("plus.circle.fill",      L10n.onboardingWidgetsSub,   L10n.onboardingWidgetsTip),
            ]
        ),
        .personalize(title: L10n.onboardingPersonalizeTitle),
        .features(
            title: L10n.onboardingPage3Title,
            showsIcon: false,
            rows: [
                ("calendar.badge.clock",    L10n.onboardingWindowsTitle,   L10n.onboardingWindowsDesc),
                ("checkmark.shield.fill",   L10n.onboardingWarningsTitle,  L10n.onboardingWarningsDesc),
                ("parkingsign.square.fill", L10n.onboardingSpotGroupsTitle, L10n.onboardingSpotGroupsDesc),
                ("arrow.right.circle.fill", L10n.onboardingDoneTitle,      L10n.onboardingDoneDesc),
            ]
        ),
    ]}

    private var isLastPage: Bool { currentPage == pages.count - 1 }
    private var isGaragePage: Bool { currentPage == 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { idx in
                    pageView(pages[idx]).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.motionStandard, value: currentPage)
            .ignoresSafeArea(edges: isGaragePage ? .top : [])

            // Bottom chrome — floats over the garage photo on page 0
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(L10n.skip) { applySelections(); dismiss() }
                        .font(.body)
                        .foregroundStyle(isGaragePage ? .white.opacity(0.75) : AppConfig.subtleGray)
                        .padding(.horizontal, 24)
                        .opacity(isLastPage ? 0 : 1)
                        .disabled(isLastPage)
                }
                .frame(height: 44)

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage
                                  ? (isGaragePage ? Color.white : AppConfig.darkText)
                                  : (isGaragePage ? Color.white.opacity(0.35) : AppConfig.subtleGray.opacity(0.3)))
                            .frame(width: 7, height: 7)
                    }
                }
                .animation(.motionSelection, value: currentPage)
                .padding(.bottom, 16)

                Button {
                    if isLastPage {
                        applySelections()
                        dismiss()
                    } else {
                        Haptics.selection()
                        withAnimation(.motionStandard) { currentPage += 1 }
                    }
                } label: {
                    Text(isLastPage ? L10n.getStarted : L10n.continueBtn)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isGaragePage ? Color(red: 0.039, green: 0.039, blue: 0.055) : AppConfig.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isGaragePage ? Color.white : AppConfig.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(AppConfig.pageBg.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    // MARK: - Page Layout

    @ViewBuilder
    private func pageView(_ page: PageKind) -> some View {
        switch page {
        case .garage:
            garagePage
        case .features(let title, let showsIcon, let rows):
            featuresPage(title: title, showsIcon: showsIcon, rows: rows)
        case .personalize(let title):
            personalizePage(title: title)
        }
    }

    // MARK: - Garage Photo Page

    private var garagePage: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Swipeable photo carousel — drag horizontally to browse the route
                TabView(selection: $photoIndex) {
                    ForEach(0..<Self.garagePhotos.count, id: \.self) { i in
                        Image(Self.garagePhotos[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: geo.size.width, height: geo.size.height)

                // Gradient scrim
                LinearGradient(
                    colors: [.clear, .clear, Color.black.opacity(0.35), Color.black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                // Text overlay
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.onboardingGarageTitle)
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)

                    Text(L10n.onboardingGarageDesc)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(L10n.onboardingGarageCaption)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 2)

                    // Photo dots + a one-time swipe hint
                    HStack(spacing: 10) {
                        HStack(spacing: 5) {
                            ForEach(0..<Self.garagePhotos.count, id: \.self) { i in
                                Capsule()
                                    .fill(photoIndex == i ? Color.white : Color.white.opacity(0.35))
                                    .frame(width: photoIndex == i ? 18 : 6, height: 6)
                                    .animation(.motionSelection, value: photoIndex)
                            }
                        }
                        if photoIndex == 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.draw")
                                    .font(.caption2)
                                Text(L10n.onboardingSwipeHint)
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.white.opacity(0.55))
                            .transition(.opacity)
                        }
                    }
                    .animation(.motionStandard, value: photoIndex)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.bottom, 148) // leaves room for the floating chrome
                .allowsHitTesting(false) // let swipes reach the photo carousel
            }
        }
        .ignoresSafeArea()
    }

    private func featuresPage(title: String, showsIcon: Bool, rows: [(icon: String, title: String, description: String)]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if showsIcon {
                    Image("AppIconImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .padding(.bottom, 20)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppConfig.darkText)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(rows, id: \.title) { row in
                        FeatureListRow(icon: row.icon, title: row.title, description: row.description)
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 36)
            }
            .padding(.top, showsIcon ? 20 : 40)
            .padding(.bottom, 100) // room for the floating bottom chrome
        }
    }

    // MARK: - Personalize Page (palette + home layout with live preview)

    private func applySelections() {
        UserDefaults.standard.set(previewCalm ? 1 : 0, forKey: "appPalette")
        UserDefaults.standard.set("compact", forKey: "homeStyle")
    }

    private func personalizePage(title: String) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppConfig.darkText)
                    .multilineTextAlignment(.center)

                homePreview
                    .padding(.top, 24)

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.colorPalette)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                        Picker(L10n.colorPalette, selection: $previewCalm) {
                            Text(L10n.paletteDefault).tag(false)
                            Text(L10n.paletteCalm).tag(true)
                        }
                        .pickerStyle(.segmented)
                    }

                    Text(L10n.changeAnytimeHint)
                        .font(.caption)
                        .foregroundStyle(AppConfig.subtleGray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 22)
                .padding(.horizontal, 36)
            }
            .padding(.top, 40)
            .padding(.bottom, 100)
        }
        .onChange(of: previewCalm) { _, _ in Haptics.selection() }
    }

    // Preview palette colors (local — independent of the live app palette).
    private var pAccent: Color {
        previewCalm ? Color(red: 0.37, green: 0.56, blue: 0.45) : Color(uiColor: .systemGreen)
    }
    private var pBg: Color {
        previewCalm ? Color(red: 0.957, green: 0.957, blue: 0.945) : Color(red: 0.949, green: 0.953, blue: 0.961)
    }
    private var pHero: Color {
        previewCalm ? Color(red: 0.133, green: 0.157, blue: 0.122) : Color(red: 0.102, green: 0.110, blue: 0.118)
    }
    private var pCard: Color { .white }

    /// Schematic mini home — re-renders as the toggles change.
    private var homePreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Two-line greeting
            RoundedRectangle(cornerRadius: 3).fill(AppConfig.darkText.opacity(0.35)).frame(width: 46, height: 9)
            RoundedRectangle(cornerRadius: 3).fill(AppConfig.darkText.opacity(0.8)).frame(width: 34, height: 9)
            // Hero
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pHero).frame(height: 44)
                .overlay(alignment: .leading) {
                    Text("75").font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(pAccent.opacity(0.9)).padding(.leading, 10)
                }
            // Tile row
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pAccent)
                    .frame(height: 52)
                VStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pCard).frame(height: 22)
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pCard).frame(height: 22)
                }
            }
            // Vehicle bar
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pHero).frame(height: 30)
                .overlay(alignment: .leading) {
                    Image(systemName: "car.side.fill").font(.caption)
                        .foregroundStyle(.white.opacity(0.8)).padding(.leading, 10)
                }
        }
        .padding(12)
        .frame(width: 210)
        .background(pBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppConfig.subtleGray.opacity(0.25), lineWidth: 1)
        )
        .animation(.motionStandard, value: previewCalm)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
