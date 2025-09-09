//
//  DocumentSearchService.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import Foundation
import SwiftData
import Photos

@MainActor
class DocumentSearchService: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchQuery = ""
    
    private var modelContext: ModelContext
    private var allDocuments: [DocumentPhoto] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Load available documents from photo library for search results
    func loadAvailableDocuments() async {
        // In a real implementation, we would need access to the scanner
        // For now, we'll work with just the SwiftData entries
        self.allDocuments = []
    }
    
    // MARK: - Search Methods
    
    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        print("🔍 Starting search for query: '\(query)'")
        
        isSearching = true
        searchQuery = query
        
        let results = await performSearch(query: query)
        
        print("📊 Search completed - found \(results.count) results")
        
        searchResults = results
        isSearching = false
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }
    
    // MARK: - Private Search Implementation
    
    private func performSearch(query: String) async -> [SearchResult] {
        // Search in SwiftData for documents containing the query
        let searchTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !searchTerms.isEmpty else { return [] }
        
        do {
            // Fetch all document texts
            let descriptor = FetchDescriptor<DocumentText>()
            let allDocumentTexts = try modelContext.fetch(descriptor)
            
            print("📚 Found \(allDocumentTexts.count) documents in SwiftData")
            for (idx, doc) in allDocumentTexts.enumerated() {
                print("   Document \(idx + 1): ID=\(doc.documentID)")
                print("   Text preview: '\(String(doc.extractedText.prefix(100)))...'")
                print("   Confidence: \(doc.confidence)")
            }
            
            var matchingResults: [SearchResult] = []
            
            for documentText in allDocumentTexts {
                let relevanceScore = calculateRelevanceScore(documentText: documentText, searchTerms: searchTerms)
                
                print("🎯 Document \(documentText.documentID): relevance score = \(relevanceScore)")
                
                if relevanceScore > 0 {
                    // Extract matching snippets
                    let snippets = extractMatchingSnippets(from: documentText.extractedText, searchTerms: searchTerms)
                    
                    // Only include documents that have actual matching text snippets
                    if !snippets.isEmpty {
                        let searchResult = SearchResult(
                            documentID: documentText.documentID,
                            documentType: documentText.documentType,
                            dateExtracted: documentText.dateExtracted,
                            extractedText: documentText.extractedText,
                            matchingSnippets: snippets,
                            relevanceScore: relevanceScore,
                            ocrConfidence: documentText.confidence,
                            textSummary: documentText.textSummary
                        )
                        
                        matchingResults.append(searchResult)
                    } else {
                        print("🚫 Document \(documentText.documentID) had relevance score \(relevanceScore) but no matching snippets - excluded from results")
                    }
                }
            }
            
            // Sort by relevance score (highest first)
            return matchingResults.sorted { $0.relevanceScore > $1.relevanceScore }
            
        } catch {
            print("Error performing search: \(error)")
            return []
        }
    }
    
    private func calculateRelevanceScore(documentText: DocumentText, searchTerms: [String]) -> Float {
        var score: Float = 0.0
        let text = documentText.extractedText.lowercased()
        let keyPhrases = documentText.keyPhrases
        
        for term in searchTerms {
            let termLower = term.lowercased()
            
            // Exact matches in text get highest score
            if text.contains(termLower) {
                score += 10.0
                
                // Bonus for multiple occurrences
                let occurrences = text.components(separatedBy: termLower).count - 1
                score += Float(occurrences - 1) * 2.0
            }
            
            // Matches in key phrases get medium score
            if keyPhrases.contains(where: { $0.contains(termLower) }) {
                score += 5.0
            }
            
            // Matches in summary get medium score
            if let summary = documentText.textSummary, summary.lowercased().contains(termLower) {
                score += 7.0
            }
            
            // Fuzzy matching for partial words
            for phrase in keyPhrases {
                if phrase.contains(termLower) || termLower.contains(phrase) {
                    score += 2.0
                }
            }
        }
        
        // Boost score based on OCR confidence
        score *= documentText.confidence
        
        return score
    }
    
    private func extractMatchingSnippets(from text: String, searchTerms: [String]) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        var matchingSnippets: [String] = []
        
        for sentence in sentences {
            let sentenceLower = sentence.lowercased()
            
            for term in searchTerms {
                if sentenceLower.contains(term.lowercased()) {
                    let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedSentence.isEmpty && trimmedSentence.count > 10 {
                        matchingSnippets.append(trimmedSentence)
                        break // Don't add the same sentence multiple times
                    }
                }
            }
        }
        
        // Return up to 3 most relevant snippets
        return Array(matchingSnippets.prefix(3))
    }
    
    // MARK: - Search Suggestions
    
    func getSearchSuggestions(for partialQuery: String) async -> [String] {
        guard partialQuery.count >= 2 else { return [] }
        
        do {
            let descriptor = FetchDescriptor<DocumentText>()
            let allDocumentTexts = try modelContext.fetch(descriptor)
            
            var suggestions = Set<String>()
            
            for documentText in allDocumentTexts {
                // Look for words that start with the partial query
                for phrase in documentText.keyPhrases {
                    if phrase.lowercased().hasPrefix(partialQuery.lowercased()) {
                        suggestions.insert(phrase)
                    }
                }
                
                // Also check the summary for suggestions
                if let summary = documentText.textSummary {
                    let words = summary.components(separatedBy: .whitespacesAndNewlines)
                    for word in words {
                        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                        if cleanWord.lowercased().hasPrefix(partialQuery.lowercased()) && cleanWord.count > 2 {
                            suggestions.insert(cleanWord)
                        }
                    }
                }
            }
            
            return Array(suggestions).sorted().prefix(5).map { String($0) }
            
        } catch {
            print("Error getting search suggestions: \(error)")
            return []
        }
    }
    
    // MARK: - Statistics
    
    func getSearchStatistics() async -> SearchStatistics {
        do {
            let descriptor = FetchDescriptor<DocumentText>()
            let allDocumentTexts = try modelContext.fetch(descriptor)
            
            let totalDocumentsWithText = allDocumentTexts.count
            let averageConfidence = allDocumentTexts.isEmpty ? 0.0 : 
                allDocumentTexts.map { $0.confidence }.reduce(0, +) / Float(allDocumentTexts.count)
            
            let documentTypeDistribution = Dictionary(grouping: allDocumentTexts, by: { $0.documentType })
                .mapValues { $0.count }
            
            return SearchStatistics(
                totalDocumentsWithText: totalDocumentsWithText,
                averageOCRConfidence: averageConfidence,
                documentTypeDistribution: documentTypeDistribution
            )
            
        } catch {
            print("Error getting search statistics: \(error)")
            return SearchStatistics(totalDocumentsWithText: 0, averageOCRConfidence: 0.0, documentTypeDistribution: [:])
        }
    }
}

// MARK: - Supporting Structures

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
        return DocumentType(rawValue: documentType) ?? .other
    }
}

struct SearchStatistics {
    let totalDocumentsWithText: Int
    let averageOCRConfidence: Float
    let documentTypeDistribution: [String: Int]
}