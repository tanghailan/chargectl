/// What the app tells the user about without being asked, found by comparing two moments.
import Foundation

/// The parts of the app's state that events come from.
nonisolated enum StatusEvent: Equatable, Sendable {
    case limitReached(Int)
    case jobFinished(String)
    case tooWarm
    case helperStopped(String)
    case weakCharger(Int?)
    case controlNotWorking

    enum Kind: String, CaseIterable, Sendable {
        case problems
        case jobs
        case limit
    }

    var kind: Kind {
        switch self {
        case .limitReached: .limit
        case .jobFinished: .jobs
        case .tooWarm, .helperStopped, .weakCharger, .controlNotWorking: .problems
        }
    }

    var title: String {
        switch self {
        case .limitReached(let limit): String(localized: "Charged to \(limit)%")
        case .jobFinished(let job): String(localized: "\(Self.localizedJob(job)) finished")
        case .tooWarm: String(localized: "Charging paused")
        case .helperStopped: String(localized: "Charge control stopped")
        case .weakCharger: String(localized: "Charger too weak")
        case .controlNotWorking: String(localized: "Charge control isn't working")
        }
    }

    private static func localizedJob(_ job: String) -> String {
        let title = String(localized: String.LocalizationValue(job))
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    var body: String {
        switch self {
        case .limitReached: String(localized: "Chargectl stopped charging; your Mac runs on the charger.")
        case .jobFinished: String(localized: "Chargectl is back to your limit.")
        case .tooWarm: String(localized: "The battery is warm. Charging resumes when it cools down.")
        case .helperStopped(let reason): reason
        case .weakCharger(let watts):
            if let watts {
                String(
                    localized: "This \(watts) W charger can't keep up: the battery is running down while plugged in.")
            } else {
                String(localized: "This charger can't keep up: the battery is running down while plugged in.")
            }
        case .controlNotWorking:
            String(
                localized:
                    "Cutting wall power has no effect: the battery keeps charging. A macOS or firmware update may have changed how charging is controlled."
            )
        }
    }
}
nonisolated struct StatusSnapshot: Equatable, Sendable {
    var activity: ChargeActivity?
    var mode: ChargeMode?
    /// Why the helper is not working, after its grace period; nil when it runs.
    var helperProblem: String?
    var weakCharger = false
    var adapterWatts: Int?
    var controlProblem = false

    static func events(from old: StatusSnapshot, to new: StatusSnapshot) -> [StatusEvent] {
        var events: [StatusEvent] = []
        if case .holding(let limit)? = new.activity, case .charging(let target)? = old.activity, target == limit {
            events.append(.limitReached(limit))
        }
        if let mode = old.mode, mode != .automatic, new.mode == .automatic {
            events.append(.jobFinished(mode.title))
        }
        if new.activity == .heatPaused, old.activity != .heatPaused, old.activity != nil {
            events.append(.tooWarm)
        }
        if let problem = new.helperProblem, old.helperProblem == nil { events.append(.helperStopped(problem)) }
        if new.weakCharger, !old.weakCharger { events.append(.weakCharger(new.adapterWatts)) }
        if new.controlProblem, !old.controlProblem { events.append(.controlNotWorking) }
        return events
    }
}
