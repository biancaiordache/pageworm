import SwiftUI
import UIKit
import PagewormDesign

struct PaperScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.pwPaper.ignoresSafeArea()
            content
        }
    }
}

struct InkyBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(PagewormFont.rounded(.body))
            .foregroundStyle(Color.pwInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.pwCream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(Color.pwCream)
                    .frame(width: 14, height: 14)
                    .offset(y: 6)
            }
            .padding(.bottom, 8)
    }
}

struct InkButtonStyle: ButtonStyle {
    var prominent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PagewormFont.rounded(.headline, weight: .semibold))
            .foregroundStyle(prominent ? Color.pwCream : Color.pwInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(prominent ? Color.pwMoss : Color.pwCream, in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct ChoiceChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PagewormFont.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(selected ? Color.pwCream : Color.pwInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selected ? Color.pwMoss : Color.pwCream, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct HoldToConfirmButton: View {
    var title: String
    var subtitle: String
    var action: () -> Void
    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var finished = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.pwSage.opacity(0.45), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.pwMoss, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(finished ? "Signed" : "Hold")
                    .font(PagewormFont.rounded(.headline, weight: .bold))
                    .foregroundStyle(Color.pwInk)
            }
            .frame(width: 132, height: 132)
            .gesture(hold)
            Text(title)
                .font(PagewormFont.rounded(.headline, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(PagewormFont.rounded(.footnote))
                .foregroundStyle(Color.pwInkSoft)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Press and hold until the ring completes.")
        .accessibilityAddTraits(.isButton)
    }

    private var hold: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !holding, !finished else { return }
                holding = true
                withAnimation(.linear(duration: 1.25)) {
                    progress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    guard holding else { return }
                    finished = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    action()
                }
            }
            .onEnded { _ in
                guard !finished else { return }
                holding = false
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
    }
}

struct StepHeader: View {
    var index: Int
    var count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { step in
                Capsule()
                    .fill(step <= index ? Color.pwMoss : Color.pwSage.opacity(0.35))
                    .frame(height: 6)
            }
        }
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }
}

struct BookCover: View {
    var url: String?
    var title: String

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 54, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Color.pwSpine
            Text(String(title.prefix(1)))
                .font(PagewormFont.rounded(.title3, weight: .bold))
                .foregroundStyle(Color.pwCream)
        }
    }
}
