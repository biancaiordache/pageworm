import SwiftUI
import UIKit

enum Theme {
    static let cream = dynamic(light: (0.965, 0.941, 0.902), dark: (0.110, 0.090, 0.082))
    static let paper = dynamic(light: (0.992, 0.976, 0.953), dark: (0.165, 0.135, 0.122))
    static let ink = dynamic(light: (0.173, 0.141, 0.125), dark: (0.965, 0.933, 0.886))
    static let inkSoft = dynamic(light: (0.420, 0.349, 0.310), dark: (0.780, 0.722, 0.655))
    static let blush = dynamic(light: (0.906, 0.718, 0.647), dark: (0.620, 0.420, 0.380))
    static let sage = dynamic(light: (0.561, 0.647, 0.541), dark: (0.455, 0.545, 0.435))
    static let gold = dynamic(light: (0.886, 0.714, 0.341), dark: (0.780, 0.620, 0.320))
    static let burgundy = dynamic(light: (0.486, 0.227, 0.290), dark: (0.835, 0.455, 0.510))
    static let spine = dynamic(light: (0.357, 0.227, 0.200), dark: (0.545, 0.365, 0.310))

    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

struct CozyBackground: View {
    var body: some View {
        ZStack {
            Theme.cream
            Circle()
                .fill(Theme.blush.opacity(0.45))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: 150, y: -280)
            Circle()
                .fill(Theme.sage.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: -160, y: 320)
        }
        .ignoresSafeArea()
    }
}

struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.burgundy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.rounded(.headline, weight: .semibold))
            .foregroundStyle(Theme.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.rounded(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.08 : 0.05), in: Capsule())
    }
}

struct ChoiceChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(selected ? Theme.paper : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selected ? Theme.burgundy : Theme.paper, in: Capsule())
                .overlay(Capsule().stroke(Theme.ink.opacity(selected ? 0 : 0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

