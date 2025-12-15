//
//  XMedia.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

struct XMedia: Codable, Identifiable, Sendable {
    let media_key: String
    let type: String  // "photo", "video", "animated_gif"
    let url: String?  // Image URL for photos
    let preview_image_url: String?  // For videos/gifs
    let width: Int?
    let height: Int?

    var id: String { media_key }

    // Get the best URL to display (prefer url for photos, preview for videos)
    nonisolated var displayUrl: String? {
        url ?? preview_image_url
    }
}
