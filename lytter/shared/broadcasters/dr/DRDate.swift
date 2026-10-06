//
//  DRDate.swift
//  lytter
//

import Foundation

/// DR's timestamps, such as "2026-10-02T20:49:10+00:00".
///
/// One formatter for the app. `startDate`, `endDate` and `playedDate` each built a new one
/// on every access, and they are read inside filters over whole arrays: picking the track
/// being heard runs every second while paused behind live, across the full track list.
enum DRDate {
    /// `ISO8601DateFormatter` is documented as thread-safe, so one instance can be shared
    /// across isolation domains; Swift cannot see that, hence `nonisolated(unsafe)`.
    nonisolated(unsafe) private static let formatter = ISO8601DateFormatter()

    nonisolated static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}

/// One of DR's timestamps, parsed once when it is made or decoded.
///
/// The parsed dates are read from view bodies and per-second checks — whether a programme
/// is on air, which track is being heard — and parsing took ~25 µs each time, which was
/// most of what a programme lookup cost. Encodes as the bare string DR sent, so the disk
/// cache keeps its format.
nonisolated struct DRTimestamp: Codable, Equatable {
    let string: String
    let date: Date?

    init(_ string: String) {
        self.string = string
        self.date = DRDate.parse(string)
    }

    init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    /// The date follows from the string.
    static func == (lhs: DRTimestamp, rhs: DRTimestamp) -> Bool { lhs.string == rhs.string }
}
