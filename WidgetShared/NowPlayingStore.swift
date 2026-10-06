//
//  NowPlayingStore.swift
//  WidgetShared
//

import Foundation

/// Where `NowPlayingSnapshot` and its artwork live: the app group's container, which the
/// app and the widget extension both declare (F18).
///
/// The artwork is a file beside the snapshot rather than a URL inside it. A widget cannot
/// load an image while it draws; it reads what the app has already downloaded for the lock
/// screen.
nonisolated struct NowPlayingStore: Sendable {
    static let appGroup = "group.com.eopio.lytter"
    static let snapshotFileName = "now_playing.json"
    static let artworkFileName = "now_playing_artwork.jpg"

    /// The kinds the app asks WidgetKit to redraw. Each must match its widget's `kind`.
    static let widgetKind = "com.eopio.lytter.now-playing"
    static let controlKind = "com.eopio.lytter.listening-control"

    /// The folder both files go in; nil if the group is missing from the entitlements,
    /// and then nothing is written or read and the widget shows its empty state.
    let directory: URL?

    init(directory: URL? = NowPlayingStore.sharedDirectory()) {
        self.directory = directory
    }

    private var snapshotURL: URL? { directory?.appendingPathComponent(Self.snapshotFileName) }
    private var artworkURL: URL? { directory?.appendingPathComponent(Self.artworkFileName) }

    /// The last snapshot written, if it is of this version.
    func load() -> NowPlayingSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(NowPlayingSnapshot.self, from: data),
              snapshot.version == NowPlayingSnapshot.schemaVersion else { return nil }
        return snapshot
    }

    func save(_ snapshot: NowPlayingSnapshot) {
        guard let url = snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Removes the snapshot and artwork: nothing has been listened to that is worth showing.
    func clear() {
        for url in [snapshotURL, artworkURL].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// The artwork, as JPEG data, or nil when there is none — the widget then draws the
    /// station's colour, as the app does with Show Images off.
    func artworkData() -> Data? {
        artworkURL.flatMap { try? Data(contentsOf: $0) }
    }

    func saveArtwork(_ data: Data?) {
        guard let url = artworkURL else { return }
        if let data {
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// `Library/Application Support/NowPlaying` in the group container, made if need be.
    static func sharedDirectory() -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        let directory = container.appendingPathComponent("Library/Application Support/NowPlaying",
                                                         isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
