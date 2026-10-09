//
// JournalAnalysisOverlay.swift
// Lunixia
//

import SwiftUI

struct JournalAnalysisOverlay: View {
    enum AnalysisState {
        case idle
        case loading
        case result(themes: [String], mood: String, reflection: String)
        case empty
        case error(String)
    }

    let state: AnalysisState
    let onClose: () -> Void
    let onRetry: () -> Void
    var dateLabel: String = ""
    var hasPrevious: Bool = false
    var hasNext: Bool = false
    var onPrevious: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Daily Analysis")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()

                    // Date navigation
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
                    .background(LGradients.blue.opacity(0.16))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.04))
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        Capsule()
                            .stroke(LGradients.blue.opacity(0.55), lineWidth: 1)
                    )

                    Button { onClose() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)

                Rectangle().fill(LColors.glassBorder).frame(height: 1)

                // Body
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        switch state {
                        case .idle:
                            VStack(spacing: 14) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32))
                                    .foregroundStyle(LColors.textSecondary)
                                Text("Ready to reflect?")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Tap below to generate your daily analysis for today.")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                Button { onRetry() } label: {
                                    Text("Generate Analysis")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(LGradients.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)

                        case .loading:
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

                        case .empty:
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32))
                                    .foregroundStyle(LColors.textSecondary)
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
                                        .background(LGradients.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)

                        case .error(let message):
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

                        case .result(let themes, let mood, let reflection):
                            resultContent(themes: themes, mood: mood, reflection: reflection)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }

                // Footer
                if case .result = state {
                    Rectangle().fill(LColors.glassBorder).frame(height: 1)
                    HStack(spacing: 10) {
                        Button { onRetry() } label: {
                            Text("Generate Again")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button { onClose() } label: {
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
            .frame(maxWidth: 400)
            .background(
                ZStack {
                    LunixiaBackground()
                    Color.black.opacity(0.22)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LGradients.blue.opacity(0.65), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
            .padding(.horizontal, 24)
        }
    }

    private struct GradientAnalysisCard<Content: View>: View {
        @ViewBuilder let content: () -> Content

        var body: some View {
            content()
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LGradients.blue.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .allowsHitTesting(false)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LGradients.blue.opacity(0.55), lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private func resultContent(themes: [String], mood: String, reflection: String) -> some View {
        // Mood badge
        HStack(spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
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
                .background(LGradients.blue)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LGradients.blue.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LGradients.blue.opacity(0.55), lineWidth: 1)
                .allowsHitTesting(false)
        )

        // Themes
        GradientAnalysisCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image("tagsparkle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                    Text("Themes")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                TagFlowLayout(spacing: 8) {
                    ForEach(themes, id: \.self) { theme in
                        Text(theme)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LGradients.tag)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(LGradients.blue.opacity(0.16))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .fill(Color.white.opacity(0.04))
                                    .allowsHitTesting(false)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(LGradients.blue.opacity(0.55), lineWidth: 1)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        // Reflection
        GradientAnalysisCard {
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

                let paragraphs = reflection.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
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
