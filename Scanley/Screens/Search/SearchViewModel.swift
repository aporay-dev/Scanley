//
//  SearchViewModel.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation
import SwiftData
import Photos
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchQuery = ""
    
    private var modelContext: ModelContext
    private let swiftDataManager = SwiftDataManager.shared
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Search Methods
    
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }
        
        isSearching = true
        searchQuery = query
        
        let results = await performSearch(query: query)
        searchResults = results
        
        isSearching = false
    }
    
    func clearSearch() {
        searchResults = []
        searchQuery = ""
        isSearching = false
    }
    
    // MARK: - Search Suggestions
    
    func getSearchSuggestions(for partialQuery: String) async -> [String] {
        guard partialQuery.count >= 2 else { return [] }
        
        do {
            let allDocumentTexts = try swiftDataManager.fetchAllDocumentTexts(context: modelContext)
            
            var suggestions: Set<String> = []
            let queryLower = partialQuery.lowercased()
            
            for documentText in allDocumentTexts {
                // Extract words from text and key phrases
                let textWords = documentText.extractedText.components(separatedBy: .whitespacesAndNewlines)
                let keyPhrases = documentText.keyPhrases
                let summaryWords = documentText.textSummary?.components(separatedBy: .whitespacesAndNewlines) ?? []
                
                let allWords = textWords + keyPhrases + summaryWords
                
                for word in allWords {
                    let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
                    if cleanWord.count >= 3 && cleanWord.hasPrefix(queryLower) && cleanWord != queryLower {
                        suggestions.insert(cleanWord.capitalized)
                        if suggestions.count >= 5 { break }
                    }
                }
                if suggestions.count >= 5 { break }
            }
            
            return Array(suggestions).sorted()
        } catch {
            print("Error generating suggestions: \(error)")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func performSearch(query: String) async -> [SearchResult] {
        // Search in SwiftData for documents containing the query
        let searchTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !searchTerms.isEmpty else { return [] }
        
        do {
            // Fetch all document texts
            let allDocumentTexts = try swiftDataManager.fetchAllDocumentTexts(context: modelContext)
            
            print("📚 Found \(allDocumentTexts.count) documents in SwiftData")
            
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
}