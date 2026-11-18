import DeviceActivity
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        ShieldRuntime.reevaluate()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        ShieldRuntime.reevaluate()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        ShieldRuntime.reevaluate()
    }
}
