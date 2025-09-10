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
    
    // Document classification data
    @Published var isClassifying = false
    @Published var classificationProgress: Double = 0.0
    @Published var classificationStatus = ""
    
    private let swiftDataManager = SwiftDataManager.shared
    private let classificationViewModel = DocumentClassificationViewModel()
    
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
    
    // MARK: - Testing Methods (Temporary)
    
    func deleteAllData(context: ModelContext) async {
        do {
            try swiftDataManager.deleteAllDocumentTexts(context: context)
            print("🗑️ All SwiftData documents deleted successfully")
            
            // Reset categories to zero
            resetPhotoCategories()
            
            // Refresh the UI
            await loadScanSummary(context: context)
        } catch {
            print("❌ Error deleting all data: \(error)")
        }
    }
    
    func classifyDocuments(context: ModelContext) async {
        guard !isClassifying else {
            print("⚠️ Classification already in progress")
            return
        }
        
        print("🤖 Starting document classification from HomeViewModel")
        
        // Set up classification ViewModel
        classificationViewModel.setModelContext(context)
        
        // Update local state
        isClassifying = true
        classificationProgress = 0.0
        classificationStatus = "Initializing AI classification..."
        
        // Start classification
        await classificationViewModel.startClassification()
        
        // Update final state
        isClassifying = classificationViewModel.isClassifying
        classificationProgress = 1.0
        
        if let error = classificationViewModel.lastError {
            classificationStatus = "Classification failed: \(error)"
        } else if classificationViewModel.hasResults {
            let summary = classificationViewModel.getClassificationSummary()
            let totalClassified = classificationViewModel.classificationResults.count
            classificationStatus = "✅ Classified \(totalClassified) documents successfully!"
            
            // Print summary to console
            print("🎯 CLASSIFICATION COMPLETE:")
            for (category, count) in summary.sorted(by: { $0.1 > $1.1 }) {
                print("📊 \(category): \(count) documents")
            }
            
            // Update photoCategories with actual counts
            await updatePhotoCategoriesWithCounts()
            
            // Refresh scan summary to show updated categories
            await loadScanSummary(context: context)
        } else {
            classificationStatus = "No documents found to classify"
        }
    }
    
    // MARK: - Private Methods
    
    private func setupPhotoCategories() {
        photoCategories = [
            PhotoCategory(numPhotos: 0, title: "Tax", icon: "briefcase", color: .red.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Receipts", icon: "person.crop.rectangle.fill", color: .blue.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Invoices & Bills", icon: "doc.text", color: .blue.opacity(0.9)),
            PhotoCategory(numPhotos: 0, title: "Bank", icon: "creditcard", color: .cyan.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Medical", icon: "qrcode", color: .orange.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Legal", icon: "scribble.variable", color: .purple.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Govt", icon: "hand.draw", color: .blue.opacity(0.7)),
            PhotoCategory(numPhotos: 0, title: "Other Documents", icon: "photo", color: .gray)
        ]
    }
    
    private func resetPhotoCategories() {
        for index in photoCategories.indices {
            photoCategories[index].numPhotos = 0
        }
    }
    
    private func updatePhotoCategoriesWithCounts() async {
        let categoryCounts = classificationViewModel.getCategoryCounts()
        
        // Update photoCategories with actual counts from classification
        for index in photoCategories.indices {
            let categoryTitle = photoCategories[index].title
            
            // Map category titles to DocumentCategory enum values
            let documentCategory: DocumentCategory?
            switch categoryTitle {
            case "Tax":
                documentCategory = .tax
            case "Receipts":
                documentCategory = .receipts
            case "Invoices & Bills":
                documentCategory = .invoiceBills
            case "Bank":
                documentCategory = .bank
            case "Medical":
                documentCategory = .medical
            case "Legal":
                documentCategory = .legal
            case "Govt":
                documentCategory = .govt
            case "Other Documents":
                documentCategory = .otherDocuments
            default:
                documentCategory = nil
            }
            
            // Update count if we have a matching category
            if let docCategory = documentCategory {
                photoCategories[index].numPhotos = categoryCounts[docCategory] ?? 0
            }
        }
        
        print("📱 Updated photoCategories with classification counts:")
        for category in photoCategories {
            print("   \(category.title): \(category.numPhotos) documents")
        }
    }
}
