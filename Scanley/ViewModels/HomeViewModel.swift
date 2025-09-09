//
//  HomeViewModel.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation
import SwiftData

@MainActor
class HomeViewModel: ObservableObject {
    @Published var showScanResults = false
    @Published var showSearchView = false
    @Published var showSimpleOCR = false
    
    // Photo category data
    @Published var photoCategories: [PhotoCategory] = []
    
    // Scan summary data
    @Published var lastScanDate: Date?
    @Published var totalDocumentsFound: Int = 0
    
    private let swiftDataManager = SwiftDataManager.shared
    
    init() {
        setupPhotoCategories()
    }
    
    // MARK: - Public Methods
    
    func loadScanSummary(context: ModelContext) async {
        do {
            let statistics = try swiftDataManager.getDocumentStatistics(context: context)
            totalDocumentsFound = statistics.totalDocumentsWithText
            
            // Get the most recent document date as last scan date
            let allDocuments = try swiftDataManager.fetchAllDocumentTexts(context: context)
            lastScanDate = allDocuments.map { $0.dateExtracted }.max()
            
        } catch {
            print("❌ Error loading scan summary: \(error)")
            totalDocumentsFound = 0
            lastScanDate = nil
        }
    }
    
    func openScanResults() {
        showScanResults = true
    }
    
    func openSearchView() {
        showSearchView = true
    }
    
    func openSimpleOCR() {
        showSimpleOCR = true
    }
    
    // MARK: - Private Methods
    
    private func setupPhotoCategories() {
        photoCategories = [
            PhotoCategory(numPhotos: 0, title: "Documents", icon: "briefcase", color: .red.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Receipts", icon: "person.crop.rectangle.fill", color: .blue.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Invoices", icon: "doc.text", color: .blue.opacity(0.9)),
            PhotoCategory(numPhotos: 0, title: "Bills", icon: "creditcard", color: .cyan.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Barcodes\n& QR codes", icon: "qrcode", color: .orange.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Handwritten notes", icon: "scribble.variable", color: .purple.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Illustrations", icon: "hand.draw", color: .blue.opacity(0.7)),
            PhotoCategory(numPhotos: 0, title: "Other Documents", icon: "photo", color: .gray)
        ]
    }
}