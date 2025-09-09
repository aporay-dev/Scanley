//
//  Global.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI

// MARK: - Global Constants

let defaultPhotoCategories: [PhotoCategory] = [
    PhotoCategory(numPhotos: 0, title: "Documents", icon: "briefcase", color: Color(red: 1.0, green: 0.4, blue: 0.5)),
    PhotoCategory(numPhotos: 0, title: "Receipts", icon: "person.crop.rectangle.fill", color: Color(red: 0.3, green: 0.3, blue: 0.9)),
    PhotoCategory(numPhotos: 0, title: "Invoices", icon: "doc.text", color: Color(red: 0.4, green: 0.4, blue: 0.9)),
    PhotoCategory(numPhotos: 0, title: "Bills", icon: "creditcard", color: Color(red: 0.2, green: 0.6, blue: 0.8)),
    PhotoCategory(numPhotos: 0, title: "Barcodes\n& QR codes", icon: "qrcode", color: Color(red: 1.0, green: 0.6, blue: 0.2)),
    PhotoCategory(numPhotos: 0, title: "Handwritten notes", icon: "scribble.variable", color: Color(red: 0.62, green: 0.102, blue: 0.82)),
    PhotoCategory(numPhotos: 0, title: "Illustrations", icon: "hand.draw", color: Color(red: 0.19, green: 0.43, blue: 0.98)),
    PhotoCategory(numPhotos: 0, title: "Other Documents", icon: "photo", color: Color.gray)
]

// MARK: - App Configuration

struct AppConfig {
    static let maxPhotosInTestMode = 100
    static let ocrConfidenceThreshold: Float = 0.1
    static let minimumTextLength = 10
    static let maxSearchSuggestions = 5
    static let maxRecentSearches = 10
    static let batchSize = 5
}
