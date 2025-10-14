//
//  PaywallView.swift
//  Scanley
//
//  Created by Claude on 2025-09-23.
//

import SwiftUI
import StoreKit


// Add near the top of PaywallView.swift
private let termsURL  = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
private let privacyURL = URL(string: "https://aporay-dev.github.io/scanley-support/privacy.html")!


// MARK: - Paywall Trigger Types

enum PaywallTrigger: Equatable {
    case searchLimit
    case categoryAccess(categoryName: String)
    case fullScreenView
    case onboarding

    var title: String {
        switch self {
        case .searchLimit:
            return "You've discovered the power of Scanley!"
        case .categoryAccess(let categoryName):
            return "Unlock \(categoryName) Documents"
        case .fullScreenView:
            return "View Documents in Full Detail"
        case .onboarding:
            return "Transform Your Photos Into Searchable Documents"
        }
    }

    var subtitle: String {
        switch self {
        case .searchLimit:
            return "You've used all 15 free searches. Upgrade to continue finding your documents instantly."
        case .categoryAccess:
            return "Access all document categories and find everything you need."
        case .fullScreenView:
            return "Get the full document viewing experience with crystal clear detail."
        case .onboarding:
            return "Scan unlimited photos and search through them with AI-powered text recognition."
        }
    }
}

// MARK: - Main Paywall View

struct PaywallView: View {
    let trigger: PaywallTrigger
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: SubscriptionProduct = .weekly
    @State private var showingTerms = false
    @State private var showingPrivacy = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    HStack{
                            Image("ScanleyLogo")
                                .resizable()
                                .renderingMode(.template)                   // use alpha mask
                                .foregroundStyle(.primary)
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 40)
                                .padding(.leading, 4)
                                .accessibilityLabel("Scanley")
                            Text("Pro")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                    }
                    // Header Section
                    headerSection


                    // Features List
                    featuresSection

                    // Pricing Options
                    pricingSection

                    // Purchase Button
                    purchaseSection

                    // Legal Links
                    legalSection

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 5)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if trigger != .onboarding {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingTerms) {
                SafariView(url: termsURL).ignoresSafeArea()
            }
            .sheet(isPresented: $showingPrivacy) {
                SafariView(url: privacyURL).ignoresSafeArea()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {

            // Title and Subtitle
            VStack(spacing: 6) {
                Text(trigger.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(trigger.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's included with Pro:")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "magnifyingglass",
                    title: "Unlimited Text Searches",
                    description: "Find any document instantly with powerful search"
                )

                FeatureRow(
                    icon: "folder.badge.plus",
                    title: "All 8 Document Categories",
                    description: "Tax, Medical, Legal, Bank, Insurance and more"
                )

                FeatureRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Full-Screen Document Viewing",
                    description: "Crystal clear detail for all your documents"
                )

                FeatureRow(
                    icon: "sparkles",
                    title: "Smart Search Suggestions",
                    description: "AI-powered suggestions as you type"
                )

                FeatureRow(
                    icon: "headphones",
                    title: "Priority Support",
                    description: "Get help when you need it most"
                )
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                // Annual Plan
                PricingCard(
                    product: .annual,
                    isSelected: selectedProduct == .annual,
                    onTap: { selectedProduct = .annual },
                    products: subscriptionManager.products
                )

                // Weekly Plan
                PricingCard(
                    product: .weekly,
                    isSelected: selectedProduct == .weekly,
                    onTap: { selectedProduct = .weekly },
                    products: subscriptionManager.products
                )
            }
        }
    }

    // MARK: - Purchase Section

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            // Main Purchase Button
            Button(action: {
                Task {
                    let success = await subscriptionManager.purchase(selectedProduct)
                    if success {
                        dismiss()
                    }
                }
            }) {
                HStack {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Text("Start 7-Day Free Trial")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(subscriptionManager.isLoading)

            // Restore Purchases
            Button("Restore Purchases") {
                Task {
                    let success = await subscriptionManager.restorePurchases()
                    if success && subscriptionManager.subscriptionState.isActive {
                        dismiss()
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)

            // Trial Information - Enhanced for App Store compliance
            VStack(spacing: 12) {
                // Prominent trial callout
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("7-Day Free Trial")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()
                }

                // Detailed trial terms
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Free for 7 days, no charges during trial")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text("• Then \(selectedProduct.getPrice(from: subscriptionManager.products)) per \(selectedProduct == .weekly ? "week" : "year")")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text("• Cancel anytime from iOS Settings > Subscriptions")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text("• Full access to all Pro features during trial")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(spacing: 12) {
            // Auto-renew disclosure (tiny copy block)
            Text("""
            Payment will be charged to your Apple ID account at confirmation of purchase. 
            Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. 
            You can manage or cancel your subscription in Settings > Apple ID > Subscriptions. 
            Any unused portion of a free trial will be forfeited when you purchase a subscription.
            """)
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            // Links row
            HStack(spacing: 16) {
                Button("Terms of Use (EULA)") { showingTerms = true }
                Button("Privacy Policy") { showingPrivacy = true }
            }
            .font(.caption)
            .tint(.blue)

            // Error message if any
            if let errorMessage = subscriptionManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 8)
    }

}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct PricingCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let onTap: () -> Void
    let products: [Product]

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let savings = product.savings {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(product.getPrice(from: products))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .stroke(isSelected ? Color.blue : Color(UIColor.separator), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Safari View for Legal Links

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    PaywallView(trigger: .searchLimit)
}

#Preview("Category Access") {
    PaywallView(trigger: .categoryAccess(categoryName: "Medical"))
}

#Preview("Onboarding") {
    PaywallView(trigger: .onboarding)
}

// Import required for SafariView
import SafariServices
