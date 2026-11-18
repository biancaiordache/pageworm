import DeviceActivity
import PagewormCore
import SwiftUI

struct WeeklyScrollConfiguration {
    var duration: TimeInterval
    var sourceName: String
    var pagesPerHour: Double
}

struct WeeklyScrollReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: SharedKeys.reportContext)
    let content: (WeeklyScrollConfiguration) -> WeeklyScrollView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> WeeklyScrollConfiguration {
        var total: TimeInterval = 0
        for await item in data {
            for await segment in item.activitySegments {
                total += segment.totalActivityDuration
            }
        }
        let snapshot = SharedStore.snapshot(in: AppGroupDefaults.suite())
        return WeeklyScrollConfiguration(
            duration: total,
            sourceName: snapshot.focusAppName,
            pagesPerHour: snapshot.pagesPerHour
        )
    }
}

struct WeeklyScrollView: View {
    var configuration: WeeklyScrollConfiguration

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            InkyView(stage: .bookling, mood: .happy, size: 72)
            Text(
                ScrollConversion.summary(
                    duration: configuration.duration,
                    pagesPerHour: configuration.pagesPerHour,
                    sourceName: configuration.sourceName.isEmpty ? nil : configuration.sourceName
                )
            )
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Color(red: 0.173, green: 0.141, blue: 0.125))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(red: 0.992, green: 0.976, blue: 0.953))
    }
}

@main
struct PagewormReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        WeeklyScrollReport { configuration in
            WeeklyScrollView(configuration: configuration)
        }
    }
}
