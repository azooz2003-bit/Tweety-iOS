//
//  CachedImage.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/31/25.
//

import SwiftUI

nonisolated
struct CachedImage {
    let image: UIImage
    let timestamp: Date

    init(image: UIImage) {
        self.image = image
        self.timestamp = Date()
    }
}

nonisolated
enum ImageCacheError: Error, LocalizedError {
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Failed to decode image data"
        }
    }
}
