//
//  FavouritesWidget.swift
//  LytterWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

/// The stations the listener has pinned, as their logos, one tap from playing (F18).
///
/// Four on the small and medium widgets, twelve on the large, in pinned order. Tapping one
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
            .init(channelID: "p1", broadcaster: "DR", channelName: "P1", stationName: "P1",
                  district: nil, stationKey: "p1"),
            .init(channelID: "p3", broadcaster: "DR", channelName: "P3", stationName: "P3",
                  district: nil, stationKey: "p3"),
            .init(channelID: "p4kbh", broadcaster: "DR", channelName: "P4 - København",
                  stationName: "P4", district: "København", stationKey: "p4"),
            .init(channelID: "p6", broadcaster: "DR", channelName: "P6", stationName: "P6",
                  district: nil, stationKey: "p6beat")
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

    /// One entry: nothing on a tile changes with the clock. The app asks for a new timeline
    /// when the favourites, the channels or what is playing change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FavouritesEntry>) -> Void) {
        completion(Timeline(entries: [entry(at: Date())], policy: .never))
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

    /// Square tiles, because the logos are: two by two on the small widget, a row of four on
    /// the medium, three rows of four on the large.
    private var columns: Int { family == .systemSmall ? 2 : 4 }
    private var rows: Int {
        switch family {
        case .systemSmall: 2
        case .systemLarge: 3
        default: 1
        }
    }

    private var stations: [FavouriteStations.Station] {
        Array((entry.favourites?.stations ?? []).prefix(columns * rows))
    }

    var body: some View {
        Group {
            if stations.isEmpty {
                EmptyFavouritesView()
            } else if family == .systemSmall {
                grid
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    FavouritesHeader(broadcaster: stations[0].broadcaster)
                    grid
                    Spacer(minLength: 0)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    /// Rows of `columns` tiles. The last row is padded so every tile is the same size, and a
    /// row with nothing in it is left out.
    private var grid: some View {
        let slots = stride(from: 0, to: columns * rows, by: columns).map { start in
            (start..<start + columns).map { stations.indices.contains($0) ? stations[$0] : nil }
        }
        return VStack(spacing: 8) {
            ForEach(slots.indices, id: \.self) { row in
                if slots[row].contains(where: { $0 != nil }) {
                    HStack(spacing: 8) {
                        ForEach(slots[row].indices, id: \.self) { column in
                            if let station = slots[row][column] {
                                FavouriteTile(station: station,
                                              isPlaying: station.channelID == entry.playingID)
                            } else {
                                Color.clear.aspectRatio(1 / (1 + FavouriteTile.stripShare), contentMode: .fit)
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

/// One station: its logo, with the logo's black band carried on below it. A district's
/// name is printed in that strip, since every P4 district shares the P4 logo; a national
/// channel's strip is left empty, so that every tile is the same size.
///
/// The strip, not a label over the logo: at widget size the logo has no free corner, and a
/// label there covered the station's number. A tap plays the station, or pauses it if it is
/// the one playing.
private struct FavouriteTile: View {
    let station: FavouriteStations.Station
    let isPlaying: Bool

    /// The strip's height, as a share of the tile's width.
    static let stripShare: CGFloat = 0.2

    /// One radius for every tile. A widget's corners are about 22 points and its content
    /// sits 16 in, so a tile that meets a corner wants 22 − 16 = 6 (see AGENTS.md), and the
    /// rest match it. Not `ContainerRelativeShape`, which follows the widget's curve: it
    /// rounded the corner tiles and left those further in nearly square.
    static let cornerRadius: CGFloat = 6

    var body: some View {
        Button(intent: PlayFavouriteIntent(channelID: station.channelID)) {
            // Sized from the tile's width: the logo a square of it, the strip the rest.
            Color.clear
                .aspectRatio(1 / (1 + Self.stripShare), contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        let side = proxy.size.width
                        VStack(spacing: 0) {
                            ChannelLogo(station: station)
                                .frame(width: side, height: side)
                            DistrictStrip(name: station.district)
                                .frame(width: side, height: max(proxy.size.height - side, 0))
                        }
                    }
                }
            .overlay(alignment: .topTrailing) {
                    if isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .padding(4)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: station.channelName))
        .accessibilityValue(isPlaying ? Text("Pause") : Text("Play"))
    }
}

/// The station's logo, in DR's own colours whatever the Home Screen's tint. A station with
/// no logo here gets its colour and name, as the app draws it with Show Images off.
///
/// The `DRP*Logo` assets (`DRP1Logo` for P1) are DR's print logos, prepared for the screen: their CMYK
/// colours converted to sRGB through ColorSync, Illustrator's editing data dropped (715 KB
/// to under 5 KB each), and the page shrunk from 800 to 120 points. Xcode renders the
/// bitmaps at that size, and an 800-point page made 2400-pixel images, ~23 MB each in
/// memory against a widget's ~30 MB. No vector copy is kept, for the same reason.
private struct ChannelLogo: View {
    let station: FavouriteStations.Station

    /// DR's national stations, by the name the directory gives them.
    private static let logos: Set<String> = ["p1", "p2", "p3", "p4", "p5", "p6", "p8"]

    var body: some View {
        let key = station.stationName.lowercased()
        if Self.logos.contains(key) {
            let image = Image("DR\(station.stationName.uppercased())Logo").resizable()
            if #available(iOS 18.0, *) {
                image.widgetAccentedRenderingMode(.fullColor)
            } else {
                image
            }
        } else {
            let colour = StationPalette.color(stationName: station.stationName,
                                              stationKey: station.stationKey)
            LinearGradient(colors: [colour, colour.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Text(verbatim: station.stationName)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(Color.white)
                        .padding(4)
                }
        }
    }
}

/// The logo's black band, continued: "København" for a district, empty for the rest.
private struct DistrictStrip: View {
    let name: String?

    /// The band's own black — DR's 100% K, as ColorSync converts it to sRGB (#1A1919) — so
    /// the strip reads as part of the logo, with no seam where they meet.
    static let black = Color(.sRGB, red: 0.1036, green: 0.0992, blue: 0.0975)

    var body: some View {
        GeometryReader { proxy in
            Self.black.overlay {
                if let name {
                    Text(verbatim: name)
                        .font(.system(size: proxy.size.height * 0.62, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 4)
                }
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
