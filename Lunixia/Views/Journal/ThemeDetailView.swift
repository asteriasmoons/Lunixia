//
//  ThemeDetailView.swift
//  Lunixia
//

import SwiftUI

struct ThemeDetailView: View {
    let userId: String
    let themeName: String

    @Environment(\.dismiss) private var dismiss

    @State private var detail: ThemeDetailResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                    errorContent(error)
                    Spacer()
                } else if let data = detail {
                    detailContent(data)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadDetail() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(themeName)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)
                .lineLimit(1)

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

    // MARK: - Detail Content

    private func detailContent(_ data: ThemeDetailResponse) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                summaryBanner(data)
                statsCard(data)

                if !data.usageByDay.isEmpty {
                    timelineCard(data.usageByDay)
                }

                if !data.relatedThemes.isEmpty {
                    relatedThemesCard(data)
                }

                if !data.entries.isEmpty {
                    entriesCard(data.entries)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Summary Banner

    private func summaryBanner(_ data: ThemeDetailResponse) -> some View {
        GlassCard {
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(data.percentage)%")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                    Text("of entries")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(LColors.glassBorder).frame(width: 1, height: 40)

                VStack(spacing: 2) {
                    Text("\(data.entryCount)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(data.entryCount == 1 ? "entry" : "entries")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(LColors.glassBorder).frame(width: 1, height: 40)

                VStack(spacing: 2) {
                    Text("\(data.mindfulMinutes)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("minutes")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Stats Card

    private func statsCard(_ data: ThemeDetailResponse) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                if let first = data.firstUsedDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("First Appeared")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LGradients.header)
                        Text(formatDateKey(first))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                }
                if let last = data.lastUsedDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Most Recent")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LGradients.header)
                        Text(formatDateKey(last))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Real Timeline (day-level dots/bars)

    private func timelineCard(_ days: [UsageDay]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image("starchart")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white)
                    Text("Usage Over Time")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                let maxCount = days.map(\.count).max() ?? 1
                let displayDays = Array(days.suffix(14)) // Last 14 data points

                // Bar chart with day labels
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(displayDays, id: \.day) { day in
                        VStack(spacing: 4) {
                            // Count label on top of bar
                            if day.count > 0 {
                                Text("\(day.count)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            // Bar
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(LGradients.blue)
                                .frame(height: max(4, CGFloat(day.count) / CGFloat(maxCount) * 60))

                            // Day label
                            Text(shortDay(day.day))
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 80, alignment: .bottom)
            }
        }
    }

    // MARK: - Related Themes with Percentages

    private func relatedThemesCard(_ data: ThemeDetailResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image("puzzlehand")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white)
                    Text("Often Appears With")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                let items = Array(data.relatedThemes.prefix(6))
                let columns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ]

                if let hero = items.first {
                    relatedThemeTile(hero, isHero: true)
                }

                if items.count > 1 {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(items.dropFirst()), id: \.name) { item in
                            relatedThemeTile(item, isHero: false)
                        }
                    }
                }
            }
        }
    }

    private func relatedThemeTile(_ item: RelatedThemeItem, isHero: Bool) -> some View {
        VStack(spacing: isHero ? 6 : 4) {
            Text(item.name)
                .font(.system(size: isHero ? 16 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("\(item.coOccurrences) \(item.coOccurrences == 1 ? "co-occurrence" : "co-occurrences")")
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

    // MARK: - Entries List

    private func entriesCard(_ entries: [ThemeEntrySummary]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image("linedlovedoc")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white)
                    Text("Entries")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(entries.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)
                }

                ForEach(Array(entries.prefix(15).enumerated()), id: \.offset) { index, entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatDateKey(entry.dateKey))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)

                            HStack(spacing: 6) {
                                Text(entry.mood.capitalized)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)

                                if entry.mindfulMinutes > 0 {
                                    Text("·")
                                        .foregroundStyle(LColors.textSecondary)
                                    Text("\(entry.mindfulMinutes) min")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 3)

                    if index < min(entries.count, 15) - 1 {
                        Rectangle().fill(LColors.glassBorder).frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - Error

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.red.opacity(0.8))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadDetail() }
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

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await JournalAnalysisService.shared.fetchThemeDetail(
                userId: userId,
                theme: themeName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func formatDateKey(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return dateKey }
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func shortDay(_ dayKey: String) -> String {
        // "2026-07-13" → "13"
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3 else { return dayKey }
        return String(parts[2])
    }
}
