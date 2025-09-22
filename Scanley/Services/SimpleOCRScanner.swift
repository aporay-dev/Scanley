//
//  SimpleOCRScanner.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import Photos
import Vision
import SwiftData

@MainActor
class SimpleOCRScanner: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusMessage = ""
    @Published var totalPhotosScanned = 0
    @Published var documentsWithTextFound = 0
    @Published var lastError: String?
    
    private var modelContext: ModelContext?
    private var scanTask: Task<Void, Never>?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    enum ScanError: Error, LocalizedError {
        case photoLibraryAccessDenied
        case noPhotosFound
        case ocrProcessingFailed
        case scanCancelled
        case noModelContext
        
        var errorDescription: String? {
            switch self {
            case .photoLibraryAccessDenied:
                return "Photo library access was denied. Please enable access in Settings."
            case .noPhotosFound:
                return "No photos found in your photo library."
            case .ocrProcessingFailed:
                return "Failed to process images for text extraction."
            case .scanCancelled:
                return "Scan was cancelled by user."
            case .noModelContext:
                return "Database not available for storing results."
            }
        }
    }
    
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    func startSimpleOCRScan() async {
        guard await requestPhotoLibraryAccess() else {
            lastError = ScanError.photoLibraryAccessDenied.localizedDescription
            scanStatusMessage = "Photo library access required"
            return
        }
        
        guard modelContext != nil else {
            lastError = ScanError.noModelContext.localizedDescription
            scanStatusMessage = "Database not available"
            return
        }
        
        scanTask?.cancel()
        
        scanTask = Task { @MainActor in
            do {
                isScanning = true
                lastError = nil
                scanProgress = 0.0
                scanStatusMessage = "Starting scan..."
                totalPhotosScanned = 0
                documentsWithTextFound = 0
                
                try await performSimpleOCRScan()
                
                if !Task.isCancelled {
                    isScanning = false
                    scanStatusMessage = "Scan complete: \(documentsWithTextFound) photos with text found from \(totalPhotosScanned) photos"
                    print("🎉 Scan completed successfully!")
                }
            } catch {
                if !Task.isCancelled {
                    isScanning = false
                    lastError = error.localizedDescription
                    scanStatusMessage = "Scan failed: \(error.localizedDescription)"
                    print("❌ Scan failed: \(error.localizedDescription)")
                }
            }
        }
        
        await scanTask?.value
    }
    
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanStatusMessage = "Scan cancelled"
        print("🛑 Scan cancelled by user")
    }
    
    private func performSimpleOCRScan() async throws {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        guard allPhotos.count > 0 else {
            throw ScanError.noPhotosFound
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
        
        // Process in larger batches for better performance
        let batchSize = 5
        
        for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalCount)
            
            try Task.checkCancellation()
            
            // Process batch concurrently for better performance
            await withTaskGroup(of: Void.self) { group in
                for i in batchStart..<batchEnd {
                    group.addTask {
                        await self.processPhotoAtIndex(i, asset: allPhotos.object(at: i), imageManager: imageManager, requestOptions: requestOptions)
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
            
            // Small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
        }
    }
    
    private func processPhotoAtIndex(_ index: Int, asset: PHAsset, imageManager: PHImageManager, requestOptions: PHImageRequestOptions) async {
        // Check if we already have OCR data for this photo
        if await ocrDataExists(for: asset.localIdentifier) {
            print("⏭️  Skipping photo \(index + 1) - Scan data already exists")
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
    
    private func ocrDataExists(for documentID: String) async -> Bool {
        guard let context = modelContext else { return false }
        
        let descriptor = FetchDescriptor<DocumentText>(
            predicate: #Predicate { $0.documentID == documentID }
        )
        
        do {
            let existingTexts = try context.fetch(descriptor)
            return !existingTexts.isEmpty
        } catch {
            print("❌ Error checking existing scan data: \(error)")
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
        guard let context = modelContext else {
            print("❌ No model context available for storing scan result")
            return
        }
        
        // For simple OCR, we don't classify - just mark as "Text Document"
        let documentText = DocumentText(
            documentID: documentID,
            extractedText: extractedText,
            confidence: confidence,
            documentType: "Text Document", // Simple classification
            textSummary: createSimpleSummary(from: extractedText)
        )
        
        context.insert(documentText)
        
        do {
            try context.save()
        } catch {
            print("❌ Error saving simple scan result: \(error)")
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

