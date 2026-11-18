import PagewormCore
import SwiftUI

struct WrapCardView: View {
    var name: String
    var stage: InkyStage
    var mood: InkyMood
    var streak: Int
    var pages: Int
    var minutes: Int
    var bookTitle: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.cream, Theme.blush.opacity(0.55), Theme.sage.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 18) {
                Text("PAGEWORM")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Theme.burgundy)
                InkyView(stage: stage, mood: mood, size: 180)
                Text(name.isEmpty ? "A reading week" : "\(name)'s week")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                VStack(spacing: 6) {
                    Text("\(streak) day streak")
                    Text("\(pages) pages · \(minutes) minutes")
                    if !bookTitle.isEmpty {
                        Text(bookTitle)
                    }
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                Spacer()
                Text("Read to unlock.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(36)
        }
        .frame(width: 360, height: 640)
    }
}

enum WrapRenderer {
    @MainActor
    static func png(progress: ReadingProgress, name: String) -> URL? {
        let card = WrapCardView(
            name: name,
            stage: progress.stage,
            mood: progress.mood,
            streak: progress.streak.currentStreak,
            pages: progress.weekPages,
            minutes: progress.weekMinutes,
            bookTitle: progress.currentBook?.title ?? ""
        )
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(width: 360, height: 640)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pageworm-wrap-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
