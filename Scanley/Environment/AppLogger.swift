//
//  AppLogger.swift
//  Scanley
//
//  Created by Claude on 2025-09-22.
//

import Foundation
import os.log

// MARK: - Log Categories

enum LogCategory: String, CaseIterable {
    case ocr = "OCR"
    case classification = "Classification"
    case search = "Search"
    case database = "Database"
    case performance = "Performance"
    case ui = "UI"
    case network = "Network"
    case memory = "Memory"
    case lifecycle = "Lifecycle"
    case fileSystem = "FileSystem"

    var subsystem: String {
        return "com.myriadtechlabs.Scanley"
    }

    var osLog: OSLog {
        return OSLog(subsystem: subsystem, category: self.rawValue)
    }
}

// MARK: - Build Configuration Detection

struct BuildConfiguration {
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var isRelease: Bool {
        return !isDebug
    }

    static var minimumLogLevel: LogLevel {
        #if DEBUG
        return .debug  // Show all logs in debug builds
        #else
        return .error  // Only show errors and critical in release builds
        #endif
    }
}

// MARK: - App Logger

@MainActor
class AppLogger: ObservableObject {
    static let shared = AppLogger()

    @Published var isLoggingEnabled: Bool
    @Published var currentLogLevel: LogLevel

    private let logQueue = DispatchQueue(label: "com.scanley.logging", qos: .utility)
    private var logHistory: [LogEntry] = []
    private let maxLogHistorySize = 1000

    private init() {
        self.isLoggingEnabled = BuildConfiguration.isDebug
        self.currentLogLevel = BuildConfiguration.minimumLogLevel
    }

    // MARK: - Public Logging Methods

    func debug(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Core Logging Method

    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        // Check if logging is enabled and meets minimum level
        guard isLoggingEnabled && level.rawValue >= currentLogLevel.rawValue else {
            return
        }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = Date()

        logQueue.async { [weak self] in
            // Create log entry
            let logEntry = LogEntry(
                timestamp: timestamp,
                level: level,
                category: category,
                message: message,
                file: fileName,
                function: function,
                line: line
            )

            // Add to history
            DispatchQueue.main.async {
                self?.addToHistory(logEntry)
            }

            // Log to system
            self?.logToSystem(logEntry)

            // Log to console in debug builds
            if BuildConfiguration.isDebug {
                self?.logToConsole(logEntry)
            }
        }
    }

    // MARK: - System Logging

    private func logToSystem(_ entry: LogEntry) {
        let osLog = entry.category.osLog
        let logMessage = "\(entry.message) [\(entry.file):\(entry.line)]"

        os_log("%{public}@", log: osLog, type: entry.level.osLogType, logMessage)
    }

    // MARK: - Console Logging (Debug Only)

    private func logToConsole(_ entry: LogEntry) {
        let timestamp = DateFormatter.logTimestamp.string(from: entry.timestamp)
        let levelIcon = entry.level.emoji
        let categoryLabel = "[\(entry.category.rawValue)]"
        let location = "[\(entry.file):\(entry.line)]"

        let logLine = "\(timestamp) \(levelIcon) \(categoryLabel) \(entry.message) \(location)"
        print(logLine)
    }

    // MARK: - Log History Management

    private func addToHistory(_ entry: LogEntry) {
        logHistory.append(entry)

        // Trim history if it gets too large
        if logHistory.count > maxLogHistorySize {
            logHistory.removeFirst(logHistory.count - maxLogHistorySize)
        }
    }

    func getLogHistory(category: LogCategory? = nil, level: LogLevel? = nil) -> [LogEntry] {
        var filteredLogs = logHistory

        if let category = category {
            filteredLogs = filteredLogs.filter { $0.category == category }
        }

        if let level = level {
            filteredLogs = filteredLogs.filter { $0.level.rawValue >= level.rawValue }
        }

        return filteredLogs.suffix(100).reversed() // Return most recent 100 entries
    }

    func clearLogHistory() {
        logHistory.removeAll()
    }

    // MARK: - Configuration

    func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
    }

    func setMinimumLogLevel(_ level: LogLevel) {
        currentLogLevel = level
    }

    // MARK: - Performance Logging

    func logPerformance<T>(_ operationName: String, category: LogCategory = .performance, operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            self.debug("Performance: \(operationName) completed in \(String(format: "%.3f", duration))s", category: category)
        }
        return try operation()
    }

    func logAsyncPerformance<T>(_ operationName: String, category: LogCategory = .performance, operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            self.debug("Async Performance: \(operationName) completed in \(String(format: "%.3f", duration))s", category: category)
        }
        return try await operation()
    }
}

// MARK: - Log Entry Model

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let file: String
    let function: String
    let line: Int
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Convenience Global Functions

/// Global convenience function for debug logging
func logDebug(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        AppLogger.shared.debug(message, category: category, file: file, function: function, line: line)
    }
}

/// Global convenience function for info logging
func logInfo(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        AppLogger.shared.info(message, category: category, file: file, function: function, line: line)
    }
}

/// Global convenience function for warning logging
func logWarning(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        AppLogger.shared.warning(message, category: category, file: file, function: function, line: line)
    }
}

/// Global convenience function for error logging
func logError(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        AppLogger.shared.error(message, category: category, file: file, function: function, line: line)
    }
}

/// Global convenience function for critical logging
func logCritical(_ message: String, category: LogCategory = .lifecycle, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        AppLogger.shared.critical(message, category: category, file: file, function: function, line: line)
    }
}