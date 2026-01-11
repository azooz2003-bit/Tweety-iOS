//
//  ImageCache.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/31/25.
//

import SwiftUI
internal import os

actor ImageCache {
    private var memoryCache: [String: CachedImage] = [:]
    private let maxMemoryCacheSize: Int

    init(maxMemoryCacheSize: Int = 200) {
        self.maxMemoryCacheSize = maxMemoryCacheSize
    }

    @discardableResult
    func image(for url: URL) async throws -> UIImage {
        let cacheKey = url.absoluteString

        if let cached = memoryCache[cacheKey] {
            return cached.image
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }

        memoryCache[cacheKey] = CachedImage(image: image)
        enforceMemoryLimit()

        return image
    }

    func prefetch(urls: [URL]) {
        Task {
            for url in urls {
                do {
                    try await image(for: url)
                } catch {
                    AppLogger.ui.warning("Image for \(url) failed to load: \(error.localizedDescription)")
                }
            }
        }
    }

    func clearCache() {
        memoryCache.removeAll()
    }

    func getCacheCount() -> Int {
        return memoryCache.count
    }

    private func enforceMemoryLimit() {
        guard memoryCache.count > maxMemoryCacheSize else { return }

        let sortedKeys = memoryCache.keys.sorted { key1, key2 in
            let date1 = memoryCache[key1]?.timestamp ?? Date.distantPast
            let date2 = memoryCache[key2]?.timestamp ?? Date.distantPast
            return date1 < date2
        }

        let keysToRemove = sortedKeys.prefix(memoryCache.count - maxMemoryCacheSize)
        keysToRemove.forEach { memoryCache.removeValue(forKey: $0) }
    }
}
