//
//  AppEnvironment.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Log Levels

enum LogLevel: Int, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - App Settings Environment

@MainActor
class AppSettingsEnvironment: ObservableObject {
    @Published var ocrConfidenceThreshold: Float = 0.1
    @Published var minimumTextLength: Int = 10

    // Logging settings
    @Published var isLoggingEnabled: Bool
    @Published var logLevel: LogLevel

    static let shared = AppSettingsEnvironment()

    private init() {
        #if DEBUG
        self.isLoggingEnabled = true
        self.logLevel = .debug
        #else
        self.isLoggingEnabled = false
        self.logLevel = .error
        #endif
    }

    func updateLoggingSettings(enabled: Bool, level: LogLevel) {
        isLoggingEnabled = enabled
        logLevel = level
        AppLogger.shared.setLoggingEnabled(enabled)
        AppLogger.shared.setMinimumLogLevel(level)
    }
}

// MARK: - Scan State Environment

@MainActor
class ScanStateEnvironment: ObservableObject {
    @Published var lastScanDate: Date?
    @Published var totalDocumentsFound: Int = 0
    @Published var isCurrentlyScanning: Bool = false
    @Published var currentScanProgress: Double = 0.0
    @Published var currentScanMessage: String = ""
    
    static let shared = ScanStateEnvironment()
    
    private init() {}
    
    func updateScanProgress(_ progress: Double, message: String) {
        currentScanProgress = progress
        currentScanMessage = message
    }
    
    func startScan() {
        isCurrentlyScanning = true
        currentScanProgress = 0.0
        currentScanMessage = AlertManager.ocrMessages.scanStarted
    }
    
    func completeScan(documentsFound: Int) {
        isCurrentlyScanning = false
        totalDocumentsFound = documentsFound
        lastScanDate = Date()
        currentScanProgress = 1.0
        currentScanMessage = AlertManager.ocrMessages.scanCompleted
    }
    
    func cancelScan() {
        isCurrentlyScanning = false
        currentScanProgress = 0.0
        currentScanMessage = AlertManager.ocrMessages.scanCancelled
    }
    
    func resetScan() {
        isCurrentlyScanning = false
        currentScanProgress = 0.0
        currentScanMessage = ""
    }
}

// MARK: - Search State Environment

@MainActor
class SearchStateEnvironment: ObservableObject {
    @Published var currentSearchQuery: String = ""
    @Published var isSearching: Bool = false
    @Published var searchResults: [SearchResult] = []
    @Published var recentSearches: [String] = []
    @Published var searchSuggestions: [String] = []
    
    static let shared = SearchStateEnvironment()
    
    private init() {}
    
    func startSearch(query: String) {
        currentSearchQuery = query
        isSearching = true
        addToRecentSearches(query)
    }
    
    func completeSearch(results: [SearchResult]) {
        searchResults = results
        isSearching = false
    }
    
    func clearSearch() {
        currentSearchQuery = ""
        searchResults = []
        searchSuggestions = []
        isSearching = false
    }
    
    func updateSuggestions(_ suggestions: [String]) {
        searchSuggestions = suggestions
    }
    
    private func addToRecentSearches(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty && !recentSearches.contains(trimmedQuery) else { return }
        
        recentSearches.insert(trimmedQuery, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
    }
}

// MARK: - Environment Keys

struct AppSettingsEnvironmentKey: EnvironmentKey {
    @MainActor static var defaultValue: AppSettingsEnvironment {
        AppSettingsEnvironment.shared
    }
}

struct ScanStateEnvironmentKey: EnvironmentKey {
    @MainActor static var defaultValue: ScanStateEnvironment {
        ScanStateEnvironment.shared
    }
}

struct SearchStateEnvironmentKey: EnvironmentKey {
    @MainActor static var defaultValue: SearchStateEnvironment {
        SearchStateEnvironment.shared
    }
}

extension EnvironmentValues {
    var appSettings: AppSettingsEnvironment {
        get { self[AppSettingsEnvironmentKey.self] }
        set { self[AppSettingsEnvironmentKey.self] = newValue }
    }
    
    var scanState: ScanStateEnvironment {
        get { self[ScanStateEnvironmentKey.self] }
        set { self[ScanStateEnvironmentKey.self] = newValue }
    }
    
    var searchState: SearchStateEnvironment {
        get { self[SearchStateEnvironmentKey.self] }
        set { self[SearchStateEnvironmentKey.self] = newValue }
    }
}