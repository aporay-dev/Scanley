//
//  OCRProgressView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI

struct OCRProgressView: View {
    @ObservedObject var ocrExtractor: OCRTextExtractor
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
                
                Text("Extracting Text from Documents")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Cancel") {
                    ocrExtractor.cancelExtraction()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Progress Bar
            ProgressView(value: ocrExtractor.processingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .frame(height: 8)
                .padding(.horizontal, 16)
            
            // Status Message
            Text(ocrExtractor.processingStatus)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    @Previewable @StateObject var mockExtractor = OCRTextExtractor(modelContext: DocumentText.modelContainer.mainContext)
    
    return OCRProgressView(ocrExtractor: mockExtractor)
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
}