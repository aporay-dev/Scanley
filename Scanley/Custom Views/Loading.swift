//
//  Loading.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI

struct Loading: View {
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
    Loading()
}
