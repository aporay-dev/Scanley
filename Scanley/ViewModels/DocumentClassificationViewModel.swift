//
//  DocumentClassificationViewModel.swift
//  Scanley
//
//  Created by Claude on 2025-09-10.
//

import Foundation
import SwiftData

@MainActor
class DocumentClassificationViewModel: ObservableObject {
    
    @Published var isClassifying = false
    @Published var classificationProgress: Double = 0.0
    @Published var statusMessage = ""
    @Published var classificationResults: [DocumentClassificationResult] = []
    @Published var lastError: String?
    
    private let classificationService = DocumentClassificationService.shared
    private var modelContext: ModelContext?
    
    init() {
        // Observe changes from the service
        setupServiceObservers()
    }
    
    // MARK: - Public Methods
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func startClassification() async {
        guard let context = modelContext else {
            lastError = "Database context not available"
            statusMessage = "Error: Database not available"
            return
        }
        
        guard !isClassifying else {
            print("⚠️ Classification already in progress")
            return
        }
        
        lastError = nil
        statusMessage = "Starting AI classification..."
        
        print("🚀 Starting document classification from ViewModel")
        
        do {
            await classificationService.classifyAllDocuments(context: context)
            
            if !classificationService.classificationResults.isEmpty {
                statusMessage = "Classification completed successfully!"
                print("✅ Classification completed from ViewModel")
                printViewModelSummary()
            } else {
                statusMessage = "No documents found to classify"
            }
            
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Classification failed: \(error.localizedDescription)"
            print("❌ Classification failed in ViewModel: \(error)")
        }
    }
    
    func clearResults() {
        classificationResults.removeAll()
        statusMessage = ""
        lastError = nil
        classificationProgress = 0.0
    }
    
    func getClassificationSummary() -> [String: Int] {
        return Dictionary(grouping: classificationResults, by: { $0.classification.rawValue })
            .mapValues { $0.count }
    }
    
    func getCategoryCounts() -> [DocumentCategory: Int] {
        return Dictionary(grouping: classificationService.classificationResults, by: { $0.classification })
            .mapValues { $0.count }
    }
    
    // MARK: - Private Methods
    
    private func setupServiceObservers() {
        // Since we're using @MainActor, we can directly observe published properties
        // In a more complex setup, you might use Combine publishers here
        
        // For now, we'll update our local state by accessing the service directly
        // This could be enhanced with proper Combine publishers if needed
    }
    
    private func updateLocalStateFromService() {
        isClassifying = classificationService.isClassifying
        classificationProgress = classificationService.classificationProgress
        classificationResults = classificationService.classificationResults
        
        if isClassifying {
            let progressPercent = Int(classificationProgress * 100)
            statusMessage = "Classifying documents... \(progressPercent)%"
        }
    }
    
    private func printViewModelSummary() {
        let summary = getClassificationSummary()
        let totalDocuments = classificationResults.count
        
        print("\n🎯 VIEWMODEL CLASSIFICATION SUMMARY:")
        print(String(repeating: "=", count: 45))
        print("📱 Total Documents Processed: \(totalDocuments)")
        
        for (category, count) in summary.sorted(by: { $0.1 > $1.1 }) {
            let percentage = totalDocuments > 0 ? (Double(count) / Double(totalDocuments)) * 100 : 0
            print("📊 \(category): \(count) documents (\(String(format: "%.1f", percentage))%)")
        }
        
        // Find highest confidence classifications
        let highConfidenceResults = classificationResults
            .filter { $0.confidence > 0.8 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(3)
        
        if !highConfidenceResults.isEmpty {
            print("\n🏆 TOP CONFIDENT CLASSIFICATIONS:")
            for (index, result) in highConfidenceResults.enumerated() {
                print("\(index + 1). \(result.classification.rawValue) - Confidence: \(String(format: "%.2f", result.confidence))")
                print("   📄 Text preview: \(result.originalText.prefix(50))...")
            }
        }
        
        print(String(repeating: "=", count: 45))
    }
}

// MARK: - Helper Extensions

extension DocumentClassificationViewModel {
    
    var hasResults: Bool {
        !classificationService.classificationResults.isEmpty
    }
    
    var isIdle: Bool {
        !isClassifying && lastError == nil
    }
    
    var hasError: Bool {
        lastError != nil
    }
    
    func getResultsFor(category: DocumentCategory) -> [DocumentClassificationResult] {
        return classificationService.classificationResults.filter { $0.classification == category }
    }
    
    func getAverageConfidence() -> Float {
        guard !classificationService.classificationResults.isEmpty else { return 0.0 }
        return classificationService.classificationResults.map { $0.confidence }.reduce(0, +) / Float(classificationService.classificationResults.count)
    }
    
    func getTotalProcessingTime() -> TimeInterval {
        return classificationService.classificationResults.map { $0.processingTime }.reduce(0, +)
    }
}