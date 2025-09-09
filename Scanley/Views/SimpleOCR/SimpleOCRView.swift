//
//  SimpleOCRView.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import SwiftUI
import SwiftData

struct SimpleOCRView: View {
    @StateObject private var viewModel = SimpleOCRViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isScanning {
                    SimpleOCRProgressView(viewModel: viewModel)
                } else if viewModel.documentsWithTextFound > 0 {
                    SimpleOCRResultsView(viewModel: viewModel)
                } else {
                    SimpleOCREmptyStateView(viewModel: viewModel)
                }
            }
            .navigationTitle("Test OCR Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(AlertManager.buttons.close) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
}

#Preview {
    SimpleOCRView()
        .modelContainer(for: DocumentText.self)
}