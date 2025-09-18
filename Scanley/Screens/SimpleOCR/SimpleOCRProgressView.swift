//
//  SimpleOCRProgressView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import SwiftUI

struct SimpleOCRProgressView: View {
    @ObservedObject var viewModel: SimpleOCRViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView(value: viewModel.scanProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .frame(height: 8)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Text("Running Simple OCR")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(viewModel.scanStatusMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("\(viewModel.totalPhotosScanned)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Photos Scanned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(viewModel.documentsWithTextFound)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("With Text Found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 10)
                
                Button(AlertManager.buttons.cancel + " Scan") {
                    viewModel.cancelScan()
                }
                .foregroundColor(.red)
                .padding(.top, 20)
            }
            
            if let error = viewModel.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            }
            
            Spacer()
        }
        .padding()
    }
}