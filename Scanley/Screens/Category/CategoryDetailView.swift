//
//  CategoryDetailView.swift
//  Scanley
//
//  Created by Claude on 2025-09-18.
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let category: PhotoCategory
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode
    @State private var documents: [SearchResult] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var navigationPath = NavigationPath()

    private let swiftDataManager = SwiftDataManager.shared

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Header with category info
                CategoryHeader(category: category)

                // Content
                if isLoading {
                    LoadingStateView()
                } else if let error = loadError {
                    ErrorStateView(error: error) {
                        loadDocuments()
                    }
                } else if documents.isEmpty {
                    EmptyStateView(category: category)
                } else {
                    DocumentGrid(documents: documents) { document in
                        navigationPath.append(document)
                    }
                }
            }
            .navigationBarTitle(category.title, displayMode: .large)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationDestination(for: SearchResult.self) { result in
                DocumentDetailView(searchResult: result)
            }
        }
        .onAppear {
            loadDocuments()
        }
    }

    private func loadDocuments() {
        isLoading = true
        loadError = nil

        Task {
            do {
                // Map PhotoCategory title to DocumentCategory for filtering
                let documentCategory = mapToDocumentCategory(category.title)
                let documentTexts = try swiftDataManager.fetchDocumentTexts(filteredBy: documentCategory, context: modelContext)

                // Convert DocumentText to SearchResult
                let searchResults = documentTexts.map { documentText in
                    SearchResult(
                        documentID: documentText.documentID,
                        documentType: documentText.documentType,
                        dateExtracted: documentText.dateExtracted,
                        extractedText: documentText.extractedText,
                        matchingSnippets: [],
                        relevanceScore: 100.0,
                        ocrConfidence: documentText.confidence,
                        textSummary: String(documentText.extractedText.prefix(150))
                    )
                }

                await MainActor.run {
                    self.documents = searchResults.sorted { $0.dateExtracted > $1.dateExtracted }
                    self.isLoading = false
                }


            } catch {
                await MainActor.run {
                    self.loadError = "Failed to load documents: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func mapToDocumentCategory(_ categoryTitle: String) -> String {
        // Map PhotoCategory titles to DocumentCategory enum values
        switch categoryTitle {
        case "Tax":
            return "Tax"
        case "Receipts":
            return "Receipts"
        case "Invoices & Bills":
            return "Invoices & Bills"
        case "Bank":
            return "Bank"
        case "Medical":
            return "Medical"
        case "Legal":
            return "Legal"
        case "Govt":
            return "Govt"
        case "Insurance":
            return "Insurance"
        case "Documents":
            return "Documents"
        default:
            return "Documents"
        }
    }
}

struct CategoryHeader: View {
    let category: PhotoCategory

    var body: some View {
        HStack(spacing: 16) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(category.color)
            }

            // Category Info
            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("\(category.numPhotos) documents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.2)

            Text("Loading documents...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

struct ErrorStateView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Error Loading Documents")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button("Try Again") {
                onRetry()
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.cyan)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

struct EmptyStateView: View {
    let category: PhotoCategory

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: category.icon)
                .font(.system(size: 64))
                .foregroundColor(category.color.opacity(0.5))

            VStack(spacing: 8) {
                Text("No \(category.title) Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Documents will appear here once you scan and classify them.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Text("💡 Tip: Use the 'Scan Documents' button to add documents, then tap 'Classify' to categorize them.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

struct DocumentGrid: View {
    let documents: [SearchResult]
    let onDocumentTapped: (SearchResult) -> Void
    @StateObject private var imageManager = ThumbnailImageManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(documents) { document in
                    SearchResultThumbnail(result: document) {
                        onDocumentTapped(document)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            preloadVisibleThumbnails()
        }
    }

    private func preloadVisibleThumbnails() {
        // Preload first batch of thumbnails for faster initial display
        let initialBatchSize = min(6, documents.count) // First 6 items (2 columns × 3 rows)
        let initialDocumentIDs = Array(documents.prefix(initialBatchSize).map { $0.documentID })

        Task {
            _ = await imageManager.batchLoadThumbnails(documentIDs: initialDocumentIDs)
        }
    }
}

#Preview {
    CategoryDetailView(category: PhotoCategory(
        numPhotos: 15,
        title: "Receipts",
        icon: "newspaper",
        color: .blue.opacity(0.8)
    ))
}