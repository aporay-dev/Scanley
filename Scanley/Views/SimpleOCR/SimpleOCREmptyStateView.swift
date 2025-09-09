//
//  SimpleOCREmptyStateView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import SwiftUI

struct SimpleOCREmptyStateView: View {
    @ObservedObject var viewModel: SimpleOCRViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Simple OCR Test")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("This will run OCR directly on all photos without document classification for faster processing")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Performance Benefits Box
            VStack(alignment: .leading, spacing: 12) {
                Text("🚀 Performance Benefits:")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 8) {
                    BenefitRow(icon: "⚡", text: "Single Vision API call per photo")
                    BenefitRow(icon: "🎯", text: "No complex document detection")
                    BenefitRow(icon: "⏱️", text: "Faster parallel processing")
                    BenefitRow(icon: "🔍", text: "Catches all text, no false negatives")
                }
            }
            .padding(16)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // Test Mode Toggle
            VStack(spacing: 12) {
                Toggle("Test Mode (Latest 100 photos)", isOn: Binding(
                    get: { viewModel.isTestMode },
                    set: { viewModel.isTestMode = $0 }
                ))
                .padding(.horizontal, 40)
                
                if viewModel.isTestMode {
                    Text("Test mode will scan only the latest 100 photos for faster testing")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.top, 10)
            
            Button(action: {
                Task {
                    await viewModel.startSimpleOCRScan()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(viewModel.isTestMode ? "Start Test OCR" : "Start Simple OCR")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(viewModel.isTestMode ? Color.orange : Color.orange.opacity(0.8))
                .cornerRadius(25)
            }
            .padding(.top, 20)
            
            if !viewModel.scanStatusMessage.isEmpty {
                Text(viewModel.scanStatusMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
            
            Spacer()
        }
    }
}



