//
//  DocumentDetailViewModel.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation
import UIKit
import Photos
import SwiftUI

@MainActor
class DocumentDetailViewModel: ObservableObject {
    @Published var documentImage: UIImage?
    @Published var isLoading = true
    @Published var loadError: String?
    @Published var showFullScreen = false
    @Published var showFullText = false
    
    private let searchResult: SearchResult
    
    init(searchResult: SearchResult) {
        self.searchResult = searchResult
    }
    
    // MARK: - Public Methods
    
    func loadDocumentImage() async {
        isLoading = true
        loadError = nil
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.resizeMode = .exact
        
        // Get the PHAsset using the document ID
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", searchResult.documentID)
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        guard let asset = assets.firstObject else {
            await MainActor.run {
                self.isLoading = false
                self.loadError = AlertManager.photoLibraryMessages.imageNotFound
            }
            print("❌ Could not find asset with ID: \(searchResult.documentID)")
            return
        }
        
        print("📸 Loading image for document: \(searchResult.documentID)")
        
        await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024),
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, info in
                Task { @MainActor in
                    if let image = image {
                        self.documentImage = image
                        print("✅ Successfully loaded document image")
                    } else {
                        self.loadError = AlertManager.photoLibraryMessages.loadingError
                        print("❌ Failed to load image for document: \(self.searchResult.documentID)")
                    }
                    self.isLoading = false
                    continuation.resume()
                }
            }
        }
    }
    
    func toggleFullScreen() {
        showFullScreen.toggle()
    }
    
    func toggleFullText() {
        showFullText.toggle()
    }
    
    func getDisplayText() -> String {
        let text = searchResult.extractedText
        if showFullText || text.count <= 500 {
            return text
        } else {
            return String(text.prefix(500)) + "..."
        }
    }
    
    func shouldShowToggleButton() -> Bool {
        return searchResult.extractedText.count > 500
    }
    
    func getToggleButtonText() -> String {
        return showFullText ? "Show Less" : "Show All"
    }
    
    // MARK: - Computed Properties
    
    var documentInfo: [(String, String, Color?)] {
        [
            ("Type", searchResult.documentTypeEnum.rawValue, searchResult.documentTypeEnum.color),
            ("Date Extracted", searchResult.dateExtracted.formatted(date: .abbreviated, time: .shortened), nil),
            ("OCR Confidence", "\(Int(searchResult.ocrConfidence * 100))%", nil),
            ("Relevance Score", "\(Int(searchResult.relevanceScore))%", .green)
        ]
    }
}