//
//  SimpleOCRResultsView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import SwiftUI

struct SimpleOCRResultsView: View {
    @ObservedObject var viewModel: SimpleOCRViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Simple Scan Complete!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Found text in \(viewModel.documentsWithTextFound) photos out of \(viewModel.totalPhotosScanned) scanned")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Results Summary Box
            VStack(alignment: .leading, spacing: 12) {
                Text("📊 Scan Results:")
                    .font(.headline)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 8) {
                    ResultRow(label: "Photos Processed", value: "\(viewModel.totalPhotosScanned)")
                    ResultRow(label: "Photos with Text", value: "\(viewModel.documentsWithTextFound)")
                    ResultRow(label: "Success Rate", value: "\(Int(Double(viewModel.documentsWithTextFound) / Double(max(viewModel.totalPhotosScanned, 1)) * 100))%")
                    ResultRow(label: "Scan Mode", value: viewModel.isTestMode ? "Test (100 photos)" : "Full Library")
                }
            }
            .padding(16)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                Text("🎉 All text has been extracted and stored!")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                
                Text("You can now search through all this text using the search feature on the home screen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 10)
            
            Button(action: {
                Task {
                    await viewModel.startSimpleOCRScan()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Scan Again")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(Color.orange)
                .cornerRadius(25)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
    }
}
