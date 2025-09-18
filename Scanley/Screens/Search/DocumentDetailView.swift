//
//  DocumentDetailView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import Photos

struct DocumentDetailView: View {
    let searchResult: SearchResult
    @State private var documentImage: UIImage?
    @State private var isLoading = true
    @State private var loadError: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Document Image Section
                    if isLoading {
                        DocumentImagePlaceholder()
                    } else if let image = documentImage {
                        DocumentImageView(image: image)
                    } else {
                        DocumentImageError(error: loadError ?? "Failed to load image")
                    }
                    
                    // Document Info Section
                    DocumentInfoSection(result: searchResult)
                    
                    // Extracted Text Section
                    ExtractedTextSection(result: searchResult)
                    
                    // Matching Snippets Section
                    if !searchResult.matchingSnippets.isEmpty {
                        MatchingSnippetsSection(result: searchResult)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            loadDocumentImage()
        }
    }
    
    private func loadDocumentImage() {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.resizeMode = .exact
        
        // Get the PHAsset using the document ID
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", searchResult.documentID)
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        guard let asset = assets.firstObject else {
            isLoading = false
            loadError = "Document not found in photo library"
            print("❌ Could not find asset with ID: \(searchResult.documentID)")
            return
        }
        
        print("📸 Loading image for document: \(searchResult.documentID)")
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 1024, height: 1024),
            contentMode: .aspectFit,
            options: requestOptions
        ) { image, info in
            DispatchQueue.main.async {
                if let image = image {
                    self.documentImage = image
                    print("✅ Successfully loaded document image")
                } else {
                    self.loadError = "Failed to load image from photo library"
                    print("❌ Failed to load image for document: \(searchResult.documentID)")
                }
                self.isLoading = false
            }
        }
    }
}

struct DocumentImagePlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.2)
            
            Text("Loading document...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct DocumentImageView: View {
    let image: UIImage
    @State private var showFullScreen = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Image")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button(action: {
                showFullScreen = true
            }) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Tap to view full size")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenImageView(image: image, isPresented: $showFullScreen)
        }
    }
}

struct DocumentImageError: View {
    let error: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Unable to Load Image")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct DocumentInfoSection: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document Information")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                InfoRow(label: "Type", value: result.documentTypeEnum.rawValue, color: result.documentTypeEnum.color)
                InfoRow(label: "Date Extracted", value: result.dateExtracted.formatted(date: .abbreviated, time: .shortened))
                InfoRow(label: "OCR Confidence", value: "\(Int(result.ocrConfidence * 100))%")
                InfoRow(label: "Relevance Score", value: "\(Int(result.relevanceScore))%", color: .green)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let color: Color?
    
    init(label: String, value: String, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(color ?? .primary)
        }
    }
}

struct ExtractedTextSection: View {
    let result: SearchResult
    @State private var showFullText = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Extracted Text")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if result.extractedText.count > 500 {
                    Button(showFullText ? "Show Less" : "Show All") {
                        showFullText.toggle()
                    }
                    .font(.caption)
                    .foregroundColor(.cyan)
                }
            }
            
            let displayText = showFullText ? result.extractedText : String(result.extractedText.prefix(500))
            
            ScrollView {
                Text(displayText + (result.extractedText.count > 500 && !showFullText ? "..." : ""))
                    .font(.system(size: 14).monospaced())
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(8)
            }
            .frame(maxHeight: showFullText ? .infinity : 200)
        }
    }
}

struct MatchingSnippetsSection: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matching Text Highlights")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.matchingSnippets.enumerated()), id: \.offset) { index, snippet in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .leading)
                        
                        Text(snippet)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
}

struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                
                Spacer()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1 {
                                        withAnimation(.spring()) {
                                            scale = 1
                                            lastScale = 1
                                            offset = .zero
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation
                                }
                                .onEnded { _ in
                                    if scale <= 1 {
                                        withAnimation(.spring()) {
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                    )
                
                Spacer()
            }
        }
    }
}

#Preview {
    DocumentDetailView(searchResult: SearchResult(
        documentID: "test-id",
        documentType: "Receipt",
        dateExtracted: Date(),
        extractedText: "Sample receipt text from Target store\nTotal: $25.99\nDate: 09/08/2025",
        matchingSnippets: ["Target store", "Total: $25.99"],
        relevanceScore: 85.0,
        ocrConfidence: 0.92,
        textSummary: "Receipt from Target store for $25.99"
    ))
}
