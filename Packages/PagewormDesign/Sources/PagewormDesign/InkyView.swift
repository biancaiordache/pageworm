import SwiftUI
import PagewormCore

/// Placeholder Inky drawn with shapes. Swap this view for artwork later;
/// call sites only need stage, mood, and size.
public struct InkyView: View {
    public var stage: InkyStage
    public var mood: InkyMood
    public var size: CGFloat
    public var animated: Bool

    public init(stage: InkyStage = .sprout, mood: InkyMood = .happy, size: CGFloat = 180, animated: Bool = true) {
        self.stage = stage
        self.mood = mood
        self.size = size
        self.animated = animated
    }

    public var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    canvas(wobble: sin(context.date.timeIntervalSinceReferenceDate * 1.7))
                }
            } else {
                canvas(wobble: 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Inky, \(mood.title), \(stage.title)")
    }

    private func canvas(wobble: Double) -> some View {
        let bob = CGFloat(wobble) * size * 0.03
        return ZStack {
            worm(bob: bob)
            accessories(bob: bob)
        }
    }

    private func worm(bob: CGFloat) -> some View {
        ZStack {
            segment(0.30, 0.70, 0.30, bob: bob, phase: 0)
            segment(0.46, 0.64, 0.33, bob: bob, phase: 0.4)
            segment(0.62, 0.57, 0.36, bob: bob, phase: 0.8)
            head(bob: bob)
        }
    }

    private func segment(_ x: CGFloat, _ y: CGFloat, _ diameter: CGFloat, bob: CGFloat, phase: CGFloat) -> some View {
        let extra = bob * (0.4 + phase)
        return ZStack {
            Circle()
                .fill(Color.pwMoss)
                .frame(width: size * diameter, height: size * diameter * 0.86)
            Circle()
                .fill(Color.pwBelly)
                .frame(width: size * diameter * 0.62, height: size * diameter * 0.42)
                .offset(y: size * diameter * 0.12)
        }
        .position(x: size * x, y: size * y + extra)
    }

    private func head(bob: CGFloat) -> some View {
        let center = CGPoint(x: size * 0.70, y: size * 0.44 + bob)
        return ZStack {
            Circle()
                .fill(Color.pwSage)
                .frame(width: size * 0.40, height: size * 0.40)
            Circle()
                .fill(Color.pwBlush.opacity(0.9))
                .frame(width: size * 0.07, height: size * 0.045)
                .offset(x: -size * 0.09, y: size * 0.05)
            Circle()
                .fill(Color.pwBlush.opacity(0.9))
                .frame(width: size * 0.07, height: size * 0.045)
                .offset(x: size * 0.09, y: size * 0.05)
            eyes
            mouth
        }
        .position(center)
    }

    @ViewBuilder
    private var eyes: some View {
        switch mood {
        case .happy:
            HStack(spacing: size * 0.06) {
                eyeDot
                eyeDot
            }
            .offset(y: -size * 0.03)
        case .sleepy:
            HStack(spacing: size * 0.07) {
                Capsule().fill(Color.pwInk).frame(width: size * 0.07, height: size * 0.018)
                Capsule().fill(Color.pwInk).frame(width: size * 0.07, height: size * 0.018)
            }
            .offset(y: -size * 0.02)
        case .missingYou:
            HStack(spacing: size * 0.06) {
                eyeDot
                eyeDot
            }
            .offset(x: size * 0.01, y: size * 0.01)
        }
    }

    private var eyeDot: some View {
        ZStack {
            Circle().fill(Color.pwInk).frame(width: size * 0.055, height: size * 0.055)
            Circle().fill(Color.white.opacity(0.85)).frame(width: size * 0.018, height: size * 0.018)
                .offset(x: -size * 0.008, y: -size * 0.008)
        }
    }

    private var mouth: some View {
        Smile(frown: mood == .missingYou)
            .stroke(Color.pwInk, style: StrokeStyle(lineWidth: max(1.5, size * 0.018), lineCap: .round))
            .frame(width: size * 0.10, height: size * 0.05)
            .offset(y: size * 0.06)
    }

    @ViewBuilder
    private func accessories(bob: CGFloat) -> some View {
        if stage == .sprout {
            sprout.position(x: size * 0.70, y: size * 0.24 + bob)
        }
        if stage.rawValue >= InkyStage.bookworm.rawValue {
            book.position(x: size * 0.40, y: size * 0.78 + bob * 0.4)
        }
        if stage == .pageEater {
            Capsule()
                .fill(Color.pwSpine)
                .frame(width: size * 0.28, height: size * 0.07)
                .rotationEffect(.degrees(-18))
                .position(x: size * 0.62, y: size * 0.58 + bob)
        }
        if stage.rawValue >= InkyStage.scholar.rawValue {
            glasses.position(x: size * 0.70, y: size * 0.41 + bob)
        }
        if stage == .legend {
            crown.position(x: size * 0.70, y: size * 0.20 + bob)
        }
    }

    private var sprout: some View {
        ZStack {
            Capsule()
                .fill(Color.pwMoss)
                .frame(width: size * 0.025, height: size * 0.08)
            Ellipse()
                .fill(Color.pwSage)
                .frame(width: size * 0.09, height: size * 0.05)
                .rotationEffect(.degrees(-30))
                .offset(x: size * 0.03, y: -size * 0.03)
        }
    }

    private var book: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
                .fill(Color.pwSpine)
                .frame(width: size * 0.22, height: size * 0.16)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.pwGold)
                .frame(width: size * 0.012, height: size * 0.16)
            VStack(alignment: .leading, spacing: size * 0.012) {
                Capsule().fill(Color.pwCream.opacity(0.8)).frame(width: size * 0.10, height: size * 0.012)
                Capsule().fill(Color.pwCream.opacity(0.55)).frame(width: size * 0.07, height: size * 0.01)
            }
            .padding(.leading, size * 0.04)
        }
    }

    private var glasses: some View {
        HStack(spacing: size * 0.01) {
            Circle().stroke(Color.pwInk, lineWidth: max(1.2, size * 0.012))
                .frame(width: size * 0.09, height: size * 0.09)
            Circle().stroke(Color.pwInk, lineWidth: max(1.2, size * 0.012))
                .frame(width: size * 0.09, height: size * 0.09)
        }
    }

    private var crown: some View {
        Crown()
            .fill(Color.pwGold)
            .frame(width: size * 0.16, height: size * 0.08)
    }
}

private struct Smile: Shape {
    var frown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if frown {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY))
        }
        return path
    }
}

private struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.25, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
