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
        print("🏗️ BatchDocumentSaver initialized with batch size: \(batchSize)")
    }
    
    // MARK: - Context Management
    
    func setBackgroundContext(_ context: ModelContext) {
        self.backgroundContext = context
        print("📱 Background context set for batch operations")
    }
    
    // MARK: - Batch Operations
    
    func addDocument(_ documentText: DocumentText) async {
        pendingDocuments.append(documentText)
        print("📝 Added document to batch. Pending: \(pendingDocuments.count)/\(batchSize)")
        
        // Trigger batch save if we've reached the batch size
        if pendingDocuments.count >= batchSize {
            await flushBatch()
        }
    }
    
    func flushBatch() async {
        guard !pendingDocuments.isEmpty else { return }
        guard let context = backgroundContext else {
            print("❌ No background context available for batch save")
            return
        }
        
        let documentsToSave = pendingDocuments
        pendingDocuments.removeAll()
        
        print("💾 Flushing batch of \(documentsToSave.count) documents")
        
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
                
                print("✅ Successfully saved batch of \(documentsToSave.count) documents in \(String(format: "%.3f", duration))s")
                
            } catch {
                print("❌ Error saving document batch: \(error)")
                
                // On failure, try to save individually as fallback
                await fallbackIndividualSave(documentsToSave, context: context)
            }
        }
        
        await saveTask?.value
    }
    
    // MARK: - Fallback Operations
    
    private func fallbackIndividualSave(_ documents: [DocumentText], context: ModelContext) async {
        print("🔄 Attempting individual save fallback for \(documents.count) documents")
        
        for (index, document) in documents.enumerated() {
            do {
                try swiftDataManager.saveDocumentText(document, context: context)
                print("✅ Fallback saved document \(index + 1)/\(documents.count)")
            } catch {
                print("❌ Fallback failed for document \(index + 1): \(error)")
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
        print("🏁 Finalizing batch operations...")
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