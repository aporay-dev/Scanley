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
    @Published var showSearchView = false
    @Published var showSimpleOCR = false
    @Published var selectedCategory: String? = nil
    
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
            
            print("🔍 DEBUG: loadScanSummary found \(totalDocumentsFound) documents in SwiftData")
            
            // Get the most recent document date as last scan date
            let allDocuments = try swiftDataManager.fetchAllDocumentTexts(context: context)
            lastScanDate = allDocuments.map { $0.dateExtracted }.max()
            
            if totalDocumentsFound == 0 {
                print("📄 No documents in database - user needs to scan documents first")
            }
            
        } catch {
            print("❌ Error loading scan summary: \(error)")
            totalDocumentsFound = 0
            lastScanDate = nil
        }
    }
    
    
    func openSearchView() {
        selectedCategory = nil  // Clear any previous category filter
        showSearchView = true
    }
    
    func openCategorySearch(for category: PhotoCategory) {
        selectedCategory = category.title
        showSearchView = true
        print("🔍 Opening search for category: \(category.title)")
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
        
        // DEBUG: Check document count before classification
        do {
            let allDocs = try swiftDataManager.fetchAllDocumentTexts(context: context)
            print("🔍 DEBUG: HomeViewModel sees \(allDocs.count) documents in context before classification")
            if allDocs.count > 0 {
                print("📋 DEBUG: Sample documents in HomeViewModel context:")
                for (index, doc) in allDocs.prefix(3).enumerated() {
                    print("   \(index + 1). ID: \(doc.documentID.prefix(8))... Type: \(doc.documentType)")
                }
            }
        } catch {
            print("❌ DEBUG: Error fetching documents in HomeViewModel: \(error)")
        }
        
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
            print("🔍 DEBUG: Classification completed but no results found")
            print("💡 This means no DocumentText records exist in SwiftData database")
            print("🚀 Next steps: Scan documents to populate data first, then try 'Classify' again")
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
            PhotoCategory(numPhotos: 0, title: "Insurance", icon: "shield.checkered", color: .green.opacity(0.8)),
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
            case "Insurance":
                documentCategory = .insurance
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
