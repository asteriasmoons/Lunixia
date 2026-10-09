//
//  JournalAnalysisSheet.swift
//  Lunixia
//

import SwiftUI

struct JournalAnalysisSheet: View {
    enum AnalysisState {
        case idle
        case loading
        case result(themes: [String], mood: String, reflection: String)
        case empty
        case error(String)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let state: AnalysisState
    let onRetry: () -> Void
    var onClose: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil

    var dateLabel: String = ""
    var hasPrevious: Bool = false
    var hasNext: Bool = false
    var onPrevious: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        switch state {
                        case .idle:
                            idleState

                        case .loading:
                            loadingState

                        case .empty:
                            emptyState

                        case .error(let message):
                            errorState(message)

                        case .result(let themes, let mood, let reflection):
                            resultContent(themes: themes, mood: mood, reflection: reflection)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }

                if case .result = state {
                    footer
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Text("Daily Analysis")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)

            Spacer()

            HStack(spacing: 6) {
                Button {
                    onPrevious?()
                } label: {
                    Image("chevleft")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(hasPrevious ? .white : Color.white.opacity(0.25))
                }
                .buttonStyle(.plain)
                .disabled(!hasPrevious)

                Text(dateLabel.isEmpty ? "Today" : dateLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LColors.textSecondary)
                    .frame(minWidth: 80, alignment: .center)

                Button {
                    onNext?()
                } label: {
                    Image("chevright")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(hasNext ? .white : Color.white.opacity(0.25))
                }
                .buttonStyle(.plain)
                .disabled(!hasNext)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                    .clipShape(Capsule())
            }

            Button {
                onClose?() ?? dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private var idleState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(LColors.textSecondary)
                .bubblyIconMaterial(tint: theme.palette.textSecondary)

            Text("Ready to reflect?")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Text("Tap below to generate an analysis for this entry.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)

            Button { onRetry() } label: {
                Text("Generate Analysis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background {
                        BubblyCardMaterial(
                            tint: theme.palette.primaryAction,
                            cornerRadius: 12
                        )
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.2)

            Text("Analyzing your entry…")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(LColors.textSecondary)
                .bubblyIconMaterial(tint: theme.palette.textSecondary)

            Text("No analysis yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Text("There isn’t a saved analysis for today yet. Generate one when you’re ready.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)

            Button { onRetry() } label: {
                Text("Generate Analysis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background {
                        BubblyCardMaterial(
                            tint: theme.palette.primaryAction,
                            cornerRadius: 12
                        )
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.red.opacity(0.8))

            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)

            Button { onRetry() } label: {
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)

            HStack(spacing: 10) {
                Button { onRetry() } label: {
                    Text("Generate Again")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            BubblyCardMaterial(
                                tint: theme.palette.indicators,
                                cornerRadius: 12
                            )
                        }
                }
                .buttonStyle(.plain)

                Button { onDone?() ?? dismiss() } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LGradients.blue.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .allowsHitTesting(false)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(LGradients.blue.opacity(0.55), lineWidth: 1)
                                .allowsHitTesting(false)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }


    @ViewBuilder
    private func resultContent(themes: [String], mood: String, reflection: String) -> some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.palette.primaryAction)
                    .bubblyIconMaterial(tint: theme.palette.primaryAction)

                Text(dateLabel.isEmpty ? "Today's Mood" : "\(dateLabel)'s Mood")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LColors.textSecondary)
                    .tracking(0.4)

                Spacer()

                Text(mood.capitalized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        BubblyIconMaterial(tint: theme.palette.primaryAction)
                            .clipShape(Capsule())
                    }
            }
        }

        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image("tagsparkle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(theme.palette.secondaryAccent)
                        .bubblyIconMaterial(tint: theme.palette.secondaryAccent)

                    Text("Themes")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.palette.secondaryAccent)
                        .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                }

                TagFlowLayout(spacing: 8) {
                    ForEach(themes, id: \.self) { themeName in
                        Text(themeName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 2, y: 1)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                                    .clipShape(Capsule())
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image("pencilwrite")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)

                    Text("Reflection")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                let paragraphs = reflection
                    .components(separatedBy: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(LColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
            }
        }
    }
}
