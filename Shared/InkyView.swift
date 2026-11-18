import SwiftUI
import PagewormCore

/// Placeholder Inky, drawn with shapes so a later illustration can replace this view in one place.
/// Swap the body of `InkyView` for an image asset named `Inky` without touching call sites.
struct InkyView: View {
    var stage: InkyStage
    var mood: InkyMood
    var size: CGFloat = 180

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bobbing = false

    var body: some View {
        ZStack {
            if stage >= .libraryLegend {
                laurels
            }
            bookmark
            segments
            head
            if stage >= .chapterChomper {
                glasses
            }
            if stage >= .novelNommer {
                heldBook
            }
            if mood == .sleepy {
                sleepMark
            }
            if mood == .cheering {
                spark
            }
        }
        .frame(width: size, height: size * 0.92)
        .offset(y: bobbing && !reduceMotion ? -size * 0.025 : size * 0.02)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: mood == .sleepy ? 2.2 : 1.5).repeatForever(autoreverses: true),
            value: bobbing
        )
        .onAppear { bobbing = true }
        .accessibilityLabel("Inky, \(stage.displayName), feeling \(mood.label)")
    }

    private var segmentCount: Int {
        switch stage {
        case .bookling: 3
        case .pageNibbler, .chapterChomper: 4
        case .novelNommer, .libraryLegend: 5
        }
    }

    private var bodyColor: Color {
        stage >= .libraryLegend ? Theme.gold : Theme.sage
    }

    private var segments: some View {
        HStack(spacing: -size * 0.07) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Circle()
                    .fill(bodyColor)
                    .frame(width: size * (index == segmentCount - 1 ? 0.34 : 0.26), height: size * (index == segmentCount - 1 ? 0.34 : 0.26))
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(Theme.paper.opacity(0.85))
                            .frame(width: size * 0.12, height: size * 0.08)
                            .offset(y: -size * 0.04)
                    }
            }
        }
        .offset(y: size * 0.08)
    }

    private var head: some View {
        let headSize = size * 0.4
        return ZStack {
            Circle()
                .fill(bodyColor)
                .frame(width: headSize, height: headSize)
            eyes
                .offset(y: -headSize * 0.08)
            cheeks
            smile
                .offset(y: headSize * 0.18)
            if mood == .missingYou {
                Circle()
                    .fill(Theme.blush)
                    .frame(width: size * 0.035, height: size * 0.05)
                    .offset(x: size * 0.09, y: size * 0.02)
            }
        }
        .offset(x: size * 0.22, y: -size * 0.08)
    }

    private var eyes: some View {
        HStack(spacing: size * 0.07) {
            eye
            eye
        }
    }

    private var eye: some View {
        Group {
            if mood == .sleepy {
                Capsule()
                    .fill(Theme.ink)
                    .frame(width: size * 0.055, height: size * 0.02)
                    .rotationEffect(.degrees(12))
            } else {
                Circle()
                    .fill(Theme.ink)
                    .frame(width: size * 0.045, height: size * 0.045)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Theme.paper)
                            .frame(width: size * 0.016, height: size * 0.016)
                    }
            }
        }
    }

    private var cheeks: some View {
        HStack(spacing: size * 0.12) {
            Circle().fill(Theme.blush.opacity(0.85)).frame(width: size * 0.05, height: size * 0.035)
            Circle().fill(Theme.blush.opacity(0.85)).frame(width: size * 0.05, height: size * 0.035)
        }
        .offset(y: size * 0.035)
    }

    private var smile: some View {
        Circle()
            .trim(from: 0.15, to: 0.35)
            .stroke(Theme.ink, style: StrokeStyle(lineWidth: max(1.5, size * 0.012), lineCap: .round))
            .frame(width: size * 0.09, height: size * 0.09)
            .rotationEffect(.degrees(180))
    }

    private var glasses: some View {
        HStack(spacing: size * 0.01) {
            Circle().stroke(Theme.ink, lineWidth: max(1.5, size * 0.012)).frame(width: size * 0.09, height: size * 0.09)
            Circle().stroke(Theme.ink, lineWidth: max(1.5, size * 0.012)).frame(width: size * 0.09, height: size * 0.09)
        }
        .offset(x: size * 0.22, y: -size * 0.11)
    }

    private var bookmark: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Theme.burgundy)
            .frame(width: size * 0.07, height: size * 0.2)
            .overlay(alignment: .bottom) {
                Triangle()
                    .fill(Theme.burgundy)
                    .frame(width: size * 0.07, height: size * 0.05)
                    .offset(y: size * 0.04)
            }
            .rotationEffect(.degrees(-18))
            .offset(x: -size * 0.34, y: size * 0.02)
            .opacity(stage == .bookling ? 0 : 1)
    }

    private var heldBook: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Theme.paper)
            .frame(width: size * 0.16, height: size * 0.12)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Theme.ink.opacity(0.3), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.burgundy).frame(width: 3)
            }
            .rotationEffect(.degrees(-12))
            .offset(x: size * 0.34, y: size * 0.16)
    }

    private var laurels: some View {
        HStack(spacing: size * 0.28) {
            Capsule().fill(Theme.gold).frame(width: size * 0.04, height: size * 0.16).rotationEffect(.degrees(28))
            Capsule().fill(Theme.gold).frame(width: size * 0.04, height: size * 0.16).rotationEffect(.degrees(-28))
        }
        .offset(y: -size * 0.34)
    }

    private var sleepMark: some View {
        Text("z")
            .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.inkSoft)
            .offset(x: size * 0.38, y: -size * 0.28)
    }

    private var spark: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size * 0.12, weight: .bold))
            .foregroundStyle(Theme.gold)
            .offset(x: -size * 0.28, y: -size * 0.28)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
