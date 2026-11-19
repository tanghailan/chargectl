import Foundation

/// Turns the helper's stored English log lines into the user's language for display. The stored
/// text stays unchanged, so logs, exports and the helper keep their original wording.
nonisolated enum LogPresentation {
    static func display(_ message: String, bundle: Bundle = .main) -> String {
        formatted(message, bundle: bundle)
            ?? String(localized: String.LocalizationValue(message), bundle: bundle)
    }

    private static func formatted(_ message: String, bundle: Bundle) -> String? {
        if let match = message.wholeMatch(of: /macOS charge limit is (\d+)%/) {
            return String(localized: "macOS charge limit is \(Int(match.1)!)%", bundle: bundle)
        }
        if let match = message.wholeMatch(of: /calibrating, draining to (\d+)%/) {
            return String(localized: "calibrating, draining to \(Int(match.1)!)%", bundle: bundle)
        }
        if let match = message.wholeMatch(of: /calibration started: draining to (\d+)%/) {
            return String(localized: "calibration started: draining to \(Int(match.1)!)%", bundle: bundle)
        }
        if let match = message.wholeMatch(of: /charging to (\d+)%/) {
            return String(localized: "charging to \(Int(match.1)!)%", bundle: bundle)
        }
        if let match = message.wholeMatch(of: /discharging to (\d+)%/) {
            return String(localized: "discharging to \(Int(match.1)!)%", bundle: bundle)
        }
        if let match = message.wholeMatch(of: /holding at (\d+)%/) {
            return String(localized: "holding at \(Int(match.1)!)%", bundle: bundle)
        }
        if let match = message.wholeMatch(of: /sailing down to (\d+)%/) {
            return String(localized: "sailing down to \(Int(match.1)!)%", bundle: bundle)
        }
        return nil
    }
}
