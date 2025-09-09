//
//  Global.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI

@MainActor
class DocumentDataManager: ObservableObject {
    @Published var documentCounts: [DocumentType: Int] = [:]
    @Published var lastScanDate: Date?
    @Published var totalDocumentsFound: Int = 0
    
    static let shared = DocumentDataManager()
    
    private init() {}
    
    func updateCounts(from documents: [DocumentPhoto]) {
        var newCounts: [DocumentType: Int] = [:]
        
        for document in documents {
            newCounts[document.documentType, default: 0] += 1
        }
        
        documentCounts = newCounts
        totalDocumentsFound = documents.count
        lastScanDate = Date()
    }
    
    func getCount(for type: DocumentType) -> Int {
        return documentCounts[type] ?? 0
    }
}

let photoCategories: [PhotoCategory] = [
    PhotoCategory(documentType: .document, title: "Documents", icon: "briefcase", color: Color(red: 1.0, green: 0.4, blue: 0.5)),
    PhotoCategory(documentType: .receipt, title: "Receipts", icon: "person.crop.rectangle.fill", color: Color(red: 0.3, green: 0.3, blue: 0.9)),
    PhotoCategory(documentType: .invoice, title: "Invoices", icon: "doc.text", color: Color(red: 0.4, green: 0.4, blue: 0.9)),
    PhotoCategory(documentType: .bill, title: "Bills", icon: "creditcard", color: Color(red: 0.2, green: 0.6, blue: 0.8)),
    PhotoCategory(documentType: .barcode, title: "Barcodes\n& QR codes", icon: "qrcode", color: Color(red: 1.0, green: 0.6, blue: 0.2)),
    PhotoCategory(documentType: .handwritten, title: "Handwritten notes", icon: "scribble.variable", color: Color(red: 0.62, green: 0.102, blue: 0.82)),
    PhotoCategory(documentType: .illustration, title: "Illustrations", icon: "hand.draw", color: Color(red: 0.19, green: 0.43, blue: 0.98)),
    PhotoCategory(documentType: .other, title: "Other Documents", icon: "photo", color: Color.gray)
]

struct PhotoCategory {
    let documentType: DocumentType
    let title: String
    let icon: String
    let color: Color
    
    @MainActor
    var numPhotos: Int {
        DocumentDataManager.shared.getCount(for: documentType)
    }
}
