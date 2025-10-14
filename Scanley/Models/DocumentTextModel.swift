//
//  DocumentTextModel.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftData
import Foundation

@Model
class DocumentText {
    var documentID: String
    var extractedText: String
    var confidence: Float
    var documentType: String
    var dateExtracted: Date
    var textSummary: String?
    var keyPhrases: [String]
    
    init(documentID: String, extractedText: String, confidence: Float, documentType: String, textSummary: String? = nil) {
        self.documentID = documentID
        self.extractedText = extractedText
        self.confidence = confidence
        self.documentType = documentType
        self.dateExtracted = Date()
        self.textSummary = textSummary
        self.keyPhrases = DocumentText.extractKeyPhrases(from: extractedText)
    }
    
    // Extract key phrases for better search performance
    private static func extractKeyPhrases(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 } // Filter out short words
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        
        // Remove common words and duplicates
        let commonWords = Set(["the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "man", "new", "now", "old", "see", "two", "way", "who", "boy", "did", "its", "let", "put", "say", "she", "too", "use"])
        
        let filteredWords = Array(Set(words.filter { !commonWords.contains($0) && $0.count > 2 }))
        
        return Array(filteredWords.prefix(20)) // Store top 20 key phrases
    }
    
    // Search helper method
    func containsText(_ searchText: String) -> Bool {
        let searchLower = searchText.lowercased()
        return extractedText.lowercased().contains(searchLower) ||
               keyPhrases.contains { $0.contains(searchLower) } ||
               (textSummary?.lowercased().contains(searchLower) ?? false)
    }
}

// MARK: - SwiftData Container Configuration
extension DocumentText {
    static var modelContainer: ModelContainer {
        do {
            let container = try ModelContainer(for: DocumentText.self)
            return container
        } catch {
            fatalError("Failed to create ModelContainer for DocumentText: \(error)")
        }
    }
}