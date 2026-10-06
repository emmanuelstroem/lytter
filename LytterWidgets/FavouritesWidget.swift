//
//  FavouritesWidget.swift
//  LytterWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

/// The stations the listener has pinned, one tap from playing (F18).
///
/// Four on the small and medium widgets, eight on the large, in pinned order. Tapping one
/// plays it; tapping the one playing pauses it. Drawn from what the app writes; nothing
/// here asks DR.
struct FavouritesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: NowPlayingStore.favouritesKind, provider: FavouritesProvider()) { entry in
            FavouritesWidgetView(entry: entry)
        }
        .configurationDisplayName("Favourites")
        .description("Your pinned stations, a tap from playing.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct FavouritesEntry: TimelineEntry {
    let date: Date
    let favourites: FavouriteStations?
    /// The station playing, if any, so its tile can say a tap pauses it.
    let playingID: String?

    static let sample = FavouritesEntry(
        date: Date(),
        favourites: FavouriteStations(stations: [
            .init(channelID: "p1", broadcaster: "DR", channelName: "P1", stationName: "P1", district: nil,
                  stationKey: "p1", programme: "P1 Morgen", programmeEnd: nil),
            .init(channelID: "p3", broadcaster: "DR", channelName: "P3", stationName: "P3", district: nil,
                  stationKey: "p3", programme: "Go' morgen P3", programmeEnd: nil),
            .init(channelID: "p4kbh", broadcaster: "DR", channelName: "P4 - København",
                  stationName: "P4", district: "København", stationKey: "p4", programme: "P4 Morgen", programmeEnd: nil),
            .init(channelID: "p6", broadcaster: "DR", channelName: "P6", stationName: "P6", district: nil,
                  stationKey: "p6beat", programme: nil, programmeEnd: nil)
        ]),
        playingID: "p3")
}

struct FavouritesProvider: TimelineProvider {
    private let store = NowPlayingStore()

    func placeholder(in context: Context) -> FavouritesEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (FavouritesEntry) -> Void) {
        let entry = entry(at: Date())
        let isEmpty = entry.favourites?.stations.isEmpty ?? true
        completion(context.isPreview && isEmpty ? .sample : entry)
    }

    /// One entry now and one as each programme ends, so its line goes. The app asks for a
    /// new timeline when the favourites, the catalogue or what is playing change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FavouritesEntry>) -> Void) {
        let now = Date()
        let favourites = store.loadFavourites()
        let playing = playingID()
        let dates = [now] + (favourites?.changes(after: now).prefix(12) ?? [])
        let entries = dates.map { FavouritesEntry(date: $0, favourites: favourites, playingID: playing) }
        completion(Timeline(entries: entries, policy: .never))
    }

    private func entry(at date: Date) -> FavouritesEntry {
        FavouritesEntry(date: date, favourites: store.loadFavourites(), playingID: playingID())
    }

    private func playingID() -> String? {
        guard let snapshot = store.load(), snapshot.isPlaying else { return nil }
        return snapshot.channelID
    }
}

// MARK: - Views

struct FavouritesWidgetView: View {
    let entry: FavouritesEntry
    @Environment(\.widgetFamily) private var family

    private var limit: Int { family == .systemLarge ? 8 : 4 }
    private var stations: [FavouriteStations.Station] {
        Array((entry.favourites?.stations ?? []).prefix(limit))
    }

    var body: some View {
        Group {
            if stations.isEmpty {
                EmptyFavouritesView()
            } else if family == .systemSmall {
                grid(columns: 2, compact: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    FavouritesHeader(broadcaster: stations[0].broadcaster)
                    grid(columns: 2, compact: false)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    /// Rows of `columns` tiles, the last row padded so every tile is the same size.
    private func grid(columns: Int, compact: Bool) -> some View {
        let rows = stride(from: 0, to: limit, by: columns).map { start in
            (start..<start + columns).map { stations.indices.contains($0) ? stations[$0] : nil }
        }
        return VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { row in
                // A row with nothing in it is left out, so two favourites fill the widget.
                if rows[row].contains(where: { $0 != nil }) {
                    HStack(spacing: 6) {
                        ForEach(rows[row].indices, id: \.self) { column in
                            if let station = rows[row][column] {
                                FavouriteTile(station: station, date: entry.date,
                                              isPlaying: station.channelID == entry.playingID,
                                              compact: compact)
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
    }
}

/// The broadcaster's mark and "Favourites".
private struct FavouritesHeader: View {
    let broadcaster: String

    var body: some View {
        HStack(spacing: 6) {
            BroadcasterMark(name: broadcaster)
            Text("Favourites")
                .font(.headline)
                .foregroundStyle(Color.primary)
        }
    }
}

/// One station: its colour, its name, and what is on. A tap plays it, or pauses it if it is
/// the one playing.
private struct FavouriteTile: View {
    let station: FavouriteStations.Station
    let date: Date
    let isPlaying: Bool
    let compact: Bool

    var body: some View {
        let colour = StationPalette.color(stationName: station.stationName, stationKey: station.stationKey)
        Button(intent: PlayFavouriteIntent(channelID: station.channelID)) {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [colour, colour.opacity(0.65)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 1) {
                    Spacer(minLength: 0)
                    titles
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(compact ? 8 : 10)
                if isPlaying {
                    Image(systemName: "pause.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                        .padding(compact ? 7 : 9)
                }
            }
            // Corner tiles meet the widget's corners; the widget's own curve, inset, keeps
            // them concentric (see AGENTS.md).
            .clipShape(ContainerRelativeShape())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: station.channelName))
        .accessibilityValue(isPlaying ? Text("Pause") : Text("Play"))
    }

    @ViewBuilder private var titles: some View {
        if compact {
            // A small tile has room for the station and, beneath, its district.
            Text(verbatim: station.stationName)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            if let district = station.district {
                Text(verbatim: district)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
            }
        } else {
            ChannelName(station: station.stationName, district: station.district,
                        font: .subheadline.weight(.bold), districtColour: Color.white.opacity(0.85)).text
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let subtitle = station.subtitle(at: date) {
                Text(verbatim: subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }
}

private struct EmptyFavouritesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "star")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Spacer(minLength: 0)
            Text("Favourites")
                .font(.headline)
            Text("Pin stations in Lytter to see them here.")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview(as: .systemMedium) {
    FavouritesWidget()
} timeline: {
    FavouritesEntry.sample
}
