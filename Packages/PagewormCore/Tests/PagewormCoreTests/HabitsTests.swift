import XCTest
@testable import PagewormCore

final class HabitsTests: XCTestCase {
    private var calendar: Calendar { PagewormCalendar.utc() }

    private func day(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var parts = DateComponents()
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return calendar.date(from: parts)!
    }

    func testStreakCountsTodayAndBridgesOneMissPerWeek() {
        let today = day(2024, 1, 11) // Thursday
        let days: Set<Date> = [day(2024, 1, 11), day(2024, 1, 9), day(2024, 1, 8)]
        let streak = StreakCalculator.evaluate(readingDays: days, today: today, calendar: calendar, allowsFreeze: true)
        XCTAssertEqual(streak.currentStreak, 3)
        XCTAssertEqual(streak.frozenDays, [day(2024, 1, 10, 0)])
        XCTAssertTrue(streak.readToday)
        XCTAssertFalse(streak.atRisk)
        XCTAssertTrue(streak.freezeUsedThisWeek)
    }

    func testTwoMissesBreakEvenWithAFreeze() {
        let today = day(2024, 1, 11)
        let days: Set<Date> = [day(2024, 1, 8)]
        let streak = StreakCalculator.evaluate(readingDays: days, today: today, calendar: calendar, allowsFreeze: true)
        XCTAssertEqual(streak.currentStreak, 0)
        XCTAssertTrue(streak.frozenDays.isEmpty)
    }

    func testTodayDoesNotBurnTheFreeze() {
        let today = day(2024, 1, 11)
        let days: Set<Date> = [day(2024, 1, 10), day(2024, 1, 9)]
        let streak = StreakCalculator.evaluate(readingDays: days, today: today, calendar: calendar, allowsFreeze: true)
        XCTAssertEqual(streak.currentStreak, 2)
        XCTAssertTrue(streak.atRisk)
        XCTAssertTrue(streak.frozenDays.isEmpty)
        XCTAssertFalse(streak.readToday)
    }

    func testFreezeCanBeRefused() {
        let today = day(2024, 1, 11)
        let days: Set<Date> = [day(2024, 1, 11), day(2024, 1, 9)]
        let streak = StreakCalculator.evaluate(readingDays: days, today: today, calendar: calendar, allowsFreeze: false)
        XCTAssertEqual(streak.currentStreak, 1)
        XCTAssertTrue(streak.frozenDays.isEmpty)
    }

    func testEmptyHistory() {
        let streak = StreakCalculator.evaluate(readingDays: [], today: day(2024, 1, 11), calendar: calendar, allowsFreeze: true)
        XCTAssertEqual(streak.currentStreak, 0)
        XCTAssertFalse(streak.atRisk)
    }

    func testSeparateWeeksEachGetAFreeze() {
        let today = day(2024, 1, 17) // Wednesday
        let days: Set<Date> = [day(2024, 1, 17), day(2024, 1, 15), day(2024, 1, 14), day(2024, 1, 12)]
        let streak = StreakCalculator.evaluate(readingDays: days, today: today, calendar: calendar, allowsFreeze: true)
        XCTAssertEqual(streak.currentStreak, 4)
        XCTAssertEqual(streak.frozenDays.count, 2)
        XCTAssertTrue(streak.freezeUsedThisWeek)
    }

    func testUnlockWindowAndSessionGate() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let window = UnlockPolicy.makeWindow(from: start, minutes: 10, source: .readingSession)
        XCTAssertEqual(window.endsAt.timeIntervalSince(window.startsAt), 15 * 60, accuracy: 0.1)
        XCTAssertTrue(window.contains(start.addingTimeInterval(14 * 60)))
        XCTAssertFalse(window.contains(start.addingTimeInterval(15 * 60)))
        XCTAssertEqual(UnlockPolicy.normalizedMinutes(50), 45)

