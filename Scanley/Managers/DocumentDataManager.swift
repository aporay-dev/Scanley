//
//  DocumentDataManager.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation

@MainActor
class DocumentDataManager: ObservableObject {
    @Published var lastScanDate: Date?
    @Published var totalDocumentsFound: Int = 0
    
    static let shared = DocumentDataManager()
    
    private init() {}
    
    func updateFromSimpleOCR(documentsFound: Int) {
        totalDocumentsFound = documentsFound
        lastScanDate = Date()
    }
}