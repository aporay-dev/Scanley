//
//  DocumentClassificationService.swift
//  Scanley
//
//  Created by Claude on 2025-09-10.
//

import Foundation
import NaturalLanguage
import SwiftData

@MainActor
class DocumentClassificationService: ObservableObject {
    
    static let shared = DocumentClassificationService()
    
    @Published var isClassifying = false
    @Published var classificationProgress: Double = 0.0
    @Published var classificationResults: [DocumentClassificationResult] = []
    
    private let swiftDataManager = SwiftDataManager.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    func classifyAllDocuments(context: ModelContext) async {
        guard !isClassifying else { return }
        
        isClassifying = true
        classificationProgress = 0.0
        classificationResults.removeAll()
        
        print("🤖 Starting on-device AI document classification...")
        
        do {
            let allDocuments = try swiftDataManager.fetchAllDocumentTexts(context: context)
            let totalDocuments = allDocuments.count
            
            guard totalDocuments > 0 else {
                print("📄 No documents found to classify")
                isClassifying = false
                return
            }
            
            print("📊 Found \(totalDocuments) documents to classify")
            
            // Process documents in batches for better performance
            let batchSize = 10
            var processedCount = 0
            
            for batchStart in stride(from: 0, to: totalDocuments, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, totalDocuments)
                let batch = Array(allDocuments[batchStart..<batchEnd])
                
                // Process batch concurrently
                await withTaskGroup(of: DocumentClassificationResult?.self) { group in
                    for document in batch {
                        group.addTask {
                            await self.classifyDocument(document)
                        }
                    }
                    
                    for await result in group {
                        if let result = result {
                            classificationResults.append(result)
                            
                            // Update document type in SwiftData
                            await updateDocumentType(
                                documentID: result.documentID,
                                newType: result.classification.rawValue,
                                context: context
                            )
                        }
                        
                        processedCount += 1
                        classificationProgress = Double(processedCount) / Double(totalDocuments)
                        
                        let progressPercent = Int(classificationProgress * 100)
                        print("🔄 Classification Progress: \(progressPercent)% (\(processedCount)/\(totalDocuments))")
                    }
                }
                
                // Small delay between batches to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            isClassifying = false
            
            // Print summary
            printClassificationSummary()
            
        } catch {
            print("❌ Error during classification: \(error)")
            isClassifying = false
        }
    }
    
    // MARK: - Private Methods
    
    private func classifyDocument(_ document: DocumentText) async -> DocumentClassificationResult? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use Apple's Natural Language framework for on-device processing
        let classification = await performNLClassification(text: document.extractedText)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTime = endTime - startTime
        
        let result = DocumentClassificationResult(
            documentID: document.documentID,
            originalText: document.extractedText,
            classification: classification,
            confidence: calculateConfidence(for: classification, text: document.extractedText),
            processingTime: processingTime
        )
        
        print("🏷️  Document \(document.documentID.prefix(8)): \(classification.rawValue) (confidence: \(String(format: "%.2f", result.confidence)))")
        
