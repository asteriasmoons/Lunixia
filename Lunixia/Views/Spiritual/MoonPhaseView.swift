//
//  MoonPhaseView.swift
//  Lunixia
//

import SwiftUI

struct MoonPhaseView: View {
    let moonPhaseData: MoonPhaseData

    @State private var showMoonInsight = false

    var body: some View {
        Button {
            showMoonInsight = true
        } label: {
            MoonPhaseCard(data: moonPhaseData)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showMoonInsight) {
            MoonAIInsightSheet(moonPhaseData: moonPhaseData)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Moon Phase Card

private struct MoonPhaseCard: View {
    @Environment(\.appTheme) private var theme

    let data: MoonPhaseData

    private var zodiacAssetName: String {
        switch data.signName.lowercased() {
        case "aries": return "aries"
        case "taurus": return "taurus"
        case "gemini": return "gemini"
        case "cancer": return "cancer"
        case "leo": return "leo"
        case "virgo": return "virgo"
        case "libra": return "libra"
        case "scorpio": return "scorpio"
        case "sagittarius": return "sagittarius"
        case "capricorn": return "capricorn"
        case "aquarius": return "aquarius"
        case "pisces": return "pisces"
        default: return "aries"
        }
    }

    private var phaseSymbolName: String {
        moonPhaseSymbolName(for: data.phaseName)
    }

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: phaseSymbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.palette.primaryAction)
                        .bubblyIconMaterial(tint: theme.palette.primaryAction)
                        .frame(width: 18, height: 18)

                    Text(data.phaseName)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .bubblyIconMaterial(tint: theme.palette.primaryAction)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .center, spacing: 8) {
                    Image(zodiacAssetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(theme.palette.primaryAction)
                        .bubblyIconMaterial(tint: theme.palette.primaryAction)

                    Text(data.signName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(data.detailLine)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - AI Insight Sheet

private struct MoonAIInsightSheet: View {
    @Environment(\.appTheme) private var theme

    let moonPhaseData: MoonPhaseData

    @State private var response: MoonAIResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var phaseSymbolName: String {
        moonPhaseSymbolName(for: moonPhaseData.phaseName)
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if isLoading {
                        loadingCard
                    } else if let response {
                        responseCard(response)
                    } else if let errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .task {
            guard response == nil, !isLoading else { return }
            await loadInsight()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: phaseSymbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    .frame(width: 22, height: 22)

                Text(moonPhaseData.phaseName)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)

                Spacer()
            }

            Text("\(moonPhaseData.signName) • \(moonPhaseData.detailLine)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loadingCard: some View {
        GlassCard(padding: 22) {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.1)

                Text("Reading the moon’s reflection…")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    .multilineTextAlignment(.center)

                Text("Considering what this moon phase, sign, and lunar detail may symbolically mean for spiritual and personal growth.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    private func responseCard(_ response: MoonAIResponse) -> some View {
        GlassCard(padding: 22) {
            VStack(alignment: .leading, spacing: 18) {
                Text(response.title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    .fixedSize(horizontal: false, vertical: true)

                keywordList(response.keywords)

                Text(response.message)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("AI-generated reflective interpretation")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.75))
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        GlassCard(padding: 22) {
            VStack(spacing: 16) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)

                Text("The moon reflection could not be created.")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        await loadInsight()
                    }
                } label: {
                    Text("Try Again")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .bubblyCardMaterial(
                            tint: theme.palette.primaryAction,
                            cornerRadius: 22
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func keywordList(_ keywords: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(keywords, id: \.self) { keyword in
                Text(keyword)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(theme.palette.primaryAction, lineWidth: 1)
                    )
            }
        }
    }

    @MainActor
    private func loadInsight() async {
        isLoading = true
        errorMessage = nil

        do {
            response = try await MoonAIService.shared
                .generateMoonInterpretation(
                    phaseName: moonPhaseData.phaseName,
                    signName: moonPhaseData.signName,
                    details: moonPhaseData.detailLine
                )
        } catch {
            response = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Shared Moon Phase Pieces

private func moonPhaseSymbolName(for phaseName: String) -> String {
    switch phaseName.lowercased() {
    case "new moon":
        return "moonphase.new.moon"
    case "waxing crescent":
        return "moonphase.waxing.crescent"
    case "first quarter":
        return "moonphase.first.quarter"
    case "waxing gibbous":
        return "moonphase.waxing.gibbous"
    case "full moon":
        return "moonphase.full.moon"
    case "waning gibbous":
        return "moonphase.waning.gibbous"
    case "last quarter":
        return "moonphase.last.quarter"
    case "waning crescent":
        return "moonphase.waning.crescent"
    default:
        return "moonphase.full.moon"
    }
}
