//
//  ScanResultsView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import Photos
import SwiftData

struct ScanResultsView: View {
    @StateObject private var scanner = PhotoLibraryDocumentScanner()
    @State private var selectedDocumentType: DocumentType? = nil
    @Environment(\.modelContext) private var modelContext
    @State private var ocrExtractor: OCRTextExtractor?
    
    var filteredDocuments: [DocumentPhoto] {
        if let selectedType = selectedDocumentType {
            return scanner.documentsFound.filter { $0.documentType == selectedType }
        }
        return scanner.documentsFound
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if scanner.isScanning {
                    ScanProgressView(scanner: scanner)
                } else if scanner.documentsFound.isEmpty {
                    EmptyStateView(scanner: scanner)
                } else {
                    DocumentResultsView(
                        documents: filteredDocuments,
                        scanner: scanner,
                        selectedType: $selectedDocumentType,
                        ocrExtractor: ocrExtractor
                    )
                }
            }
            .onAppear {
                // Initialize OCR extractor with model context
                if ocrExtractor == nil {
                    ocrExtractor = OCRTextExtractor(modelContext: modelContext)
                }
            }
            .navigationTitle("Document Scanner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ScanProgressView: View {
    @ObservedObject var scanner: PhotoLibraryDocumentScanner
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView(value: scanner.scanProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 8)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Text("Scanning Photo Library")
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
                        Text("\(scanner.documentsDetected)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Documents Found")
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

struct EmptyStateView: View {
    @ObservedObject var scanner: PhotoLibraryDocumentScanner
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("Scan Photo Library")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Find all document photos in your library using on-device AI")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
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
                    await scanner.startDocumentScan()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text(scanner.isTestMode ? "Start Test Scan" : "Start Scanning")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(scanner.isTestMode ? Color.orange : Color.cyan)
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

struct DocumentResultsView: View {
    let documents: [DocumentPhoto]
    @ObservedObject var scanner: PhotoLibraryDocumentScanner
    @Binding var selectedType: DocumentType?
    @State var ocrExtractor: OCRTextExtractor?
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DocumentTypeFilter(selectedType: $selectedType, scanner: scanner, ocrExtractor: ocrExtractor)
            
            // OCR Progress View (if processing)
            if let extractor = ocrExtractor, extractor.isProcessing {
                OCRProgressView(ocrExtractor: extractor)
            }
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(documents) { document in
                        DocumentPhotoCard(document: document)
                    }
                }
                .padding()
            }
        }
    }
}

struct DocumentTypeFilter: View {
    @Binding var selectedType: DocumentType?
    @ObservedObject var scanner: PhotoLibraryDocumentScanner
    @State var ocrExtractor: OCRTextExtractor?
    
    var documentTypeCounts: [DocumentType: Int] {
        Dictionary(grouping: scanner.documentsFound, by: \.documentType)
            .mapValues { $0.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Found \(scanner.documentsDetected) documents")
                        .font(.headline)
                    if scanner.isTestMode {
                        Text("Test Mode - Latest 100 photos")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.leading, 16)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // OCR Extract Button
                    Button("Extract Text") {
                        if let extractor = ocrExtractor {
                            Task {
                                await extractor.extractTextFromDocuments(scanner.documentsFound)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .disabled(ocrExtractor?.isProcessing ?? false)
                    
                    Button("Scan Again") {
                        Task {
                            await scanner.startDocumentScan()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(scanner.isTestMode ? .orange : .cyan)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChip(
                        title: "All",
                        count: scanner.documentsDetected,
                        isSelected: selectedType == nil
                    ) {
                        selectedType = nil
                    }
                    
                    ForEach(DocumentType.allCases, id: \.self) { type in
                        if let count = documentTypeCounts[type], count > 0 {
                            FilterChip(
                                title: type.rawValue,
                                count: count,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text("(\(count))")
            }
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.cyan : Color(UIColor.secondarySystemFill))
            )
        }
    }
}

struct DocumentPhotoCard: View {
    let document: DocumentPhoto
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(uiImage: document.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.documentType.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(document.documentType.color)
                    
                    Text(document.dateCreated, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(document.detectionConfidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ScanResultsView()
}