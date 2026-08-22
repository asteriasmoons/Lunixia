//
//  ThemeInsightsView.swift
//  Lunixia
//

import SwiftUI

struct ThemeInsightsView: View {
    let userId: String

    @Environment(\.dismiss) private var dismiss

    @State private var insights: ThemeInsightsResponse?
    @State private var selectedPeriod: String = "week"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTheme: ThemeInsightItem?

    private let periods = ["week", "month", "year", "all"]
    private let periodLabels = [
        "week": "This Week",
        "month": "This Month",
        "year": "This Year",
        "all": "All Time",
    ]

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    errorView(error)
                    Spacer()
                } else if let data = insights {
                    insightsContent(data)
                } else {
                    Spacer()
                    Text("No insights available yet.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadInsights() }
        .navigationDestination(item: $selectedTheme) { theme in
            ThemeDetailView(userId: userId, themeName: theme.name)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Theme Insights")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)

            Spacer()

            periodPicker

            Button { dismiss() } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(LGradients.header)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var periodPicker: some View {
        Menu {
            ForEach(periods, id: \.self) { period in
                Button {
                    selectedPeriod = period
                    Task { await loadInsights() }
                } label: {
                    HStack {
                        Text(periodLabels[period] ?? period)
                        if selectedPeriod == period {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(periodLabels[selectedPeriod] ?? selectedPeriod)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(LGradients.blue.opacity(0.16))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(LGradients.blue.opacity(0.55), lineWidth: 1))
        }
    }

    // MARK: - Content

    private func insightsContent(_ data: ThemeInsightsResponse) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                overviewCard(data.overview)

                if !data.themes.mostCommon.isEmpty {
                    themeTilesSection(
                        title: "Most Common",
                        icon: "starchart",
                        items: data.themes.mostCommon
                    )
                }

                if !data.themes.emerging.isEmpty {
                    trendingSection(
                        title: "Trending Up",
                        icon: "upwavy",
                        items: data.themes.emerging
                    )
                }

                if !data.themes.new.isEmpty {
                    chipsSection(
                        title: "New \(periodLabels[selectedPeriod] ?? "")",
                        icon: "sparkle",
                        items: data.themes.new
                    )
                }

                if !data.themes.declining.isEmpty {
                    trendingSection(
                        title: "Less Present",
                        icon: "downwavy",
                        items: Array(data.themes.declining.prefix(3))
                    )
                }

                if !data.tags.mostCommon.isEmpty {
                    themeTilesSection(
                        title: "Top Tags",
                        icon: "tagsparkle",
                        items: data.tags.mostCommon
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Overview Card

    private func overviewCard(_ overview: ThemeInsightOverview) -> some View {
        GlassCard {
            HStack(spacing: 0) {
                statColumn(value: "\(overview.totalEntries)", label: "Entries")
                Spacer()
                Rectangle().fill(LColors.glassBorder).frame(width: 1, height: 36)
                Spacer()
                statColumn(value: "\(overview.totalMindfulMinutes)", label: "Mindful Min")
                Spacer()
                Rectangle().fill(LColors.glassBorder).frame(width: 1, height: 36)
                Spacer()
                statColumn(value: "\(overview.uniqueThemes)", label: "Themes")
            }
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
        }
    }

    // MARK: - Frosted Tiles Grid

    private func themeTilesSection(title: String, icon: String, items: [ThemeInsightItem]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                let columns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ]

                // First item gets a full-width hero tile
                if let hero = items.first {
                    Button { selectedTheme = hero } label: {
                        themeTile(hero, isHero: true)
                    }
                    .buttonStyle(.plain)
                }

                // Remaining items in 2-column grid
                if items.count > 1 {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(items.dropFirst()), id: \.name) { item in
                            Button { selectedTheme = item } label: {
                                themeTile(item, isHero: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func themeTile(_ item: ThemeInsightItem, isHero: Bool) -> some View {
        VStack(spacing: isHero ? 6 : 4) {
            Text(item.name)
                .font(.system(size: isHero ? 16 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("\(item.entryCount) \(item.entryCount == 1 ? "entry" : "entries")")
                .font(.system(size: isHero ? 13 : 11, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)

            Text("\(item.percentage)%")
                .font(.system(size: isHero ? 11 : 10, weight: .bold))
                .foregroundStyle(LGradients.tag)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isHero ? 18 : 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(isHero ? 0.10 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isHero ? 0.22 : 0.14),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Trending Section (compact rows with comparison)

    private func trendingSection(title: String, icon: String, items: [ThemeInsightItem]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                ForEach(items.prefix(3), id: \.name) { item in
                    Button { selectedTheme = item } label: {
                        HStack(spacing: 10) {
                            Text(item.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Spacer()

                            // Comparison: "3 this week / 1 last week"
                            HStack(spacing: 3) {
                                Text("\(item.currentPeriodCount)")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)

                                if item.previousPeriodCount > 0 {
                                    Text("/")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                    Text("\(item.previousPeriodCount)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }

                            // Tiny trend indicator
                            Image(systemName: item.trend == "declining" ? "arrow.down" : "arrow.up")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(
                                    item.trend == "declining"
                                        ? LColors.danger
                                        : Color(lunixiaHex: "#e2ed8a")
                                )
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Chips Section (New This Week)

    private func chipsSection(title: String, icon: String, items: [ThemeInsightItem]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                TagFlowLayout(spacing: 8) {
                    ForEach(items.prefix(8), id: \.name) { item in
                        Button { selectedTheme = item } label: {
                            Text(item.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LGradients.tag)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LGradients.blue.opacity(0.4),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.red.opacity(0.8))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadInsights() }
            } label: {
                Text("Try Again")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(LGradients.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Load

    private func loadInsights() async {
        isLoading = true
        errorMessage = nil
        do {
            insights = try await JournalAnalysisService.shared.fetchInsights(
                userId: userId,
                period: selectedPeriod
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
