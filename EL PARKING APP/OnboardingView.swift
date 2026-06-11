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
    // Local preview choices — applied when onboarding closes so the palette
    // rebuild doesn't tear the sheet down mid-flow.
    @State private var previewCalm = UserDefaults.standard.integer(forKey: "appPalette") == 1
    @State private var previewCompact = UserDefaults.standard.string(forKey: "homeStyle") == "compact"
    @ObservedObject private var lang = LanguageManager.shared

    private struct Page {
        let title: String
        var showsAppIcon: Bool = false
        var features: [(icon: String, title: String, description: String)] = []
        var isPersonalize: Bool = false
    }

    // Computed so L10n is evaluated at render time (language switching).
    private var pages: [Page] {[
        Page(
            title: L10n.onboardingWelcomeTitle,
            showsAppIcon: true,
            features: [
                ("house.fill",
                 L10n.onboardingHomeTitle,
                 L10n.onboardingHomeDesc),
                ("square.grid.3x3.fill",
                 L10n.onboardingGridTitle,
                 L10n.onboardingGridDesc),
                ("calendar.badge.plus",
                 L10n.onboardingBookTitle,
                 L10n.onboardingBookDesc),
            ]
        ),
        Page(
            title: L10n.onboardingPage2Title,
            features: [
                ("bell.badge.fill",
                 L10n.onboardingRemTitle,
                 L10n.onboardingRemDesc),
                ("rectangle.3.group.fill",
                 L10n.onboardingWidgetsTitle,
                 L10n.onboardingWidgetsDesc),
                ("plus.circle.fill",
                 L10n.onboardingWidgetsSub,
                 L10n.onboardingWidgetsTip),
            ]
        ),
        Page(title: L10n.onboardingPersonalizeTitle, isPersonalize: true),
        Page(
            title: L10n.onboardingPage3Title,
            features: [
                ("calendar.badge.clock",
                 L10n.onboardingWindowsTitle,
                 L10n.onboardingWindowsDesc),
                ("checkmark.shield.fill",
                 L10n.onboardingWarningsTitle,
                 L10n.onboardingWarningsDesc),
                ("parkingsign.square.fill",
                 L10n.onboardingSpotGroupsTitle,
                 L10n.onboardingSpotGroupsDesc),
                ("arrow.right.circle.fill",
                 L10n.onboardingDoneTitle,
                 L10n.onboardingDoneDesc),
            ]
        ),
    ]}

    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Skip (hidden on last page; cleared frame keeps layout stable)
            HStack {
                Spacer()
                Button(L10n.skip) { applySelections(); dismiss() }
                    .font(.body)
                    .foregroundStyle(AppConfig.subtleGray)
                    .padding(.horizontal, 24)
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
            }
            .frame(height: 44)
            .padding(.top, 8)

            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { idx in
                    pageView(pages[idx]).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.motionStandard, value: currentPage)

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage
                              ? AppConfig.darkText
                              : AppConfig.subtleGray.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .animation(.motionSelection, value: currentPage)
            .padding(.bottom, 20)

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
                    .foregroundStyle(AppConfig.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppConfig.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppConfig.pageBg.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    // MARK: - Page Layout

    @ViewBuilder
    private func pageView(_ page: Page) -> some View {
        if page.isPersonalize {
            personalizePage(page)
        } else {
            featuresPage(page)
        }
    }

    private func featuresPage(_ page: Page) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if page.showsAppIcon {
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

                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppConfig.darkText)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(page.features, id: \.title) { feature in
                        FeatureListRow(
                            icon: feature.icon,
                            title: feature.title,
                            description: feature.description
                        )
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 36)
            }
            .padding(.top, page.showsAppIcon ? 20 : 40)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Personalize Page (palette + home layout with live preview)

    private func applySelections() {
        UserDefaults.standard.set(previewCalm ? 1 : 0, forKey: "appPalette")
        UserDefaults.standard.set(previewCompact ? "compact" : "roomy", forKey: "homeStyle")
    }

    private func personalizePage(_ page: Page) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Text(page.title)
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.homeLayout)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                        Picker(L10n.homeLayout, selection: $previewCompact) {
                            Text(L10n.homeRoomy).tag(false)
                            Text(L10n.homeCompact).tag(true)
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
            .padding(.bottom, 24)
        }
        .onChange(of: previewCalm) { _, _ in Haptics.selection() }
        .onChange(of: previewCompact) { _, _ in Haptics.selection() }
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
            if previewCompact {
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
            } else {
                // Roomy: big greeting + hero + two pills + vehicle bar
                RoundedRectangle(cornerRadius: 4).fill(AppConfig.darkText.opacity(0.8)).frame(width: 84, height: 14)
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pHero).frame(height: 58)
                    .overlay(alignment: .leading) {
                        Text("75").font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(pAccent.opacity(0.9)).padding(.leading, 10)
                    }
                HStack(spacing: 7) {
                    Capsule().fill(pCard).frame(height: 22)
                    Capsule().fill(pAccent).frame(height: 22)
                }
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pHero).frame(height: 30)
                    .overlay(alignment: .leading) {
                        Image(systemName: "car.side.fill").font(.caption)
                            .foregroundStyle(.white.opacity(0.8)).padding(.leading, 10)
                    }
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
        .animation(.motionStandard, value: previewCompact)
        .animation(.motionStandard, value: previewCalm)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
