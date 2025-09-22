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


            // Get the most recent document date as last scan date
            let allDocuments = try swiftDataManager.fetchAllDocumentTexts(context: context)
            lastScanDate = allDocuments.map { $0.dateExtracted }.max()

            // Load category counts from existing data
            await loadCategoryCounts(context: context)

            if totalDocumentsFound == 0 {
            }

        } catch {
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


            // Debug: Check for unexpected document types
            let knownTypes = ["Tax", "Receipts", "Invoices & Bills", "Bank", "Medical", "Legal", "Govt", "Insurance"]
            let unknownTypes = categoryCounts.keys.filter { !knownTypes.contains($0) }
            if !unknownTypes.isEmpty {
            }

            // Handle "Text Document" type (from simple OCR scan before classification)
            if categoryCounts["Text Document"] != nil {
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


        } catch {
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
            
            // Reset categories to zero
            resetPhotoCategories()
            
            // Refresh the UI
            await loadScanSummary(context: context)
        } catch {
        }
    }
    
    func classifyDocuments(context: ModelContext) async {
        guard !isClassifying else {
            return
        }
        
        
        // DEBUG: Check document count before classification
        do {
            _ = try swiftDataManager.fetchAllDocumentTexts(context: context)
        } catch {
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
            _ = classificationViewModel.getClassificationSummary()
            let totalClassified = classificationViewModel.classificationResults.count
            classificationStatus = "✅ Classified \(totalClassified) documents successfully!"
            
            
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
        
    }
}
