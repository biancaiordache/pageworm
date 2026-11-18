import DeviceActivity
import FamilyControls
import Foundation
import Observation
import PagewormCore
import SwiftData

@MainActor
@Observable
final class ScreenTimeManager {
    var status: AuthorizationStatus = .notDetermined
    var selection = FamilyActivitySelection()
    var schedule = BlockSchedule()
    var strictMode = false
    var unlockMinutes = UnlockPolicy.defaultWindowMinutes
    var unlockEndsAt: Date?
    var emergencyUsesThisWeek = 0
    var emergencyWeekOf: Date?
    var lastMessage: String?
    private var context: ModelContext?

    var isAuthorized: Bool { status == .approved }

    func attach(_ context: ModelContext) {
        self.context = context
        refreshStatus()
        let record = Store.block(context)
        if let shared = AppGroupStore.load(), shared.updatedAt >= record.updatedAt {
            schedule = shared.block.schedule
            strictMode = shared.block.strictMode
            unlockMinutes = shared.block.unlockWindowMinutes
            unlockEndsAt = shared.block.unlockEndsAt
            emergencyUsesThisWeek = shared.block.emergencyUsesThisWeek
            emergencyWeekOf = shared.block.emergencyWeekOf
            writeRecord(record)
        } else {
            schedule = record.schedule
            strictMode = record.strictMode
            unlockMinutes = record.unlockWindowMinutes
            unlockEndsAt = record.unlockEndsAt
            emergencyUsesThisWeek = record.emergencyUsesThisWeek
            emergencyWeekOf = record.emergencyWeekOf
        }
        selection = ShieldApplier.loadSelection()
        try? context.save()
        reconcile()
    }

