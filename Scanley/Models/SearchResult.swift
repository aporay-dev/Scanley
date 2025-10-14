//
//  SearchResult.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation

struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let documentID: String
    let documentType: String
    let dateExtracted: Date
    let extractedText: String
    let matchingSnippets: [String]
    let relevanceScore: Float
    let ocrConfidence: Float
    let textSummary: String?
    
    var primarySnippet: String {
        return matchingSnippets.first ?? textSummary ?? "No text preview available"
    }
    
    // Helper to get DocumentType enum from string
    var documentTypeEnum: DocumentType {
        return DocumentType(rawValue: documentType) ?? .receipts
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.id == rhs.id
    }
}