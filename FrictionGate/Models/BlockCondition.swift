import Foundation

// MARK: - DaySet

/// Bitmask representing which days of the week a time-window condition applies to.
struct DaySet: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let monday    = DaySet(rawValue: 1 << 0)
    static let tuesday   = DaySet(rawValue: 1 << 1)
    static let wednesday = DaySet(rawValue: 1 << 2)
    static let thursday  = DaySet(rawValue: 1 << 3)
    static let friday    = DaySet(rawValue: 1 << 4)
    static let saturday  = DaySet(rawValue: 1 << 5)
    static let sunday    = DaySet(rawValue: 1 << 6)

    static let weekdays: DaySet = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: DaySet  = [.saturday, .sunday]
    static let everyday: DaySet = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    /// Human-readable label used in UI summaries.
    var displayName: String {
        switch self {
        case .weekdays: return "Weekdays"
        case .weekend:  return "Weekends"
        case .everyday: return "Every day"
        default:
            let names: [(DaySet, String)] = [
                (.monday, "Mon"), (.tuesday, "Tue"), (.wednesday, "Wed"),
                (.thursday, "Thu"), (.friday, "Fri"),
                (.saturday, "Sat"), (.sunday, "Sun"),
            ]
            let active = names.filter { contains($0.0) }.map(\.1)
            return active.joined(separator: ", ")
        }
    }
}

// MARK: - BlockCondition

/// Defines when a Rule is active and should block the selected app.
enum BlockCondition: Codable, Hashable {

    /// Block during a recurring time window on selected days of the week.
    /// - Parameters:
    ///   - start: Time-of-day only (hour/minute); date components are ignored.
    ///   - end:   Time-of-day only (hour/minute).
    ///   - days:  Which days the window applies.
    case timeWindow(start: DateComponents, end: DateComponents, days: DaySet)

    /// Block for `durationMinutes` after the device wakes from an idle period
    /// (detected by `WakeUpDetector`).
    case afterWakeUp(durationMinutes: Int)

    /// Block for `durationMinutes` leading up to the user's target sleep time.
    case beforeSleep(sleepTime: DateComponents, durationMinutes: Int)

    /// Block once the app has been opened `maxOpens` times today.
    case dailyOpenLimit(maxOpens: Int)

    // MARK: Codable boilerplate
    // Swift synthesises CodingKeys / init(from:) / encode(to:) automatically for
    // enums with associated values when all associated types are Codable.
    // DateComponents and DaySet are both Codable, so no manual conformance needed.
}
