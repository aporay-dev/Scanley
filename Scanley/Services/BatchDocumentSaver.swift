//
//  BatchDocumentSaver.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation
import SwiftData

@MainActor
class BatchDocumentSaver: ObservableObject {
    
    private var pendingDocuments: [DocumentText] = []
    private var saveTask: Task<Void, Never>?
    private let batchSize: Int
    private let swiftDataManager = SwiftDataManager.shared
    
    // Separate context for background operations
    private var backgroundContext: ModelContext?
    
    init(batchSize: Int = 15) {
        self.batchSize = batchSize
    }
    
    // MARK: - Context Management
    
    func setBackgroundContext(_ context: ModelContext) {
        self.backgroundContext = context
    }
    
    // MARK: - Batch Operations
    
    func addDocument(_ documentText: DocumentText) async {
        pendingDocuments.append(documentText)
        
        // Trigger batch save if we've reached the batch size
        if pendingDocuments.count >= batchSize {
            await flushBatch()
        }
    }
    
    func flushBatch() async {
        guard !pendingDocuments.isEmpty else { return }
        guard let context = backgroundContext else {
            return
        }
        
        let documentsToSave = pendingDocuments
        pendingDocuments.removeAll()
        
        
        // Cancel any existing save task
        saveTask?.cancel()
        
        saveTask = Task { @MainActor in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                // Batch insert all documents
                for document in documentsToSave {
                    context.insert(document)
                }
                
                // Single save operation for the entire batch
                try context.save()
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = endTime - startTime
                
                
            } catch {
                
                // On failure, try to save individually as fallback
                await fallbackIndividualSave(documentsToSave, context: context)
            }
        }
        
        await saveTask?.value
    }
    
    // MARK: - Fallback Operations
    
    private func fallbackIndividualSave(_ documents: [DocumentText], context: ModelContext) async {
        
        for (index, document) in documents.enumerated() {
            do {
                try swiftDataManager.saveDocumentText(document, context: context)
            } catch {
            }
        }
    }
    
    // MARK: - Deferred Saving
    
    func scheduleDeferredSave() {
        guard !pendingDocuments.isEmpty else { return }
        
        // Save remaining documents after a delay if batch isn't full
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await flushBatch()
        }
    }
    
    // MARK: - Cleanup
    
    func finalizeAndSave() async {
        await flushBatch()
        saveTask?.cancel()
        saveTask = nil
    }
    
    // MARK: - Stats
    
    func getPendingCount() -> Int {
        return pendingDocuments.count
    }
    
    func getBatchSize() -> Int {
        return batchSize
    }
}