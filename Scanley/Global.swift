//
//  Global.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI

// MARK: - Global Constants

let defaultPhotoCategories: [PhotoCategory] = [
    PhotoCategory(numPhotos: 0, title: "Tax", icon: "briefcase", color: Color(red: 0.0, green: 0.7, blue: 0.0)),
    PhotoCategory(numPhotos: 0, title: "Receipts", icon: "receipt", color: Color(red: 0.3, green: 0.3, blue: 0.9)),
    PhotoCategory(numPhotos: 0, title: "Invoices & Bills", icon: "doc.text", color: Color(red: 0.4, green: 0.4, blue: 0.9)),
    PhotoCategory(numPhotos: 0, title: "Bank", icon: "creditcard", color: Color(red: 0.2, green: 0.6, blue: 0.8)),
    PhotoCategory(numPhotos: 0, title: "Medical", icon: "cross.fill", color: Color(red: 0.8, green: 0.2, blue: 0.4)),
    PhotoCategory(numPhotos: 0, title: "Legal", icon: "scale.3d", color: Color(red: 0.6, green: 0.4, blue: 0.2)),
    PhotoCategory(numPhotos: 0, title: "Govt", icon: "building.columns", color: Color(red: 0.5, green: 0.2, blue: 0.8)),
    PhotoCategory(numPhotos: 0, title: "Insurance", icon: "shield.checkered", color: Color(red: 0.2, green: 0.8, blue: 0.6)),
]

// MARK: - App Configuration

struct AppConfig {
    static let ocrConfidenceThreshold: Float = 0.1
    static let minimumTextLength = 10
    static let maxSearchSuggestions = 5
    static let maxRecentSearches = 10
    static let batchSize = 5
}
