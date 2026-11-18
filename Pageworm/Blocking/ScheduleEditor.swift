import PagewormCore
import SwiftUI

struct ScheduleEditor: View {
    @Binding var schedule: BlockSchedule

    private let presets: [(String, BlockSchedule)] = [
        ("All day", .allDay),
        ("Mornings", .mornings),
        ("Workday", .workday),
        ("Evenings", .evenings)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { preset in
                        ChoiceChip(title: preset.0, selected: matches(preset.1)) {
                            schedule = preset.1
                        }
                    }
                }
            }
            HStack {
                timePicker("From", minutes: schedule.startMinutes) { schedule.startMinutes = $0 }
                timePicker("Until", minutes: displayedEnd) { schedule.endMinutes = $0 == 0 ? 24 * 60 : $0 }
            }
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    let on = schedule.weekdays.contains(weekday)
                    Button(short(weekday)) {
                        var days = schedule.weekdays
                        if on {
                            days.remove(weekday)
                        } else {
                            days.insert(weekday)
                        }
                        schedule.weekdays = days
                    }
                    .font(Theme.rounded(.caption, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(on ? Theme.burgundy : Theme.paper, in: Circle())
                    .foregroundStyle(on ? Theme.paper : Theme.ink)
                }
            }
            Text(schedule.crossesMidnight ? "This window continues past midnight." : "Outside these hours, the apps open on their own.")
                .font(Theme.rounded(.caption))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var displayedEnd: Int {
        schedule.endMinutes >= 24 * 60 ? 0 : schedule.endMinutes
    }

    private func matches(_ preset: BlockSchedule) -> Bool {
        schedule.startMinutes == preset.startMinutes
            && schedule.endMinutes == preset.endMinutes
            && schedule.weekdays == preset.weekdays
    }

    private func timePicker(_ title: String, minutes: Int, update: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.rounded(.caption, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            DatePicker(
                title,
                selection: Binding(
                    get: { date(from: minutes) },
                    set: { update(minutes(from: $0)) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func date(from minutes: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: (minutes / 60) % 24, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func minutes(from date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private func short(_ weekday: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][weekday - 1]
    }
}
