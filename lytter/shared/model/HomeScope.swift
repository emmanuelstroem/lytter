//
//  HomeScope.swift
//  lytter
//

import Foundation

/// What Home is showing: the listener's own stations, every broadcaster, or one of them
/// (F54c). The chips under Home's header on iPhone and iPad, in this order.
enum HomeScope: Hashable, Sendable {

    /// Favourites, favourite shows and Recently Played — what Home was before there were
    /// chips.
    case forYou

    /// One shelf per broadcaster. Took over from the Radio tab.
    case all

    /// Every one of that broadcaster's stations, A to Z.
    case broadcaster(String)

    /// The chips to offer, given the broadcasters the listener has not hidden.
    ///
    /// A chip per broadcaster shown, in the listener's order — DR's too while it is the only
    /// one, so the row keeps its shape as broadcasters come and go.
    static func available(visible: [Broadcaster]) -> [HomeScope] {
        [.forYou, .all] + visible.map { HomeScope.broadcaster($0.id) }
    }

    /// Where Home opens.
    ///
    /// The chip last chosen, if it is still offered. One that is not — its broadcaster has
    /// been hidden since — falls back to `.all`, the scope that
    /// still holds its stations. With nothing chosen yet, `.forYou` once there is
    /// something of the listener's own to show, otherwise `.all`: a first launch should
    /// open on stations, not on an empty page.
    static func initial(stored: String, available: [HomeScope], hasOwnStations: Bool) -> HomeScope {
        guard let chosen = HomeScope(storageValue: stored) else {
            return hasOwnStations ? .forYou : .all
        }
        return available.contains(chosen) ? chosen : .all
    }

    /// `scope`, unless it is no longer offered — a broadcaster hidden in Settings while
    /// Home was showing it — in which case `.all`.
    static func resolved(_ scope: HomeScope, in available: [HomeScope]) -> HomeScope {
        available.contains(scope) ? scope : .all
    }

    // MARK: - Storage

    /// How the choice is kept in UserDefaults. A broadcaster's id, not its name, since a
    /// name can change and an id must not.
    var storageValue: String {
        switch self {
        case .forYou: "forYou"
        case .all: "all"
        case .broadcaster(let id): "broadcaster:\(id)"
        }
    }

    init?(storageValue: String) {
        switch storageValue {
        case "forYou": self = .forYou
        case "all": self = .all
        default:
            let prefix = "broadcaster:"
            guard storageValue.hasPrefix(prefix), storageValue.count > prefix.count else { return nil }
            self = .broadcaster(String(storageValue.dropFirst(prefix.count)))
        }
    }
}
