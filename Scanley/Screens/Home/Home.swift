//
//  Home.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import SwiftData

struct Home: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var dataManager = DocumentDataManager.shared
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var showSearchSuggestions = false
    @State private var searchSuggestions: [String] = []
    @State private var searchService: DocumentSearchService?
    @State private var showSearchResults = false
    @State private var isSearching = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Scanley Logo
                    HStack {
                        Image("ScanleyLogo")
                            .resizable()
                            .renderingMode(.template)                   // use alpha mask
                            .foregroundStyle(.primary)
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 40)
                            .padding(.leading, 4)
                            .accessibilityLabel("Scanley")

                        
                        Spacer()
                        

                    }
                    .padding(.top, 1)
                    
                    // Functional Search Box
                    FunctionalSearchBox(
                        searchText: $searchText,
                        showSuggestions: $showSearchSuggestions,
                        suggestions: searchSuggestions,
                        onSearchTextChanged: { newText in
                            searchText = newText
                            if newText.isEmpty {
                                searchService?.clearSearch()
                                searchSuggestions = []
                                showSearchSuggestions = false
                            } else if newText.count >= 2 {
                                Task {
                                    if searchService == nil {
                                        searchService = DocumentSearchService(modelContext: modelContext)
                                    }
                                    searchSuggestions = await searchService?.getSearchSuggestions(for: newText) ?? []
                                    showSearchSuggestions = true
                                }
                            }
                        },
                        onSearchSubmitted: {
                            showSearchSuggestions = false
                            if !searchText.isEmpty {
                                Task {
                                    if searchService == nil {
                                        searchService = DocumentSearchService(modelContext: modelContext)
                                    }
                                    isSearching = true
                                    await searchService?.search(query: searchText)
                                    isSearching = false
                                    showSearchResults = true
                                }
                            }
                        },
                        onSuggestionSelected: { suggestion in
                            searchText = suggestion
                            showSearchSuggestions = false
                            Task {
                                if searchService == nil {
                                    searchService = DocumentSearchService(modelContext: modelContext)
                                }
                                isSearching = true
                                await searchService?.search(query: suggestion)
                                isSearching = false
                                showSearchResults = true
                            }
                        }
                    )

                    // Classification Status (if active)
                    if viewModel.isClassifying || !viewModel.classificationStatus.isEmpty {
                        ClassificationStatusView(
                            isClassifying: viewModel.isClassifying,
                            progress: viewModel.classificationProgress,
                            statusMessage: viewModel.classificationStatus
                        )
                    }
                    
                    // Summary section
                    ScanSummarySection(
                        totalDocuments: viewModel.totalDocumentsFound,
                        lastScanDate: viewModel.lastScanDate
                    )

                    // Photo Categories Grid
                    PhotoCategoriesGrid(
                        categories: viewModel.photoCategories,
                        onCategoryTapped: { category in
                            viewModel.openCategorySearch(for: category)
                        }
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

            }
            .background(Color(UIColor.systemGroupedBackground))
            
            // Floating Action Buttons - Bottom Right
        VStack {
                Spacer()
                HStack {
                    Spacer()
                    // TMP BUTTONS. REMOVE HSTACK
                    HStack(spacing: 8) {
                        // Classify Button (For Testing)
                        Button(action: {
                            Task {
                                await viewModel.classifyDocuments(context: modelContext)
                            }
                        }) {
                            HStack(spacing: 4) {
                                if viewModel.isClassifying {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                } else {
                                    Image(systemName: "brain")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                Text(viewModel.isClassifying ? "Classifying..." : "Classify")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isClassifying)
                        
                        // Temporary Delete All Data Button (For Testing)
                        Button(action: {
                            Task {
                                await viewModel.deleteAllData(context: modelContext)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Delete All")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    VStack(spacing: 12) {
                        // Test OCR Button (New Simple Approach)
                        Button(action: {
                            viewModel.openSimpleOCR()
                        }) {
                            HStack(spacing: 8) {
                                Text("Scan now")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.orange)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20) // Account for safe area
                    
                    
                    
                    
                }
            
            }
        }
        .sheet(isPresented: $viewModel.showSearchView) {
            SearchView(modelContext: modelContext, filterByCategory: viewModel.selectedCategory)
        }
        .sheet(isPresented: $viewModel.showSimpleOCR) {
            SimpleOCRView()
        }
        .sheet(isPresented: $showSearchResults) {
            if let searchService = searchService {
                HomeSearchResultsView(
                    searchText: searchText,
                    searchService: searchService,
                    isSearching: isSearching,
                    onResultTapped: { _ in }, // Not used anymore
                    onDismiss: {
                        showSearchResults = false
                    }
                )
            }
        }
        .task {
            await viewModel.loadScanSummary(context: modelContext)
        }
    }
}

struct FunctionalSearchBox: View {
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

                TextField("Search receipts, bills, documents...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .tint(.purple)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        onSearchSubmitted()
                    }
                    .onChange(of: searchText) { _, newValue in
                        onSearchTextChanged(newValue)
                    }

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        onSearchTextChanged("")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
                    .padding(.trailing, 16)
                } else {
                    Text("Go")
                        .font(.system(size: 18, weight: .black))
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
            .padding(.top, 10)
            .padding(.horizontal, 4)

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
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
        }
    }
}

struct ScanSummarySection: View {
    let totalDocuments: Int
    let lastScanDate: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String("Last Scan Summary"))
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

            }
            
                Group {
                    if totalDocuments > 0 {
                        if let lastScanDate = lastScanDate {
                            Text("\(totalDocuments) documents found • \(lastScanDate, style: .date)")
                        } else {
                            Text("\(totalDocuments) documents found")
                        }
                    } else {
                        Text("No scan performed yet")
                    }
                }
                .font(.system(size: 16, weight: .medium))
                  .foregroundColor(.white)
                  .multilineTextAlignment(.leading)
                  .lineLimit(nil)
        }
        .padding(16)
        .frame(height: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1.0, green: 0.6, blue: 0.2))
        .cornerRadius(12)
    }
}

