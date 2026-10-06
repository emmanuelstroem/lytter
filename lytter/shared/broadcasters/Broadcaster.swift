//
//  Broadcaster.swift
//  lytter
//

import Foundation

/// Who supplies a channel.
///
/// The home screen reads as one section per broadcaster, so the difference between "a
/// section per broadcaster" and "a section called DR" only shows when a second source
/// arrives. The seam exists so that arrival is a data change.
///
/// Adding one means a folder under `broadcasters/` holding its `BroadcasterSource`, and
/// that source's type in `BroadcasterRegistry`. No layout changes.
struct Broadcaster: Identifiable, Hashable, Sendable {

    let id: String

    /// Shown as the section heading. Not localised — these are proper nouns.
    let name: String

    /// Lower sorts first on the home screen. Explicit rather than alphabetical, because
    /// the national broadcaster belongs at the top regardless of what it is called.
    let displayOrder: Int

    static let dr = Broadcaster(id: "dr", name: "DR", displayOrder: 0)
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
    /// A channel says so itself, and one that does not is DR's: DR's own JSON carries no
    /// broadcaster, and neither does a channel cached before there was more than one.
    static func supplying(_ channel: DRChannel,
                          in registered: [Broadcaster] = BroadcasterRegistry.broadcasters) -> Broadcaster {
        let id = channel.broadcasterID ?? Broadcaster.dr.id
        return registered.first { $0.id == id } ?? .dr
    }

    /// Groups channels into sections, in display order.
    ///
    /// A broadcaster with no channels is omitted rather than rendered as an empty heading —
    /// which matters as soon as a source fails to load while others succeed.
    static func sections(from channels: [DRChannel],
                         registered: [Broadcaster] = BroadcasterRegistry.broadcasters) -> [BroadcasterSection] {
        let grouped = Dictionary(grouping: channels) { supplying($0, in: registered).id }

        return registered
            .sorted { $0.displayOrder < $1.displayOrder }
            .compactMap { broadcaster in
                guard let owned = grouped[broadcaster.id], !owned.isEmpty else { return nil }
                return BroadcasterSection(broadcaster: broadcaster, channels: owned)
            }
    }
}
