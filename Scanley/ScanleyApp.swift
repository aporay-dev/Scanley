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
    
    var body: some Scene {
        WindowGroup {
            Home()
                .task {
                    if !hasPerformedAppLaunchCleanup {
                        await performAppLaunchCleanup()
                        hasPerformedAppLaunchCleanup = true
                    }
                }
        }
        .modelContainer(for: DocumentText.self)
    }
    
    @MainActor
    private func performAppLaunchCleanup() async {
        print("🚀 Scanley app launched - starting orphaned records cleanup...")
        
        do {
            let container = try ModelContainer(for: DocumentText.self)
            let context = container.mainContext
            let swiftDataManager = SwiftDataManager.shared
            
            let cleanedCount = try swiftDataManager.performAppLaunchCleanup(context: context)
            
            if cleanedCount > 0 {
                print("🎯 App launch cleanup summary: \(cleanedCount) orphaned records were removed from SwiftData")
            }
            
        } catch {
            print("❌ App launch cleanup failed: \(error.localizedDescription)")
        }
    }
}
