//
//  SwiftDataManager.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation
import SwiftData

@MainActor
class SwiftDataManager: ObservableObject {
    
    static let shared = SwiftDataManager()
    
    private init() {}
    
    // MARK: - DocumentText Operations
    
    func saveDocumentText(_ documentText: DocumentText, context: ModelContext) throws {
        context.insert(documentText)
        try context.save()
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