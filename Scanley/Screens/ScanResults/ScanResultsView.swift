//
//  ScanResultsView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-08.
//

import SwiftUI
import SwiftData

struct ScanResultsView: View {
    @StateObject private var viewModel = SimpleOCRViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isScanning {
                    SimpleOCRProgressView(viewModel: viewModel)
                } else if viewModel.documentsWithTextFound > 0 {
                    SimpleOCRResultsView(viewModel: viewModel)
                } else {
                    SimpleOCREmptyStateView(viewModel: viewModel)
                }
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
            .navigationTitle("OCR Scanner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ScanResultsView()
        .modelContainer(for: DocumentText.self)
}