    func refreshStatus() {
        status = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshStatus()
        } catch {
            refreshStatus()
            lastMessage = "Screen Time didn't grant access. You can keep setting up Pageworm and turn blocking on after Apple approves the Family Controls entitlement."
        }
    }

    func updateSelection(_ newSelection: FamilyActivitySelection, isPremium: Bool) -> String? {
        let fits = Access.selectionFitsFreeTier(
            applicationCount: newSelection.applicationTokens.count,
            categoryCount: newSelection.categoryTokens.count,
            webDomainCount: newSelection.webDomainTokens.count
        )
        if !isPremium && !fits {
            return "The free plan blocks one app. Pick a single app, or unlock Plus to block the rest."
        }
        selection = newSelection
        ShieldApplier.save(newSelection)
        persist()
        applyCurrentShields()
        return nil
    }

    func updateSchedule(_ newSchedule: BlockSchedule) -> String? {
        guard newSchedule.meetsDeviceActivityMinimum else {
            return "Apple needs the block to last at least 15 minutes."
        }
        schedule = newSchedule
        persist()
        startDailyMonitoring()
        return nil
    }

    func setStrictMode(_ enabled: Bool, isPremium: Bool) -> String? {
        if enabled && !Access.allows(.strictMode, isPremium: isPremium) {
            return "Strict mode is part of Pageworm Plus."
        }
        strictMode = enabled
        persist()
        return nil
    }

    func setUnlockMinutes(_ minutes: Int, isPremium: Bool) -> String? {
        if minutes != UnlockPolicy.defaultWindowMinutes && !Access.allows(.customUnlockWindow, isPremium: isPremium) {
            return "A custom unlock length is part of Pageworm Plus."
        }
        unlockMinutes = minutes
        persist()
        return nil
    }

    func grantEarnedUnlock(isPremium: Bool) {
        let policy = UnlockPolicy(
            windowMinutes: isPremium ? unlockMinutes : UnlockPolicy.defaultWindowMinutes,
            strictMode: strictMode
        )
        let ledger = UnlockEngine.grantEarned(now: Date(), policy: policy, ledger: currentLedger)
        unlockEndsAt = ledger.windowEndsAt
        persist()
        ShieldApplier.clear()
        startUnlockMonitoring()
        InkyNotifications.scheduleUnlockEnding(at: unlockEndsAt)
    }

    func redeemEmergency(isPremium: Bool) -> String? {
        guard Access.allows(.strictMode, isPremium: isPremium) else {
            return "Emergency unlocks are part of Pageworm Plus."
        }
        let policy = UnlockPolicy(windowMinutes: unlockMinutes, strictMode: strictMode)
        switch UnlockEngine.redeemEmergency(now: Date(), policy: policy, ledger: currentLedger, calendar: .current) {
        case .success(let ledger):
            unlockEndsAt = ledger.windowEndsAt
            emergencyUsesThisWeek = ledger.emergencyUsesThisWeek
            emergencyWeekOf = ledger.emergencyWeekOf
            persist()
            ShieldApplier.clear()
            startUnlockMonitoring()
            InkyNotifications.scheduleUnlockEnding(at: unlockEndsAt)
            return nil
        case .failure(.weeklyLimitReached):
            return "Inky already spent this week's emergency unlock."
        case .failure(.strictModeRequired):
            return "Turn on strict mode to use the emergency unlock."
        }
    }

    func reconcile() {
        if let end = unlockEndsAt, end <= Date() {
            unlockEndsAt = nil
            persist()
        }
        if let shared = AppGroupStore.load() {
            unlockEndsAt = shared.block.unlockEndsAt
            if let context {
                let record = Store.block(context)
                record.unlockEndsAt = unlockEndsAt
                record.updatedAt = Date()
            }
        }
        applyCurrentShields()
    }

    func emergencyRemaining(isPremium: Bool) -> Int {
        let policy = UnlockPolicy(windowMinutes: unlockMinutes, strictMode: strictMode && isPremium)
        return UnlockEngine.emergencyRemaining(now: Date(), policy: policy, ledger: currentLedger, calendar: .current)
    }

    private var currentLedger: UnlockLedger {
        UnlockLedger(
            windowEndsAt: unlockEndsAt,
            emergencyWeekOf: emergencyWeekOf,
            emergencyUsesThisWeek: emergencyUsesThisWeek
        )
    }

    private func persist() {
        if let context {
            writeRecord(Store.block(context))
            try? context.save()
        }
        let premium = AppGroupStore.load()?.block.isPremium ?? false
        AppGroupStore.update { state in
            state.block.schedule = schedule
            state.block.strictMode = strictMode
            state.block.unlockWindowMinutes = unlockMinutes
            state.block.unlockEndsAt = unlockEndsAt
            state.block.emergencyWeekOf = emergencyWeekOf
            state.block.emergencyUsesThisWeek = emergencyUsesThisWeek
            state.block.isPremium = premium
        }
    }

    private func writeRecord(_ record: BlockRecord) {
        record.schedule = schedule
        record.strictMode = strictMode
        record.unlockWindowMinutes = unlockMinutes
        record.unlockEndsAt = unlockEndsAt
        record.emergencyWeekOf = emergencyWeekOf
        record.emergencyUsesThisWeek = emergencyUsesThisWeek
        record.updatedAt = Date()
    }

    private func startDailyMonitoring() {
        let center = DeviceActivityCenter()
        let name = DeviceActivityName(rawValue: ActivityNames.dailyBlock)
        center.stopMonitoring([name])
        guard schedule.enabled, isAuthorized else {
            ShieldApplier.clear()
            return
        }
        let start = schedule.startMinutes == schedule.endMinutes
            ? DateComponents(hour: 0, minute: 0)
            : DateComponents(hour: schedule.startHour, minute: schedule.startMinute)
        let end = schedule.startMinutes == schedule.endMinutes
            ? DateComponents(hour: 23, minute: 59)
            : DateComponents(hour: schedule.endHour, minute: schedule.endMinute)
        let activity = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: true
        )
        do {
            try center.startMonitoring(name, during: activity)
            lastMessage = nil
        } catch {
            lastMessage = "Inky couldn't start the schedule. \(error.localizedDescription)"
        }
        applyCurrentShields()
    }

    private func startUnlockMonitoring() {
        guard let end = unlockEndsAt, isAuthorized else { return }
        let center = DeviceActivityCenter()
        let name = DeviceActivityName(rawValue: ActivityNames.unlockWindow)
        center.stopMonitoring([name])
        let calendar = Calendar.current
        let start = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let finish = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end)
        let activity = DeviceActivitySchedule(intervalStart: start, intervalEnd: finish, repeats: false)
        try? center.startMonitoring(name, during: activity)
    }

    private func applyCurrentShields() {
        if isAuthorized {
            ShieldApplier.applyIfNeeded()
        } else {
            ShieldApplier.clear()
        }
    }
}
