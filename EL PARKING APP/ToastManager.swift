//
//  ToastManager.swift
//  EL PARKING APP
//
//  Global toast + offline banner system.
//  Inject via .environmentObject(ToastManager.shared) at the root.
//  Show toasts from anywhere: ToastManager.shared.show("Message", style: .error)

import SwiftUI
import Network
import Combine

// MARK: - Toast Model

enum ToastStyle {
    case success, error, warning, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var color: Color {
        if AppConfig.isCalmPalette {
            switch self {
            case .success: return Color(red: 0.42, green: 0.58, blue: 0.47)   // sage
            case .error:   return Color(red: 0.75, green: 0.44, blue: 0.31)   // clay
            case .warning: return Color(red: 0.79, green: 0.61, blue: 0.31)   // ochre
            case .info:    return Color(red: 0.40, green: 0.50, blue: 0.58)   // fog
            }
        }
        switch self {
        case .success: return Color(red: 0.2,  green: 0.78, blue: 0.35)
        case .error:   return Color(red: 0.85, green: 0.2,  blue: 0.2)
        case .warning: return Color(red: 1.0,  green: 0.6,  blue: 0.0)
        case .info:    return Color(red: 0.4,  green: 0.6,  blue: 1.0)
        }
    }
}

struct Toast: Identifiable {
    let id = UUID()
    let message: String
    let style: ToastStyle
}

// MARK: - ToastManager

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var toasts:        [Toast] = []
    @Published var isOffline:     Bool    = false

    // Undo state
    @Published var undoMessage:   String? = nil
    @Published var undoCountdown: Int     = 5
    private var undoAction:       (() -> Void)?
    private var undoTask:         Task<Void, Never>?

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "NetworkMonitor")

    private init() {
        startNetworkMonitor()
    }

    // MARK: - Show Toast

    func show(_ message: String, style: ToastStyle = .info, duration: Double = 3.5) {
        let toast = Toast(message: message, style: style)
        switch style {
        case .success: Haptics.notify(.success)
        case .error:   Haptics.notify(.error)
        case .warning: Haptics.impact(.medium)
        case .info:    Haptics.selection()
        }
        withAnimation(.easeOut(duration: 0.28)) {
            toasts.append(toast)
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            dismiss(toast)
        }
    }

    func dismiss(_ toast: Toast) {
        withAnimation(.easeIn(duration: 0.22)) {
            toasts.removeAll { $0.id == toast.id }
        }
    }

    // MARK: - Undo Toast

    /// Shows a dismissible undo banner for `seconds` seconds.
    /// The caller provides the undo action; shake or tapping "Undo" calls it.
    func showUndo(message: String, seconds: Int = 5, action: @escaping () -> Void) {
        undoTask?.cancel()
        undoAction   = action
        undoCountdown = seconds
        withAnimation(.easeOut(duration: 0.28)) { undoMessage = message }
        Haptics.impact(.medium)

        undoTask = Task {
            for remaining in stride(from: seconds - 1, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                undoCountdown = remaining
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.22)) { undoMessage = nil }
            undoAction = nil
        }
    }

    func performUndo() {
        undoTask?.cancel()
        undoAction?()
        Haptics.notify(.success)
        withAnimation(.easeIn(duration: 0.22)) { undoMessage = nil }
        undoAction = nil
        NotificationCenter.default.post(name: .cancelOverlayDismiss, object: nil)
    }

    func dismissUndo() {
        undoTask?.cancel()
        withAnimation(.easeIn(duration: 0.22)) { undoMessage = nil }
        undoAction = nil
        NotificationCenter.default.post(name: .cancelOverlayDismiss, object: nil)
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let offline = path.status != .satisfied
                withAnimation(.spring(response: 0.4)) {
                    self?.isOffline = offline
                }
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: - Toast Overlay View

struct ToastOverlay: View {
    @ObservedObject var manager: ToastManager

    @State private var bannerPulse: Double = 0.72
    @State private var showBackOnline = false

    var body: some View {
        VStack(spacing: 0) {
            // Offline banner (top) — breathes while disconnected
            if manager.isOffline {
                offlineBanner
                    .opacity(bannerPulse)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                            bannerPulse = 1.0
                        }
                    }
                    .onDisappear { bannerPulse = 0.72 }
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showBackOnline {
                backOnlinePill
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            // Toast stack (bottom) — glass shapes share one container so
            // adjacent toasts blend correctly while animating in/out.
            GlassEffectContainer {
                VStack(spacing: 8) {
                    // Undo banner (appears above regular toasts)
                    if let msg = manager.undoMessage {
                        undoBanner(message: msg, countdown: manager.undoCountdown)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                    ForEach(manager.toasts) { toast in
                        toastCard(toast)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // above tab bar
        }
        .ignoresSafeArea(edges: .top)
        .animation(.easeOut(duration: 0.28), value: manager.isOffline)
        .animation(.easeOut(duration: 0.28), value: manager.toasts.count)
        .animation(.easeOut(duration: 0.28), value: showBackOnline)
        .onChange(of: manager.isOffline) { _, nowOffline in
            if !nowOffline {
                withAnimation(.easeOut(duration: 0.28)) { showBackOnline = true }
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation(.easeIn(duration: 0.22)) { showBackOnline = false }
                }
            }
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.footnote.weight(.bold))
            Text("No internet connection")
                .font(.footnote.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.85, green: 0.35, blue: 0.0))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Back Online Pill

    private var backOnlinePill: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppConfig.activeGreen)
            Text("Back online")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(AppConfig.activeGreen.opacity(0.25)), in: Capsule())
        .padding(.top, 60)
    }

    // MARK: - Undo Banner

    private func undoBanner(message: String, countdown: Int) -> some View {
        VStack(spacing: 12) {
            // Top row: icon + message + countdown ring
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppConfig.activeGreen)

                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.15), lineWidth: 2.5)
                        .frame(width: 30, height: 30)
                    Circle()
                        .trim(from: 0, to: CGFloat(countdown) / 5)
                        .stroke(AppConfig.activeGreen, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: countdown)
                    Text("\(countdown)")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }

            // Bottom row: Done + Undo buttons
            HStack(spacing: 10) {
                Button {
                    manager.dismissUndo()
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    manager.performUndo()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline.weight(.bold))
                        Text("Undo")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(Color(red: 19/255, green: 31/255, blue: 0/255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppConfig.activeGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .glassEffect(
            .regular.tint(AppConfig.activeGreen.opacity(0.18)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: - Toast Card

    private func toastCard(_ toast: Toast) -> some View {
        ToastCardView(toast: toast, manager: manager)
    }
}

private struct ToastCardView: View {
    let toast: Toast
    let manager: ToastManager

    @State private var iconScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.style.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(toast.style.color)
                .scaleEffect(iconScale)
                .onAppear {
                    if toast.style == .success {
                        iconScale = 0.4
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                            iconScale = 1.0
                        }
                    }
                }

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button { manager.dismiss(toast) } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(
            .regular.tint(toast.style.color.opacity(0.18)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let deviceDidShake      = Notification.Name("deviceDidShake")
    static let triggerBookingSheet = Notification.Name("triggerBookingSheet")
    /// Posted when Done or Undo is tapped — tells CancelSuccessOverlay to fly away.
    static let cancelOverlayDismiss = Notification.Name("cancelOverlayDismiss")
}

// MARK: - View Modifier

struct ToastViewModifier: ViewModifier {
    @ObservedObject var manager = ToastManager.shared
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            ToastOverlay(manager: manager)
        }
    }
}

extension View {
    func withToastOverlay() -> some View {
        modifier(ToastViewModifier())
    }
}
