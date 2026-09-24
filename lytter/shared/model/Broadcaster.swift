//
//  Broadcaster.swift
//  lytter
//

import Foundation

/// Who supplies a channel.
///
/// The app talks to one API today, so DR is the only entry. The type exists anyway because
/// the home screen is meant to read as one section per broadcaster — and the difference
/// between "a section per broadcaster" and "a section called DR" only shows up when a
/// second source arrives. Building the seam now means that arrival is a data change.
///
/// Adding one means: a `Broadcaster` here, a network service that returns its channels, and
/// an entry in `registered`. No layout changes.
struct Broadcaster: Identifiable, Hashable, Sendable {

    let id: String

    /// Shown as the section heading. Not localised — these are proper nouns.
    let name: String

    /// Lower sorts first on the home screen. Explicit rather than alphabetical, because
    /// the national broadcaster belongs at the top regardless of what it is called.
    let displayOrder: Int

    static let dr = Broadcaster(id: "dr", name: "DR", displayOrder: 0)

    /// Every broadcaster the app knows about, whether or not it currently has channels.
    static let registered: [Broadcaster] = [.dr]
}

/// One home-screen section: a broadcaster and the channels it supplies.
struct BroadcasterSection: Identifiable, Equatable {
    var id: String { broadcaster.id }
    let broadcaster: Broadcaster
    let channels: [DRChannel]
}

extension Broadcaster {

    /// Which broadcaster supplies `channel`.
    ///
    /// Everything is DR while DR is the only API the app calls. This is the lookup a second
    /// source would extend — deliberately a function rather than an assumption spread
    /// through the views.
    static func supplying(_ channel: DRChannel) -> Broadcaster { .dr }

    /// Groups channels into sections, in display order.
    ///
    /// A broadcaster with no channels is omitted rather than rendered as an empty heading —
    /// which matters as soon as a source fails to load while others succeed.
    static func sections(from channels: [DRChannel]) -> [BroadcasterSection] {
        let grouped = Dictionary(grouping: channels) { supplying($0).id }

        return registered
            .sorted { $0.displayOrder < $1.displayOrder }
            .compactMap { broadcaster in
                guard let owned = grouped[broadcaster.id], !owned.isEmpty else { return nil }
                return BroadcasterSection(broadcaster: broadcaster, channels: owned)
            }
    }
}
