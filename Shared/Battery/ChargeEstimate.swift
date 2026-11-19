import Foundation

/// How long until the charge reaches where Chargectl is taking it: the limit while charging to
/// it, the lower bound while sailing down, the target of a discharge, or empty on battery.
nonisolated struct ChargeEstimate: Equatable, Sendable {
    /// Nil when there is no time to show, such as while holding.
    var minutes: Int?
    /// The big figure when there is no time: String(localized: "Holding"), String(localized: "Full"), String(localized: "Paused").
    var headline: String?
    /// What the figure means: "until 70%", String(localized: "until empty at this rate"), "at 70% on the charger".
    var caption: String

    /// Below this many amps the battery counts as idle.
    static let idleCurrent = 0.05

    /// - Parameters:
    ///   - activity: what the helper is doing, or nil when it is not running.
    ///   - current: A, positive while charging; pass a smoothed value so the time does not jump.
    static func make(battery: BatterySnapshot, activity: ChargeActivity?, current: Double) -> ChargeEstimate {
        let charging = current > idleCurrent
        let draining = current < -idleCurrent
        switch activity {
        case .charging(let target)?:
            return toward(
                target, battery: battery, current: current, moving: charging, verb: String(localized: "Charging"))
        case .toppingUp?, .calibrating(.charging)?, .chargingFull?:
            return toward(
                100, battery: battery, current: current, moving: charging, verb: String(localized: "Charging"))
        case .aboveLimit(let target)?, .discharging(let target)?, .stoppedOvercharge(let target)?:
            return toward(
                target, battery: battery, current: current, moving: draining, verb: String(localized: "Discharging"))
        case .sailing(let limit, let lowerBound)?:
            if limit == lowerBound {
                return ChargeEstimate(
                    headline: String(localized: "Holding"), caption: String(localized: "at \(limit)%"))
            }
            return toward(
                lowerBound, battery: battery, current: current, moving: draining, verb: String(localized: "Sailing"))
        case .calibrating(.draining)?:
            return toward(
                ChargePolicy.calibrationFloor, battery: battery, current: current, moving: draining,
                verb: String(localized: "Discharging"))
        case .holding(let level)?, .holdingAbove(let level)?:
            return ChargeEstimate(
                headline: String(localized: "Holding"), caption: String(localized: "at \(level)% on the charger"))
        case .sailingHold(_, let resumeAt)?:
            return ChargeEstimate(
                headline: String(localized: "Sailing"),
                caption: String(localized: "on the charger; charges again at \(resumeAt)%"))
        case .calibrating(.holding)?:
            return ChargeEstimate(
                headline: String(localized: "Resting"), caption: String(localized: "at 100% for an hour"))
        case .full?:
            return ChargeEstimate(
                headline: String(localized: "Full"), caption: String(localized: "running on the charger"))
        case .starting?:
            return ChargeEstimate(headline: String(localized: "Starting"), caption: String(localized: "charge control"))
        case .heatPaused?:
            return ChargeEstimate(
                headline: String(localized: "Paused"), caption: String(localized: "until the battery cools"))
        case .onBattery?, .off?, nil:
            break
        }
        // No target from the helper: macOS's own estimates.
        if draining {
            let minutes =
                battery.minutesToEmpty
                ?? (battery.isPluggedIn ? nil : linearMinutes(from: battery.percent, to: 0, battery, current))
            return minutes.map { ChargeEstimate(minutes: $0, caption: String(localized: "until empty at this rate")) }
                ?? ChargeEstimate(
                    headline: String(localized: "Discharging"), caption: String(localized: "no time to estimate yet"))
        }
        if charging {
            return battery.minutesToFull.map { ChargeEstimate(minutes: $0, caption: String(localized: "until full")) }
                ?? ChargeEstimate(
                    headline: String(localized: "Charging"), caption: String(localized: "no time to estimate yet"))
        }
        return ChargeEstimate(
            headline: battery.isPluggedIn ? String(localized: "Idle") : "–",
            caption: battery.isPluggedIn
                ? String(localized: "on the charger") : String(localized: "no time to estimate"))
    }

    /// Time to reach target at the present current. Charging slows near full, so a charging time
    /// is capped at macOS's own estimate to 100%.
    private static func toward(
        _ target: Int, battery: BatterySnapshot, current: Double, moving: Bool, verb: String
    ) -> ChargeEstimate {
        let caption = target >= 100 ? String(localized: "until full") : String(localized: "until \(target)%")
        guard moving else { return ChargeEstimate(headline: verb, caption: String(localized: "to \(target)%")) }
        if target >= 100, current > 0, let full = battery.minutesToFull {
            return ChargeEstimate(minutes: full, caption: caption)
        }
        guard var minutes = linearMinutes(from: battery.percent, to: target, battery, current) else {
            return ChargeEstimate(headline: verb, caption: String(localized: "to \(target)%"))
        }
        if current > 0, let full = battery.minutesToFull { minutes = min(minutes, full) }
        return ChargeEstimate(minutes: minutes, caption: caption)
    }

    /// Minutes to move between two charge levels at a constant current, at least one.
    static func linearMinutes(from percent: Int, to target: Int, _ battery: BatterySnapshot, _ current: Double) -> Int?
    {
        guard battery.fullChargeCapacity > 0, abs(current) > idleCurrent else { return nil }
        let milliampHours = Double(battery.fullChargeCapacity) * Double(abs(target - percent)) / 100
        let minutes = milliampHours / (abs(current) * 1000) * 60
        guard minutes.isFinite else { return nil }
        return max(1, Int(minutes.rounded()))
    }
}
