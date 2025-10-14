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
                } else if viewModel.isClassifying {
                    SimpleOCRClassificationView(viewModel: viewModel)
                } else if viewModel.documentsWithTextFound > 0 {
                    SimpleOCRResultsView(viewModel: viewModel)
                } else {
                    SimpleOCREmptyStateView(viewModel: viewModel)
                }
            }
//            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(AlertManager.buttons.close) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
}

struct SimpleOCRClassificationView: View {
    @ObservedObject var viewModel: SimpleOCRViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Classification Icon
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Text("Classifying Documents")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(viewModel.classificationStatus)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            // Progress Indicator
            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)

                Text("This may take a few moments...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SimpleOCRView()
        .modelContainer(for: DocumentText.self)
}
