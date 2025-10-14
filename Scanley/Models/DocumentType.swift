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
        }
    }
}