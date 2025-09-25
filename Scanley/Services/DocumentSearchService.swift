//
//  DocumentSearchService.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import Foundation
import SwiftData
import Photos
import SwiftUI

@MainActor
class DocumentSearchService: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchQuery = ""

    private var modelContext: ModelContext
    private let swiftDataManager = SwiftDataManager.shared
    private let filterByCategory: String?
    
    init(modelContext: ModelContext, filterByCategory: String? = nil) {
        self.modelContext = modelContext
        self.filterByCategory = filterByCategory
        
        if let category = filterByCategory {
            logDebug("Initialized DocumentSearchService with category filter: \(category)", category: .search)
        }
    }
    
    // MARK: - Search Methods
    
    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchQuery = query

        let results = await performSearch(query: query)

        searchResults = results
        isSearching = false
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }
    
    func loadCategoryDocuments(category: String) async {
        
        isSearching = true
        searchQuery = ""
        
        do {
            let documents = try swiftDataManager.fetchDocumentTexts(filteredBy: category, context: modelContext)
            let results = convertToSearchResults(documents, searchTerms: [])
            
            
            searchResults = results
            isSearching = false
            
        } catch {
            searchResults = []
            isSearching = false
        }
    }
    
    // MARK: - Private Search Implementation
    
    private func performSearch(query: String) async -> [SearchResult] {
        // Search in SwiftData for documents containing the query
        let searchTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !searchTerms.isEmpty else { return [] }
        
        do {
            // Use SwiftDataManager for filtering by category if specified
            let allDocumentTexts: [DocumentText]
            if let category = filterByCategory {
                allDocumentTexts = try swiftDataManager.searchDocumentTexts(
                    query: query,
                    context: modelContext,
                    filterByCategory: category
                )
            } else {
                allDocumentTexts = try swiftDataManager.searchDocumentTexts(
                    query: query,
                    context: modelContext
                )
            }
            
            return convertToSearchResults(allDocumentTexts, searchTerms: searchTerms)
            
        } catch {
            return []
        }
    }
    
    private func convertToSearchResults(_ documents: [DocumentText], searchTerms: [String]) -> [SearchResult] {
        
        var matchingResults: [SearchResult] = []
        
        for documentText in documents {
            let relevanceScore: Float
            let snippets: [String]
            
            if searchTerms.isEmpty {
                // For category browsing (no search terms), show all documents with default relevance
                relevanceScore = 50.0 * documentText.confidence
                snippets = createDefaultSnippets(from: documentText.extractedText)
            } else {
                // For search, calculate relevance and extract matching snippets
                relevanceScore = calculateRelevanceScore(documentText: documentText, searchTerms: searchTerms)
                
                snippets = extractMatchingSnippets(from: documentText.extractedText, searchTerms: searchTerms)
                
                // Debug: Check why snippets might be empty
                if relevanceScore > 0 && snippets.isEmpty {
                    continue
                }
                
                if relevanceScore <= 0 {
                    continue
                }
            }
            
            if relevanceScore > 0 {
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
            }
        }
        
        // Sort by relevance score (highest first)
        return matchingResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func createDefaultSnippets(from text: String) -> [String] {
        // For category browsing, create snippets from the beginning of the document
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        let meaningfulSentences = sentences
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 15 }
            .prefix(2)
        
        return Array(meaningfulSentences)
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
        var matchingSnippets: [String] = []
        
        // Split by sentences and newlines for different snippet strategies
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let lines = text.components(separatedBy: .newlines)
        
        // Strategy 1: Look for sentence-based matches (traditional documents)
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
        
        // Strategy 2: Look for line-based matches (cards, forms, structured documents)
        if matchingSnippets.isEmpty {
            for line in lines {
                let lineLower = line.lowercased()
                
                for term in searchTerms {
                    if lineLower.contains(term.lowercased()) {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedLine.isEmpty && trimmedLine.count >= 2 {
                            // For short matches, include surrounding context
                            if trimmedLine.count < 8 {
                                let context = createContextSnippet(for: trimmedLine, in: text, searchTerm: term)
                                matchingSnippets.append(context)
                            } else {
                                matchingSnippets.append(trimmedLine)
                            }
                            break // Don't add the same line multiple times
                        }
                    }
                }
            }
        }
        
        // Strategy 3: Fallback - if no structured snippets, create context around matches
        if matchingSnippets.isEmpty {
            for term in searchTerms {
                if text.lowercased().contains(term.lowercased()) {
                    let contextSnippet = createContextSnippet(for: term, in: text, searchTerm: term)
                    if !contextSnippet.isEmpty {
                        matchingSnippets.append(contextSnippet)
                    }
                }
            }
        }
        
        
        // Return up to 3 most relevant snippets
        return Array(matchingSnippets.prefix(3))
    }
    
    private func createContextSnippet(for matchTerm: String, in text: String, searchTerm: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // Find the index of the matching word
        guard let matchIndex = words.firstIndex(where: { $0.lowercased().contains(searchTerm.lowercased()) }) else {
            return matchTerm
        }
        
        // Create context with 2 words before and after (if available)
        let contextStart = max(0, matchIndex - 2)
        let contextEnd = min(words.count, matchIndex + 3)
        let contextWords = Array(words[contextStart..<contextEnd])
        
        let snippet = contextWords.joined(separator: " ")
        return snippet.count > 3 ? snippet : matchTerm
    }
    
    // MARK: - Search Suggestions
    
    func getSearchSuggestions(for partialQuery: String) async -> [String] {
        guard partialQuery.count >= 2 else { return [] }

        // Only provide suggestions for Pro users
        let subscriptionManager = SubscriptionManager.shared
        guard subscriptionManager.subscriptionState.canUseSearchSuggestions else { return [] }
        
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
            return SearchStatistics(totalDocumentsWithText: 0, averageOCRConfidence: 0.0, documentTypeDistribution: [:])
        }
    }
}

// MARK: - Supporting Structures

struct SearchStatistics {
    let totalDocumentsWithText: Int
    let averageOCRConfidence: Float
    let documentTypeDistribution: [String: Int]
}