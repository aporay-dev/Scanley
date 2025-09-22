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
                Text("Document Scan")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This scan will process all photos to extract text and automatically classify documents")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // What Scan Does Box
            VStack(alignment: .leading, spacing: 12) {
                Text("📋 What This Scan Does:")
                    .font(.headline)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 8) {
                    BenefitRow(icon: "📸", text: "Analyzes all photos in your library")
                    BenefitRow(icon: "🔍", text: "Makes all text searchable from home screen")
                    BenefitRow(icon: "🤖", text: "AI search for your photos")
                    BenefitRow(icon: "📱", text: "All on your device")
                    BenefitRow(icon: "🔒", text: "Nothing leaves your phone")
                    BenefitRow(icon: "🛡️", text: "Safe. Private. Secure")
                }
            }
            .padding(16)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            
            Button(action: {
                Task {
                    await viewModel.startSimpleOCRScan()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Document Scan")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(Color.orange)
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



