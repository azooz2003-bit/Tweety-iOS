//
//  GenericProperties.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import Foundation
import UIKit

struct GenericProperties: Encodable {
    let gitRevision: String
    let localizedName: String
    let debugBuild: Bool
    let isSimulator: Bool
    let physicalMemory: UInt64
    let physicalCores: Int
    let screenSize: String
    let screenScale: CGFloat

    enum CodingKeys: String, CodingKey {
        case gitRevision = "git_revision"
        case localizedName = "localized_name"
        case debugBuild = "debug_build"
        case isSimulator = "is_simulator"
        case physicalMemory = "physical_memory"
        case physicalCores = "physical_cores"
        case screenSize = "screen_size"
        case screenScale = "screen_scale"
    }

    static var current: GenericProperties {
        GenericProperties(
            gitRevision: gitRevision,
            localizedName: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "",
            debugBuild: isDebugBuild,
            isSimulator: isSimulator,
            physicalMemory: ProcessInfo.processInfo.physicalMemory,
            physicalCores: ProcessInfo.processInfo.activeProcessorCount,
            screenSize: "\(Int(UIScreen.current?.bounds.size.width ?? 0))x\(Int(UIScreen.current?.bounds.size.height ?? 0))",
            screenScale: UIScreen.current?.scale ?? 0
        )
    }

    private static var gitRevision: String {
        Bundle.main.object(forInfoDictionaryKey: "GitRevision") as? String ?? "unknown"
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
