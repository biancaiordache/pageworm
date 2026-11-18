import DeviceActivity
import PagewormCore
import PagewormDesign
import SwiftUI

extension DeviceActivityReport.Context {
    static let weeklyScroll = Self(rawValue: ReportNames.weeklyScroll)
}

struct AppScroll: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var hours: Double
    var pages: Int
}

struct WeeklyScrollConfiguration: Hashable {
    var rows: [AppScroll]
    var totalPages: Int
}

struct WeeklyScrollReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .weeklyScroll
    let content: (WeeklyScrollConfiguration) -> WeeklyScrollReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> WeeklyScrollConfiguration {
        let pagesPerHour = AppGroupStore.load()?.pagesPerHour ?? ForecastMath.defaultPagesPerHour
        var totals: [String: TimeInterval] = [:]
        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                for await category in segment.categories {
                    for await application in category.applications {
                        let name = application.application.localizedDisplayName ?? "App"
                        totals[name, default: 0] += application.totalActivityDuration
                    }
                }
            }
        }
        let rows = totals
            .map { name, seconds in
                let hours = seconds / 3600
                return AppScroll(name: name, hours: hours, pages: ScrollToBooks.pages(hours: hours, pagesPerHour: pagesPerHour))
            }
            .sorted { $0.hours > $1.hours }
        return WeeklyScrollConfiguration(rows: rows, totalPages: rows.reduce(0) { $0 + $1.pages })
    }
}

struct WeeklyScrollReportView: View {
    var configuration: WeeklyScrollConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if configuration.rows.isEmpty {
                Text("No scroll to trade in yet.")
                    .font(PagewormFont.rounded(.body))
                    .foregroundStyle(Color.pwInkSoft)
            } else {
                ForEach(configuration.rows.prefix(4)) { row in
                    Text(ScrollToBooks.summary(appName: row.name, hours: row.hours, pagesPerHour: pagesPerHour(for: row)))
                        .font(PagewormFont.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.pwInk)
                }
                Text("\(configuration.totalPages) pages if those hours had been a book.")
                    .font(PagewormFont.rounded(.caption))
                    .foregroundStyle(Color.pwInkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }

    private func pagesPerHour(for row: AppScroll) -> Double {
        guard row.hours > 0 else { return ForecastMath.defaultPagesPerHour }
        return Double(row.pages) / row.hours
    }
}

@main
struct PagewormReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        WeeklyScrollReport { configuration in
            WeeklyScrollReportView(configuration: configuration)
        }
    }
}
