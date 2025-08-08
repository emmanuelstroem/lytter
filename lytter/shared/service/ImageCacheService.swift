    //
    //  ImageCacheService.swift
    //  ios
    //
    //  Created by Emmanuel on 27/07/2025.
    //

import Foundation
import UIKit
import SwiftUI
import Combine

    // MARK: - Image Cache Service

class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    let objectWillChange = ObservableObjectPublisher()
    
        // MARK: - Properties
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxMemoryCacheSize = 50 // Maximum number of images in memory
    private let maxDiskCacheSize = 100 * 1024 * 1024 // 100 MB disk cache
    
        // MARK: - Initialization
    private init() {
            // Configure memory cache
        memoryCache.countLimit = maxMemoryCacheSize
        memoryCache.totalCostLimit = maxMemoryCacheSize * 1024 * 1024 // 50 MB
        
            // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
            // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
            // Setup memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
            // Clean up old cache files on startup
        Task {
            await cleanupOldCacheFiles()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
        // MARK: - Public Methods
    
        /// Loads an image from cache or network
        /// - Parameters:
        ///   - urlString: The URL string of the image
        ///   - completion: Completion handler with the loaded image or nil if failed
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let cacheKey = NSString(string: urlString)
        
            // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
            // Check disk cache
        if let diskImage = loadImageFromDisk(for: cacheKey) {
            memoryCache.setObject(diskImage, forKey: cacheKey)
            completion(diskImage)
            return
        }
        
            // Download from network
        downloadImage(from: url, cacheKey: cacheKey, completion: completion)
    }
    
        /// Loads an image asynchronously using async/await
        /// - Parameter urlString: The URL string of the image
        /// - Returns: The loaded image or nil if failed
    func loadImage(from urlString: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            loadImage(from: urlString) { image in
                continuation.resume(returning: image)
            }
        }
    }
    
        /// Preloads images for better performance
        /// - Parameter urls: Array of URL strings to preload
    func preloadImages(from urls: [String]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in urls {
                    group.addTask {
                        _ = await self.loadImage(from: url)
                    }
                }
            }
        }
    }
    
        /// Preloads all images from episodes with background priority
        /// - Parameter episodes: Array of episodes containing image assets
    func preloadAllEpisodeImages(from episodes: [DREpisode], priority: TaskPriority = .background) {
        Task(priority: priority) {
            let allImageURLs = extractAllImageURLs(from: episodes)
            print("🖼️ Background preloading \(allImageURLs.count) images from \(episodes.count) episodes")
            
            await withTaskGroup(of: Void.self) { group in
                for url in allImageURLs {
                    group.addTask {
                        _ = await self.loadImage(from: url)
                    }
                }
            }
            
            print("✅ Background image preloading completed")
        }
    }
    
        /// Preloads images with different priorities based on usage patterns
        /// - Parameter episodes: Array of episodes
    func preloadImagesWithPriority(from episodes: [DREpisode]) {
            // High priority: Primary images (immediate use)
        let primaryURLs = episodes.compactMap { $0.primaryImageURL }.uniqued()
        Task(priority: .userInitiated) {
            print("🖼️ High priority: Preloading \(primaryURLs.count) primary images")
            await withTaskGroup(of: Void.self) { group in
                for url in primaryURLs {
                    group.addTask {
                        _ = await self.loadImage(from: url)
                    }
                }
            }
            print("✅ High priority image preloading completed")
        }
        
            // Medium priority: Landscape images (detail views)
        let landscapeURLs = episodes.compactMap { $0.landscapeImageURL }.uniqued()
        Task(priority: .utility) {
            print("🖼️ Medium priority: Preloading \(landscapeURLs.count) landscape images")
            await withTaskGroup(of: Void.self) { group in
                for url in landscapeURLs {
                    group.addTask {
                        _ = await self.loadImage(from: url)
                    }
                }
            }
            print("✅ Medium priority image preloading completed")
        }
        
            // Low priority: All remaining images (background)
        let allURLs = extractAllImageURLs(from: episodes)
        let remainingURLs = allURLs.filter { url in
            !primaryURLs.contains(url) && !landscapeURLs.contains(url)
        }
        
        Task(priority: .background) {
            print("🖼️ Low priority: Preloading \(remainingURLs.count) remaining images")
            await withTaskGroup(of: Void.self) { group in
                for url in remainingURLs {
                    group.addTask {
                        _ = await self.loadImage(from: url)
                    }
                }
            }
            print("✅ Low priority image preloading completed")
        }
    }
    
        /// Extracts all unique image URLs from episodes
        /// - Parameter episodes: Array of episodes
        /// - Returns: Array of unique image URLs
    private func extractAllImageURLs(from episodes: [DREpisode]) -> [String] {
        var allURLs: Set<String> = []
        
        for episode in episodes {
            allURLs.formUnion(episode.allImageURLs)
        }
        
        return Array(allURLs)
    }
    
        /// Clears all cached images
    func clearAllCaches() {
        clearMemoryCache()
        clearDiskCache()
    }
    
        /// Returns cache statistics
    func getCacheStatistics() -> (memoryCount: Int, diskSize: Int64) {
        let memoryCount = memoryCache.totalCostLimit
        let diskSize = getDiskCacheSize()
        return (memoryCount, diskSize)
    }
    
        /// Gets the current disk cache size in bytes
    private func getDiskCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, file in
            guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return total }
            return total + Int64(size)
        }
    }
    
        // MARK: - Private Methods
    
    private func downloadImage(from url: URL, cacheKey: NSString, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
                // Cache the image
            self.memoryCache.setObject(image, forKey: cacheKey)
            self.saveImageToDisk(image, for: cacheKey)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
    
    private func loadImageFromDisk(for cacheKey: NSString) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey.hash.description)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    private func saveImageToDisk(_ image: UIImage, for cacheKey: NSString) {
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey.hash.description)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        try? data.write(to: fileURL)
    }
    
    @objc private func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    private func clearDiskCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func cleanupOldCacheFiles() async {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]) else {
            return
        }
        
        let totalSize = files.reduce(0) { total, file in
            guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return total }
            return total + size
        }
        
            // If cache is too large, remove oldest files
        if totalSize > maxDiskCacheSize {
            let sortedFiles = files.sorted { file1, file2 in
                guard let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate,
                      let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                    return false
                }
                return date1 < date2
            }
            
            var currentSize = totalSize
            for file in sortedFiles {
                guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize else { continue }
                
                try? fileManager.removeItem(at: file)
                currentSize -= size
                
                if currentSize <= maxDiskCacheSize / 2 {
                    break
                }
            }
        }
    }
}

    // MARK: - Cached AsyncImage View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var imageCache = ImageCacheService.shared
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var currentURL: String?
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url?.absoluteString) { _,_ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        // Check if URL has changed
        let urlString = url.absoluteString
        if currentURL == urlString && image != nil {
            return // URL hasn't changed and we already have an image
        }
        
        isLoading = true
        currentURL = urlString
        
        Task {
            let loadedImage = await imageCache.loadImage(from: urlString)
            
            await MainActor.run {
                self.image = loadedImage
                self.isLoading = false
            }
        }
    }
}

    // MARK: - Convenience Extensions

extension CachedAsyncImage where Placeholder == EmptyView {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content) {
            EmptyView()
        }
    }
} 

