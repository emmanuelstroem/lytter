    //
    //  ImageCacheService.swift
    //  ios
    //
    //  Created by Emmanuel on 27/07/2025.
    //

import CryptoKit
import Foundation
import UIKit
import SwiftUI

    // MARK: - Image Cache Service

/// Two-level cache for DR artwork: decoded images in memory, encoded originals on disk.
///
/// DR serves artwork at 1920×1080. Decoded that is roughly 8 MB per image, so the mini
/// player's 36pt thumbnail used to cost the same as the full-screen one. Everything is
/// downsampled on the way in, and the memory cache is bounded by *bytes* rather than by
/// a count of images.
final class ImageCacheService {
    static let shared = ImageCacheService()

    // nonisolated because these are read as default arguments of an async method. Under
    // approachable concurrency a plain static is inferred main-actor isolated, which makes
    // that read a warning today and an error under Swift 6. They are immutable CGFloats,
    // so there is nothing to isolate.
    //
    /// Large enough for the biggest artwork the app shows (the tvOS 400pt card at @2x)
    /// while still being a fraction of the 1920×1080 original.
    nonisolated static let defaultMaxPixelSize: CGFloat = 1024
    /// Lists and thumbnails never need more than this.
    nonisolated static let thumbnailMaxPixelSize: CGFloat = 512

    private let memory = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let session: URLSession

    private let maxMemoryBytes = 48 * 1024 * 1024
    private let maxDiskBytes = 100 * 1024 * 1024
    private let maxConcurrentPreloads = 4

    /// One task per cache key, so N views asking for the same artwork share one download
    /// instead of starting N. `updateUIView` on tvOS could previously fire a fresh request
    /// on every layout pass.
    private let inFlight = InFlightTasks<UIImage?>()

    private var preloadTask: Task<Void, Never>?

    private init() {
        memory.totalCostLimit = maxMemoryBytes

        // Caches, not Documents. Artwork in Documents is backed up to iCloud, never
        // purged by the system under disk pressure, and visible to the user if file
        // sharing is ever switched on.
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        cacheDirectory = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)

        NotificationCenter.default.addObserver(
            self, selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        Task(priority: .background) { [weak self] in
            await self?.trimDiskCache()
        }
    }

    // MARK: - Loading

    /// Returns the artwork, downsampled to `maxPixelSize` on its longest edge.
    func image(for urlString: String,
               maxPixelSize: CGFloat = defaultMaxPixelSize) async -> UIImage? {
        let key = cacheKey(for: urlString, maxPixelSize: maxPixelSize)
        if let hit = memory.object(forKey: key as NSString) { return hit }

        let task = inFlight.claim(key) { [weak self] in
            Task<UIImage?, Never> {
                guard let self else { return nil }
                return await self.fetch(urlString, key: key, maxPixelSize: maxPixelSize)
            }
        }

        let image = await task.value

        // Passes the task back, so a caller that shared it cannot retire a newer one that
        // was registered while this one was finishing.
        inFlight.release(task, for: key)

        return image
    }

    /// Completion-handler form, for UIKit call sites.
    func loadImage(from urlString: String,
                   maxPixelSize: CGFloat = defaultMaxPixelSize,
                   completion: @escaping (UIImage?) -> Void) {
        // Serve straight from memory without a hop, so a synchronous layout pass that
        // already has the image does not flicker.
        let key = cacheKey(for: urlString, maxPixelSize: maxPixelSize)
        if let hit = memory.object(forKey: key as NSString) {
            completion(hit)
            return
        }
        Task { [weak self] in
            let image = await self?.image(for: urlString, maxPixelSize: maxPixelSize)
            await MainActor.run { completion(image) }
        }
    }

    private func fetch(_ urlString: String, key: String,
                       maxPixelSize: CGFloat) async -> UIImage? {
        // A different size of the same artwork may already be on disk; decoding it again
        // at the size we need avoids a second download.
        if let onDisk = dataFromDisk(for: urlString),
           let image = downsample(onDisk, maxPixelSize: maxPixelSize) {
            store(image, for: key)
            return image
        }
        guard let url = URL(string: urlString) else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let image = downsample(data, maxPixelSize: maxPixelSize)
        else { return nil }

        store(image, for: key)
        writeToDisk(data, for: urlString)
        return image
    }

    // MARK: - Downsampling

