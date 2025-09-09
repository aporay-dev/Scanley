//
//  ScanResultsViewModel.swift
//  Scanley
//
//  Created by Anand Poray on 2025-09-09.
//

import Foundation
import SwiftData

@MainActor
class ScanResultsViewModel: ObservableObject {
    @Published var simpleOCRScanner: SimpleOCRViewModel
    
    private var modelContext: ModelContext?
    
    init() {
        self.simpleOCRScanner = SimpleOCRViewModel()
    }
    
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        simpleOCRScanner.setModelContext(context)
    }
}