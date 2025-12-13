//
//  AppLogger.swift
//  GrokMode
//
//  Centralized logging utility for GrokMode
//

import Foundation
import OSLog

nonisolated
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.grokmode"

    static let voice = Logger(subsystem: subsystem, category: "Voice")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let tools = Logger(subsystem: subsystem, category: "Tools")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let ui = Logger(subsystem: subsystem, category: "UI")

    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Logs sensitive data only in DEBUG mode
    /// - Parameters:
    ///   - logger: The logger to use
    ///   - level: The log level
    ///   - message: The message containing sensitive data
    static func logSensitive(
        _ logger: Logger,
        level: OSLogType = .debug,
        _ message: String
    ) {
        #if DEBUG
        logger.log(level: level, "\(message, privacy: .private)")
        #else
        // In release, log that sensitive data was omitted
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
}
