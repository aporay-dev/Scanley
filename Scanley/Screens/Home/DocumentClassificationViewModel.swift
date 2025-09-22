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
            return
        }
        
        lastError = nil
        statusMessage = "Starting AI classification..."
        
        
        await classificationService.classifyAllDocuments(context: context)
        
        if !classificationService.classificationResults.isEmpty {
            statusMessage = "Classification completed successfully!"
        } else {
            statusMessage = "No documents found to classify"
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
