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

    /// Groups channels into sections, one per broadcaster in `shown`, in that order.
    ///
    /// A broadcaster with no channels is omitted rather than rendered as an empty heading —
    /// which matters as soon as a source fails to load while others succeed. So is one not
    /// in `shown`: the listener has hidden it.
    static func sections(from channels: [DRChannel],
                         shown: [Broadcaster],
                         registered: [Broadcaster] = BroadcasterRegistry.broadcasters) -> [BroadcasterSection] {
        let grouped = Dictionary(grouping: channels) { supplying($0, in: registered).id }

        return shown.compactMap { broadcaster in
            guard let owned = grouped[broadcaster.id], !owned.isEmpty else { return nil }
            return BroadcasterSection(broadcaster: broadcaster, channels: owned)
        }
    }

    /// Every registered broadcaster in the listener's order, hidden ones included — what
    /// Settings lists (F54b).
    ///
    /// The saved order comes first. A broadcaster it does not name — one registered since
    /// it was saved, or every one before anything has been moved — follows, by
    /// `displayOrder`. Ids no longer registered are passed over.
    static func arranged(_ registered: [Broadcaster], order: [String]) -> [Broadcaster] {
        let byID = Dictionary(registered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let saved = order.uniqued().compactMap { byID[$0] }
        let savedIDs = Set(saved.map(\.id))
        let unsaved = registered
            .filter { !savedIDs.contains($0.id) }
            .sorted { $0.displayOrder < $1.displayOrder }
        return saved + unsaved
    }

    /// The broadcasters the app shows and fetches, in the listener's order.
    ///
    /// Never none: an app with every broadcaster hidden would be an empty screen with no
    /// way to say why. Settings will not hide the last one, and should the stored ids say
    /// otherwise — the last one shown was renamed, say — the first in order is shown.
    static func visible(registered: [Broadcaster], order: [String], hidden: Set<String>) -> [Broadcaster] {
        let arranged = arranged(registered, order: order)
        let shown = arranged.filter { !hidden.contains($0.id) }
        return shown.isEmpty ? Array(arranged.prefix(1)) : shown
    }
}
