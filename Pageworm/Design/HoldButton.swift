import SwiftUI
import UIKit

struct HoldButton: View {
    var title: String
    var hint: String
    var duration: TimeInterval = 1.35
    var action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Capsule()
                    .stroke(Theme.burgundy.opacity(0.18), lineWidth: 10)
                Capsule()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.burgundy, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(progress >= 1 ? "Signed" : title)
                    .font(Theme.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(height: 68)
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !holding { start() }
                    }
                    .onEnded { _ in release() }
            )
            .accessibilityLabel(title)
            .accessibilityHint(hint)
            .accessibilityAction(.default) {
                progress = 1
                action()
            }
            Text(hint)
                .font(Theme.rounded(.caption))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
    }

    private func start() {
        holding = true
        let began = Date()
        withAnimation(reduceMotion ? nil : .linear(duration: duration)) {
            progress = 1
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard holding, Date().timeIntervalSince(began) >= duration - 0.05 else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        }
    }

    private func release() {
        guard progress < 1 else { return }
        holding = false
        withAnimation(.easeOut(duration: 0.2)) {
            progress = 0
        }
    }
}
