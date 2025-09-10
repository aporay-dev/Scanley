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
                    }
                    .padding(.top, 1)
                    
                    // Search Box
                    SearchBox(onTapped: {
                        viewModel.openSearchView()
                    })
                    
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
                    PhotoCategoriesGrid(categories: viewModel.photoCategories)
                    
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
                    VStack(spacing: 12) {
                        // Test OCR Button (New Simple Approach)
                        Button(action: {
                            viewModel.openSimpleOCR()
                        }) {
                            HStack(spacing: 8) {
                                Text("Test OCR")
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
                        
                        // Original Scan Now Button
                        Button(action: {
                            viewModel.openScanResults()
                        }) {
                            HStack(spacing: 8) {
                                Text("Scan Now")
                                    .font(.system(size: 16, weight: .medium))
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.cyan)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20) // Account for safe area
                }
            }
        }
        .sheet(isPresented: $viewModel.showScanResults) {
            ScanResultsView()
        }
        .sheet(isPresented: $viewModel.showSearchView) {
            SearchView(modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showSimpleOCR) {
            SimpleOCRView()
        }
        .task {
            await viewModel.loadScanSummary(context: modelContext)
        }
    }
}

struct SearchBox: View {
    let onTapped: () -> Void
    
    var body: some View {
        // Search Box with Purple Border - Tap to open search
        Button(action: onTapped) {
            HStack(spacing: 12) {
                // Purple magnifying glass icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.purple)
                    .padding(.leading, 16)
                
                // Placeholder text
                Text("Search receipts, bills, documents...")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Go")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.purple)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top,10)
        .padding(.horizontal, 4)
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
                Spacer()
                Image(systemName: "heart")
                    .font(.largeTitle)
                    .foregroundColor(.white)
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
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(categories, id: \.title) { category in
                PhotoCategoryCard(category: category)
            }
        }
        .padding(.top,10)
    }
}

struct PhotoCategoryCard: View {
    let category: PhotoCategory
    
    var body: some View {
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

#Preview {
    Home()
        .modelContainer(for: DocumentText.self)
}
