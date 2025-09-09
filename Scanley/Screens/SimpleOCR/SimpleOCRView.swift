//
//  SimpleOCRView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI

struct SimpleOCRView: View {
    @ObservedObject var scanner: SimpleOCRScanner
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if scanner.isScanning {
                    SimpleOCRProgressView(scanner: scanner)
                } else if scanner.documentsWithTextFound > 0 {
                    SimpleOCRResultsView(scanner: scanner)
                } else {
                    SimpleOCREmptyStateView(scanner: scanner)
                }
            }
            .navigationTitle("Test OCR Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct SimpleOCREmptyStateView: View {
    @ObservedObject var scanner: SimpleOCRScanner
    
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
                    get: { scanner.isTestMode },
                    set: { scanner.isTestMode = $0 }
                ))
                .padding(.horizontal, 40)
                
                if scanner.isTestMode {
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
                    await scanner.startSimpleOCRScan()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(scanner.isTestMode ? "Start Test OCR" : "Start Simple OCR")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(scanner.isTestMode ? Color.orange : Color.orange.opacity(0.8))
                .cornerRadius(25)
            }
            .padding(.top, 20)
            
            if !scanner.scanStatusMessage.isEmpty {
                Text(scanner.scanStatusMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
            
            Spacer()
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}

struct SimpleOCRProgressView: View {
    @ObservedObject var scanner: SimpleOCRScanner
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView(value: scanner.scanProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .frame(height: 8)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Text("Running Simple OCR")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(scanner.scanStatusMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("\(scanner.totalPhotosScanned)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Photos Scanned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(scanner.documentsWithTextFound)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("With Text Found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 10)
                
                Button("Cancel Scan") {
                    scanner.cancelScan()
                }
                .foregroundColor(.red)
                .padding(.top, 20)
            }
            
            if let error = scanner.lastError {
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

struct SimpleOCRResultsView: View {
    @ObservedObject var scanner: SimpleOCRScanner
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Simple OCR Complete!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Found text in \(scanner.documentsWithTextFound) photos out of \(scanner.totalPhotosScanned) scanned")
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
                    ResultRow(label: "Photos Processed", value: "\(scanner.totalPhotosScanned)")
                    ResultRow(label: "Photos with Text", value: "\(scanner.documentsWithTextFound)")
                    ResultRow(label: "Success Rate", value: "\(Int(Double(scanner.documentsWithTextFound) / Double(max(scanner.totalPhotosScanned, 1)) * 100))%")
                    ResultRow(label: "Scan Mode", value: scanner.isTestMode ? "Test (100 photos)" : "Full Library")
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
                // Reset for another scan
                Task {
                    await scanner.startSimpleOCRScan()
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

struct ResultRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    SimpleOCRView(scanner: SimpleOCRScanner())
}