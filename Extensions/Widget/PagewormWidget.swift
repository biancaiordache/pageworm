import PagewormActivity
import PagewormCore
import PagewormDesign
import SwiftUI
import WidgetKit

struct WidgetEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
}

struct WidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), snapshot: .placeholder(isPremium: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetEntry(date: Date(), snapshot: AppGroupStore.load()?.widget ?? .placeholder(isPremium: false)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = WidgetEntry(date: Date(), snapshot: AppGroupStore.load()?.widget ?? .placeholder(isPremium: false))
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct PagewormWidgetView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.snapshot.isPremium {
            premium
        } else {
            locked
        }
    }

    private var premium: some View {
        HStack(spacing: 10) {
            InkyView(stage: entry.snapshot.stage, mood: entry.snapshot.mood, size: family == .systemSmall ? 64 : 84, animated: false)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.snapshot.streak)-day streak")
                    .font(PagewormFont.rounded(.headline, weight: .bold))
                    .foregroundStyle(Color.pwInk)
                if let title = entry.snapshot.bookTitle {
                    Text(title)
                        .font(PagewormFont.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Color.pwInkSoft)
                        .lineLimit(2)
                    if let page = entry.snapshot.currentPage, let total = entry.snapshot.totalPages {
                        Text("\(page)/\(total)")
                            .font(PagewormFont.rounded(.caption2, weight: .semibold))
                            .foregroundStyle(Color.pwMoss)
                    }
                } else {
                    Text("Pick a book")
                        .font(PagewormFont.rounded(.caption))
                        .foregroundStyle(Color.pwInkSoft)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var locked: some View {
        VStack(spacing: 6) {
            InkyView(stage: .sprout, mood: .sleepy, size: 56, animated: false)
            Text("Plus keeps Inky on your home screen")
                .font(PagewormFont.rounded(.caption2, weight: .semibold))
                .foregroundStyle(Color.pwInk)
                .multilineTextAlignment(.center)
        }
    }
}

struct PagewormHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PagewormHome", provider: WidgetProvider()) { entry in
            PagewormWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.pwPaper
                }
        }
        .configurationDisplayName("Inky")
        .description("Your streak and the book that's open.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            HStack(spacing: 12) {
                InkyView(mood: .happy, size: 44, animated: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.bookTitle)
                        .font(PagewormFont.rounded(.headline, weight: .bold))
                        .lineLimit(1)
                    Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                        .font(PagewormFont.rounded(.subheadline, weight: .semibold))
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .foregroundStyle(Color.pwInk)
            .activityBackgroundTint(Color.pwPaper)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    InkyView(mood: .happy, size: 36, animated: false)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.bookTitle)
                        .font(PagewormFont.rounded(.headline, weight: .semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .frame(width: 64)
                }
            } compactLeading: {
                InkyView(mood: .happy, size: 22, animated: false)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                InkyView(mood: .happy, size: 18, animated: false)
            }
        }
    }
}

@main
struct PagewormWidgets: WidgetBundle {
    var body: some Widget {
        PagewormHomeWidget()
        ReadingLiveActivity()
    }
}
