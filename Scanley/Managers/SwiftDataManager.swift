//
//  SwiftDataManager.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation
import SwiftData
import Photos

@MainActor
class SwiftDataManager: ObservableObject {
    
    static let shared = SwiftDataManager()
    
    private init() {}
    
    // MARK: - DocumentText Operations
    
    func saveDocumentText(_ documentText: DocumentText, context: ModelContext) throws {
        context.insert(documentText)
        try context.save()
    }
    
    // MARK: - Batch Operations (Performance Optimized)
    
    func saveBatchDocumentTexts(_ documentTexts: [DocumentText], context: ModelContext) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Batch insert all documents
        for documentText in documentTexts {
            context.insert(documentText)
        }
        
        // Single save operation for entire batch
        try context.save()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("📊 Batch saved \(documentTexts.count) documents in \(String(format: "%.3f", duration))s")
    }
    
    // MARK: - Background Context Support
    
    func createBackgroundContext(from container: ModelContainer) -> ModelContext {
        let backgroundContext = ModelContext(container)
        print("🔧 Created background context for batch operations")
        return backgroundContext
    }
    
    func fetchAllDocumentTexts(context: ModelContext) throws -> [DocumentText] {
        let descriptor = FetchDescriptor<DocumentText>()
        return try context.fetch(descriptor)
    }
    
    func fetchDocumentText(by documentID: String, context: ModelContext) throws -> DocumentText? {
        let descriptor = FetchDescriptor<DocumentText>(
            predicate: #Predicate { $0.documentID == documentID }
        )
        return try context.fetch(descriptor).first
    }
    
    func documentTextExists(for documentID: String, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<DocumentText>(
            predicate: #Predicate { $0.documentID == documentID }
        )
        let existingTexts = try context.fetch(descriptor)
        return !existingTexts.isEmpty
    }
    
    func deleteDocumentText(_ documentText: DocumentText, context: ModelContext) throws {
        context.delete(documentText)
        try context.save()
    }
    
    func deleteAllDocumentTexts(context: ModelContext) throws {
        let descriptor = FetchDescriptor<DocumentText>()
        let allTexts = try context.fetch(descriptor)
        for text in allTexts {
            context.delete(text)
        }
        try context.save()
    }
    
    // MARK: - Search Operations
    
    func searchDocumentTexts(
        query: String,
        context: ModelContext
    ) throws -> [DocumentText] {
        let searchTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !searchTerms.isEmpty else { return [] }
        
        // Fetch all documents and filter in memory for complex text matching
        let descriptor = FetchDescriptor<DocumentText>()
        let allDocumentTexts = try context.fetch(descriptor)
        
        return allDocumentTexts.filter { documentText in
            let text = documentText.extractedText.lowercased()
            let keyPhrases = documentText.keyPhrases
            let summary = documentText.textSummary?.lowercased() ?? ""
            
            return searchTerms.contains { term in
                let termLower = term.lowercased()
                return text.contains(termLower) || 
                       keyPhrases.contains(where: { $0.contains(termLower) }) ||
                       summary.contains(termLower)
            }
        }
    }
    
    // MARK: - App Launch Orphaned Records Cleanup
    
    func performAppLaunchCleanup(context: ModelContext) throws -> Int {
        print("🧹 Starting app launch cleanup - checking for orphaned records...")
        
        let allDocuments = try fetchAllDocumentTexts(context: context)
        var cleanedCount = 0
        
        for document in allDocuments {
            if !isPhotoLibraryAssetValid(documentID: document.documentID) {
                print("🗑️  Cleaning up orphaned record: \(document.documentID.prefix(8))... (Text: \(String(document.extractedText.prefix(50)))...)")
                context.delete(document)
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
            try context.save()
            print("✅ App launch cleanup completed: \(cleanedCount) orphaned records removed")
        } else {
            print("✅ App launch cleanup completed: No orphaned records found")
        }
        
        return cleanedCount
    }
    
    private func isPhotoLibraryAssetValid(documentID: String) -> Bool {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", documentID)
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        return assets.firstObject != nil
    }
    
    // MARK: - Statistics
    
    func getDocumentStatistics(context: ModelContext) throws -> DocumentStatistics {
        let allTexts = try fetchAllDocumentTexts(context: context)
        
        let totalDocuments = allTexts.count
        let averageConfidence = allTexts.isEmpty ? 0.0 : 
            allTexts.map { $0.confidence }.reduce(0, +) / Float(allTexts.count)
        
        let typeDistribution = Dictionary(grouping: allTexts, by: { $0.documentType })
            .mapValues { $0.count }
        
        return DocumentStatistics(
            totalDocumentsWithText: totalDocuments,
            averageOCRConfidence: averageConfidence,
            documentTypeDistribution: typeDistribution
        )
    }
}

struct DocumentStatistics {
    let totalDocumentsWithText: Int
    let averageOCRConfidence: Float
    let documentTypeDistribution: [String: Int]
}