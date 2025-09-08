//
//  Home.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI


struct SearchBoxContainer: View {
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

struct Home: View {
    @State private var isShowingAppDetail = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Main content or AppDetail based on navigation state
            if isShowingAppDetail {
//                AppDetail(onBack: handleBackToHome)
//                    .transition(AnyTransition.asymmetric(insertion: AnyTransition.move(edge: .trailing), removal: AnyTransition.move(edge: .leading)))
            } else {
                mainContentView
            }
            
            // Loading overlay
            if isLoading {
                LoadingView()
            }
        }
    }
    
    private var mainContentView: some View {
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
                    
                    // Search Box Container
                    SearchBoxContainer()

                    ScanSummary()

                    // Event Categories Grid
                    EventCategoriesGrid()
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 100) // Add padding to prevent content from being hidden behind tab bar
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

struct ScanSummary: View {
    
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

struct EventCategoriesGrid: View {
    let categories = [
        EventCategory(numPhotos: 756, title: "Documents", icon: "briefcase", color: Color(red: 1.0, green: 0.4, blue: 0.5)),
        EventCategory(numPhotos: 34, title: "Receipts", icon: "person.crop.rectangle.fill", color: Color(red: 0.3, green: 0.3, blue: 0.9)),
        EventCategory(numPhotos: 89, title: "Invoices", icon: "doc.text", color: Color(red: 0.4, green: 0.4, blue: 0.9)),
        EventCategory(numPhotos: 523, title: "Barcodes\n& QR codes", icon: "qrcode", color: Color(red: 1.0, green: 0.6, blue: 0.2)),
        
        EventCategory(numPhotos: 43, title: "Handwritten notes", icon: "scribble.variable", color: Color(red: 0.62, green: 0.102, blue: 0.82)),
        EventCategory(numPhotos: 67, title: "Illustrations", icon: "hand.draw", color: Color(red: 0.19, green: 0.43, blue: 0.98))

    ]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(categories, id: \.title) { category in
                CategoryCard(category: category)
            }
        }
        .padding(.top,10)
    }
}

struct CategoryCard: View {
    let category: EventCategory
    
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

struct EventCategory {
    let numPhotos: Int32
    let title: String
    let icon: String
    let color: Color
}

struct LoadingView: View {
    @State private var rotationAngle: Double = 0
    @State private var offsetDistance: Double = 30
    
    let dotColors = [
        Color(red: 1.0, green: 0.4, blue: 0.5),    // Red/Pink
        Color(red: 0.3, green: 0.8, blue: 0.9),    // Cyan/Teal
        Color(red: 0.2, green: 0.3, blue: 0.8),    // Blue
        Color(red: 1.0, green: 0.6, blue: 0.2)     // Orange
    ]
    
    var body: some View {
        ZStack {
            // Full screen background matching main screen
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Colorful rotating dots
                ZStack {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(dotColors[index])
                            .frame(width: 30, height: 30)
                            .offset(y: -offsetDistance) // Dynamic distance from center
                            .rotationEffect(.degrees(rotationAngle + Double(index * 90)))
                    }
                }
                .frame(width: 120, height: 120)
                .onAppear {
                    // Spinning animation
                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                    
                    // Spreading and huddling animation
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        offsetDistance = 45
                    }
                }
                

            }
        }
    }
}

#Preview {
    Home()
}
