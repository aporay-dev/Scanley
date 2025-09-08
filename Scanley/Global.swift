//
//  Global.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI

let photoCategories = [
    PhotoCategory(numPhotos: 756, title: "Documents", icon: "briefcase", color: Color(red: 1.0, green: 0.4, blue: 0.5)),
    PhotoCategory(numPhotos: 34, title: "Receipts", icon: "person.crop.rectangle.fill", color: Color(red: 0.3, green: 0.3, blue: 0.9)),
    PhotoCategory(numPhotos: 89, title: "Invoices", icon: "doc.text", color: Color(red: 0.4, green: 0.4, blue: 0.9)),
    PhotoCategory(numPhotos: 523, title: "Barcodes\n& QR codes", icon: "qrcode", color: Color(red: 1.0, green: 0.6, blue: 0.2)),
    
    PhotoCategory(numPhotos: 43, title: "Handwritten notes", icon: "scribble.variable", color: Color(red: 0.62, green: 0.102, blue: 0.82)),
    PhotoCategory(numPhotos: 67, title: "Illustrations", icon: "hand.draw", color: Color(red: 0.19, green: 0.43, blue: 0.98))

]

struct PhotoCategory {
    let numPhotos: Int32
    let title: String
    let icon: String
    let color: Color
}
