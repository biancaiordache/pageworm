import XCTest
@testable import PagewormCore

final class StreakUnlockTests: XCTestCase {
    func testWeekStartsOnMonday() {
        let calendar = utcCalendar()
        XCTAssertEqual(StreakEngine.weekStart(date(2024, 1, 4, calendar: calendar), calendar: calendar), date(2024, 1, 1, calendar: calendar))
        XCTAssertEqual(StreakEngine.weekStart(date(2024, 1, 1, 23, calendar: calendar), calendar: calendar), date(2024, 1, 1, calendar: calendar))
    }

    func testStreakGrowsFreezesOnceAndBreaks() {
        let calendar = utcCalendar()
        var state = StreakState()
        state = StreakEngine.registerReading(on: date(2024, 1, 1, 9, calendar: calendar), state: state, allowFreeze: true, calendar: calendar)
        state = StreakEngine.registerReading(on: date(2024, 1, 2, 9, calendar: calendar), state: state, allowFreeze: true, calendar: calendar)
        state = StreakEngine.registerReading(on: date(2024, 1, 3, 9, calendar: calendar), state: state, allowFreeze: true, calendar: calendar)
        XCTAssertEqual(state.currentStreak, 3)
        XCTAssertEqual(StreakEngine.health(state: state, today: date(2024, 1, 3, 21, calendar: calendar), allowFreeze: true, calendar: calendar), .active(days: 3))

        let bridged = StreakEngine.reconcile(state: state, today: date(2024, 1, 5, 8, calendar: calendar), allowFreeze: true, calendar: calendar)
        XCTAssertEqual(bridged.currentStreak, 3)
        XCTAssertEqual(bridged.lastQualifiedDay, date(2024, 1, 4, calendar: calendar))
        XCTAssertEqual(bridged.lastFreezeCoveredDay, date(2024, 1, 4, calendar: calendar))
        XCTAssertEqual(StreakEngine.health(state: state, today: date(2024, 1, 5, 8, calendar: calendar), allowFreeze: true, calendar: calendar), .savedByFreeze(days: 3))

        state = StreakEngine.registerReading(on: date(2024, 1, 5, 9, calendar: calendar), state: state, allowFreeze: true, calendar: calendar)
        XCTAssertEqual(state.currentStreak, 4)

        let broken = StreakEngine.reconcile(state: state, today: date(2024, 1, 7, calendar: calendar), allowFreeze: true, calendar: calendar)
        XCTAssertEqual(broken.currentStreak, 0)
        XCTAssertEqual(StreakEngine.health(state: state, today: date(2024, 1, 7, calendar: calendar), allowFreeze: true, calendar: calendar), .broken)

        state = StreakEngine.registerReading(on: date(2024, 1, 7, calendar: calendar), state: state, allowFreeze: true, calendar: calendar)
        XCTAssertEqual(state.currentStreak, 1)
        XCTAssertEqual(state.longestStreak, 4)
    }

    func testReadingTwiceOnTheSameDayDoesNotDoubleCount() {
        let calendar = utcCalendar()
        var state = StreakEngine.registerReading(on: date(2024, 2, 1, 8, calendar: calendar), state: StreakState(), allowFreeze: false, calendar: calendar)
        state = StreakEngine.registerReading(on: date(2024, 2, 1, 22, calendar: calendar), state: state, allowFreeze: false, calendar: calendar)
        XCTAssertEqual(state.currentStreak, 1)
    }

    func testFreezeDoesNotApplyWhenPremiumIsOff() {
        let calendar = utcCalendar()
        var state = StreakEngine.registerReading(on: date(2024, 1, 1, calendar: calendar), state: StreakState(), allowFreeze: false, calendar: calendar)
        state = StreakEngine.reconcile(state: state, today: date(2024, 1, 3, calendar: calendar), allowFreeze: false, calendar: calendar)
        XCTAssertEqual(state.currentStreak, 0)
        XCTAssertNil(state.lastFreezeCoveredDay)
    }

    func testAtRiskBeforeEvening() {
        let calendar = utcCalendar()
        let state = StreakEngine.registerReading(on: date(2024, 1, 1, calendar: calendar), state: StreakState(), allowFreeze: true, calendar: calendar)
        XCTAssertEqual(StreakEngine.health(state: state, today: date(2024, 1, 2, 12, calendar: calendar), allowFreeze: true, calendar: calendar), .atRisk(days: 1))
    }

