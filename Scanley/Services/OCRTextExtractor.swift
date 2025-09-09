//
//  OCRTextExtractor.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import Foundation
import Vision
import UIKit
import Photos
import SwiftData

@MainActor
class OCRTextExtractor: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingStatus = ""
    
    private var modelContext: ModelContext
    private var extractionTask: Task<Void, Never>?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    func extractTextFromDocuments(_ documents: [DocumentPhoto]) async {
        guard !isProcessing else { return }
        
        isProcessing = true
        processingStatus = "Starting text extraction..."
        processingProgress = 0.0
        
        extractionTask = Task {
            await processDocumentsForOCR(documents)
            
            await MainActor.run {
                isProcessing = false
                processingStatus = "Text extraction completed"
                processingProgress = 1.0
            }
        }
        
        await extractionTask?.value
    }
    
    func cancelExtraction() {
        extractionTask?.cancel()
        isProcessing = false
        processingStatus = "Extraction cancelled"
    }
    
    // MARK: - Private Methods
    
    private func processDocumentsForOCR(_ documents: [DocumentPhoto]) async {
        let totalDocuments = documents.count
        
        for (index, document) in documents.enumerated() {
            guard !Task.isCancelled else { break }
            
            // Check if we already have text for this document
            if await documentTextExists(for: document.asset.localIdentifier) {
                await updateProgress(current: index + 1, total: totalDocuments, status: "Skipping processed document")
                continue
            }
            
            await updateProgress(current: index + 1, total: totalDocuments, status: "Extracting text from document \(index + 1)")
            
            // Extract text using OCR
            let ocrResult = await performOCR(on: document.image)
            
            // Store the extracted text
            print("🔍 OCR Result for document \(index + 1):")
            print("   Text extracted: '\(ocrResult.text)'")
            print("   Confidence: \(ocrResult.confidence)")
            print("   Document ID: \(document.asset.localIdentifier)")
            
            if ocrResult.confidence > 0.1 { // Lower threshold to capture more text
                await storeDocumentText(
                    documentID: document.asset.localIdentifier,
                    extractedText: ocrResult.text,
                    confidence: ocrResult.confidence,
                    documentType: document.documentType.rawValue,
                    textSummary: extractTextSummary(from: ocrResult.text, documentType: document.documentType)
                )
                print("   ✅ Text stored successfully")
            } else {
                print("   ❌ Text not stored - confidence too low (\(ocrResult.confidence))")
            }
            
            // Small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
    
    private func updateProgress(current: Int, total: Int, status: String) async {
        await MainActor.run {
            self.processingProgress = Double(current) / Double(total)
            self.processingStatus = status
        }
    }
    
    private func documentTextExists(for documentID: String) async -> Bool {
        let descriptor = FetchDescriptor<DocumentText>(
            predicate: #Predicate { $0.documentID == documentID }
        )
        
        do {
            let existingTexts = try modelContext.fetch(descriptor)
            return !existingTexts.isEmpty
        } catch {
            print("Error checking existing document text: \(error)")
            return false
        }
    }
    
    private func performOCR(on image: UIImage) async -> OCRResult {
        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: OCRResult(text: "", confidence: 0.0))
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    print("❌ OCR failed: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: OCRResult(text: "", confidence: 0.0))
                    return
                }
                
                // Sort observations by vertical position (top to bottom)
                let sortedObservations = observations.sorted { obs1, obs2 in
                    obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
                }
                
                let recognizedTexts = sortedObservations.compactMap { observation in
                    return observation.topCandidates(1).first
                }
                
                print("📝 Found \(recognizedTexts.count) text observations")
                
                // Join text with newlines to preserve document structure
                let fullText = recognizedTexts.map { candidate in
                    print("   - Text: '\(candidate.string)' (confidence: \(candidate.confidence))")
                    return candidate.string
                }.joined(separator: "\n")
                
                let averageConfidence = recognizedTexts.isEmpty ? 0.0 : 
                    recognizedTexts.map { $0.confidence }.reduce(0, +) / Float(recognizedTexts.count)
                
                print("📊 Combined text length: \(fullText.count) characters")
                print("📊 Average confidence: \(averageConfidence)")
                
                continuation.resume(returning: OCRResult(text: fullText, confidence: averageConfidence))
            }
            
            // Configure OCR for optimal document reading
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "es-ES", "fr-FR"]
            request.minimumTextHeight = 0.005
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: OCRResult(text: "", confidence: 0.0))
            }
        }
    }
    
    private func storeDocumentText(documentID: String, extractedText: String, confidence: Float, documentType: String, textSummary: String?) async {
        let documentText = DocumentText(
            documentID: documentID,
            extractedText: extractedText,
            confidence: confidence,
            documentType: documentType,
            textSummary: textSummary
        )
        
        modelContext.insert(documentText)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving document text: \(error)")
        }
    }
    
    private func extractTextSummary(from text: String, documentType: DocumentType) -> String? {
        // Extract key information based on document type
        switch documentType {
        case .receipt:
            return extractReceiptSummary(from: text)
        case .invoice:
            return extractInvoiceSummary(from: text)
        case .bill:
            return extractBillSummary(from: text)
        default:
            return extractGeneralSummary(from: text)
        }
    }
    
    private func extractReceiptSummary(from text: String) -> String? {
        var summary: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        // Look for business name (usually at the top)
        if let businessName = lines.first(where: { $0.count > 5 && !$0.contains(":") }) {
            summary.append("Store: \(businessName)")
        }
        
        // Look for total amount
        let totalRegex = try! NSRegularExpression(pattern: "(?:total|amount|balance)\\s*:?\\s*\\$?([\\d,]+\\.\\d{2})", options: .caseInsensitive)
        for line in lines {
            if let match = totalRegex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                if let range = Range(match.range(at: 1), in: line) {
                    summary.append("Total: $\(line[range])")
                    break
                }
            }
        }
        
        // Look for date
        let dateRegex = try! NSRegularExpression(pattern: "\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4}", options: [])
        for line in lines {
            if dateRegex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil {
                summary.append("Date: \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
                break
            }
        }
        
        return summary.isEmpty ? nil : summary.joined(separator: " • ")
    }
    
    private func extractInvoiceSummary(from text: String) -> String? {
        var summary: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        // Look for invoice number
        let invoiceRegex = try! NSRegularExpression(pattern: "(?:invoice|inv)\\s*(?:#|no)?\\s*:?\\s*([A-Z0-9\\-]+)", options: .caseInsensitive)
        for line in lines {
            if let match = invoiceRegex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                if let range = Range(match.range(at: 1), in: line) {
                    summary.append("Invoice: \(line[range])")
                    break
                }
            }
        }
        
        // Look for due date
        if let dueLine = lines.first(where: { $0.lowercased().contains("due") }) {
            summary.append("Due: \(dueLine)")
        }
        
        return summary.isEmpty ? nil : summary.joined(separator: " • ")
    }
    
    private func extractBillSummary(from text: String) -> String? {
        var summary: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        // Look for account number
        if let accountLine = lines.first(where: { $0.lowercased().contains("account") && $0.contains(":") }) {
            summary.append(accountLine.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Look for statement period
        if let periodLine = lines.first(where: { $0.lowercased().contains("period") || $0.lowercased().contains("statement") }) {
            summary.append(periodLine.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return summary.isEmpty ? nil : summary.joined(separator: " • ")
    }
    
    private func extractGeneralSummary(from text: String) -> String? {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let firstFewWords = Array(words.prefix(10)).joined(separator: " ")
        return firstFewWords.isEmpty ? nil : firstFewWords
    }
}

// MARK: - Supporting Structures

struct OCRResult {
    let text: String
    let confidence: Float
}