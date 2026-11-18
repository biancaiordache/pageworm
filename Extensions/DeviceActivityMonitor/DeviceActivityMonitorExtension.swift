import DeviceActivity
import PagewormCore

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity.rawValue {
        case ActivityNames.unlockWindow:
            ShieldApplier.clear()
        case ActivityNames.dailyBlock:
            ShieldApplier.applyIfNeeded()
        default:
            break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        switch activity.rawValue {
        case ActivityNames.unlockWindow:
            ShieldApplier.endUnlockIfExpired()
        case ActivityNames.dailyBlock:
            ShieldApplier.clear()
        default:
            break
        }
    }
}
