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
    var body: some Scene {
        WindowGroup {
            Home()
        }
        .modelContainer(for: DocumentText.self)
    }
}
