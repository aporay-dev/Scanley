//
//  SearchView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import SwiftData
import Photos

struct SearchView: View {
    @StateObject private var searchService: DocumentSearchService
    @State private var searchText = ""
    @State private var showSearchSuggestions = false
    @State private var searchSuggestions: [String] = []
    @State private var selectedResult: SearchResult?
    @State private var showDocumentDetail = false
    @Environment(\.presentationMode) var presentationMode
    
    private let filterByCategory: String?
    
    init(modelContext: ModelContext, filterByCategory: String? = nil) {
        self.filterByCategory = filterByCategory
        self._searchService = StateObject(wrappedValue: DocumentSearchService(modelContext: modelContext, filterByCategory: filterByCategory))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                SearchHeader(
                    searchText: $searchText,
                    showSuggestions: $showSearchSuggestions,
                    suggestions: searchSuggestions,
                    onSearchTextChanged: { newText in
                        searchText = newText
                        if newText.isEmpty {
                            searchService.clearSearch()
                            searchSuggestions = []
                        } else if newText.count >= 2 {
                            Task {
                                searchSuggestions = await searchService.getSearchSuggestions(for: newText)
                                showSearchSuggestions = true
                            }
                        }
                    },
                    onSearchSubmitted: {
                        showSearchSuggestions = false
                        if !searchText.isEmpty {
                            Task {
                                await searchService.search(query: searchText)
                            }
                        }
                    },
                    onSuggestionSelected: { suggestion in
                        searchText = suggestion
                        showSearchSuggestions = false
                        Task {
                            await searchService.search(query: suggestion)
                        }
                    }
                )
                
                // Search Status and Statistics
                if searchService.isSearching {
                    SearchProgressView()
                } else if !searchText.isEmpty && searchService.searchResults.isEmpty {
                    NoResultsView(searchText: searchText)
                } else if searchService.searchResults.isEmpty && searchText.isEmpty {
                    if filterByCategory != nil {
                        CategoryEmptyStateView(category: filterByCategory!)
                    } else {
                        SearchEmptyStateView()
                    }
                } else {
                    // Search Results Header
                    HStack {
                        Text("Found \(searchService.searchResults.count) documents")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("Tap to view details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Search Results Grid
                    SearchResultsList(results: searchService.searchResults) { result in
                        selectedResult = result
                        showDocumentDetail = true
                    }
                }
                
                Spacer()
            }
            .onAppear {
                // If filtering by category, automatically load all documents in that category
                if let category = filterByCategory {
                    Task {
                        await searchService.loadCategoryDocuments(category: category)
                    }
                }
            }
            .navigationTitle(filterByCategory != nil ? filterByCategory! : "Search Documents")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $showDocumentDetail) {
            if let result = selectedResult {
                DocumentDetailView(searchResult: result)
            }
        }
    }
}

struct SearchHeader: View {
    @Binding var searchText: String
    @Binding var showSuggestions: Bool
    let suggestions: [String]
    let onSearchTextChanged: (String) -> Void
    let onSearchSubmitted: () -> Void
    let onSuggestionSelected: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.purple)
                    .padding(.leading, 16)
                
                TextField("Search in document text...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .tint(.purple) // Sets cursor color
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        onSearchSubmitted()
                    }
                    .onChange(of: searchText) { _, newValue in
                       // onSearchTextChanged(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        onSearchTextChanged("")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
                    .padding(.trailing, 16)
                }
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Search Suggestions
            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: {
                            onSuggestionSelected(suggestion)
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Text(suggestion)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if suggestion != suggestions.last {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }
}

struct SearchProgressView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                .scaleEffect(1.2)
            
            Text("Searching documents...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
}

struct NoResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No documents found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("No documents contain text matching '\(searchText)'")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Text("Try searching for:")
                .font(.headline)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Company or store names")
                Text("• Invoice or receipt numbers")
                Text("• Dates or amounts")
                Text("• Product names")
            }
            .font(.body)
            .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }
}

struct SearchEmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("Search Document Text")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Find documents by searching the text extracted from your scanned photos")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.top, 100)
    }
}

struct CategoryEmptyStateView: View {
    let category: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: categoryIcon)
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No \(category) Documents")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Documents classified as \(category) will appear here after you run AI classification")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 8) {
                Text("To populate this category:")
                    .font(.headline)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Scan documents using 'Test OCR' or 'Scan Now'")
                    Text("2. Use 'Classify' button to run AI classification")
                    Text("3. Documents will be automatically categorized")
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
        }
        .padding(.top, 60)
    }
    
    private var categoryIcon: String {
        switch category {
        case "Tax": return "briefcase"
        case "Receipts": return "person.crop.rectangle.fill"
        case "Invoices & Bills": return "doc.text"
        case "Bank": return "creditcard"
        case "Medical": return "qrcode"
        case "Legal": return "scribble.variable"
        case "Govt": return "hand.draw"
        case "Other Documents": return "photo"
        default: return "doc.text.magnifyingglass"
        }
    }
}

struct SearchResultsList: View {
    let results: [SearchResult]
    let onResultTapped: (SearchResult) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(results) { result in
                    SearchResultThumbnail(result: result) {
                        onResultTapped(result)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

struct SearchResultThumbnail: View {
    let result: SearchResult
    let onTapped: () -> Void
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingImage = true
    
    var body: some View {
        Button(action: onTapped) {
            VStack(spacing: 8) {
                // Document Thumbnail
                ZStack {
                    if isLoadingImage {
                        // Loading placeholder
                        Rectangle()
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 120)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                    .scaleEffect(0.8)
                            )
                    } else if let image = thumbnailImage {
                        // Document image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    } else {
                        // Error/fallback state
                        Rectangle()
                            .fill(result.documentTypeEnum.color.opacity(0.2))
                            .frame(height: 120)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: result.documentTypeEnum.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(result.documentTypeEnum.color)
                                    Text("No Image")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    
                    // Relevance score overlay
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(Int(result.relevanceScore))%")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                                .padding(.top, 6)
                                .padding(.trailing, 6)
                        }
                        Spacer()
                    }
                }
                .cornerRadius(8)
                
                // Document info below thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.documentTypeEnum.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(result.documentTypeEnum.color)
                        .lineLimit(1)
                    
                    Text(result.dateExtracted, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let summary = result.textSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadThumbnailImage()
        }
    }
    
    private func loadThumbnailImage() {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .opportunistic
        requestOptions.isNetworkAccessAllowed = false
        requestOptions.resizeMode = .exact
        
        // Get the PHAsset using the document ID
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", result.documentID)
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        guard let asset = assets.firstObject else {
            isLoadingImage = false
            return
        }
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: requestOptions
        ) { image, info in
            DispatchQueue.main.async {
                self.thumbnailImage = image
                self.isLoadingImage = false
            }
        }
    }
}


#Preview {
    SearchView(modelContext: DocumentText.modelContainer.mainContext)
}
