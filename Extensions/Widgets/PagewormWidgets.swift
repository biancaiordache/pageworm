import PagewormCore
import SwiftUI
import WidgetKit

struct PagewormEntry: TimelineEntry {
    var date: Date
    var snapshot: ShieldSnapshot
    var session: ActiveSessionState?
}

struct PagewormProvider: TimelineProvider {
    func placeholder(in context: Context) -> PagewormEntry {
        PagewormEntry(date: Date(), snapshot: .placeholder(), session: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PagewormEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PagewormEntry>) -> Void) {
        let entry = load()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }

    private func load() -> PagewormEntry {
        let defaults = AppGroupDefaults.suite()
        return PagewormEntry(
            date: Date(),
            snapshot: SharedStore.snapshot(in: defaults),
            session: SharedStore.activeSession(in: defaults)
        )
    }
}

struct PagewormHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PagewormInky", provider: PagewormProvider()) { entry in
            PagewormWidgetView(entry: entry)
                .containerBackground(Theme.cream, for: .widget)
        }
        .configurationDisplayName("Inky")
        .description("Your streak and the book you're reading.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PagewormWidgetView: View {
    var entry: PagewormEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.snapshot.isPremium {
            HStack(spacing: 8) {
                InkyView(stage: entry.snapshot.inkyStage, mood: entry.snapshot.inkyMood, size: family == .systemSmall ? 78 : 100)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.snapshot.streak)-day streak")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(caption)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                InkyView(stage: .bookling, mood: .sleepy, size: 68)
                Text("Plus keeps Inky on your Home Screen.")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var caption: String {
        if let session = entry.session {
            return "Reading \(session.bookTitle)"
        }
        return entry.snapshot.bookTitle.isEmpty ? "Pick up a book" : entry.snapshot.bookTitle
    }
}

struct ReadingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            HStack(spacing: 12) {
                InkyView(
                    stage: InkyStage(rawValue: context.state.stageRaw) ?? .bookling,
                    mood: InkyMood(rawValue: context.state.moodRaw) ?? .happy,
                    size: 58
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.bookTitle)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .lineLimit(1)
                    Text(timerInterval: context.state.startedAt...Date().addingTimeInterval(8 * 60 * 60), countsDown: false)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
            .activityBackgroundTint(Theme.cream)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    InkyView(
                        stage: InkyStage(rawValue: context.state.stageRaw) ?? .bookling,
                        mood: InkyMood(rawValue: context.state.moodRaw) ?? .happy,
                        size: 36
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("p. \(context.state.startPage)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.bookTitle)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
            } compactLeading: {
                Image(systemName: "book.closed")
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...Date().addingTimeInterval(8 * 60 * 60), countsDown: false)
                    .monospacedDigit()
                    .frame(width: 52)
            } minimal: {
                Image(systemName: "book.closed")
            }
        }
    }
}

@main
struct PagewormWidgetBundle: WidgetBundle {
    var body: some Widget {
        PagewormHomeWidget()
        ReadingLiveActivityWidget()
    }
}
