//
//  ScheduleScope.swift
//  lytter
//

import Foundation

/// Which stations' schedules the daily show-schedule refresh asks DR for (F33), chosen
/// under Settings → Network.
///
/// Every station is the default: the weekly template then learns them all, so a show
/// favourited later already has its usual times behind it. Favourites asks for only the
/// listener's favourite stations and the stations their favourite shows are on, at the cost
/// of a show favourited elsewhere starting with no history. Low Data Mode is narrower still,
/// whichever is chosen: only the stations favourite shows are on.
enum ScheduleScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case favourites

    static let `default` = ScheduleScope.all

    var id: String { rawValue }

    /// What Settings lists.
    var title: String {
        switch self {
        case .all: String(localized: "All Shows/Channels")
        case .favourites: String(localized: "Favourite Shows/Channels")
        }
    }
}
