//
//  SearchResult.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation

struct SearchResult: Identifiable {
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
        return DocumentType(rawValue: documentType) ?? .receipt
    }
}