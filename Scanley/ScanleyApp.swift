//
//  ScanleyApp.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import SwiftData

@main
struct ScanleyApp: App {
    @State private var hasPerformedAppLaunchCleanup = false
    @State private var isPerformingCleanup = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            if isPerformingCleanup || !hasPerformedAppLaunchCleanup {
                StartupScreen()
                    .task {
                        if !hasPerformedAppLaunchCleanup {
                            isPerformingCleanup = true

                            // Initialize subscription manager
                            await subscriptionManager.initialize()

                            // Perform app launch cleanup
                            await performAppLaunchCleanup()
                            hasPerformedAppLaunchCleanup = true

                            // Add a small delay to ensure smooth transition
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            isPerformingCleanup = false
                        }
                    }
            } else {
                Home()
                    .environmentObject(subscriptionManager)
            }
        }
        .modelContainer(for: DocumentText.self)
    }
    
    @MainActor
    private func performAppLaunchCleanup() async {
        // Initialize logger
        let logger = AppLogger.shared
        logger.info("Scanley app launched - starting orphaned records cleanup", category: .lifecycle)


        do {
            let container = try ModelContainer(for: DocumentText.self)
            let context = container.mainContext
            let swiftDataManager = SwiftDataManager.shared

            let cleanedCount = try swiftDataManager.performAppLaunchCleanup(context: context)

            if cleanedCount > 0 {
                logger.info("App launch cleanup summary: \(cleanedCount) orphaned records were removed from SwiftData", category: .database)
            } else {
                logger.debug("App launch cleanup completed: No orphaned records found", category: .database)
            }

        } catch {
            logger.error("App launch cleanup failed: \(error.localizedDescription)", category: .database)
        }
    }
}
