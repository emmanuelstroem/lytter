//
//  NowPlayingWidget.swift
//  LytterWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

/// The station the listener has on, on the Home Screen, the Lock Screen and in StandBy (F18).
///
/// Drawn from the snapshot the app writes; nothing here asks DR. Each programme the app
/// knew of becomes an entry, so the widget moves on to the next one at its start.
struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: NowPlayingStore.widgetKind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("The station you're listening to, what's on, and what's next.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot?
    let artwork: UIImage?

    var programme: NowPlayingSnapshot.Programme? { snapshot?.programme(at: date) }
    var subtitle: String? { snapshot?.subtitle(at: date) }
    var next: NowPlayingSnapshot.Programme? { snapshot?.next(after: date) }

    /// What the gallery shows before anything has been played.
    static let sample = NowPlayingEntry(
        date: Date(),
        snapshot: NowPlayingSnapshot(
            channelID: "sample", broadcaster: "DR", channelName: "P4 - København", stationName: "P4",
            district: "København", stationKey: "p4",
            isPlaying: true,
            programmes: [
                .init(title: "P4 Morgen København", start: Date().addingTimeInterval(-40 * 60),
                      end: Date().addingTimeInterval(80 * 60)),
                .init(title: "P4 Formiddag", start: Date().addingTimeInterval(80 * 60),
                      end: Date().addingTimeInterval(140 * 60))
            ],
            savedAt: Date()),
        artwork: nil)
}

struct NowPlayingProvider: TimelineProvider {
    private let store = NowPlayingStore()

    func placeholder(in context: Context) -> NowPlayingEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let now = Date()
        guard let snapshot = store.load() else {
            completion(context.isPreview ? .sample : NowPlayingEntry(date: now, snapshot: nil, artwork: nil))
            return
        }
        completion(NowPlayingEntry(date: now, snapshot: snapshot, artwork: artwork()))
    }

    /// One entry now and one at each change the snapshot foresees. Never refreshed on a
    /// schedule of its own: the app asks for a new timeline whenever something changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let now = Date()
        let snapshot = store.load()
        let image = snapshot == nil ? nil : artwork()
        let dates = [now] + (snapshot?.changes(after: now) ?? [])
        let entries = dates.map { NowPlayingEntry(date: $0, snapshot: snapshot, artwork: image) }
        completion(Timeline(entries: entries, policy: .never))
    }

    private func artwork() -> UIImage? {
        store.artworkData().flatMap(UIImage.init(data:))
    }
}

// MARK: - Views

struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium: MediumView(entry: entry, snapshot: snapshot)
                case .accessoryRectangular: RectangularView(entry: entry, snapshot: snapshot)
                case .accessoryCircular: CircularView(entry: entry, snapshot: snapshot)
                case .accessoryInline: InlineView(entry: entry, snapshot: snapshot)
                default: SmallView(entry: entry, snapshot: snapshot)
                }
            } else {
                EmptyStateView()
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium {
                BackdropView(snapshot: entry.snapshot)
            } else {
                AccessoryWidgetBackground()
            }
        }
    }
}

/// The station's colour, faint, behind the Home Screen widgets.
private struct BackdropView: View {
    let snapshot: NowPlayingSnapshot?

    var body: some View {
        let colour = snapshot.map { StationPalette.color(stationName: $0.stationName,
                                                         stationKey: $0.stationKey) } ?? .purple
        LinearGradient(colors: [colour.opacity(0.35), colour.opacity(0.1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .background(Color(.systemBackground))
    }
}

private struct SmallView: View {
    let entry: NowPlayingEntry
    let snapshot: NowPlayingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                // Meets the widget's corner, so it takes the widget's own curve, inset.
                Artwork(image: entry.artwork, snapshot: snapshot)
                    .frame(width: 56, height: 56)
                    .clipShape(ContainerRelativeShape())
                Spacer(minLength: 0)
                PlayPauseButton(isPlaying: snapshot.isPlaying)
            }
            Spacer(minLength: 0)
            StationTitles(snapshot: snapshot, subtitle: entry.subtitle, subtitleLines: 1)
            ProgrammeProgress(entry: entry, snapshot: snapshot)
        }
    }
}

private struct MediumView: View {
    let entry: NowPlayingEntry
    let snapshot: NowPlayingSnapshot

    var body: some View {
        HStack(spacing: 14) {
            // A square as tall as the widget allows, filled: a filled image left to size
            // itself would push the square wider than it is tall.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { Artwork(image: entry.artwork, snapshot: snapshot) }
                .clipShape(ContainerRelativeShape())
            VStack(alignment: .leading, spacing: 3) {
                // The whole width for the name: "P4 København" did not fit beside the button.
                StationTitles(snapshot: snapshot, subtitle: entry.subtitle)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        ProgrammeProgress(entry: entry, snapshot: snapshot)
                        if let next = entry.next {
                            NextLine(programme: next, snapshot: snapshot)
                        }
                    }
                    PlayPauseButton(isPlaying: snapshot.isPlaying)
                }
            }
        }
    }
}

