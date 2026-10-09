//
//  PremiumView.swift
//  Lunixia
//

import SwiftUI
import StoreKit

struct PremiumView: View {

    @EnvironmentObject private var storeManager: LunixiaStoreManager

    @State private var selectedProductID: String?

    var body: some View {
        ZStack(alignment: .top) {
            LunixiaBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {

                    premiumHeroCard

                    featuresSection

                    subscriptionSection

                    restoreButton

                    footerText
                }
                .padding(.horizontal, 20)
                .padding(.top, 70)
                .padding(.bottom, 120)
            }

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {

                        Text("Lunixia Premium")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)

                        Text("Unlock your full emotional sanctuary.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if storeManager.products.isEmpty {
                await storeManager.loadProducts()
            }

            if selectedProductID == nil {
                selectedProductID = LunixiaStoreManager.ProductID.monthly
            }
        }
    }

    // MARK: - Hero

    private var premiumHeroCard: some View {
        VStack(spacing: 16) {
            Image("heartlock")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(LGradients.header)

            VStack(spacing: 8) {
                Text("Unlimited Healing Space")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Expand beyond free limits and unlock the full Lunixia experience.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            sectionTitle("Premium Includes")

            VStack(spacing: 14) {

                premiumFeature(
                    title: "Unlimited Journal Books",
                    subtitle: "Create as many healing spaces as you need.",
                    icon: "lockheartjournal"
                )

                premiumFeature(
                    title: "Unlimited Mood History",
                    subtitle: "Keep your emotional timeline forever.",
                    icon: "timebook"
                )

                premiumFeature(
                    title: "Unlimited Health Tracking",
                    subtitle: "Remove vitals, medication, and exercise caps.",
                    icon: "health"
                )

                premiumFeature(
                    title: "Unlimited Sticky Notes",
                    subtitle: "Expand your thoughts without restriction.",
                    icon: "starnote"
                )
            }
        }
    }

    // MARK: - Subscriptions

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            sectionTitle("Choose Your Plan")

            if storeManager.isLoadingProducts {

                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)

            } else {

                VStack(spacing: 14) {

                    ForEach(storeManager.products, id: \.id) { product in

                        subscriptionCard(product)
                    }
                }

                purchaseButton
            }
        }
    }

    private func subscriptionCard(_ product: Product) -> some View {

        let isSelected = selectedProductID == product.id

        return Button {

            selectedProductID = product.id

        } label: {

            GlassCard(padding: 20) {
                VStack(alignment: .leading, spacing: 8) {

                    HStack {

                        VStack(alignment: .leading, spacing: 4) {

                            Text(storeManager.premiumProductTitle(for: product.id))
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text(product.displayPrice)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                        }

                        Spacer()

                        if isSelected {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LColors.accentGradient)
                                    .frame(width: 18, height: 18)

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }

                    if product.id == LunixiaStoreManager.ProductID.yearly {

                        Text("Best Value")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase

    private var purchaseButton: some View {

        Button {

            Task {

                guard let selectedProductID,
                      let product = storeManager.product(for: selectedProductID)
                else {
                    return
                }

                await storeManager.purchase(product)
            }

        } label: {

            HStack(spacing: 10) {

                if storeManager.isPurchasing {

                    ProgressView()
                        .tint(.white)

                } else {

                    Image("sparklesearch")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }

                Text(storeManager.isPurchasing ? "Purchasing..." : "Unlock Premium")
                    .font(.system(size: 17, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LColors.accentGradient)
                    .shadow(color: LColors.gradientPurple.opacity(0.4), radius: 14, y: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(storeManager.isPurchasing)
    }

    // MARK: - Restore

    private var restoreButton: some View {

        Button {

            Task {
                await storeManager.restorePurchases()
            }

        } label: {

            Text("Restore Purchases")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(LGradients.header)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Footer

    private var footerText: some View {
        Text("Subscriptions automatically renew unless cancelled at least 24 hours before renewal.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(LColors.textSecondary.opacity(0.82))
            .multilineTextAlignment(.center)
            .padding(.top, 10)
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(LGradients.header)
    }

    private func premiumFeature(
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {

        HStack(spacing: 14) {

            ZStack {

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 52, height: 52)

                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(LGradients.header)
            }

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            GlassCard(padding: 0) {
                Color.clear
            }
        )
    }
}
