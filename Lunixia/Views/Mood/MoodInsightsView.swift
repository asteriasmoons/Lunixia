//
//  MoodInsightsView.swift
//  Lunixia
//

import SwiftUI

struct MoodInsightsView: View {
    let entry: MoodEntry
    let userId: String

    @Environment(\.dismiss) private var dismiss

    @State private var analysis: MoodAnalysisResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if isLoading {
                    Spacer()
                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Analyzing your mood...")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    errorView(error)
                    Spacer()
                } else if let data = analysis {
                    insightContent(data)
                }
            }
        }
        .task { await runAnalysis() }
    }

    // MARK: - Header

    private var header: some View {
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
    }

    // MARK: - Content

    private func insightContent(_ data: MoodAnalysisResponse) -> some View {
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

                        Text(data.mindset)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Emotional Balance
                insightCard(
                    icon: "balancewavy",
                    title: "Emotional Balance",
                    body: data.emotionalBalance
                )

                // Influences
                insightCard(
                    icon: "sparkle",
                    title: "What May Be Influencing It",
                    body: data.influences
                )

                // Reflection
                insightCard(
                    icon: "starnote",
                    title: "Overall Reflection",
                    body: data.reflection
                )

                // Themes
                if !data.themes.isEmpty {
                    GlassCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "tagstar", title: "Themes")

                            FlowLayout(spacing: 8) {
                                ForEach(data.themes, id: \.self) { theme in
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

    // MARK: - Helpers

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

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.red.opacity(0.8))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                Task { await runAnalysis() }
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

    private func runAnalysis() async {
        isLoading = true
        errorMessage = nil
        do {
            analysis = try await MoodAnalysisService.shared.analyze(
                userId: userId,
                entry: entry
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
