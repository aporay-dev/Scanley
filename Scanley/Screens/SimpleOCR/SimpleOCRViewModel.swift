//
//  SimpleOCRViewModel.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import SwiftUI
import Photos
import Vision
import SwiftData

@MainActor
class SimpleOCRViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusMessage = ""
    @Published var totalPhotosScanned = 0
    @Published var documentsWithTextFound = 0
    @Published var lastError: String?

    // Classification properties
    @Published var isClassifying = false
    @Published var classificationProgress: Double = 0.0
    @Published var classificationStatus = ""

    private var modelContext: ModelContext?
    private var backgroundContext: ModelContext?
    private var scanTask: Task<Void, Never>?
    private let swiftDataManager = SwiftDataManager.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private var batchDocumentSaver: BatchDocumentSaver?
    private let classificationViewModel = DocumentClassificationViewModel()
    
    init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        
        // Create background context for batch operations
        let container = context.container
        self.backgroundContext = swiftDataManager.createBackgroundContext(from: container)
        
        // Initialize batch saver with background context
        self.batchDocumentSaver = BatchDocumentSaver(batchSize: 15)
        self.batchDocumentSaver?.setBackgroundContext(backgroundContext!)
        
        print("🔧 Performance optimizations initialized")
    }
    
    // MARK: - Public Methods
    
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    func startSimpleOCRScan() async {
        guard await requestPhotoLibraryAccess() else {
            lastError = AlertManager.ocrMessages.photoLibraryAccessDenied
            scanStatusMessage = AlertManager.photoLibraryMessages.accessRequired
            return
        }
        
        guard modelContext != nil else {
            lastError = AlertManager.ocrMessages.noModelContext
            scanStatusMessage = AlertManager.ocrMessages.noModelContext
            return
        }
        
        scanTask?.cancel()
        
        scanTask = Task { @MainActor in
            do {
                isScanning = true
                lastError = nil
                scanProgress = 0.0
                scanStatusMessage = AlertManager.ocrMessages.scanStarted
                totalPhotosScanned = 0
                documentsWithTextFound = 0
                
                try await performSimpleOCRScan()

                if !Task.isCancelled {
                    isScanning = false
                    scanStatusMessage = "\(AlertManager.ocrMessages.scanCompleted): \(documentsWithTextFound) photos with text found from \(totalPhotosScanned) photos"
                    print("🎉 Simple OCR scan completed successfully!")

                    // Automatically start classification after scan completion
                    if documentsWithTextFound > 0 {
                        print("🤖 Starting automatic classification after scan completion...")
                        await startAutoClassification()
                    }
                }
            } catch {
                if !Task.isCancelled {
                    isScanning = false
                    lastError = error.localizedDescription
                    scanStatusMessage = "\(AlertManager.ocrMessages.scanFailed): \(error.localizedDescription)"
                    print("❌ Simple scan failed: \(error.localizedDescription)")
                }
            }
        }
        
        await scanTask?.value
    }
    
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanStatusMessage = AlertManager.ocrMessages.scanCancelled
        print("🛑 Simple scan cancelled by user")
        
        // Finalize any pending batch operations
        Task {
            await batchDocumentSaver?.finalizeAndSave()
        }
    }

    private func startAutoClassification() async {
        guard let modelContext = modelContext else {
            print("❌ No model context available for classification")
            return
        }

        guard !isClassifying else {
            print("⚠️ Classification already in progress")
            return
        }

        print("🤖 Starting automatic document classification after scan")

        // Set up classification ViewModel
        classificationViewModel.setModelContext(modelContext)

        // Update local state
        isClassifying = true
        classificationProgress = 0.0
        classificationStatus = "Classifying documents..."
        scanStatusMessage = "Scan complete. Classifying documents..."

        // Start classification
        await classificationViewModel.startClassification()

        // Update final state
        isClassifying = classificationViewModel.isClassifying
        classificationProgress = 1.0

        if let error = classificationViewModel.lastError {
            classificationStatus = "Classification failed: \(error)"
            scanStatusMessage = "Classification failed: \(error)"
        } else if classificationViewModel.hasResults {
            let summary = classificationViewModel.getClassificationSummary()
            let totalClassified = classificationViewModel.classificationResults.count
            classificationStatus = "✅ Classified \(totalClassified) documents successfully!"
            scanStatusMessage = "✅ Scan and classification complete! \(totalClassified) documents classified."

            // Print summary to console
            print("🎯 AUTO-CLASSIFICATION COMPLETE:")
            for (category, count) in summary.sorted(by: { $0.1 > $1.1 }) {
                print("📊 \(category): \(count) documents")
            }
        } else {
            classificationStatus = "No documents found to classify"
            scanStatusMessage = "Scan complete. No documents found to classify."
            print("🔍 Classification completed but no results found")
        }
    }

    // MARK: - Private Methods
    
    private func performSimpleOCRScan() async throws {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        guard allPhotos.count > 0 else {
            throw OCRScanError.noPhotosFound
        }
        
        // Process all photos in the library
        let totalCount = allPhotos.count
        scanStatusMessage = "Running scan on \(totalCount) photos..."

        print("🚀 Starting Document scan on \(totalCount) photos")
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = false
        requestOptions.resizeMode = .exact
        
        // Dynamic batch sizing based on device capabilities
        let batchSize = performanceMonitor.optimalBatchSize()
        print("📊 Using optimal batch size: \(batchSize) for this device")
        
        // Reset performance monitoring
        performanceMonitor.resetStats()
        
        // Pipeline processing with overlapping batches
        
        for batchStart in Swift.stride(from: 0, to: totalCount, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalCount)
            let batchStartTime = CFAbsoluteTimeGetCurrent()
            
            try Task.checkCancellation()
            
            // Process batch concurrently with improved performance
            await withTaskGroup(of: Void.self) { group in
                for i in batchStart..<batchEnd {
                    group.addTask {
                        let startTime = CFAbsoluteTimeGetCurrent()
                        await self.processPhotoAtIndex(i, asset: allPhotos.object(at: i), imageManager: imageManager, requestOptions: requestOptions)
                        let endTime = CFAbsoluteTimeGetCurrent()
                        
                        // Record processing time for performance monitoring
                        await MainActor.run {
                            self.performanceMonitor.recordProcessingTime(endTime - startTime)
                        }
                    }
                }
                
                await group.waitForAll()
            }
            
            
            // Update progress after each batch
            await MainActor.run {
                self.scanProgress = Double(batchEnd) / Double(totalCount)
                let progressPercent = Int(self.scanProgress * 100)
                self.scanStatusMessage = "Scan Progress: \(progressPercent)% (\(self.documentsWithTextFound) with text found)"
            }
            
            // Dynamic throttling based on performance
            let batchTime = CFAbsoluteTimeGetCurrent() - batchStartTime
            let throttleTime = performanceMonitor.shouldThrottle()
            
            if throttleTime > 0 {
                print("⏱️ Dynamic throttling: \(String(format: "%.3f", throttleTime))s (batch took \(String(format: "%.3f", batchTime))s)")
                try? await Task.sleep(nanoseconds: UInt64(throttleTime * 1_000_000_000))
            }
        }
        
        // Finalize any remaining batch operations
        await batchDocumentSaver?.finalizeAndSave()
        
        // CRITICAL: Save background context to ensure data is persisted to main context
        if let bgContext = backgroundContext {
            do {
                try bgContext.save()
                print("💾 Background context saved successfully")
                
                // Refresh main context to see background changes
                if let mainContext = modelContext {
                    try mainContext.save()
                    print("🔄 Main context refreshed")
                    
                    // Verify documents are now visible in main context
                    let allDocs = try swiftDataManager.fetchAllDocumentTexts(context: mainContext)
                    print("🔍 DEBUG: After scan, main context has \(allDocs.count) documents")
                }
            } catch {
                print("❌ Error saving contexts after Scan: \(error)")
            }
        }
        
        // Print performance summary
        let stats = performanceMonitor.getPerformanceStats()
        print("📈 Performance Summary: avg processing time: \(String(format: "%.3f", stats.averageProcessingTime))s, total processed: \(stats.totalProcessedCount)")
    }
    
    private func processPhotoAtIndex(_ index: Int, asset: PHAsset, imageManager: PHImageManager, requestOptions: PHImageRequestOptions) async {
        guard let context = modelContext else { return }
        
        // Check if we already have OCR data for this photo
        do {
            if try swiftDataManager.documentTextExists(for: asset.localIdentifier, context: context) {
                print("⏭️  Skipping photo \(index + 1) - scan data already exists")
                return
            }
        } catch {
            print("❌ Error checking existing scan data: \(error)")
            return
        }
        
        let processedImage = await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024),
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, info in
                continuation.resume(returning: image)
            }
        }
        
        guard let image = processedImage else {
            print("❌ Failed to load image for photo \(index + 1)")
            return
        }
        
        // Perform OCR directly on the image
        let ocrResult = await performOCR(on: image)
        
        await MainActor.run {
            self.totalPhotosScanned += 1
        }
        
        print("🔍 Photo \(index + 1): scan data found \(ocrResult.text.count) characters (confidence: \(ocrResult.confidence))")
        
        // Filter by confidence and text length - keep photos with meaningful text
        if ocrResult.confidence > 0.1 && ocrResult.text.count > 10 {
            await storeSimpleOCRResult(
                documentID: asset.localIdentifier,
                extractedText: ocrResult.text,
                confidence: ocrResult.confidence,
                dateCreated: asset.creationDate ?? Date()
            )
            
            await MainActor.run {
                self.documentsWithTextFound += 1
            }
            
            print("✅ Photo \(index + 1): Text stored (length: \(ocrResult.text.count))")
        } else {
            print("⏭️  Photo \(index + 1): Skipped - insufficient text (confidence: \(ocrResult.confidence), length: \(ocrResult.text.count))")
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
                
                // Join text with newlines to preserve document structure
                let fullText = recognizedTexts.map { $0.string }.joined(separator: "\n")
                let averageConfidence = recognizedTexts.isEmpty ? 0.0 :
                    recognizedTexts.map { $0.confidence }.reduce(0, +) / Float(recognizedTexts.count)
                
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
    
    private func storeSimpleOCRResult(documentID: String, extractedText: String, confidence: Float, dateCreated: Date) async {
        // For simple OCR, we don't classify - just mark as "Text Document"
        let documentText = DocumentText(
            documentID: documentID,
            extractedText: extractedText,
            confidence: confidence,
            documentType: "Text Document", // Simple classification
            textSummary: createSimpleSummary(from: extractedText)
        )
        
        // Use batch saver for optimal database performance
        if let batchSaver = batchDocumentSaver {
            await batchSaver.addDocument(documentText)
        } else {
            // Fallback to individual save if batch saver not available
            guard let context = modelContext else {
                print("❌ No model context available for storing scan result")
                return
            }
            
            do {
                try swiftDataManager.saveDocumentText(documentText, context: context)
            } catch {
                print("❌ Error saving scan result: \(error)")
            }
        }
    }
    
    private func createSimpleSummary(from text: String) -> String? {
        // Create a simple summary from the first few meaningful words
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 2 }
            .prefix(8)
        
        guard !words.isEmpty else { return nil }
        return Array(words).joined(separator: " ")
    }
}

// MARK: - Models

struct OCRResult {
    let text: String
    let confidence: Float
}

enum OCRScanError: Error, LocalizedError {
    case photoLibraryAccessDenied
    case noPhotosFound
    case ocrProcessingFailed
    case scanCancelled
    case noModelContext
    
    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessDenied:
            return AlertManager.ocrMessages.photoLibraryAccessDenied
        case .noPhotosFound:
            return AlertManager.ocrMessages.noPhotosFound
        case .ocrProcessingFailed:
            return AlertManager.ocrMessages.ocrProcessingFailed
        case .scanCancelled:
            return AlertManager.ocrMessages.scanCancelled
        case .noModelContext:
            return AlertManager.ocrMessages.noModelContext
        }
    }
}
