//
//  PerformanceMonitor.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation

@MainActor
class PerformanceMonitor: ObservableObject {
    
    static let shared = PerformanceMonitor()
    
    private var recentProcessingTimes: [TimeInterval] = []
    private let maxHistoryCount = 20
    
    private init() {}
    
    // MARK: - Device Capabilities
    
    func optimalBatchSize() -> Int {
        let processInfo = ProcessInfo.processInfo
        let memoryGB = processInfo.physicalMemory / (1024 * 1024 * 1024)
        let coreCount = processInfo.activeProcessorCount
        
        // Device-aware batch sizing
        switch (memoryGB, coreCount) {
        case (8..., 6...):  return 12  // iPhone 15 Pro, high-end devices
        case (6..., 4...):  return 10  // iPhone 14/15, mid-range
        case (4..., 2...):  return 8   // iPhone 12/13, older devices
        default:            return 6   // Conservative fallback
        }
    }
    
    // MARK: - Performance Tracking
    
    func recordProcessingTime(_ time: TimeInterval) {
        recentProcessingTimes.append(time)
        
        // Keep only recent history
        if recentProcessingTimes.count > maxHistoryCount {
            recentProcessingTimes.removeFirst()
        }
    }
    
    func averageProcessingTime() -> TimeInterval {
        guard !recentProcessingTimes.isEmpty else { return 0.1 }
        return recentProcessingTimes.reduce(0, +) / Double(recentProcessingTimes.count)
    }
    
    // MARK: - Dynamic Throttling
    
    func shouldThrottle() -> TimeInterval {
        let avgTime = averageProcessingTime()
        let memoryPressure = getCurrentMemoryPressure()
        
        switch (avgTime, memoryPressure) {
        case (..<0.1, .normal):   return 0.0      // No delay needed
        case (..<0.2, .normal):   return 0.01     // Minimal delay  
        case (..<0.3, .warning):  return 0.025    // Light throttling
        case (..<0.5, .warning):  return 0.05     // Medium throttling
        case (_, .critical):      return 0.1      // Heavy throttling
        default:                  return 0.03     // Default fallback
        }
    }
    
    private func getCurrentMemoryPressure() -> MemoryPressure {
        // For now, return normal - can be enhanced with actual memory monitoring later
        // The DispatchSource approach requires more setup and proper lifecycle management
        return .normal
    }
    
    // MARK: - Performance Metrics
    
    func getPerformanceStats() -> PerformanceStats {
        return PerformanceStats(
            optimalBatchSize: optimalBatchSize(),
            averageProcessingTime: averageProcessingTime(),
            recommendedThrottle: shouldThrottle(),
            totalProcessedCount: recentProcessingTimes.count
        )
    }
    
    func resetStats() {
        recentProcessingTimes.removeAll()
    }
}

// MARK: - Supporting Types

enum MemoryPressure {
    case normal
    case warning  
    case critical
}

struct PerformanceStats {
    let optimalBatchSize: Int
    let averageProcessingTime: TimeInterval
    let recommendedThrottle: TimeInterval
    let totalProcessedCount: Int
}