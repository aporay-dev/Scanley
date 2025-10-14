//
//  BenefitRow.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import SwiftUI

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(icon)
                .font(.system(size: 16))
                .frame(width: 20, alignment: .leading)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}