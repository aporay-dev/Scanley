//
//  Home.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI

struct Home: View {
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
                    SearchBox()
                    
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
            
            // Scan Now Button - Bottom Right
        VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        // Handle scan action
                        print("Scan Now button tapped!")
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
                    .padding(.trailing, 20)
                    .padding(.bottom, 20) // Account for safe area
                }
            }
        }
    }
}

struct SearchBox: View {
    @State private var searchText = ""
    
    var body: some View {
        // Search Box with Purple Border
        HStack(spacing: 12) {
            // Purple magnifying glass icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.purple)
                .padding(.leading, 16)
            
            // Search text field
            TextField("Search receipts, bills, documents...", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .textFieldStyle(PlainTextFieldStyle())
                .accentColor(.purple)
                .colorScheme(.light)
            Text("Go")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.purple)
                .padding(.leading, 16)

            
            Spacer()
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
        .padding(.top,10)
        .padding(.horizontal, 4)
    }
}

struct ScanSummarySection: View {
    
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
            
                Text("Total photos/Last scan date")
                .font(.system(size: 18, weight: .bold))
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
            ForEach(photoCategories, id: \.title) { category in
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
}
