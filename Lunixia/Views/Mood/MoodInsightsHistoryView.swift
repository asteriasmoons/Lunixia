//
//  MoodInsightsHistoryView.swift
//  Lunixia
//

import SwiftUI

struct MoodInsightsHistoryView: View {
    let userId: String
    let moodEntryId: String?

    @Environment(\.dismiss) private var dismiss

    @State private var analyses: [MoodAnalysisHistoryItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAnalysis: MoodAnalysisHistoryItem?
    @State private var visibleCount = 6
    private let pageSize = 6

    private var displayedAnalyses: [MoodAnalysisHistoryItem] {
        Array(analyses.prefix(visibleCount))
    }

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
                } else if analyses.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    historyList
                }
            }
        }
        .task { await loadHistory() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Analysis History")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)

            Spacer()

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

    // MARK: - History List

    private var historyList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                ForEach(displayedAnalyses) { item in
                    Button {
                        selectedAnalysis = item
                    } label: {
                        historyCard(item)
                    }
                    .buttonStyle(.plain)
                }

                if analyses.count > pageSize {
                    VStack(spacing: 10) {
                        if visibleCount < analyses.count {
                            Button {
                                withAnimation { visibleCount = min(visibleCount + pageSize, analyses.count) }
                            } label: {
                                Text("Load More")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 9)
                                    .background(LColors.accentGradient, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if visibleCount > pageSize {
                            Button {
                                withAnimation { visibleCount = pageSize }
                            } label: {
                                Text("See Less")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule().fill(LColors.glassSurface)
                                            .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .sheet(item: $selectedAnalysis) { item in
            MoodInsightsDetailSheet(analysis: item)
        }
    }

    private func historyCard(_ item: MoodAnalysisHistoryItem) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image("cloudmind")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(LGradients.header)

                    Text(item.mindset)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)
                }

                Text(item.reflection)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(LColors.textPrimary.opacity(0.75))
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Text(formatDate(item.createdAt))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)

                    if !item.themes.isEmpty {
                        Text(item.themes.prefix(3).joined(separator: " · "))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(LGradients.tag)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("cloudmind")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .foregroundStyle(LColors.textSecondary.opacity(0.4))

            Text("No analyses yet")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            Text("Tap Analyze on a mood log to get your first insight.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
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
                Task { await loadHistory() }
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

    // MARK: - Helpers

    private func loadHistory() async {
        isLoading = true
        errorMessage = nil
        do {
            analyses = try await MoodAnalysisService.shared.fetchHistory(
                userId: userId,
                moodEntryId: moodEntryId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date2 = formatter.date(from: isoString) else { return isoString }
            return date2.formatted(date: .abbreviated, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Detail Sheet for a past analysis

struct MoodInsightsDetailSheet: View {
    let analysis: MoodAnalysisHistoryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Mood Insights")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)

                    Spacer()

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

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Mindset hero
                        GlassCard(padding: 18) {
                            VStack(spacing: 8) {
                                Image("cloudmind")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(LGradients.header)

                                Text(analysis.mindset)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)

                                Text(formatDate(analysis.createdAt))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        insightCard(icon: "balancewavy", title: "Emotional Balance", body: analysis.emotionalBalance)
                        insightCard(icon: "sparkle", title: "What May Be Influencing It", body: analysis.influences)
                        insightCard(icon: "starnote", title: "Overall Reflection", body: analysis.reflection)

                        if !analysis.themes.isEmpty {
                            GlassCard(padding: 18) {
                                VStack(alignment: .leading, spacing: 12) {
                                    sectionHeader(icon: "tagstar", title: "Themes")

                                    FlowLayout(spacing: 8) {
                                        ForEach(analysis.themes, id: \.self) { theme in
                                            Text(theme)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(LGradients.tag)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(
                                                    Capsule().fill(Color.white.opacity(0.06))
                                                )
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(LGradients.blue.opacity(0.4), lineWidth: 1)
                                                )
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    private func insightCard(icon: String, title: String, body: String) -> some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(icon: icon, title: title)

                Text(body)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(LColors.textPrimary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 7) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(LGradients.header)

            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
        }
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date2 = formatter.date(from: isoString) else { return isoString }
            return date2.formatted(date: .abbreviated, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
