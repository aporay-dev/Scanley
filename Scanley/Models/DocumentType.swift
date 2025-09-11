//
//  DocumentType.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import SwiftUI

enum DocumentType: String, CaseIterable {
    case tax = "Tax"
    case receipts = "Receipts"
    case invoiceBills = "Invoices & Bills"
    case bank = "Bank"
    case medical = "Medical"
    case legal = "Legal"
    case govt = "Govt"
    case insurance = "Insurance"
    case otherDocuments = "Other Documents"
    case textDocument = "Text Document"
    case document = "Document"
    case receipt = "Receipt"
    case invoice = "Invoice"
    case bill = "Bill"
    case barcode = "Barcode"
    case handwritten = "Handwritten"
    case illustration = "Illustration"
    case other = "Other"
    
    var color: Color {
        switch self {
        case .tax: return Color(red: 0.0, green: 0.7, blue: 0.0)
        case .receipts: return Color(red: 0.3, green: 0.3, blue: 0.9)
        case .invoiceBills: return Color(red: 0.4, green: 0.4, blue: 0.9)
        case .bank: return Color(red: 0.2, green: 0.6, blue: 0.8)
        case .medical: return Color(red: 0.8, green: 0.2, blue: 0.4)
        case .legal: return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .govt: return Color(red: 0.5, green: 0.2, blue: 0.8)
        case .insurance: return Color(red: 0.2, green: 0.8, blue: 0.6)
        case .otherDocuments: return Color.gray
        case .textDocument, .document: return Color(red: 1.0, green: 0.4, blue: 0.5)
        case .receipt: return Color(red: 0.3, green: 0.3, blue: 0.9)
        case .invoice: return Color(red: 0.4, green: 0.4, blue: 0.9)
        case .bill: return Color(red: 0.2, green: 0.6, blue: 0.8)
        case .barcode: return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .handwritten: return Color(red: 0.62, green: 0.102, blue: 0.82)
        case .illustration: return Color(red: 0.19, green: 0.43, blue: 0.98)
        case .other: return Color.gray
        }
    }
    
    var icon: String {
        switch self {
        case .tax: return "briefcase"
        case .receipts: return "receipt"
        case .invoiceBills: return "doc.text"
        case .bank: return "creditcard"
        case .medical: return "cross.fill"
        case .legal: return "scale.3d"
        case .govt: return "building.columns"
        case .insurance: return "shield.checkered"
        case .otherDocuments: return "photo"
        case .textDocument, .document: return "doc.text"
        case .receipt: return "receipt"
        case .invoice: return "doc.text"
        case .bill: return "creditcard"
        case .barcode: return "qrcode"
        case .handwritten: return "scribble.variable"
        case .illustration: return "hand.draw"
        case .other: return "photo"
        }
    }
}