struct PhotoCategoriesGrid: View {
    let categories: [PhotoCategory]
    let onCategoryTapped: (PhotoCategory) -> Void
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(categories, id: \.title) { category in
                PhotoCategoryCard(
                    category: category,
                    onTapped: {
                        onCategoryTapped(category)
                    }
                )
            }
        }
        .padding(.top,10)
    }
}

struct PhotoCategoryCard: View {
    let category: PhotoCategory
    let onTapped: () -> Void
    
    var body: some View {
        Button(action: onTapped) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(category.numPhotos))
                        .font(.system(size: 38, weight: .light))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: category.icon)
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                
                              Text(category.title)
                    .font(.system(size: 18, weight: .bold))
                      .foregroundColor(.white)
                      .multilineTextAlignment(.leading)
                      .lineLimit(nil)
            }
            .padding(16)
            .frame(height: 85)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(category.color)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ClassificationStatusView: View {
    let isClassifying: Bool
    let progress: Double
    let statusMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text("AI Classification")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isClassifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            
            Text(statusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
            
            if isClassifying && progress > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .background(Color.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.8))
        .cornerRadius(12)
    }
}

struct HomeSearchResultsView: View {
    let searchText: String
    let searchService: DocumentSearchService
    let isSearching: Bool
    let onResultTapped: (SearchResult) -> Void
    let onDismiss: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedResult: SearchResult?
    @State private var showDocumentDetail = false

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Search Status and Statistics
                    if isSearching {
                        HomeSearchProgressView()
                    } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                        HomeNoResultsView(searchText: searchText)
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

                // Navigation Links (hidden)
                NavigationLink(
                    destination: selectedResult != nil ? DocumentDetailView(searchResult: selectedResult!) : nil,
                    isActive: $showDocumentDetail
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationTitle("Search: \(searchText)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    onDismiss()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct HomeSearchProgressView: View {
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

struct HomeNoResultsView: View {
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

#Preview {
    Home()
        .modelContainer(for: DocumentText.self)
}
