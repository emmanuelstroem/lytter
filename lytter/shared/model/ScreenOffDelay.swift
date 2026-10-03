//
//  ScreenOffDelay.swift
//  lytter
//

import Foundation

/// How long the app waits, while playing, before blacking out the screen (F43).
///
/// For a radio left playing on a TV, or a phone on a stand: after this long without a touch
/// or a press the screen goes black and the sound carries on. The first touch after that
/// only brings the screen back — see `ScreenOffController`.
///
/// Stored as its number of seconds, so the raw values are part of the stored format.
enum ScreenOffDelay: Int, CaseIterable, Identifiable, Sendable {
    case never = 0
    case thirtySeconds = 30
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300

    static let `default` = ScreenOffDelay.thirtySeconds

    var id: Int { rawValue }

    /// The wait, or nil when the screen is never blacked out.
    var interval: TimeInterval? {
        self == .never ? nil : TimeInterval(rawValue)
    }

    /// What Settings lists.
    var title: String {
        switch self {
        case .never: String(localized: "Never")
        case .thirtySeconds: String(localized: "After 30 Seconds")
        case .oneMinute: String(localized: "After 1 Minute")
        case .twoMinutes: String(localized: "After 2 Minutes")
        case .fiveMinutes: String(localized: "After 5 Minutes")
        }
    }

    /// When the screen should go black, given the last interaction — or nil if it should
    /// not, because nothing is playing or the listener has switched it off.
    ///
    /// Only while playing: a paused app on a stand is the system's to dim and lock, as any
    /// other app is.
    func blackoutTime(after lastActivity: Date, isPlaying: Bool) -> Date? {
        guard isPlaying, let interval else { return nil }
        return lastActivity.addingTimeInterval(interval)
    }
}
