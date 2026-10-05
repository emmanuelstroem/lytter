//
//  CarPlayCatalogue.swift
//  lytter
//

import Foundation

/// What the car's screen lists (F21), worked out from the same state the phone draws.
///
/// Kept apart from the CarPlay templates on purpose. A `CPListTemplate` can only be looked
/// at in a car or in the simulator's CarPlay window, and neither runs under a test; this
/// can. The scene delegate turns it into templates and does nothing else.
///
/// Two tabs. **Home** is one tap to sound: favourites, then recently played without the
/// favourites already above it — a list in the car is short, and the same row twice wastes
/// it. **Stations** is the catalogue, one row a station, with P4 and P5 opening a list of
/// districts exactly as the phone's picker does: driving is when a listener leaves their
/// region, so the car must not hide the others behind it.
struct CarPlayCatalogue: Equatable {

    struct Row: Identifiable, Equatable {
        enum Action: Equatable {
            case play(DRChannel)
            /// Opens the station's districts, the listener's region first.
            case chooseDistrict(stationID: String)
        }

        let id: String
        let title: String
        /// What is on air, where it is known.
        let detail: String?
        let imageURL: String?
        /// Whether this row can be heard right now: the car's playing indicator.
        let isPlaying: Bool
        let action: Action
    }

    struct Section: Equatable {
        let title: String
        let rows: [Row]
    }

    let home: [Section]
    let stations: [Row]

    /// What the row reads off the rest of the app, as plain values — a programme title
    /// and an image for a channel, and which channel is audible.
    struct Context {
        var region: District?
        var audibleChannelID: String?
        var programme: (DRChannel) -> String? = { _ in nil }
        var artwork: (DRChannel) -> String? = { _ in nil }
    }

    init(channels: [DRChannel], favourites: Favourites, recentlyPlayed: RecentlyPlayed,
         context: Context, titles: (favourites: String, recent: String)) {
        let favourite = favourites.resolve(in: channels)
        let pinned = Set(favourite.map(\.id))
        let recent = recentlyPlayed.resolve(in: channels).filter { !pinned.contains($0.id) }

        home = [
            Section(title: titles.favourites, rows: favourite.map { Self.row(for: $0, context) }),
            Section(title: titles.recent, rows: recent.map { Self.row(for: $0, context) }),
        ].filter { !$0.rows.isEmpty }

        stations = GroupedChannel.grouped(from: channels).map { Self.row(for: $0, context) }
    }

    /// The districts of `station`, for the list a station row opens. Nil when the station
    /// is gone from the catalogue, or has no districts to choose between.
    static func districts(of stationID: String, in channels: [DRChannel],
                          context: Context) -> [Row]? {
        guard let station = GroupedChannel.grouped(from: channels).first(where: { $0.id == stationID }),
              station.hasMultipleDistricts else { return nil }
        return station.channels(regionFirst: context.region).map { channel in
            row(for: channel, context, title: channel.district ?? channel.qualifiedName)
        }
    }

    /// `sections`, cut to the car's limits: CarPlay lists at most so many rows in all, and
    /// fewer while driving. Rows past the limit go from the end, so favourites outlast
    /// history; a section left with nothing is dropped rather than shown as a heading.
    static func capped(_ sections: [Section], items: Int, sections sectionLimit: Int) -> [Section] {
        var remaining = max(items, 0)
        return sections.prefix(max(sectionLimit, 0)).compactMap { section in
            let rows = Array(section.rows.prefix(remaining))
            remaining -= rows.count
            return rows.isEmpty ? nil : Section(title: section.title, rows: rows)
        }
    }

    /// A specific channel: a favourite, a recent play or a district. Named in full on Home,
    /// where "P4" alone would not say which of the ten it is.
    private static func row(for channel: DRChannel, _ context: Context,
                            title: String? = nil) -> Row {
        Row(id: channel.id,
            title: title ?? channel.qualifiedName,
            detail: context.programme(channel),
            imageURL: context.artwork(channel),
            isPlaying: channel.id == context.audibleChannelID,
            action: .play(channel))
    }

    /// A station. One with districts stands for all of them: it is playing if any is, and
    /// shows what is on in the listener's region — another district's programme would be
    /// a guess about what they will hear, so without a region it shows none.
    private static func row(for station: GroupedChannel, _ context: Context) -> Row {
        if let only = station.soleChannel { return row(for: only, context) }

        let face = context.region.flatMap(station.channel(in:))
        return Row(id: station.id,
                   title: station.name,
                   detail: face.flatMap(context.programme),
                   imageURL: (face ?? station.representative).flatMap(context.artwork),
                   isPlaying: station.channels.contains { $0.id == context.audibleChannelID },
                   action: .chooseDistrict(stationID: station.id))
    }
}
