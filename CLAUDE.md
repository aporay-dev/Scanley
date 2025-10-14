# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Scanley is a SwiftUI-based iOS document scanning application built with Xcode 16.4, targeting iOS 18.5+. The app allows users to scan, categorize, and manage documents across eight categories: Tax, Receipts, Invoices & Bills, Bank, Medical, Legal, Government, and Insurance.

## Build and Development Commands

### Build and Run
```bash
# Build the project
xcodebuild -project Scanley.xcodeproj -scheme Scanley -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run in iOS Simulator
open Scanley.xcodeproj
# Use Xcode's Run button (⌘+R) or Product > Run
```

### Development Setup
- **Xcode Version**: 16.4+
- **iOS Deployment Target**: 18.5
- **Swift Version**: 5.0
- **Bundle ID**: com.myriadtechlabs.Scanley
- **Team ID**: YF57MZPJ2Q

## Architecture

### Project Structure
```
Scanley/
├── ScanleyApp.swift          # Main app entry point
├── Global.swift              # Global data models and constants
├── Screens/
│   └── Home/
│       └── Home.swift        # Main home screen with search, categories, and scan button
└── Custom Views/
    └── Loading.swift         # Animated loading screen component
```

### Key Components

#### Main App Structure
- **ScanleyApp.swift**: Entry point using `@main` attribute, displays `Home()` view
- **Home.swift**: Primary screen containing the main UI layout

#### Data Models
- **PhotoCategory**: Struct defining document categories with count, title, icon, and color
- **photoCategories**: Global array of predefined categories (Tax, Receipts, Invoices & Bills, Bank, Medical, Legal, Govt, Insurance)

#### UI Components
- **SearchBox**: Purple-themed search interface for documents
- **ScanSummarySection**: Orange summary card showing last scan information
- **PhotoCategoriesGrid**: 2-column grid displaying category cards
- **PhotoCategoryCard**: Individual category cards with count, icon, and colored backgrounds
- **Loading**: Animated loading screen with rotating colorful dots

### Design System
- Uses system background colors (`UIColor.systemGroupedBackground`)
- Color palette includes purple accents, cyan scan button, and category-specific colors
- Custom rounded corners (12pt radius) and shadows
- SwiftUI-native styling with accessibility labels
- Portrait-only orientation support

### Development Notes
- SwiftUI-based with iOS 18.5+ deployment target
- Uses `LazyVGrid` for efficient category grid rendering
- Implements proper accessibility with `accessibilityLabel`
- Template rendering mode for logo to support light/dark themes
- Uses `@State` for local component state management