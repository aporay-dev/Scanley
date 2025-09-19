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
    @Published var showSimpleOCR = false

    // Photo category data
    @Published var photoCategories: [PhotoCategory] = []

    // Category detail navigation
    @Published var selectedCategory: PhotoCategory?
    @Published var showCategoryDetail = false
    
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

            // Load category counts from existing data
            await loadCategoryCounts(context: context)

            if totalDocumentsFound == 0 {
                print("📄 No documents in database - user needs to scan documents first")
            }

        } catch {
            print("❌ Error loading scan summary: \(error)")
            totalDocumentsFound = 0
            lastScanDate = nil
        }
    }

    func loadCategoryCounts(context: ModelContext) async {
        do {
            let allDocuments = try swiftDataManager.fetchAllDocumentTexts(context: context)

            // Count documents by category
            var categoryCounts: [String: Int] = [:]
            for document in allDocuments {
                let category = document.documentType
                categoryCounts[category, default: 0] += 1
            }

            print("🔍 DEBUG: Found category counts from SwiftData:")
            print("🔍 DEBUG: Total documents: \(allDocuments.count)")
            for (category, count) in categoryCounts.sorted(by: { $0.1 > $1.1 }) {
                print("   \(category): \(count) documents")
            }

            // Debug: Check for unexpected document types
            let knownTypes = ["Tax", "Receipts", "Invoices & Bills", "Bank", "Medical", "Legal", "Govt", "Insurance", "Text Document"]
            let unknownTypes = categoryCounts.keys.filter { !knownTypes.contains($0) }
            if !unknownTypes.isEmpty {
                print("⚠️ DEBUG: Found unexpected document types:")
                for unknownType in unknownTypes {
                    print("   Unknown: '\(unknownType)' (\(categoryCounts[unknownType] ?? 0) documents)")
                }
            }

            // Handle "Text Document" type (from simple OCR scan before classification)
            if let textDocumentCount = categoryCounts["Text Document"] {
                print("📄 DEBUG: Found \(textDocumentCount) unclassified 'Text Document' entries")
                print("💡 These documents need to be classified to appear in categories")
                // Note: We don't show these in any category until they're properly classified
            }

            // Update photoCategories with actual counts
            for index in photoCategories.indices {
                let categoryTitle = photoCategories[index].title

                // Map category titles to document type strings (must match DocumentCategory enum values)
                let documentTypeString: String
                switch categoryTitle {
                case "Tax":
                    documentTypeString = "Tax"
                case "Receipts":
                    documentTypeString = "Receipts"
                case "Invoices & Bills":
                    documentTypeString = "Invoices & Bills"  // Fixed: matches enum exactly
                case "Bank":
                    documentTypeString = "Bank"
                case "Medical":
                    documentTypeString = "Medical"
                case "Legal":
                    documentTypeString = "Legal"
                case "Govt":
                    documentTypeString = "Govt"  // Fixed: matches enum exactly
                case "Insurance":
                    documentTypeString = "Insurance"
                default:
                    documentTypeString = categoryTitle
                }

                photoCategories[index].numPhotos = categoryCounts[documentTypeString] ?? 0
            }

            print("📱 Updated photoCategories with SwiftData counts:")
            for category in photoCategories {
                print("   \(category.title): \(category.numPhotos) documents")
            }

        } catch {
            print("❌ Error loading category counts: \(error)")
            // Reset to 0 if there's an error
            resetPhotoCategories()
        }
    }
    
    
    
    func openSimpleOCR() {
        showSimpleOCR = true
    }

    func openCategoryDetail(for category: PhotoCategory) {
        selectedCategory = category
        showCategoryDetail = true
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
            PhotoCategory(numPhotos: 0, title: "Receipts", icon: "newspaper", color: .blue.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Invoices & Bills", icon: "doc.text", color: .blue.opacity(0.9)),
            PhotoCategory(numPhotos: 0, title: "Bank", icon: "creditcard", color: .cyan.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Medical", icon: "cross", color: .orange.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Legal", icon: "signature", color: .purple.opacity(0.8)),
            PhotoCategory(numPhotos: 0, title: "Govt", icon: "building.columns", color: .blue.opacity(0.7)),
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
