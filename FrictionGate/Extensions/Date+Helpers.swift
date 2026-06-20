import Foundation

// MARK: - Date helpers

extension Date {

    /// Midnight (00:00:00) of `self` in the current calendar.
    ///
    /// Used by `HealthKitService` to query steps since the start of today.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Whole hours elapsed between `other` and `self`.
    /// Positive when `self` is later than `other`.
    ///
    /// Used by `WakeUpDetector` to compare idle gaps against the threshold.
    func hours(since other: Date) -> Double {
        timeIntervalSince(other) / 3_600
    }

    /// `true` when `self` falls on today's calendar date.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}

// MARK: - DateComponents helpers

extension DateComponents {

    /// Converts a `DateComponents` that holds only `hour`/`minute` values into
    /// a concrete `Date` anchored to today.
    ///
    /// Used by `DatePicker` bindings in `ConditionPickerView` and
    /// `GlobalSettingsView` to bridge between the time-only `DateComponents`
    /// stored in the model and the `Date` that `DatePicker` requires.
    var asDate: Date {
        var c   = self
        let now = Date()
        let cal = Calendar.current
        c.year  = cal.component(.year,  from: now)
        c.month = cal.component(.month, from: now)
        c.day   = cal.component(.day,   from: now)
        return cal.date(from: c) ?? now
    }
}