    /// Decodes straight to the size actually needed. `CGImageSourceCreateThumbnail…`
    /// never materialises the full-size bitmap, so peak memory stays low too.
    private func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions)
        else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as [CFString: Any] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Cost is the decoded byte size. Without it `totalCostLimit` does nothing, which is
    /// how a 50-image cache of 1920×1080 artwork could reach several hundred megabytes.
    private func store(_ image: UIImage, for key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        memory.setObject(image, forKey: key as NSString, cost: cost)
    }

    // MARK: - Preloading

    /// Warms the artwork the channel lists actually show — one image per episode, at
    /// thumbnail size, four at a time.
    ///
    /// This replaced three concurrent task groups that walked *every* image asset on
    /// every episode with no concurrency limit and no way to cancel.
    func preloadPrimaryImages(from episodes: [DREpisode]) {
        let urls = Array(Set(episodes.compactMap { $0.primaryImageURL }))
        guard !urls.isEmpty else { return }

        preloadTask?.cancel()
        preloadTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await withTaskGroup(of: Void.self) { group in
                var iterator = urls.makeIterator()

                // Keep a fixed window of downloads in flight rather than starting all of
                // them at once.
                for _ in 0..<self.maxConcurrentPreloads {
                    guard let next = iterator.next() else { break }
                    group.addTask {
                        _ = await self.image(for: next,
                                             maxPixelSize: Self.thumbnailMaxPixelSize)
                    }
                }
                while await group.next() != nil {
                    if Task.isCancelled { break }
                    guard let next = iterator.next() else { continue }
                    group.addTask {
                        _ = await self.image(for: next,
                                             maxPixelSize: Self.thumbnailMaxPixelSize)
                    }
                }
            }
        }
    }

    func cancelPreloading() {
        preloadTask?.cancel()
        preloadTask = nil
    }

    // MARK: - Cache management

    func clearAllCaches() {
        clearMemoryCache()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func getCacheStatistics() -> (memoryCount: Int, diskSize: Int64) {
        (memory.totalCostLimit, diskCacheSize())
    }

    @objc private func clearMemoryCache() {
        memory.removeAllObjects()
    }

    // MARK: - Disk

    /// SHA-256 of the URL.
    ///
    /// The previous key was `NSString.hash`, which is seeded per process: it changed
    /// between launches, so the disk cache never hit after a relaunch and every image was
    /// downloaded again. It could also collide, which meant serving the wrong picture.
    private func digest(of urlString: String) -> String {
        SHA256.hash(data: Data(urlString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Memory is keyed by URL *and* decode size, because the same artwork is held at
    /// thumbnail size for lists and at full size for the player.
    private func cacheKey(for urlString: String, maxPixelSize: CGFloat) -> String {
        "\(digest(of: urlString))-\(Int(maxPixelSize))"
    }

    /// Disk is keyed by URL alone. It stores the original encoded bytes, which do not
    /// vary with the size we happen to decode them at — keying it like memory would store
    /// the same JPEG once per size.
    private func fileURL(for urlString: String) -> URL {
        cacheDirectory.appendingPathComponent(digest(of: urlString))
    }

    private func dataFromDisk(for urlString: String) -> Data? {
        try? Data(contentsOf: fileURL(for: urlString))
    }

    private func writeToDisk(_ data: Data, for urlString: String) {
        try? data.write(to: fileURL(for: urlString), options: .atomic)
    }

    private func diskCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { total, file in
            total + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private func trimDiskCache() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        else { return }

        var total = files.reduce(0) {
            $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        guard total > maxDiskBytes else { return }

        let oldestFirst = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return a < b
        }
        for file in oldestFirst where total > maxDiskBytes / 2 {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try? fileManager.removeItem(at: file)
            total -= size
        }
    }
}

    // MARK: - Cached AsyncImage View

/// Drop-in replacement for `AsyncImage` that goes through `ImageCacheService`, so the
/// artwork is downsampled, shared between views and reused across launches.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let maxPixelSize: CGFloat
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(url: URL?,
         maxPixelSize: CGFloat = ImageCacheService.defaultMaxPixelSize,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        // Keyed on the URL: changing channel cancels the previous load and starts the
        // new one, rather than racing it.
        .task(id: url?.absoluteString) {
            guard let url else {
                image = nil
                return
            }
            image = await ImageCacheService.shared.image(for: url.absoluteString,
                                                         maxPixelSize: maxPixelSize)
        }
    }
}

extension CachedAsyncImage where Placeholder == EmptyView {
    init(url: URL?,
         maxPixelSize: CGFloat = ImageCacheService.defaultMaxPixelSize,
         @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, maxPixelSize: maxPixelSize, content: content) { EmptyView() }
    }
}
