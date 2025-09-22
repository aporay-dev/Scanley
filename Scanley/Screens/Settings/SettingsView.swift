//
//  SettingsView.swift
//  Scanley
//
//  Created by Claude on 2025-09-20.
//

import SwiftUI
import Photos
import SwiftData

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @State private var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @State private var showClearDataAlert = false
    @State private var showSimpleOCR = false

    private let swiftDataManager = SwiftDataManager.shared

    var body: some View {
        NavigationView {
            List {

                // About Section
                Section {
                    SettingsRow(
                        icon: "info.circle",
                        iconColor: .orange,
                        title: "About",
                        subtitle: "Information about the app",
                        showChevron: false
                    )

                    SettingsRow(
                        icon: "doc.text",
                        iconColor: .blue,
                        title: "Privacy Policy",
                        subtitle: nil,
                        showChevron: true
                    )

                    SettingsRow(
                        icon: "doc.text",
                        iconColor: .blue,
                        title: "Terms of Service",
                        subtitle: nil,
                        showChevron: true
                    )
                }

                // App Information Section
                Section {
                    SettingsRow(
                        icon: "hammer",
                        iconColor: .orange,
                        title: "App Information",
                        subtitle: "Build and versioning information",
                        showChevron: false
                    )

                    SettingsInfoRow(
                        icon: "info.circle",
                        iconColor: .blue,
                        title: "Version",
                        value: "1.0"
                    )

                    SettingsInfoRow(
                        icon: "gear",
                        iconColor: .blue,
                        title: "Build",
                        value: "1"
                    )
                }

                // Data Management Section
                Section {
                    SettingsRow(
                        icon: "externaldrive.badge.xmark",
                        iconColor: .orange,
                        title: "Data Management",
                        subtitle: "Manage history and app settings",
                        showChevron: false
                    )

                    Button(action: {
                        showClearDataAlert = true
                    }) {
                        SettingsRow(
                            icon: "trash",
                            iconColor: .red,
                            title: "Clear Scan Data",
                            subtitle: nil,
                            showChevron: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        showSimpleOCR = true
                    }) {
                        SettingsRow(
                            icon: "arrow.clockwise",
                            iconColor: .blue,
                            title: "Perform Full Scan",
                            subtitle: nil,
                            showChevron: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // User Permissions Section
                Section {
                    SettingsRow(
                        icon: "photo",
                        iconColor: .orange,
                        title: "User Permissions",
                        subtitle: "User authorization permissions for this app",
                        showChevron: false
                    )

                    SettingsInfoRow(
                        icon: "photo.on.rectangle",
                        iconColor: .blue,
                        title: "Photo Library Usage",
                        value: photoLibraryStatus == .authorized ? "Authorized" :
                               photoLibraryStatus == .limited ? "Limited" :
                               photoLibraryStatus == .denied ? "Denied" : "Not Determined"
                    )
                }

#if DEBUG
                // Debug Section (only in debug builds)
                Section {
                    SettingsRow(
                        icon: "ladybug",
                        iconColor: .purple,
                        title: "Debug Tools",
                        subtitle: "Development and debugging tools (Debug Build Only)",
                        showChevron: false
                    )
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                checkPhotoLibraryPermission()
            }
            .alert("Clear All Scan Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Data", role: .destructive) {
                    Task {
                        await clearAllScanData()
                    }
                }
            } message: {
                Text("This will permanently delete all scanned documents and data. This action cannot be undone.")
            }
            .sheet(isPresented: $showSimpleOCR) {
                SimpleOCRView()
            }
        }
    }

    private func checkPhotoLibraryPermission() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func clearAllScanData() async {
        do {
            try swiftDataManager.deleteAllDocumentTexts(context: modelContext)
        } catch {
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let showChevron: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            // Text Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Chevron
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            // Title
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            // Value
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(value == "Authorized" ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
}
