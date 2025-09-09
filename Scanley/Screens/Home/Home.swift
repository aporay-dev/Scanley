//
//  Home.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import SwiftData

struct Home: View {
    @State private var showScanResults = false
    @State private var showSearchView = false
    @State private var showSimpleOCR = false
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
                    }
                    .padding(.top, 1)
                    
                    // Search Box
                    SearchBox(onTapped: {
                        showSearchView = true
                    })
                    
                    // Summary section
                    ScanSummarySection()

                    // Photo Categories Grid
                    PhotoCategoriesGrid()
                    
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
                            showSimpleOCR = true
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
                            showScanResults = true
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
        .sheet(isPresented: $showScanResults) {
            ScanResultsView()
        }
        .sheet(isPresented: $showSearchView) {
            SearchView(modelContext: modelContext)
        }
        .sheet(isPresented: $showSimpleOCR) {
            SimpleOCRView()
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
    @ObservedObject var dataManager = DocumentDataManager.shared
    
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
                    if dataManager.totalDocumentsFound > 0 {
                        if let lastScanDate = dataManager.lastScanDate {
                            Text("\(dataManager.totalDocumentsFound) documents found • \(lastScanDate, style: .date)")
                        } else {
                            Text("\(dataManager.totalDocumentsFound) documents found")
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
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(defaultPhotoCategories, id: \.title) { category in
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
        .frame(height: 140)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(category.color)
        .cornerRadius(12)
    }
}

#Preview {
    Home()
        .modelContainer(for: DocumentText.self)
}