private struct RectangularView: View {
    let entry: NowPlayingEntry
    let snapshot: NowPlayingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // "DR P2" on one line: the Lock Screen has room for three.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: snapshot.broadcaster)
                    .font(.caption2.weight(.bold))
                ChannelName(station: snapshot.stationName, district: snapshot.district).text
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .widgetAccentable()
            }
            if let subtitle = entry.subtitle {
                Text(verbatim: subtitle)
                    .font(.caption)
                    .lineLimit(1)
            }
            ProgrammeProgress(entry: entry, snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CircularView: View {
    let entry: NowPlayingEntry
    let snapshot: NowPlayingSnapshot

    var body: some View {
        let label = Text(verbatim: snapshot.stationName).font(.system(.caption, design: .rounded).weight(.bold))
        if let programme = entry.programme, let interval = snapshot.clockInterval(of: programme) {
            ProgressView(timerInterval: interval, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                label
            }
            .progressViewStyle(.circular)
            .widgetAccentable()
        } else {
            ZStack {
                AccessoryWidgetBackground()
                label
            }
        }
    }
}

private struct InlineView: View {
    let entry: NowPlayingEntry
    let snapshot: NowPlayingSnapshot

    var body: some View {
        // A composition of a station and a programme, both proper names.
        if let subtitle = entry.subtitle {
            Text(verbatim: "\(snapshot.channelName) · \(subtitle)")
        } else {
            Text(verbatim: snapshot.channelName)
        }
    }
}

private struct EmptyStateView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline, .accessoryCircular:
            Image(systemName: "radio")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(verbatim: "Lytter").font(.headline)
                Text("Play a station to see it here.").font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "radio")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 0)
                Text(verbatim: "Lytter").font(.headline)
                Text("Play a station to see it here.")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Parts

/// The programme's artwork, or the station's colour and name where there is none.
private struct Artwork: View {
    let image: UIImage?
    let snapshot: NowPlayingSnapshot

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            let colour = StationPalette.color(stationName: snapshot.stationName,
                                              stationKey: snapshot.stationKey)
            LinearGradient(colors: [colour, colour.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Text(verbatim: snapshot.stationName)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .foregroundStyle(Color.white)
                        .padding(4)
                }
                .accessibilityHidden(true)
        }
    }
}

/// "**P4** København": the station, and its district in the same size but lighter.
///
/// Rather than "P4 - København", which at headline size does not fit beside a logo in a
/// medium widget. Without the dash it reads as one name, and the weight says which part is
/// the station. A long district shrinks a little before it is cut short.
struct ChannelName {
    let station: String
    let district: String?
    var font: Font = .headline
    var districtColour: Color = .secondary

    var text: Text {
        let station = Text(verbatim: station).font(font)
        guard let district else { return station }
        return station + Text(verbatim: " \(district)")
            .font(font.weight(.regular))
            .foregroundStyle(districtColour)
    }
}

/// The broadcaster's mark and the channel on one line — DR LYD's logo beside "**P4**
/// København" — and what is on beneath. Nothing says "Paused": the button already does.
struct StationTitles: View {
    let broadcaster: String
    let name: ChannelName
    let subtitle: String?
    var subtitleLines = 2

    init(snapshot: NowPlayingSnapshot, subtitle: String?, subtitleLines: Int = 2) {
        self.broadcaster = snapshot.broadcaster
        self.name = ChannelName(station: snapshot.stationName, district: snapshot.district)
        self.subtitle = subtitle
        self.subtitleLines = subtitleLines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                BroadcasterMark(name: broadcaster)
                name.text
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.primary)
            }
            if let subtitle {
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .lineLimit(subtitleLines)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

/// Who broadcasts the channel: DR LYD's logo for DR, which is all the app plays today, and
/// the broadcaster's name for one with no logo here.
///
/// In full colour even in the tinted and clear Home Screen styles, where a picture would
/// otherwise be drawn as a flat grey square. The Lock Screen draws in one colour whatever
/// the widget asks, so its widgets spell the name instead.
struct BroadcasterMark: View {
    let name: String

    var body: some View {
        if name == "DR" {
            logo
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .accessibilityLabel(Text(verbatim: name))
        } else {
            Text(verbatim: name)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.secondary)
        }
    }

    @ViewBuilder private var logo: some View {
        let image = Image("DRLydLogo").resizable()
        if #available(iOS 18.0, *) {
            image.widgetAccentedRenderingMode(.fullColor)
        } else {
            image
        }
    }
}

/// How far through the programme the listener is: a bar that fills on its own while
/// playing, and stands still while paused.
private struct ProgrammeProgress: View {
    let entry: NowPlayingEntry
    let snapshot: NowPlayingSnapshot

    var body: some View {
        if let programme = entry.programme {
            if let interval = snapshot.clockInterval(of: programme) {
                ProgressView(timerInterval: interval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .widgetAccentable()
            } else if let value = programme.progress(at: snapshot.heardDate(at: entry.date)) {
                ProgressView(value: value)
                    .progressViewStyle(.linear)
                    .widgetAccentable()
            }
        }
    }
}

/// "Next: P3 Dokumentar · 14:00".
private struct NextLine: View {
    let programme: NowPlayingSnapshot.Programme
    let snapshot: NowPlayingSnapshot

    var body: some View {
        HStack(spacing: 4) {
            Text("Next: \(programme.title)")
                .lineLimit(1)
            if let start = programme.start?.addingTimeInterval(snapshot.secondsBehindLive) {
                Text(start, style: .time)
                    .monospacedDigit()
            }
        }
        .font(.caption2)
        .foregroundStyle(Color.secondary)
    }
}

/// Play or pause, run by the app.
struct PlayPauseButton: View {
    let isPlaying: Bool

    var body: some View {
        Button(intent: ToggleListeningIntent()) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.primary.opacity(0.12)))
                .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? Text("Pause") : Text("Play"))
    }
}

#Preview(as: .systemSmall) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.sample
}

#Preview(as: .systemMedium) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.sample
}
