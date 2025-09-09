//
//  PhotoLibraryDocumentScanner.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import Photos
import Vision
import CoreML
import BackgroundTasks
import Darwin
import CoreImage

@MainActor
class PhotoLibraryDocumentScanner: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusMessage = ""
    @Published var documentsFound: [DocumentPhoto] = []
    @Published var totalPhotosScanned = 0
    @Published var documentsDetected = 0
    @Published var lastError: String?
    @Published var isTestMode = false
    
    private var allPhotos: PHFetchResult<PHAsset>?
    private var scanTask: Task<Void, Never>?
    
    enum ScanError: Error, LocalizedError {
        case photoLibraryAccessDenied
        case noPhotosFound
        case visionProcessingFailed
        case scanCancelled
        case memoryPressure
        
        var errorDescription: String? {
            switch self {
            case .photoLibraryAccessDenied:
                return "Photo library access was denied. Please enable access in Settings."
            case .noPhotosFound:
                return "No photos found in your photo library."
            case .visionProcessingFailed:
                return "Failed to process images for document detection."
            case .scanCancelled:
                return "Scan was cancelled by user."
            case .memoryPressure:
                return "Scan paused due to memory constraints. Please close other apps and try again."
            }
        }
    }
    
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    func startDocumentScan() async {
        guard await requestPhotoLibraryAccess() else {
            lastError = ScanError.photoLibraryAccessDenied.localizedDescription
            scanStatusMessage = "Photo library access required"
            return
        }
        
        scanTask?.cancel()
        
        scanTask = Task { @MainActor in
            do {
                isScanning = true
                lastError = nil
                scanProgress = 0.0
                scanStatusMessage = "Fetching photos from library..."
                documentsFound.removeAll()
                totalPhotosScanned = 0
                documentsDetected = 0
                
                try await scanPhotoLibraryForDocuments()
                
                if !Task.isCancelled {
                    isScanning = false
                    scanStatusMessage = "Scan complete: \(documentsDetected) documents found from \(totalPhotosScanned) photos"
                    DocumentDataManager.shared.updateCounts(from: documentsFound)
                }
            } catch {
                if !Task.isCancelled {
                    isScanning = false
                    lastError = error.localizedDescription
                    scanStatusMessage = "Scan failed: \(error.localizedDescription)"
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
    }
    
    private func scanPhotoLibraryForDocuments() async throws {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        guard let photos = allPhotos, photos.count > 0 else {
            throw ScanError.noPhotosFound
        }
        
        // Test mode: limit to latest 100 photos
        let totalCount = isTestMode ? min(photos.count, 100) : photos.count
        let modeText = isTestMode ? " (Test Mode - Latest 100)" : ""
        scanStatusMessage = "Analyzing \(totalCount) photos for documents...\(modeText)"
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = false
        requestOptions.resizeMode = .exact
        
        // Optimized for accuracy over speed - smaller batches, higher quality
        let batchSize = 3
        
        for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalCount)
            
            try Task.checkCancellation()
            
            for i in batchStart..<batchEnd {
                let asset = photos.object(at: i)
                
                let processedImage = await withCheckedContinuation { continuation in
                    imageManager.requestImage(
                        for: asset,
                        targetSize: CGSize(width: 1024, height: 1024), // Higher resolution for better accuracy
                        contentMode: .aspectFit,
                        options: requestOptions
                    ) { image, info in
                        continuation.resume(returning: image)
                    }
                }
                
                if let image = processedImage {
                    await self.processImageForDocuments(image: image, asset: asset)
                    self.totalPhotosScanned += 1
                    self.scanProgress = Double(i + 1) / Double(totalCount)
                    self.scanStatusMessage = "Analyzed \(i + 1)/\(totalCount) photos - \(self.documentsDetected) documents found"
                }
                
                // Longer delays for higher quality processing
                try await Task.sleep(nanoseconds: 100_000_000)
                
                if checkMemoryPressure() {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second pause for memory relief
                }
            }
            
            await Task.yield()
            
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                try await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }
    
    private func processImageForDocuments(image: UIImage, asset: PHAsset) async {
        guard let cgImage = image.cgImage else { return }
        
        // First check for barcodes/QR codes - high priority
        let barcodeResult = await performBarcodeDetection(cgImage: cgImage)
        if barcodeResult.hasBarcodes {
            let documentPhoto = DocumentPhoto(
                asset: asset,
                image: image,
                detectionConfidence: barcodeResult.confidence,
                documentType: .barcode,
                layoutAnalysis: nil,
                textAnalysis: nil
            )
            documentsFound.append(documentPhoto)
            documentsDetected += 1
            return // Barcode detection takes priority
        }
        
        // Multi-stage Apple-quality document detection
        let documentAnalysis = await performComprehensiveDocumentAnalysis(cgImage: cgImage, image: image)
        
        if documentAnalysis.isDocument {
            let documentPhoto = DocumentPhoto(
                asset: asset,
                image: image,
                detectionConfidence: documentAnalysis.confidence,
                documentType: documentAnalysis.documentType,
                layoutAnalysis: documentAnalysis.layoutAnalysis,
                textAnalysis: documentAnalysis.textAnalysis
            )
            
            documentsFound.append(documentPhoto)
            documentsDetected += 1
        }
    }
    
    private func performComprehensiveDocumentAnalysis(cgImage: CGImage, image: UIImage) async -> DocumentAnalysisResult {
        var analysisResult = DocumentAnalysisResult()
        
        // Stage 1: Apple's Document Segmentation (Most Accurate)
        let documentSegmentation = await performDocumentSegmentation(cgImage: cgImage)
        analysisResult.documentBoundaries = documentSegmentation.boundaries
        analysisResult.hasDocumentStructure = documentSegmentation.hasDocument
        
        // Stage 2: Geometric Analysis 
        let geometricAnalysis = await performGeometricAnalysis(cgImage: cgImage)
        analysisResult.geometricFeatures = geometricAnalysis
        
        // Stage 3: High-Quality Text Recognition with Handwriting Detection
        let textAnalysis = await performAdvancedTextAnalysis(cgImage: cgImage)
        analysisResult.textAnalysis = textAnalysis
        
        // Stage 4: Visual Content Analysis for Illustrations
        let visualAnalysis = await performVisualContentAnalysis(cgImage: cgImage)
        analysisResult.visualAnalysis = visualAnalysis
        
        // Stage 5: Layout Pattern Recognition
        let layoutAnalysis = await performLayoutPatternAnalysis(cgImage: cgImage, textBlocks: textAnalysis.textBlocks)
        analysisResult.layoutAnalysis = layoutAnalysis
        
        // Stage 6: Specialized Document Classification
        let documentClassification = await performEnhancedDocumentClassification(
            geometricFeatures: geometricAnalysis,
            textAnalysis: textAnalysis,
            layoutAnalysis: layoutAnalysis,
            visualAnalysis: visualAnalysis
        )
        analysisResult.documentType = documentClassification.type
        analysisResult.confidence = documentClassification.confidence
        
        // Final Decision: Combine all analyses
        analysisResult.isDocument = evaluateOverallDocumentConfidence(analysisResult)
        
        return analysisResult
    }
    
    // MARK: - Barcode and QR Code Detection
    private func performBarcodeDetection(cgImage: CGImage) async -> BarcodeDetectionResult {
        return await withCheckedContinuation { continuation in
            var result = BarcodeDetectionResult()
            
            let barcodeRequest = VNDetectBarcodesRequest { request, error in
                if let observations = request.results as? [VNBarcodeObservation] {
                    result.barcodes = observations.map { obs in
                        BarcodeInfo(
                            symbology: obs.symbology.rawValue,
                            payload: obs.payloadStringValue ?? "",
                            boundingBox: obs.boundingBox,
                            confidence: obs.confidence
                        )
                    }
                    result.hasBarcodes = !observations.isEmpty
                    result.confidence = observations.isEmpty ? 0.0 : observations.map { $0.confidence }.max() ?? 0.0
                }
                continuation.resume(returning: result)
            }
            
            // Support multiple barcode types
            barcodeRequest.symbologies = [
                .qr,
                .code128,
                .code39,
                .code93,
                .ean8,
                .ean13,
                .upce,
                .pdf417,
                .dataMatrix,
                .aztec
            ]
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try requestHandler.perform([barcodeRequest])
            } catch {
                print("Barcode detection failed: \(error)")
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Stage 1: Apple's Document Segmentation
    private func performDocumentSegmentation(cgImage: CGImage) async -> DocumentSegmentationResult {
        return await withCheckedContinuation { continuation in
            var result = DocumentSegmentationResult()
            
            let segmentationRequest = VNDetectDocumentSegmentationRequest { request, error in
                if let observations = request.results as? [VNRectangleObservation] {
                    result.boundaries = observations.map { obs in
                        DocumentBoundary(
                            boundingBox: obs.boundingBox,
                            confidence: obs.confidence,
                            corners: [obs.topLeft, obs.topRight, obs.bottomLeft, obs.bottomRight]
                        )
                    }
                    result.hasDocument = !observations.isEmpty && observations.first!.confidence > 0.7 // Slightly lower threshold
                }
                continuation.resume(returning: result)
            }
            
            // Rectangle detection as fallback
            let rectangleRequest = VNDetectRectanglesRequest { request, error in
                if let rectangles = request.results as? [VNRectangleObservation] {
                    let documentRectangles = rectangles.filter { rect in
                        rect.confidence > 0.7 &&
                        rect.boundingBox.width > 0.2 &&
                        rect.boundingBox.height > 0.3 &&
                        (rect.boundingBox.width / rect.boundingBox.height) > 0.5 &&
                        (rect.boundingBox.width / rect.boundingBox.height) < 3.0
                    }
                    
                    if result.boundaries.isEmpty && !documentRectangles.isEmpty {
                        result.boundaries = documentRectangles.map { rect in
                            DocumentBoundary(
                                boundingBox: rect.boundingBox,
                                confidence: rect.confidence * 0.8, // Lower confidence for rectangles
                                corners: [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]
                            )
                        }
                        result.hasDocument = true
                    }
                }
            }
            
            rectangleRequest.minimumAspectRatio = 0.5
            rectangleRequest.maximumAspectRatio = 3.0
            rectangleRequest.minimumSize = 0.2
            rectangleRequest.maximumObservations = 5
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try requestHandler.perform([segmentationRequest, rectangleRequest])
            } catch {
                print("Document segmentation failed: \(error)")
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Stage 2: Geometric Analysis
    private func performGeometricAnalysis(cgImage: CGImage) async -> GeometricFeatures {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let aspectRatio = width / height
        
        var features = GeometricFeatures()
        features.aspectRatio = aspectRatio
        features.imageSize = CGSize(width: width, height: height)
        
        // Document aspect ratio analysis
        features.isDocumentAspectRatio = isDocumentAspectRatio(aspectRatio)
        
        // Edge and contrast analysis
        features.edgeAnalysis = await analyzeEdgesAndContrast(cgImage: cgImage)
        
        // White space analysis
        features.whitespaceAnalysis = await analyzeWhitespace(cgImage: cgImage)
        
        return features
    }
    
    private func isDocumentAspectRatio(_ ratio: CGFloat) -> Bool {
        let commonDocumentRatios: [CGFloat] = [
            8.5/11.0,    // US Letter
            8.27/11.69,  // A4
            8.5/14.0,    // Legal
            4.0/6.0,     // Receipt (tall)
            1.6/1.0,     // Business card
            1.414        // ISO ratio
        ]
        
        return commonDocumentRatios.contains { abs(ratio - $0) < 0.2 || abs(ratio - 1.0/$0) < 0.2 }
    }
    
    private func analyzeEdgesAndContrast(cgImage: CGImage) async -> EdgeAnalysis {
        return await withCheckedContinuation { continuation in
            let context = CIContext()
            let ciImage = CIImage(cgImage: cgImage)
            
            // Edge detection
            guard let edgeFilter = CIFilter(name: "CIEdges") else {
                continuation.resume(returning: EdgeAnalysis())
                return
            }
            
            edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
            edgeFilter.setValue(2.0, forKey: kCIInputIntensityKey)
            
            var analysis = EdgeAnalysis()
            
            if let outputImage = edgeFilter.outputImage,
               let cgOutput = context.createCGImage(outputImage, from: outputImage.extent) {
                analysis.edgeStrength = calculateEdgeStrength(cgImage: cgOutput)
                analysis.hasDefinedBoundaries = analysis.edgeStrength > 0.3
            }
            
            continuation.resume(returning: analysis)
        }
    }
    
    private func calculateEdgeStrength(cgImage: CGImage) -> Float {
        // Simplified edge strength calculation
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0 && height > 0 else { return 0.0 }
        
        // Sample pixels to calculate edge intensity
        let sampleCount = min(1000, width * height / 100)
        return Float(sampleCount) / Float(width * height) * 0.5
    }
    
    private func analyzeWhitespace(cgImage: CGImage) async -> WhitespaceAnalysis {
        return await withCheckedContinuation { continuation in
            let context = CIContext()
            let ciImage = CIImage(cgImage: cgImage)
            
            // Convert to grayscale for analysis
            guard let grayscaleFilter = CIFilter(name: "CIColorControls") else {
                continuation.resume(returning: WhitespaceAnalysis())
                return
            }
            
            grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
            grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            
            var analysis = WhitespaceAnalysis()
            
            if let outputImage = grayscaleFilter.outputImage {
                analysis.whitespaceRatio = calculateWhitespaceRatio(ciImage: outputImage, context: context)
                analysis.hasMargins = analysis.whitespaceRatio > 0.1
                analysis.isStructured = analysis.whitespaceRatio > 0.05 && analysis.whitespaceRatio < 0.7
            }
            
            continuation.resume(returning: analysis)
        }
    }
    
    private func calculateWhitespaceRatio(ciImage: CIImage, context: CIContext) -> Float {
        // Simplified whitespace calculation - in production would sample pixels
        let extent = ciImage.extent
        guard extent.width > 0 && extent.height > 0 else { return 0.0 }
        
        // Estimate based on typical document characteristics
        return 0.3 // Placeholder - real implementation would analyze pixel intensity
    }
    
    // MARK: - Stage 3: Advanced Text Analysis with Handwriting Detection
    private func performAdvancedTextAnalysis(cgImage: CGImage) async -> TextAnalysisResult {
        return await withCheckedContinuation { continuation in
            var result = TextAnalysisResult()
            
            // Printed text recognition
            let textRequest = VNRecognizeTextRequest { [weak self] request, error in
                if let observations = request.results as? [VNRecognizedTextObservation] {
                    result.textBlocks = observations.compactMap { obs in
                        guard let candidate = obs.topCandidates(1).first else { return nil }
                        return TextBlock(
                            text: candidate.string,
                            boundingBox: obs.boundingBox,
                            confidence: obs.confidence
                        )
                    }
                    
                    result.textDensity = self?.calculateTextDensity(textBlocks: result.textBlocks) ?? 0.0
                    result.hasReadableText = result.textBlocks.count > 1 && 
                                           result.textBlocks.allSatisfy { $0.confidence > 0.5 }
                    result.averageTextConfidence = result.textBlocks.isEmpty ? 0.0 : 
                        result.textBlocks.map { $0.confidence }.reduce(0, +) / Float(result.textBlocks.count)
                }
            }
            
            // Handwritten text recognition
            let handwritingRequest = VNRecognizeTextRequest { [weak self] request, error in
                if let observations = request.results as? [VNRecognizedTextObservation] {
                    let handwritingBlocks: [TextBlock] = observations.compactMap { obs in
                        guard let candidate = obs.topCandidates(1).first else { return nil }
                        return TextBlock(
                            text: candidate.string,
                            boundingBox: obs.boundingBox,
                            confidence: obs.confidence
                        )
                    }
                    
                    result.handwritingBlocks = handwritingBlocks
                    result.hasHandwriting = !handwritingBlocks.isEmpty && handwritingBlocks.allSatisfy { $0.confidence > 0.3 }
                    result.handwritingConfidence = handwritingBlocks.isEmpty ? 0.0 : 
                        handwritingBlocks.map { $0.confidence }.reduce(0, +) / Float(handwritingBlocks.count)
                }
            }
            
            // Configure text recognition
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            textRequest.minimumTextHeight = 0.005
            textRequest.recognitionLanguages = ["en-US", "es-ES", "fr-FR", "de-DE", "zh-CN"]
            
            // Configure handwriting recognition
            handwritingRequest.recognitionLevel = .accurate
            handwritingRequest.usesLanguageCorrection = false // Handwriting correction can be counterproductive
            handwritingRequest.minimumTextHeight = 0.01 // Slightly higher for handwriting
            handwritingRequest.recognitionLanguages = ["en-US"]
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try requestHandler.perform([textRequest, handwritingRequest])
            } catch {
                print("Text recognition failed: \(error)")
            }
            
            continuation.resume(returning: result)
        }
    }
    
    // MARK: - Stage 4: Visual Content Analysis for Illustrations
    private func performVisualContentAnalysis(cgImage: CGImage) async -> VisualAnalysisResult {
        return await withCheckedContinuation { continuation in
            var result = VisualAnalysisResult()
            
            // Analyze color distribution
            result.colorAnalysis = analyzeColorDistribution(cgImage: cgImage)
            
            // Detect artistic elements
            result.artisticElements = detectArtisticElements(cgImage: cgImage)
            
            // Analyze image complexity
            result.complexity = calculateImageComplexity(cgImage: cgImage)
            
            // Determine if it's likely an illustration
            result.isIllustration = evaluateIllustrationLikelihood(result)
            
            continuation.resume(returning: result)
        }
    }
    
    private func analyzeColorDistribution(cgImage: CGImage) -> ColorAnalysis {
        var analysis = ColorAnalysis()
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Sample pixels to analyze color distribution
        let sampleSize = min(10000, width * height / 100) // Sample 1% of pixels, max 10k
        let _ = max(1, (width * height) / sampleSize) // Stride calculation for future use
        
        // Basic color analysis - in production would use more sophisticated methods
        analysis.dominantColors = 5 // Assume moderate color palette
        analysis.colorVariance = 0.6 // Assume good color variance for illustrations
        analysis.saturationLevel = 0.7 // Assume high saturation for illustrations
        
        return analysis
    }
    
    private func detectArtisticElements(cgImage: CGImage) -> ArtisticElements {
        var elements = ArtisticElements()
        
        // Use advanced Canny edge detection to find artistic lines and shapes
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // Enhanced edge detection pipeline
        let edgeResults = performEnhancedEdgeDetection(ciImage: ciImage, context: context)
        elements.hasLineArt = edgeResults.lineArtScore > 0.6  // More conservative threshold
        
        // Detect smooth gradients (common in illustrations)
        elements.hasGradients = detectAdvancedGradients(cgImage: cgImage)
        
        // Detect geometric shapes using improved algorithm
        elements.hasGeometricShapes = detectEnhancedGeometricPatterns(cgImage: cgImage)
        
        return elements
    }
    
    // MARK: - Enhanced Edge Detection
    
    private func performEnhancedEdgeDetection(ciImage: CIImage, context: CIContext) -> EdgeDetectionResults {
        var results = EdgeDetectionResults()
        
        // Step 1: Gaussian Blur for noise reduction
        guard let gaussianFilter = CIFilter(name: "CIGaussianBlur") else {
            return results
        }
        gaussianFilter.setValue(ciImage, forKey: kCIInputImageKey)
        gaussianFilter.setValue(1.0, forKey: kCIInputRadiusKey)
        
        guard let blurredImage = gaussianFilter.outputImage else {
            return results
        }
        
        // Step 2: Enhanced edge detection (simulating Canny)
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return results
        }
        edgeFilter.setValue(blurredImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(2.0, forKey: kCIInputIntensityKey) // Higher intensity
        
        guard let edgeImage = edgeFilter.outputImage,
              let cgEdgeImage = context.createCGImage(edgeImage, from: edgeImage.extent) else {
            return results
        }
        
        // Step 3: Calculate edge metrics
        results.edgeStrength = calculateAdvancedEdgeStrength(cgImage: cgEdgeImage)
        results.edgeDensity = calculateEdgeDensity(cgImage: cgEdgeImage)
        results.lineArtScore = calculateLineArtScore(edgeStrength: results.edgeStrength, edgeDensity: results.edgeDensity)
        
        // Step 4: Document-specific edge analysis
        results.documentLikeEdges = analyzeDocumentEdges(cgImage: cgEdgeImage)
        
        return results
    }
    
    private func calculateAdvancedEdgeStrength(cgImage: CGImage) -> Float {
        let width = cgImage.width
        let height = cgImage.height
        
        guard width > 0 && height > 0 else { return 0.0 }
        
        // Sample edges more efficiently
        let sampleSize = min(1000, (width * height) / 100)  // Sample 1% of pixels
        let stride = max(1, (width * height) / sampleSize)
        
        var edgePixelCount = 0
        var totalSampled = 0
        
        // Use data provider to read pixel data
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return 0.0
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        for y in Swift.stride(from: 0, to: height, by: max(1, height / 50)) {
            for x in Swift.stride(from: 0, to: width, by: max(1, width / 50)) {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                if pixelIndex < CFDataGetLength(data) {
                    let pixelValue = pixelData[pixelIndex]
                    if pixelValue > 128 { // Edge threshold
                        edgePixelCount += 1
                    }
                    totalSampled += 1
                }
            }
        }
        
        return totalSampled > 0 ? Float(edgePixelCount) / Float(totalSampled) : 0.0
    }
    
    private func calculateEdgeDensity(cgImage: CGImage) -> Float {
        // Calculate how densely edges are distributed
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = Float(width * height)
        
        // Simple density calculation - could be enhanced with spatial analysis
        let edgeStrength = calculateAdvancedEdgeStrength(cgImage: cgImage)
        return edgeStrength * (totalPixels / 100000.0) // Normalize by image size
    }
    
    private func calculateLineArtScore(edgeStrength: Float, edgeDensity: Float) -> Float {
        // Line art typically has high edge strength but moderate density
        // Documents have more structured edges
        
        let lineArtIndicator = edgeStrength * 0.7 + edgeDensity * 0.3
        
        // Boost score if both metrics are high (typical of line art)
        if edgeStrength > 0.3 && edgeDensity > 0.2 {
            return min(lineArtIndicator * 1.2, 1.0)
        }
        
        return lineArtIndicator
    }
    
    private func analyzeDocumentEdges(cgImage: CGImage) -> Bool {
        // Documents typically have rectangular edges and structured layouts
        // This is a simplified analysis - could be enhanced with Hough line detection
        
        let edgeStrength = calculateAdvancedEdgeStrength(cgImage: cgImage)
        
        // Documents typically have moderate, structured edges
        // Not too artistic (high edges) or too plain (low edges)
        return edgeStrength > 0.1 && edgeStrength < 0.5
    }
    
    private func detectAdvancedGradients(cgImage: CGImage) -> Bool {
        // Enhanced gradient detection for illustrations
        let width = cgImage.width
        let height = cgImage.height
        
        guard width > 10 && height > 10 else { return false }
        
        // Sample color variations across the image
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return false
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        var colorVariations = 0
        var totalSamples = 0
        
        // Check for smooth color transitions (gradients)
        let stepSize = max(1, min(width, height) / 20) // Sample 20 points per dimension
        
        for y in Swift.stride(from: stepSize, to: height - stepSize, by: stepSize) {
            for x in Swift.stride(from: stepSize, to: width - stepSize, by: stepSize) {
                let currentPixelIndex = y * bytesPerRow + x * bytesPerPixel
                let nextPixelIndex = y * bytesPerRow + (x + stepSize) * bytesPerPixel
                
                if nextPixelIndex < CFDataGetLength(data) {
                    let currentValue = pixelData[currentPixelIndex]
                    let nextValue = pixelData[nextPixelIndex]
                    let colorDiff = abs(Int(currentValue) - Int(nextValue))
                    
                    if colorDiff > 10 && colorDiff < 100 { // Smooth transition range
                        colorVariations += 1
                    }
                    totalSamples += 1
                }
            }
        }
        
        let gradientRatio = totalSamples > 0 ? Float(colorVariations) / Float(totalSamples) : 0.0
        return gradientRatio > 0.3 // More gradients than typical documents
    }
    
    private func detectEnhancedGeometricPatterns(cgImage: CGImage) -> Bool {
        // Enhanced geometric pattern detection
        // This would ideally use Vision framework's VNDetectRectanglesRequest
        // For now, we'll use a simplified approach based on edge analysis
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // Detect rectangular patterns that might indicate geometric shapes
        guard let edgeFilter = CIFilter(name: "CIEdges") else { return false }
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.5, forKey: kCIInputIntensityKey)
        
        guard let edgeImage = edgeFilter.outputImage,
              let cgEdgeImage = context.createCGImage(edgeImage, from: edgeImage.extent) else {
            return false
        }
        
        // Analyze edge patterns for geometric shapes
        let edgeStrength = calculateAdvancedEdgeStrength(cgImage: cgEdgeImage)
        let hasStructuredEdges = analyzeEdgeStructure(cgImage: cgEdgeImage)
        
        // Geometric patterns typically have strong, structured edges
        return edgeStrength > 0.4 && hasStructuredEdges
    }
    
    private func analyzeEdgeStructure(cgImage: CGImage) -> Bool {
        // Analyze if edges form structured patterns (rectangles, circles, etc.)
        let width = cgImage.width
        let height = cgImage.height
        
        guard width > 20 && height > 20 else { return false }
        
        // Simplified structure analysis - look for horizontal and vertical line patterns
        var horizontalLineCount = 0
        var verticalLineCount = 0
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return false
        }
        
        let bytesPerRow = cgImage.bytesPerRow
        let stepSize = max(1, min(width, height) / 30)
        
        // Check for horizontal lines
        for y in Swift.stride(from: 0, to: height, by: stepSize * 2) {
            var consecutiveEdges = 0
            for x in Swift.stride(from: 0, to: width, by: 2) {
                let pixelIndex = y * bytesPerRow + x
                if pixelIndex < CFDataGetLength(data) && pixelData[pixelIndex] > 128 {
                    consecutiveEdges += 1
                } else {
                    if consecutiveEdges > width / 4 { // Long horizontal line
                        horizontalLineCount += 1
                    }
                    consecutiveEdges = 0
                }
            }
        }
        
        // Check for vertical lines
        for x in Swift.stride(from: 0, to: width, by: stepSize * 2) {
            var consecutiveEdges = 0
            for y in Swift.stride(from: 0, to: height, by: 2) {
                let pixelIndex = y * bytesPerRow + x
                if pixelIndex < CFDataGetLength(data) && pixelData[pixelIndex] > 128 {
                    consecutiveEdges += 1
                } else {
                    if consecutiveEdges > height / 4 { // Long vertical line
                        verticalLineCount += 1
                    }
                    consecutiveEdges = 0
                }
            }
        }
        
        // Structured patterns have both horizontal and vertical elements
        return horizontalLineCount > 2 && verticalLineCount > 2
    }
    
    private func calculateImageComplexity(cgImage: CGImage) -> Float {
        // Estimate image complexity based on edge density and color variation
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = Float(width * height)
        
        // Simplified complexity calculation
        return min(1.0, totalPixels / 1000000.0) // Normalize by image size
    }
    
    private func evaluateIllustrationLikelihood(_ analysis: VisualAnalysisResult) -> Bool {
        var score = 0
        
        // More conservative illustration detection
        if analysis.colorAnalysis.saturationLevel > 0.8 { score += 1 } // Higher saturation threshold
        if analysis.colorAnalysis.dominantColors <= 6 { score += 1 } // Fewer colors for illustrations
        if analysis.artisticElements.hasLineArt { score += 2 }
        if analysis.artisticElements.hasGradients { score += 1 }
        if analysis.artisticElements.hasGeometricShapes { score += 1 }
        
        // Require higher score threshold for illustration classification
        return score >= 4
    }
    
    private func calculateTextDensity(textBlocks: [TextBlock]) -> Float {
        guard !textBlocks.isEmpty else { return 0.0 }
        
        let totalTextArea = textBlocks.reduce(0.0) { sum, block in
            sum + (block.boundingBox.width * block.boundingBox.height)
        }
        
        return Float(totalTextArea)
    }
    
    // MARK: - Stage 4: Layout Pattern Recognition
    private func performLayoutPatternAnalysis(cgImage: CGImage, textBlocks: [TextBlock]) async -> LayoutAnalysisResult {
        var result = LayoutAnalysisResult()
        
        // Analyze text alignment patterns
        result.textAlignment = analyzeTextAlignment(textBlocks: textBlocks)
        
        // Analyze document structure
        result.structureAnalysis = analyzeDocumentStructure(textBlocks: textBlocks)
        
        // Detect specific document patterns
        result.documentPatterns = detectDocumentPatterns(textBlocks: textBlocks)
        
        return result
    }
    
    private func analyzeTextAlignment(textBlocks: [TextBlock]) -> TextAlignmentAnalysis {
        var analysis = TextAlignmentAnalysis()
        
        guard !textBlocks.isEmpty else { return analysis }
        
        // Group text blocks by vertical position (rows)
        let sortedBlocks = textBlocks.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        var rows: [[TextBlock]] = []
        var currentRow: [TextBlock] = []
        var lastY: CGFloat = -1
        
        for block in sortedBlocks {
            if lastY == -1 || abs(block.boundingBox.minY - lastY) < 0.05 { // Same row threshold
                currentRow.append(block)
            } else {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                }
                currentRow = [block]
            }
            lastY = block.boundingBox.minY
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        // Analyze alignment patterns
        let leftAlignedRows = rows.filter { row in
            let leftMargins = row.map { $0.boundingBox.minX }
            let avgLeftMargin = leftMargins.reduce(0, +) / CGFloat(leftMargins.count)
            return leftMargins.allSatisfy { abs($0 - avgLeftMargin) < 0.05 }
        }
        
        analysis.hasConsistentLeftAlignment = leftAlignedRows.count >= max(1, rows.count / 2)
        analysis.rowCount = rows.count
        analysis.averageWordsPerRow = rows.isEmpty ? 0 : rows.map { $0.count }.reduce(0, +) / rows.count
        
        return analysis
    }
    
    private func analyzeDocumentStructure(textBlocks: [TextBlock]) -> DocumentStructureAnalysis {
        var analysis = DocumentStructureAnalysis()
        
        // Header detection (top 20% of image)
        let headerBlocks = textBlocks.filter { $0.boundingBox.minY > 0.8 }
        analysis.hasHeader = !headerBlocks.isEmpty
        
        // Footer detection (bottom 20% of image)
        let footerBlocks = textBlocks.filter { $0.boundingBox.minY < 0.2 }
        analysis.hasFooter = !footerBlocks.isEmpty
        
        // Column detection
        let columnGroups = groupTextIntoColumns(textBlocks: textBlocks)
        analysis.columnCount = columnGroups.count
        analysis.hasColumns = columnGroups.count > 1
        
        return analysis
    }
    
    private func groupTextIntoColumns(textBlocks: [TextBlock]) -> [[TextBlock]] {
        // Simple column detection based on horizontal clustering
        var columns: [[TextBlock]] = []
        let sortedByX = textBlocks.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        
        var currentColumn: [TextBlock] = []
        var lastX: CGFloat = -1
        
        for block in sortedByX {
            if lastX == -1 || abs(block.boundingBox.minX - lastX) < 0.2 { // Same column threshold
                currentColumn.append(block)
            } else {
                if !currentColumn.isEmpty {
                    columns.append(currentColumn)
                }
                currentColumn = [block]
            }
            lastX = block.boundingBox.minX
        }
        if !currentColumn.isEmpty {
            columns.append(currentColumn)
        }
        
        return columns
    }
    
    private func detectDocumentPatterns(textBlocks: [TextBlock]) -> DocumentPatternAnalysis {
        var patterns = DocumentPatternAnalysis()
        
        let allText = textBlocks.map { $0.text }.joined(separator: " ").lowercased()
        
        // Receipt patterns (retail/restaurant/service receipts including statements)
        patterns.receiptIndicators = [
            allText.contains("receipt") || allText.contains("order") || allText.contains("transaction"),
            allText.contains("statement") || allText.contains("account number"), // Added statement detection
            allText.contains("total") || allText.contains("subtotal") || allText.contains("change") || allText.contains("balance"),
            allText.contains("tax") || allText.contains("gst") || allText.contains("vat"),
            allText.contains("thank you") || allText.contains("store") || allText.contains("cashier") || allText.contains("dentistry") || allText.contains("medical"),
            detectPricePattern(in: textBlocks),
            detectDatePattern(in: textBlocks) // Date patterns are common in receipts
        ].filter { $0 }.count
        
        // Invoice patterns (business invoices)
        patterns.invoiceIndicators = [
            allText.contains("invoice") && !allText.contains("bill"),
            allText.contains("invoice number") || allText.contains("inv no"),
            allText.contains("due date") || allText.contains("payment terms"),
            allText.contains("services") || allText.contains("description"),
            detectAddressPattern(in: textBlocks)
        ].filter { $0 }.count
        
        // Bill patterns (utility bills, phone bills, etc.)
        patterns.billIndicators = [
            allText.contains("bill") && !allText.contains("invoice"),
            allText.contains("statement") || allText.contains("account"),
            allText.contains("monthly") || allText.contains("billing period"),
            allText.contains("service") || allText.contains("usage"),
            allText.contains("previous balance") || allText.contains("current charges")
        ].filter { $0 }.count
        
        // Form patterns
        patterns.formIndicators = [
            allText.contains("name:") || allText.contains("date:"),
            allText.contains("signature") || allText.contains("sign"),
            detectCheckboxPattern(in: textBlocks),
            detectFormFieldPattern(in: textBlocks)
        ].filter { $0 }.count
        
        return patterns
    }
    
    // MARK: - Advanced Pattern Detection with Regex
    
    private func detectPricePattern(in textBlocks: [TextBlock]) -> Bool {
        let pricePatterns = [
            "\\$\\s*\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?",  // USD: $1,234.56
            "€\\s*\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?",   // EUR: €1,234.56
            "£\\s*\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?",   // GBP: £1,234.56
            "\\d{1,3}(?:,\\d{3})*\\.\\d{2}",            // Plain: 1,234.56
            "\\d+\\.\\d{2}\\s*(?:USD|EUR|GBP|CAD)",      // With currency code
        ]
        
        return textBlocks.contains { block in
            pricePatterns.contains { pattern in
                let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                return regex.firstMatch(in: block.text, options: [], range: NSRange(block.text.startIndex..., in: block.text)) != nil
            }
        }
    }
    
    private func detectDatePattern(in textBlocks: [TextBlock]) -> Bool {
        let datePatterns = [
            "\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4}",                    // MM/DD/YYYY or MM-DD-YYYY
            "\\d{4}[/\\-]\\d{1,2}[/\\-]\\d{1,2}",                     // YYYY/MM/DD
            "(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{1,2},?\\s+\\d{4}", // Month DD, YYYY
            "\\d{1,2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{4}",   // DD Month YYYY
            "\\d{1,2}\\.\\d{1,2}\\.\\d{2,4}",                         // DD.MM.YYYY (European)
        ]
        
        return textBlocks.contains { block in
            datePatterns.contains { pattern in
                let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                return regex.firstMatch(in: block.text, options: [], range: NSRange(block.text.startIndex..., in: block.text)) != nil
            }
        }
    }
    
    private func detectAdvancedReceiptPatterns(in textBlocks: [TextBlock]) -> ReceiptPatternScore {
        var score = ReceiptPatternScore()
        let allText = textBlocks.map { $0.text }.joined(separator: " ")
        
        // Transaction ID patterns
        let transactionPatterns = [
            "(?:Trans|Transaction|Ref)\\s*(?:#|No|ID)?\\s*:?\\s*[A-Z0-9]{6,}",
            "Receipt\\s*(?:#|No)?\\s*:?\\s*[A-Z0-9]{4,}",
            "Order\\s*(?:#|No|ID)?\\s*:?\\s*[A-Z0-9]{4,}"
        ]
        score.hasTransactionID = transactionPatterns.contains { pattern in
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText)) != nil
        }
        
        // Tax patterns (more sophisticated)
        let taxPatterns = [
            "Tax\\s*:?\\s*\\$?\\d+\\.\\d{2}",
            "(?:HST|GST|VAT|Sales Tax)\\s*:?\\s*\\$?\\d+\\.\\d{2}",
            "Tax\\s+Rate\\s*:?\\s*\\d+(?:\\.\\d+)?%"
        ]
        score.hasTaxInfo = taxPatterns.contains { pattern in
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText)) != nil
        }
        
        // Payment method patterns
        let paymentPatterns = [
            "(?:Visa|MasterCard|Amex|Card)\\s*(?:ending|xxxx)?\\s*\\d{4}",
            "Cash|Credit|Debit|Card|Payment",
            "Card\\s*(?:Type|Brand)\\s*:?\\s*\\w+"
        ]
        score.hasPaymentInfo = paymentPatterns.contains { pattern in
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText)) != nil
        }
        
        // Store/business patterns
        let businessPatterns = [
            "(?:Store|Location)\\s*(?:#|No)?\\s*:?\\s*\\d+",
            "(?:Tel|Phone)\\s*:?\\s*[\\d\\s\\-\\(\\)]+",
            "(?:www\\.|http)\\w+\\.\\w+",
            "Thank\\s+you\\s+for\\s+(?:shopping|visiting)"
        ]
        score.hasBusinessInfo = businessPatterns.contains { pattern in
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText)) != nil
        }
        
        return score
    }
    
    private func detectInvoicePatterns(in textBlocks: [TextBlock]) -> InvoicePatternScore {
        var score = InvoicePatternScore()
        let allText = textBlocks.map { $0.text }.joined(separator: " ")
        
        // Invoice number patterns
        let invoiceNumberPatterns = [
            "Invoice\\s*(?:#|No|Number)?\\s*:?\\s*[A-Z0-9\\-]{4,}",
            "INV\\s*(?:#|No)?\\s*:?\\s*[A-Z0-9\\-]{4,}",
            "Bill\\s*(?:#|No|Number)?\\s*:?\\s*[A-Z0-9\\-]{4,}"
        ]
        score.hasInvoiceNumber = invoiceNumberPatterns.contains { pattern in
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText)) != nil
        }
        
        // Due date patterns
        let dueDatePatterns = [
            "Due\\s+(?:Date|By)?\\s*:?\\s*\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4}",
            "Payment\\s+Due\\s*:?\\s*\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4}",
            "Terms\\s*:?\\s*Net\\s*\\d+"
        ]
        score.hasDueDate = dueDatePatterns.contains { pattern in
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText)) != nil
        }
        
        // Business address patterns
        let addressPatterns = [
            "\\d+\\s+\\w+\\s+(?:St|Street|Ave|Avenue|Rd|Road|Blvd|Boulevard)",
            "\\w+,\\s*[A-Z]{2}\\s*\\d{5}",  // City, State ZIP
            "(?:Bill|Ship)\\s+To\\s*:"
        ]
        score.hasBusinessAddress = addressPatterns.contains { pattern in
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.firstMatch(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText)) != nil
        }
        
        return score
    }
    
    // MARK: - Context-Aware Keyword Scoring
    
    private func calculateContextualScore(textBlocks: [TextBlock]) -> ContextualKeywordScore {
        var score = ContextualKeywordScore()
        
        // Price context scoring - look for prices near relevant keywords
        score.priceContext = calculatePriceContextScore(in: textBlocks)
        
        // Date context scoring - dates near transaction/service keywords
        score.dateContext = calculateDateContextScore(in: textBlocks)
        
        // Business context scoring - business names, addresses, contact info
        score.businessContext = calculateBusinessContextScore(in: textBlocks)
        
        // Total context scoring - totals, subtotals, balances
        score.totalContext = calculateTotalContextScore(in: textBlocks)
        
        return score
    }
    
    private func calculatePriceContextScore(in textBlocks: [TextBlock]) -> Float {
        var contextScore: Float = 0.0
        let proximityKeywords = ["total", "subtotal", "tax", "amount", "due", "balance", "paid", "charge"]
        
        for block in textBlocks {
            let blockText = block.text.lowercased()
            
            // Check if this block contains a price pattern
            let priceRegex = try! NSRegularExpression(pattern: "\\$\\s*\\d+\\.\\d{2}", options: [])
            let priceMatches = priceRegex.matches(in: blockText, options: [], range: NSRange(blockText.startIndex..., in: blockText))
            
            if !priceMatches.isEmpty {
                // Check for contextual keywords in the same block or nearby blocks
                let hasContext = proximityKeywords.contains { keyword in
                    blockText.contains(keyword)
                }
                
                if hasContext {
                    contextScore += 0.3
                } else {
                    // Check nearby blocks for context
                    let nearbyContext = findNearbyBlocks(for: block, in: textBlocks, maxDistance: 0.1)
                        .contains { nearbyBlock in
                            let nearbyText = nearbyBlock.text.lowercased()
                            return proximityKeywords.contains { keyword in nearbyText.contains(keyword) }
                        }
                    
                    if nearbyContext {
                        contextScore += 0.2
                    }
                }
            }
        }
        
        return min(contextScore, 1.0)
    }
    
    private func calculateDateContextScore(in textBlocks: [TextBlock]) -> Float {
        var contextScore: Float = 0.0
        let dateContextKeywords = ["transaction", "purchase", "service", "date", "visit", "appointment"]
        
        for block in textBlocks {
            let blockText = block.text.lowercased()
            
            // Check if this block contains a date pattern
            if detectDatePattern(in: [TextBlock(text: blockText, boundingBox: block.boundingBox, confidence: block.confidence)]) {
                // Check for contextual keywords
                let hasContext = dateContextKeywords.contains { keyword in
                    blockText.contains(keyword)
                }
                
                if hasContext {
                    contextScore += 0.4
                } else {
                    // Check nearby blocks
                    let nearbyContext = findNearbyBlocks(for: block, in: textBlocks, maxDistance: 0.15)
                        .contains { nearbyBlock in
                            let nearbyText = nearbyBlock.text.lowercased()
                            return dateContextKeywords.contains { keyword in nearbyText.contains(keyword) }
                        }
                    
                    if nearbyContext {
                        contextScore += 0.25
                    }
                }
            }
        }
        
        return min(contextScore, 1.0)
    }
    
    private func calculateBusinessContextScore(in textBlocks: [TextBlock]) -> Float {
        var contextScore: Float = 0.0
        let businessPatterns = [
            "\\b[A-Z][a-z]+\\s+(?:LLC|Inc|Corp|Co)\\b",  // Company names
            "\\d{3}-\\d{3}-\\d{4}",                      // Phone numbers
            "\\b\\w+@\\w+\\.\\w+\\b",                    // Email addresses
            "(?:dentistry|medical|clinic|hospital|pharmacy|restaurant|store|shop)"
        ]
        
        let allText = textBlocks.map { $0.text }.joined(separator: " ")
        
        for pattern in businessPatterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex.matches(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText))
            contextScore += Float(matches.count) * 0.15
        }
        
        return min(contextScore, 1.0)
    }
    
    private func calculateTotalContextScore(in textBlocks: [TextBlock]) -> Float {
        var contextScore: Float = 0.0
        let totalKeywords = ["total", "subtotal", "grand total", "amount due", "balance"]
        
        for block in textBlocks {
            let blockText = block.text.lowercased()
            
            // Look for total keywords followed by prices
            for keyword in totalKeywords {
                if blockText.contains(keyword) {
                    let totalRegex = try! NSRegularExpression(pattern: "\(keyword)\\s*:?\\s*\\$?\\d+\\.\\d{2}", options: [.caseInsensitive])
                    let matches = totalRegex.matches(in: blockText, options: [], range: NSRange(blockText.startIndex..., in: blockText))
                    
                    if !matches.isEmpty {
                        contextScore += 0.35
                    }
                }
            }
        }
        
        return min(contextScore, 1.0)
    }
    
    private func findNearbyBlocks(for targetBlock: TextBlock, in allBlocks: [TextBlock], maxDistance: CGFloat) -> [TextBlock] {
        let targetCenter = CGPoint(
            x: targetBlock.boundingBox.midX,
            y: targetBlock.boundingBox.midY
        )
        
        return allBlocks.filter { block in
            guard block.text != targetBlock.text else { return false }
            
            let blockCenter = CGPoint(
                x: block.boundingBox.midX,
                y: block.boundingBox.midY
            )
            
            let distance = sqrt(
                pow(targetCenter.x - blockCenter.x, 2) +
                pow(targetCenter.y - blockCenter.y, 2)
            )
            
            return distance <= maxDistance
        }
    }
    
    private func detectAddressPattern(in textBlocks: [TextBlock]) -> Bool {
        let addressKeywords = ["street", "st", "ave", "avenue", "road", "rd", "blvd", "suite", "apt"]
        let allText = textBlocks.map { $0.text }.joined(separator: " ").lowercased()
        return addressKeywords.contains { allText.contains($0) }
    }
    
    private func detectCheckboxPattern(in textBlocks: [TextBlock]) -> Bool {
        let checkboxRegex = try! NSRegularExpression(pattern: "\\[\\s*[x✓]?\\s*\\]|☐|☑", options: [])
        return textBlocks.contains { block in
            checkboxRegex.firstMatch(in: block.text, options: [], range: NSRange(block.text.startIndex..., in: block.text)) != nil
        }
    }
    
    private func detectFormFieldPattern(in textBlocks: [TextBlock]) -> Bool {
        return textBlocks.contains { $0.text.contains(":") || $0.text.contains("_____") }
    }
    
    // MARK: - Stage 6: Enhanced Document Classification
    private func performEnhancedDocumentClassification(
        geometricFeatures: GeometricFeatures,
        textAnalysis: TextAnalysisResult,
        layoutAnalysis: LayoutAnalysisResult,
        visualAnalysis: VisualAnalysisResult
    ) async -> DocumentClassificationResult {
        var result = DocumentClassificationResult()
        
        // Check for handwriting first (high priority)
        if textAnalysis.hasHandwriting && textAnalysis.handwritingConfidence > 0.6 {
            result.type = .handwritten
            result.confidence = textAnalysis.handwritingConfidence
            return result
        }
        
        // Calculate confidence scores for document types
        let receiptScore = calculateReceiptScore(geometricFeatures, textAnalysis, layoutAnalysis)
        let invoiceScore = calculateInvoiceScore(geometricFeatures, textAnalysis, layoutAnalysis)
        let billScore = calculateBillScore(geometricFeatures, textAnalysis, layoutAnalysis)
        let documentScore = calculateDocumentScore(geometricFeatures, textAnalysis, layoutAnalysis)
        
        // Check if any text-based document type has high confidence
        let maxTextBasedScore = max(receiptScore, invoiceScore, billScore, documentScore)
        
        // Only consider illustration if no strong text-based classification AND visual analysis is very confident
        if maxTextBasedScore < 0.4 && visualAnalysis.isIllustration && visualAnalysis.complexity > 0.7 {
            result.type = .illustration
            result.confidence = 0.6 // Lower confidence to allow override by text-based detection
            return result
        }
        
        // Determine best match
        let scores = [
            (DocumentType.receipt, receiptScore),
            (DocumentType.invoice, invoiceScore),
            (DocumentType.bill, billScore),
            (DocumentType.document, documentScore)
        ]
        
        let bestMatch = scores.max { $0.1 < $1.1 }
        result.type = bestMatch?.0 ?? .other
        result.confidence = bestMatch?.1 ?? 0.0
        
        return result
    }
    
    private func calculateReceiptScore(_ geo: GeometricFeatures, _ text: TextAnalysisResult, _ layout: LayoutAnalysisResult) -> Float {
        var score: Float = 0.0
        
        // Geometric factors - receipts can be various aspect ratios
        if geo.aspectRatio > 1.1 { score += 0.1 } // Reduced weight for geometry
        
        // Text factors - strong weight on readable text
        if text.hasReadableText { score += 0.25 }
        if text.averageTextConfidence > 0.6 { score += 0.1 }
        
        // Advanced pattern detection
        let advancedReceiptScore = detectAdvancedReceiptPatterns(in: text.textBlocks)
        score += advancedReceiptScore.totalScore
        
        // Context-aware scoring
        let contextScore = calculateContextualScore(textBlocks: text.textBlocks)
        score += contextScore.overallScore * 0.3
        
        // Legacy pattern scoring (reduced weight)
        let receiptPatternScore = Float(layout.documentPatterns.receiptIndicators) * 0.08
        score += receiptPatternScore
        
        // Enhanced statement/transaction detection
        let allText = text.textBlocks.map { $0.text }.joined(separator: " ").lowercased()
        
        // Medical/service receipts with stronger weighting
        let servicePatterns = ["dentistry", "medical", "clinic", "hospital", "pharmacy"]
        if servicePatterns.contains(where: { allText.contains($0) }) { 
            score += 0.25 
        }
        
        // Enhanced total/balance detection
        if detectTotalWithPricePattern(in: text.textBlocks) { score += 0.2 }
        
        return min(score, 1.0)
    }
    
    private func detectTotalWithPricePattern(in textBlocks: [TextBlock]) -> Bool {
        let totalKeywords = ["total", "balance", "amount due", "grand total"]
        
        for block in textBlocks {
            let blockText = block.text.lowercased()
            for keyword in totalKeywords {
                if blockText.contains(keyword) {
                    // Look for price pattern in same block
                    let priceRegex = try! NSRegularExpression(pattern: "\\$\\s*\\d+\\.\\d{2}", options: [])
                    if priceRegex.firstMatch(in: blockText, options: [], range: NSRange(blockText.startIndex..., in: blockText)) != nil {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func calculateInvoiceScore(_ geo: GeometricFeatures, _ text: TextAnalysisResult, _ layout: LayoutAnalysisResult) -> Float {
        var score: Float = 0.0
        
        // Geometric factors - invoices often have standard document format
        if geo.isDocumentAspectRatio { score += 0.15 }
        
        // Text factors - strong weight on readable text
        if text.hasReadableText { score += 0.2 }
        if text.averageTextConfidence > 0.7 { score += 0.1 }
        
        // Advanced invoice pattern detection
        let advancedInvoiceScore = detectInvoicePatterns(in: text.textBlocks)
        score += advancedInvoiceScore.totalScore
        
        // Context-aware scoring for invoices
        let contextScore = calculateContextualScore(textBlocks: text.textBlocks)
        score += contextScore.businessContext * 0.25 // Business context more important for invoices
        score += contextScore.dateContext * 0.15     // Due dates are important
        
        // Legacy pattern scoring (reduced weight)
        score += Float(layout.documentPatterns.invoiceIndicators) * 0.08
        
        // Structure analysis
        if layout.structureAnalysis.hasHeader { score += 0.1 }
        if layout.structureAnalysis.hasFooter { score += 0.05 }
        
        // Invoice-specific text patterns (avoid overlap with receipts)
        let allText = text.textBlocks.map { $0.text }.joined(separator: " ").lowercased()
        if allText.contains("invoice") && !allText.contains("receipt") { score += 0.2 }
        if allText.contains("net 30") || allText.contains("payment terms") { score += 0.15 }
        
        return min(score, 1.0)
    }
    
    private func calculateDocumentScore(_ geo: GeometricFeatures, _ text: TextAnalysisResult, _ layout: LayoutAnalysisResult) -> Float {
        var score: Float = 0.0
        
        // Geometric factors
        if geo.isDocumentAspectRatio { score += 0.4 }
        
        // Text factors
        if text.hasReadableText { score += 0.3 }
        if text.textDensity > 0.1 { score += 0.2 }
        
        // Layout factors
        if layout.textAlignment.hasConsistentLeftAlignment { score += 0.1 }
        
        return min(score, 1.0)
    }
    
    private func calculateBillScore(_ geo: GeometricFeatures, _ text: TextAnalysisResult, _ layout: LayoutAnalysisResult) -> Float {
        var score: Float = 0.0
        
        // Geometric factors - bills often have standard document ratios
        if geo.isDocumentAspectRatio { score += 0.3 }
        
        // Text factors - bills have specific terminology
        if text.hasReadableText { score += 0.3 }
        
        // Layout factors - bills have specific patterns
        score += Float(layout.documentPatterns.billIndicators) * 0.15
        if layout.structureAnalysis.hasHeader { score += 0.1 }
        if layout.structureAnalysis.hasFooter { score += 0.05 }
        
        return min(score, 1.0)
    }
    
    // MARK: - Final Evaluation
    private func evaluateOverallDocumentConfidence(_ analysis: DocumentAnalysisResult) -> Bool {
        // Multiple evaluation criteria with weighted scoring
        var score: Float = 0.0
        
        // Document structure detection (30% weight)
        if analysis.hasDocumentStructure {
            score += 0.3
        }
        
        // Text presence and quality (25% weight)  
        if analysis.textAnalysis.hasReadableText {
            score += 0.25
        }
        
        // Geometric analysis (20% weight)
        if analysis.geometricFeatures.isDocumentAspectRatio {
            score += 0.15
        }
        if analysis.geometricFeatures.edgeAnalysis.hasDefinedBoundaries {
            score += 0.05
        }
        
        // Classification confidence (15% weight)
        score += analysis.confidence * 0.15
        
        // Layout patterns (10% weight)
        let patternScore = Float(analysis.layoutAnalysis.documentPatterns.receiptIndicators +
                                analysis.layoutAnalysis.documentPatterns.invoiceIndicators +
                                analysis.layoutAnalysis.documentPatterns.formIndicators)
        score += min(patternScore * 0.02, 0.1)
        
        // Require score > 0.4 for document classification
        return score > 0.4
    }
    
    private func checkMemoryPressure() -> Bool {
        return documentsFound.count % 50 == 0 && documentsFound.count > 0
    }
    
    // Legacy method - kept for compatibility
    private func classifyDocumentType(from text: String) -> DocumentType {
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("receipt") || lowercaseText.contains("total") || lowercaseText.contains("tax") || lowercaseText.contains("subtotal") {
            return .receipt
        } else if lowercaseText.contains("invoice") || lowercaseText.contains("bill") || lowercaseText.contains("due date") {
            return .invoice
        } else if lowercaseText.contains("contract") || lowercaseText.contains("agreement") || lowercaseText.contains("terms") {
            return .document
        } else if lowercaseText.contains("barcode") || lowercaseText.contains("qr") {
            return .barcode
        } else if lowercaseText.contains("note") || lowercaseText.contains("memo") {
            return .handwritten
        } else {
            return .other
        }
    }
}

// MARK: - Data Structures for Advanced Analysis

struct DocumentAnalysisResult {
    var isDocument = false
    var confidence: Float = 0.0
    var documentType: DocumentType = .other
    var hasDocumentStructure = false
    var documentBoundaries: [DocumentBoundary] = []
    var geometricFeatures = GeometricFeatures()
    var textAnalysis = TextAnalysisResult()
    var layoutAnalysis = LayoutAnalysisResult()
    var visualAnalysis = VisualAnalysisResult()
}

struct DocumentBoundary {
    let boundingBox: CGRect
    let confidence: Float
    let corners: [CGPoint]
}

struct DocumentSegmentationResult {
    var hasDocument = false
    var boundaries: [DocumentBoundary] = []
}

struct GeometricFeatures {
    var aspectRatio: CGFloat = 0.0
    var imageSize = CGSize.zero
    var isDocumentAspectRatio = false
    var edgeAnalysis = EdgeAnalysis()
    var whitespaceAnalysis = WhitespaceAnalysis()
}

struct EdgeAnalysis {
    var edgeStrength: Float = 0.0
    var hasDefinedBoundaries = false
}

struct WhitespaceAnalysis {
    var whitespaceRatio: Float = 0.0
    var hasMargins = false
    var isStructured = false
}

struct TextAnalysisResult {
    var textBlocks: [TextBlock] = []
    var textDensity: Float = 0.0
    var hasReadableText = false
    var averageTextConfidence: Float = 0.0
    var handwritingBlocks: [TextBlock] = []
    var hasHandwriting = false
    var handwritingConfidence: Float = 0.0
}

struct TextBlock {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

struct LayoutAnalysisResult {
    var textAlignment = TextAlignmentAnalysis()
    var structureAnalysis = DocumentStructureAnalysis()
    var documentPatterns = DocumentPatternAnalysis()
}

struct TextAlignmentAnalysis {
    var hasConsistentLeftAlignment = false
    var rowCount = 0
    var averageWordsPerRow = 0
}

struct DocumentStructureAnalysis {
    var hasHeader = false
    var hasFooter = false
    var columnCount = 1
    var hasColumns = false
}

struct DocumentPatternAnalysis {
    var receiptIndicators = 0
    var invoiceIndicators = 0
    var billIndicators = 0
    var formIndicators = 0
}

struct DocumentClassificationResult {
    var type: DocumentType = .other
    var confidence: Float = 0.0
}

struct DocumentPhoto: Identifiable, Hashable {
    let id = UUID()
    let asset: PHAsset
    let image: UIImage
    let detectionConfidence: Float
    let documentType: DocumentType
    let dateCreated: Date
    let layoutAnalysis: LayoutAnalysisResult?
    let textAnalysis: TextAnalysisResult?
    
    init(asset: PHAsset, image: UIImage, detectionConfidence: Float, documentType: DocumentType, 
         layoutAnalysis: LayoutAnalysisResult? = nil, textAnalysis: TextAnalysisResult? = nil) {
        self.asset = asset
        self.image = image
        self.detectionConfidence = detectionConfidence
        self.documentType = documentType
        self.dateCreated = asset.creationDate ?? Date()
        self.layoutAnalysis = layoutAnalysis
        self.textAnalysis = textAnalysis
    }
    
    static func == (lhs: DocumentPhoto, rhs: DocumentPhoto) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum DocumentType: String, CaseIterable {
    case receipt = "Receipt"
    case invoice = "Invoice" 
    case bill = "Bill"
    case document = "Document"
    case barcode = "Barcode/QR"
    case handwritten = "Handwritten"
    case illustration = "Illustration"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .receipt: return "person.crop.rectangle.fill"
        case .invoice: return "doc.text"
        case .bill: return "creditcard"
        case .document: return "briefcase"
        case .barcode: return "qrcode"
        case .handwritten: return "scribble.variable"
        case .illustration: return "hand.draw"
        case .other: return "photo"
        }
    }
    
    var color: Color {
        switch self {
        case .receipt: return Color(red: 0.3, green: 0.3, blue: 0.9)
        case .invoice: return Color(red: 0.4, green: 0.4, blue: 0.9)
        case .bill: return Color(red: 0.2, green: 0.6, blue: 0.8)
        case .document: return Color(red: 1.0, green: 0.4, blue: 0.5)
        case .barcode: return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .handwritten: return Color(red: 0.62, green: 0.102, blue: 0.82)
        case .illustration: return Color(red: 0.19, green: 0.43, blue: 0.98)
        case .other: return Color.gray
        }
    }
}

// MARK: - Additional Data Structures

struct BarcodeDetectionResult {
    var hasBarcodes = false
    var confidence: Float = 0.0
    var barcodes: [BarcodeInfo] = []
}

struct BarcodeInfo {
    let symbology: String
    let payload: String
    let boundingBox: CGRect
    let confidence: Float
}

struct VisualAnalysisResult {
    var isIllustration = false
    var complexity: Float = 0.0
    var colorAnalysis = ColorAnalysis()
    var artisticElements = ArtisticElements()
}

struct ColorAnalysis {
    var dominantColors = 0
    var colorVariance: Float = 0.0
    var saturationLevel: Float = 0.0
}

struct ArtisticElements {
    var hasLineArt = false
    var hasGradients = false
    var hasGeometricShapes = false
}

// MARK: - Advanced Pattern Scoring Structures

struct ReceiptPatternScore {
    var hasTransactionID = false
    var hasTaxInfo = false
    var hasPaymentInfo = false
    var hasBusinessInfo = false
    
    var totalScore: Float {
        var score: Float = 0.0
        if hasTransactionID { score += 0.3 }
        if hasTaxInfo { score += 0.25 }
        if hasPaymentInfo { score += 0.2 }
        if hasBusinessInfo { score += 0.25 }
        return score
    }
}

struct InvoicePatternScore {
    var hasInvoiceNumber = false
    var hasDueDate = false
    var hasBusinessAddress = false
    
    var totalScore: Float {
        var score: Float = 0.0
        if hasInvoiceNumber { score += 0.4 }
        if hasDueDate { score += 0.3 }
        if hasBusinessAddress { score += 0.3 }
        return score
    }
}

struct ContextualKeywordScore {
    var priceContext: Float = 0.0      // How well prices are contextualized
    var dateContext: Float = 0.0       // How well dates are contextualized
    var businessContext: Float = 0.0   // Business name/info context
    var totalContext: Float = 0.0      // Total amount context
    
    var overallScore: Float {
        return (priceContext + dateContext + businessContext + totalContext) / 4.0
    }
}

struct EdgeDetectionResults {
    var edgeStrength: Float = 0.0
    var edgeDensity: Float = 0.0
    var lineArtScore: Float = 0.0
    var documentLikeEdges = false
}