        let granted = try SessionMath.result(SessionDraft(
            startPage: 10,
            endPage: 20,
            startedAt: start,
            endedAt: start.addingTimeInterval(90)
        ))
        XCTAssertEqual(granted.pages, 10)
        XCTAssertEqual(granted.minutes, 1.5, accuracy: 0.001)
        XCTAssertEqual(granted.pagesPerHour ?? 0, 400, accuracy: 0.1)
        XCTAssertTrue(granted.grantsUnlock)

        let tooShort = try SessionMath.result(SessionDraft(
            startPage: 10,
            endPage: 10,
            startedAt: start,
            endedAt: start.addingTimeInterval(30)
        ))
        XCTAssertFalse(tooShort.grantsUnlock)
        XCTAssertNil(tooShort.pagesPerHour)

        XCTAssertThrowsError(try SessionMath.result(SessionDraft(
            startPage: 8, endPage: 3, startedAt: start, endedAt: start.addingTimeInterval(120)
        ))) { error in
            XCTAssertEqual(error as? SessionMath.Validation, .endBeforeStart)
        }
    }

    func testEmergencyUnlockIsWeekly() {
        let monday = day(2024, 1, 8, 9)
        let wednesday = day(2024, 1, 10, 9)
        let nextMonday = day(2024, 1, 15, 9)
        XCTAssertTrue(EmergencyUnlockPolicy.canRedeem(lastRedeemedAt: nil, now: monday, calendar: calendar))
        XCTAssertFalse(EmergencyUnlockPolicy.canRedeem(lastRedeemedAt: monday, now: wednesday, calendar: calendar))
        XCTAssertTrue(EmergencyUnlockPolicy.canRedeem(lastRedeemedAt: monday, now: nextMonday, calendar: calendar))
    }

    func testScheduleIncludesOvernightTailAndExcludesTheEndMinute() {
        let nights = BlockSchedule(enabled: true, startMinutes: 22 * 60, endMinutes: 7 * 60, weekdays: [2])
        XCTAssertTrue(nights.contains(day(2024, 1, 8, 23), calendar: calendar))
        XCTAssertTrue(nights.contains(day(2024, 1, 9, 6, 59), calendar: calendar))
        XCTAssertFalse(nights.contains(day(2024, 1, 9, 7), calendar: calendar))
        XCTAssertFalse(nights.contains(day(2024, 1, 9, 23), calendar: calendar))
        XCTAssertFalse(nights.contains(day(2024, 1, 7, 23), calendar: calendar))

        let work = BlockSchedule.workday
        XCTAssertTrue(work.contains(day(2024, 1, 8, 9), calendar: calendar))
        XCTAssertFalse(work.contains(day(2024, 1, 8, 17), calendar: calendar))
        XCTAssertFalse(work.contains(day(2024, 1, 7, 10), calendar: calendar))
        XCTAssertTrue(BlockSchedule.allDay.contains(day(2024, 1, 7, 0), calendar: calendar))
        XCTAssertFalse(BlockSchedule(enabled: false, startMinutes: 0, endMinutes: 100, weekdays: [1]).contains(day(2024, 1, 7, 1), calendar: calendar))
    }

    func testShieldBrainPrefersAnOpenUnlock() {
        let now = day(2024, 1, 8, 10)
        let unlock = UnlockWindow(startsAt: now.addingTimeInterval(-60), endsAt: now.addingTimeInterval(600), source: .readingSession)
        let decision = ShieldBrain.decide(
            now: now,
            blockingEnabled: true,
            schedule: .allDay,
            unlock: unlock,
            calendar: calendar
        )
        XCTAssertEqual(decision, .unlocked(until: unlock.endsAt))

        let blocked = ShieldBrain.decide(now: now, blockingEnabled: true, schedule: .allDay, unlock: nil, calendar: calendar)
        XCTAssertEqual(blocked, .blocked)

        let off = ShieldBrain.decide(now: now, blockingEnabled: false, schedule: .allDay, unlock: unlock, calendar: calendar)
        XCTAssertEqual(off, .inactive)
    }
}
