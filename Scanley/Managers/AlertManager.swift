//
//  AlertManager.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation

struct AlertManager {
    
    // MARK: - OCR Related Messages
    
    static let ocrMessages = OCRMessages()
    
    struct OCRMessages {
        let scanStarted = "Starting scan..."
        let scanCompleted = "Scan completed successfully!"
        let scanCancelled = "Scan cancelled by user"
        let scanFailed = "Scan failed. Please try again."
        
        let photoLibraryAccessDenied = "Photo library access was denied. Please enable access in Settings."
        let noPhotosFound = "No photos found in your photo library."
        let ocrProcessingFailed = "Failed to process images for text extraction."
        let noModelContext = "Database not available for storing results."
        
        func scanProgress(current: Int, total: Int) -> String {
            "Processing photo \(current) of \(total)..."
        }
        
        func documentsFound(count: Int) -> String {
            "Found text in \(count) \(count == 1 ? "document" : "documents")"
        }
    }
    
    // MARK: - Search Related Messages
    
    static let searchMessages = SearchMessages()
    
    struct SearchMessages {
        let searching = "Searching documents..."
        let noResults = "No documents found matching your search"
        let searchError = "An error occurred while searching. Please try again."
        
        func resultsFound(count: Int) -> String {
            "Found \(count) \(count == 1 ? "document" : "documents")"
        }
        
        func searchSuggestion(term: String) -> String {
            "Search for '\(term)'"
        }
    }
    
    // MARK: - Photo Library Messages
    
    static let photoLibraryMessages = PhotoLibraryMessages()
    
    struct PhotoLibraryMessages {
        let accessRequired = "Photo library access required"
        let accessDenied = "Please enable photo access in Settings"
        let loadingError = "Failed to load image from photo library"
        let imageNotFound = "Document not found in photo library"
    }
    
    // MARK: - General Messages
    
    static let generalMessages = GeneralMessages()
    
    struct GeneralMessages {
        let loading = "Loading..."
        let saving = "Saving..."
        let genericError = "An unexpected error occurred. Please try again."
        let internetRequired = "Internet connection required"
        let tryAgain = "Please try again"
        
        func itemsProcessed(count: Int, total: Int) -> String {
            "Processed \(count) of \(total) items"
        }
    }
    
    // MARK: - Button Labels
    
    static let buttons = ButtonLabels()
    
    struct ButtonLabels {
        let ok = "OK"
        let cancel = "Cancel"
        let tryAgain = "Try Again"
        let settings = "Settings"
        let close = "Close"
        let done = "Done"
        let save = "Save"
        let delete = "Delete"
        let edit = "Edit"
        let add = "Add"
        let search = "Search"
        let clear = "Clear"
        let refresh = "Refresh"
    }
}