    func testUnlockWindowAndEmergencyQuota() throws {
        let calendar = utcCalendar()
        let policy = UnlockPolicy(windowMinutes: 10, strictMode: true)
        XCTAssertEqual(policy.effectiveWindowMinutes, 15)
        var ledger = UnlockLedger()
        let now = date(2024, 1, 1, 12, calendar: calendar)
        ledger = UnlockEngine.grantEarned(now: now, policy: policy, ledger: ledger)
        XCTAssertEqual(ledger.windowEndsAt, now.addingTimeInterval(15 * 60))
        XCTAssertTrue(UnlockEngine.isUnlocked(now: now.addingTimeInterval(14 * 60), ledger: ledger))
        XCTAssertFalse(UnlockEngine.isUnlocked(now: now.addingTimeInterval(15 * 60), ledger: ledger))
        ledger = UnlockEngine.snapBack(now: now.addingTimeInterval(15 * 60), ledger: ledger)
        XCTAssertNil(ledger.windowEndsAt)

        let first = UnlockEngine.redeemEmergency(now: now, policy: policy, ledger: UnlockLedger(), calendar: calendar)
        let granted = try XCTUnwrap(first.get())
        XCTAssertEqual(granted.emergencyUsesThisWeek, 1)
        XCTAssertNotNil(granted.windowEndsAt)

        let second = UnlockEngine.redeemEmergency(now: now.addingTimeInterval(3600), policy: policy, ledger: granted, calendar: calendar)
        XCTAssertEqual(second, .failure(.weeklyLimitReached))

        let nextWeek = date(2024, 1, 8, 9, calendar: calendar)
        let third = UnlockEngine.redeemEmergency(now: nextWeek, policy: policy, ledger: granted, calendar: calendar)
        XCTAssertEqual(try third.get().emergencyUsesThisWeek, 1)

        let soft = UnlockPolicy(windowMinutes: 15, strictMode: false)
        XCTAssertEqual(
            UnlockEngine.redeemEmergency(now: now, policy: soft, ledger: UnlockLedger(), calendar: calendar),
            .failure(.strictModeRequired)
        )
    }

    func testShieldFollowsScheduleAndUnlock() {
        let calendar = utcCalendar()
        let schedule = BlockSchedule(enabled: true, startHour: 9, startMinute: 0, endHour: 21, endMinute: 0)
        let noon = date(2024, 5, 1, 12, calendar: calendar)
        let late = date(2024, 5, 1, 22, calendar: calendar)
        XCTAssertEqual(ShieldPolicy.decision(now: noon, schedule: schedule, unlockEndsAt: nil, calendar: calendar), .shield)
        XCTAssertEqual(ShieldPolicy.decision(now: late, schedule: schedule, unlockEndsAt: nil, calendar: calendar), .clear)
        let unlock = noon.addingTimeInterval(15 * 60)
        XCTAssertEqual(ShieldPolicy.decision(now: noon.addingTimeInterval(60), schedule: schedule, unlockEndsAt: unlock, calendar: calendar), .clear)
        XCTAssertEqual(ShieldPolicy.decision(now: unlock, schedule: schedule, unlockEndsAt: unlock, calendar: calendar), .shield)

        let overnight = BlockSchedule(enabled: true, startHour: 22, startMinute: 0, endHour: 7, endMinute: 0)
        XCTAssertTrue(overnight.contains(date(2024, 5, 1, 23, calendar: calendar), calendar: calendar))
        XCTAssertTrue(overnight.contains(date(2024, 5, 1, 6, calendar: calendar), calendar: calendar))
        XCTAssertFalse(overnight.contains(date(2024, 5, 1, 12, calendar: calendar), calendar: calendar))
        XCTAssertFalse(BlockSchedule(enabled: false, startHour: 0, startMinute: 0, endHour: 23, endMinute: 59).contains(noon, calendar: calendar))
        XCTAssertFalse(BlockSchedule(enabled: true, startHour: 9, startMinute: 0, endHour: 9, endMinute: 10).meetsDeviceActivityMinimum)
        XCTAssertTrue(BlockSchedule.allDay.meetsDeviceActivityMinimum)
        XCTAssertEqual(BlockSchedule(enabled: true, startHour: 9, startMinute: 0, endHour: 9, endMinute: 0).intervalMinutes, 24 * 60)
    }
}