        return result
    }
    
    private func performNLClassification(text: String) async -> DocumentCategory {
        // Use keyword-based classification with Natural Language processing
        let lowercasedText = text.lowercased()
        let words = extractKeywords(from: lowercasedText)
        
        // Tax Related Keywords
        let taxKeywords = ["tax", "irs", "deduction", "form", "w-2", "w2", "1099", "tax return", "refund", "taxable", "tax year", "schedule", "tax code", "withholding", "tax liability", "tax credit", "filing", "itemized", "standard deduction", "earned income"]
        
        // Receipt Keywords  
        let receiptKeywords = ["receipt", "purchase", "bought", "paid", "total", "subtotal", "cash", "card", "visa", "mastercard", "amex", "store", "shop", "retail", "checkout", "transaction", "sale", "qty", "quantity", "item", "product", "price", "amount"]
        
        // Invoice & Bills Keywords
        let invoiceBillKeywords = ["invoice", "bill", "billing", "due date", "amount due", "payment terms", "net 30", "remit", "remittance", "services rendered", "professional services", "consultation", "hourly rate", "project", "milestone", "contractor", "vendor", "supplier"]
        
        // Bank Statement Keywords
        let bankKeywords = ["bank", "account", "statement", "balance", "deposit", "withdrawal", "transfer", "atm", "check", "checking", "savings", "routing", "swift", "iban", "branch", "debit", "credit", "overdraft", "interest", "transaction history", "account summary"]
        
        // Medical Keywords
        let medicalKeywords = ["doctor", "hospital", "clinic", "medical", "health", "prescription", "medicine", "pharmacy", "patient", "diagnosis", "treatment", "insurance", "copay", "deductible", "appointment", "lab", "test", "surgery", "therapy", "physician", "nurse", "healthcare"]
        
        // Legal Keywords
        let legalKeywords = ["legal", "attorney", "lawyer", "court", "case", "lawsuit", "contract", "agreement", "settlement", "litigation", "deposition", "affidavit", "subpoena", "judgment", "motion", "brief", "legal fees", "retainer", "paralegal", "law firm"]
        
        // Government Keywords
        let govtKeywords = ["government", "federal", "state", "county", "city", "municipal", "license", "permit", "registration", "dmv", "social security", "passport", "immigration", "uscis", "customs", "usps", "postal service", "public", "official", "agency", "department"]
        
        // Calculate scores for each category
        let taxScore = calculateCategoryScore(words: words, categoryKeywords: taxKeywords)
        let receiptScore = calculateCategoryScore(words: words, categoryKeywords: receiptKeywords)
        let invoiceBillScore = calculateCategoryScore(words: words, categoryKeywords: invoiceBillKeywords)
        let bankScore = calculateCategoryScore(words: words, categoryKeywords: bankKeywords)
        let medicalScore = calculateCategoryScore(words: words, categoryKeywords: medicalKeywords)
        let legalScore = calculateCategoryScore(words: words, categoryKeywords: legalKeywords)
        let govtScore = calculateCategoryScore(words: words, categoryKeywords: govtKeywords)
        
        // Find the highest scoring category
        let scores = [
            (DocumentCategory.tax, taxScore),
            (DocumentCategory.receipts, receiptScore),
            (DocumentCategory.invoiceBills, invoiceBillScore),
            (DocumentCategory.bank, bankScore),
            (DocumentCategory.medical, medicalScore),
            (DocumentCategory.legal, legalScore),
            (DocumentCategory.govt, govtScore)
        ]
        
        let bestMatch = scores.max { $0.1 < $1.1 }
        
        // Threshold for classification (minimum confidence required)
        let minConfidenceThreshold: Float = 0.15
        
        if let bestMatch = bestMatch, bestMatch.1 >= minConfidenceThreshold {
            return bestMatch.0
        } else {
            return .otherDocuments
        }
    }
    
    private func extractKeywords(from text: String) -> [String] {
        // Use Natural Language framework to extract meaningful words
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.english)
        
        var keywords: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange]).lowercased()
            
            // Filter out common stop words and short words
            if token.count > 2 && !isStopWord(token) {
                keywords.append(token)
            }
            
            return true
        }
        
        return keywords
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = Set(["the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "its", "may", "new", "now", "old", "see", "two", "way", "who", "boy", "did", "doesn", "let", "put", "say", "she", "too", "use"])
        return stopWords.contains(word)
    }
    
    private func calculateCategoryScore(words: [String], categoryKeywords: [String]) -> Float {
        var score: Float = 0.0
        let totalWords = Float(words.count)
        
        guard totalWords > 0 else { return 0.0 }
        
        for keyword in categoryKeywords {
            let keywordParts = keyword.components(separatedBy: " ")
            
            if keywordParts.count == 1 {
                // Single word keyword
                let matches = words.filter { $0.contains(keyword) }.count
                score += Float(matches) * 1.0
            } else {
                // Multi-word keyword - check for partial matches
                let keywordText = words.joined(separator: " ")
                if keywordText.contains(keyword) {
                    score += 2.0 // Higher weight for exact multi-word matches
                }
            }
        }
        
        // Normalize score based on text length
        return score / totalWords
    }
    
    private func calculateConfidence(for category: DocumentCategory, text: String) -> Float {
        // Simple confidence calculation based on text analysis
        let words = extractKeywords(from: text.lowercased())
        
        switch category {
        case .tax:
            let taxKeywords = ["tax", "irs", "deduction", "form", "w-2", "1099", "refund"]
            return calculateCategoryScore(words: words, categoryKeywords: taxKeywords) * 5.0
            
        case .receipts:
            let receiptKeywords = ["receipt", "purchase", "total", "paid", "store", "transaction"]
            return calculateCategoryScore(words: words, categoryKeywords: receiptKeywords) * 5.0
            
        case .invoiceBills:
            let invoiceBillKeywords = ["invoice", "bill", "due date", "amount due", "services rendered"]
            return calculateCategoryScore(words: words, categoryKeywords: invoiceBillKeywords) * 5.0
            
        case .bank:
            let bankKeywords = ["bank", "statement", "balance", "deposit", "account"]
            return calculateCategoryScore(words: words, categoryKeywords: bankKeywords) * 5.0
            
        case .medical:
            let medicalKeywords = ["doctor", "hospital", "medical", "prescription", "patient"]
            return calculateCategoryScore(words: words, categoryKeywords: medicalKeywords) * 5.0
            
        case .legal:
            let legalKeywords = ["legal", "attorney", "court", "contract", "lawsuit"]
            return calculateCategoryScore(words: words, categoryKeywords: legalKeywords) * 5.0
            
        case .govt:
            let govtKeywords = ["government", "license", "permit", "federal", "state"]
            return calculateCategoryScore(words: words, categoryKeywords: govtKeywords) * 5.0
            
        case .otherDocuments:
            return 0.5 // Default confidence for unclassified documents
        }
    }
    
    private func updateDocumentType(documentID: String, newType: String, context: ModelContext) async {
        do {
            if let document = try swiftDataManager.fetchDocumentText(by: documentID, context: context) {
                document.documentType = newType
                try context.save()
            }
        } catch {
            print("❌ Error updating document type: \(error)")
        }
    }
    
    private func printClassificationSummary() {
        let summary = Dictionary(grouping: classificationResults, by: { $0.classification })
            .mapValues { $0.count }
        
        print("\n📊 CLASSIFICATION SUMMARY:")
        print(String(repeating: "=", count: 40))
        
        for (category, count) in summary.sorted(by: { $0.1 > $1.1 }) {
            print("📋 \(category.rawValue): \(count) documents")
        }
        
        let avgConfidence = classificationResults.isEmpty ? 0.0 : 
            classificationResults.map { $0.confidence }.reduce(0, +) / Float(classificationResults.count)
        
        let avgProcessingTime = classificationResults.isEmpty ? 0.0 : 
            classificationResults.map { $0.processingTime }.reduce(0, +) / Double(classificationResults.count)
        
        print("📈 Average Confidence: \(String(format: "%.2f", avgConfidence))")
        print("⏱️  Average Processing Time: \(String(format: "%.3f", avgProcessingTime))s per document")
        print("🎯 Total Documents Classified: \(classificationResults.count)")
        print(String(repeating: "=", count: 40))
    }
}

// MARK: - Supporting Models

enum DocumentCategory: String, CaseIterable {
    case tax = "Tax"
    case receipts = "Receipts"
    case invoiceBills = "Invoices & Bills"
    case bank = "Bank"
    case medical = "Medical"
    case legal = "Legal"
    case govt = "Govt"
    case otherDocuments = "Other Documents"
    
    var emoji: String {
        switch self {
        case .tax: return "📊"
        case .receipts: return "🧾"
        case .invoiceBills: return "📄"
        case .bank: return "🏦"
        case .medical: return "🏥"
        case .legal: return "⚖️"
        case .govt: return "🏛️"
        case .otherDocuments: return "📄"
        }
    }
}

struct DocumentClassificationResult: Identifiable {
    let id = UUID()
    let documentID: String
    let originalText: String
    let classification: DocumentCategory
    let confidence: Float
    let processingTime: TimeInterval
}