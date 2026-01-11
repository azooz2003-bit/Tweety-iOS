//
//  AppLogger.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import Foundation
import OSLog

nonisolated
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.tweety.app"

    static let voice = Logger(subsystem: subsystem, category: "Voice")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let tools = Logger(subsystem: subsystem, category: "Tools")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let store = Logger(subsystem: subsystem, category: "Store")
    static let usage = Logger(subsystem: subsystem, category: "Usage")

    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Logs sensitive data only in DEBUG mode
    static func logSensitive(
        _ logger: Logger,
        level: OSLogType = .debug,
        _ message: String
    ) {
        #if DEBUG
        logger.log(level: level, "\(message, privacy: .private)")
        #else
        logger.log(level: level, "[Sensitive data omitted]")
        #endif
    }

    /// Redacts sensitive parts of a string for logging
    /// - Parameters:
    ///   - value: The sensitive value (e.g., API key, token)
    ///   - visiblePrefix: Number of characters to show at the start (default: 4)
    ///   - visibleSuffix: Number of characters to show at the end (default: 4)
    /// - Returns: Redacted string like "abcd...xyz123"
    static func redacted(_ value: String, visiblePrefix: Int = 4, visibleSuffix: Int = 4) -> String {
        guard value.count > (visiblePrefix + visibleSuffix) else {
            return String(repeating: "*", count: value.count)
        }

        let prefix = value.prefix(visiblePrefix)
        let suffix = value.suffix(visibleSuffix)
        return "\(prefix)...\(suffix)"
    }

    static func prettyJSON(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return String(data: data, encoding: .utf8) ?? "Unable to decode"
        }
        return prettyString
    }

    static func prettyJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8) else {
            return jsonString
        }
        return prettyJSON(data)
    }
}
