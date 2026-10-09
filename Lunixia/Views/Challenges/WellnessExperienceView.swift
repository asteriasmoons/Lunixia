//
//  WellnessExperienceView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct WellnessExperienceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    let challenge: WellnessChallengeDefinition
    let experience: WellnessExperienceDefinition
    let experienceIndex: Int
    let participation: WellnessChallengeParticipation
    let progress: WellnessExperienceProgress
    let onReturnToLibrary: () -> Void

    @State private var currentStepIndex: Int
    @State private var showCompletion: Bool
    @State private var completionError: String?

    init(
        challenge: WellnessChallengeDefinition,
        experience: WellnessExperienceDefinition,
        experienceIndex: Int,
        participation: WellnessChallengeParticipation,
        progress: WellnessExperienceProgress,
        onReturnToLibrary: @escaping () -> Void
    ) {
        self.challenge = challenge
        self.experience = experience
        self.experienceIndex = experienceIndex
        self.participation = participation
        self.progress = progress
        self.onReturnToLibrary = onReturnToLibrary
        _currentStepIndex = State(
            initialValue: min(
                max(0, progress.currentStepIndex),
                max(0, experience.steps.count - 1)
            )
        )
        _showCompletion = State(initialValue: progress.isCompleted)
    }

    var body: some View {
        ZStack {
            LunixiaBackground()

            if showCompletion {
                completionContent
            } else {
                experienceContent
            }
        }
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
        .onDisappear {
            progress.currentStepIndex = currentStepIndex
            progress.updatedAt = Date()
            participation.updatedAt = Date()
            try? modelContext.save()
        }
    }

    private var experienceContent: some View {
        VStack(spacing: 0) {
            experienceHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stepProgress

                    if let currentStep {
                        WellnessStepRenderer(
                            step: currentStep,
                            response: responseBinding(for: currentStep),
                            allResponses: progress.responses
                        )
                        .id(currentStep.id)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                    }

                    if let completionError {
                        Text(completionError)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.palette.indicators)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)

            navigationBar
        }
    }

    private var experienceHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                saveAndDismiss()
            } label: {
                WellnessTintedIcon(
                    name: "xmarkwavy",
                    tint: theme.palette.primaryAction,
                    size: 23,
                    containerSize: 44
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save and close experience")

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.palette.primaryAction)
                Text(experience.title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(theme.palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text("\(experienceIndex + 1)/\(challenge.experiences.count)")
                .font(.caption.weight(.heavy).monospacedDigit())
                .foregroundStyle(theme.palette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(theme.palette.surface))
                .accessibilityLabel("Experience \(experienceIndex + 1) of \(challenge.experiences.count)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(theme.palette.background)
    }

    private var stepProgress: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Step \(currentStepIndex + 1) of \(experience.steps.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.palette.textSecondary)
                Spacer()
                Text(currentStep?.kind.accessibilityName ?? "")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.palette.indicators)
            }
            WellnessProgressBar(
                value: experience.steps.isEmpty ? 0 : Double(currentStepIndex + 1) / Double(experience.steps.count),
                tint: theme.palette.indicators,
                height: 7
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button {
                moveBackward()
            } label: {
                HStack(spacing: 7) {
                    Image("chevleft")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text("Back")
                        .font(.headline)
                }
                .foregroundStyle(theme.palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.palette.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.palette.secondaryAccent, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(currentStepIndex == 0)
            .opacity(currentStepIndex == 0 ? 0.45 : 1)

            WellnessActionButton(
                title: isLastStep ? "Complete Experience" : "Continue",
                icon: isLastStep ? "checkwavy" : "chevright",
                tint: isLastStep ? theme.palette.indicators : theme.palette.primaryAction,
                isEnabled: canContinue
            ) {
                moveForward()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(theme.palette.background)
    }

    @ViewBuilder
    private var completionContent: some View {
        if participation.status == .completed {
            WellnessFinalChallengeCompletionView(
                challenge: challenge,
                participation: participation,
                onReview: { dismiss() },
                onRepeat: repeatChallenge,
                onReturnToLibrary: {
                    dismiss()
                    onReturnToLibrary()
                }
            )
        } else {
            WellnessDailyExperienceCompletionView(
                challenge: challenge,
                experience: experience,
                participation: participation,
                nextExperience: nextExperience,
                onReturn: { dismiss() }
            )
        }
    }

    private var currentStep: WellnessStepDefinition? {
        guard experience.steps.indices.contains(currentStepIndex) else { return nil }
        return experience.steps[currentStepIndex]
    }

    private var isLastStep: Bool {
        currentStepIndex >= experience.steps.count - 1
    }

    private var canContinue: Bool {
        guard let currentStep else { return false }
        return currentStep.canAdvance(with: progress.response(for: currentStep.id))
    }

    private var nextExperience: WellnessExperienceDefinition? {
        let nextIndex = experienceIndex + 1
        guard challenge.experiences.indices.contains(nextIndex) else { return nil }
        return challenge.experiences[nextIndex]
    }

    private func responseBinding(for step: WellnessStepDefinition) -> Binding<WellnessStepResponse> {
        Binding(
            get: { progress.response(for: step.id) },
            set: { newResponse in
                do {
                    try WellnessChallengeProgressionService.saveStep(
                        response: newResponse,
                        stepID: step.id,
                        stepIndex: currentStepIndex,
                        progress: progress,
                        participation: participation,
                        in: modelContext
                    )
                } catch {
                    completionError = "Your response could not be saved. Please try again."
                }
            }
        )
    }

    private func moveBackward() {
        guard currentStepIndex > 0 else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            currentStepIndex -= 1
        }
        persistCurrentStep()
    }

    private func moveForward() {
        guard canContinue else { return }
        completionError = nil

        if isLastStep {
            do {
                progress.currentStepIndex = currentStepIndex
                _ = try WellnessChallengeProgressionService.completeExperience(
                    progress,
                    participation: participation,
                    challenge: challenge,
                    in: modelContext
                )
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    showCompletion = true
                }
            } catch {
                completionError = "This experience could not be completed. Your responses are still saved."
            }
            return
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            currentStepIndex += 1
        }
        persistCurrentStep()
    }

    private func persistCurrentStep() {
        progress.currentStepIndex = currentStepIndex
        progress.updatedAt = Date()
        participation.updatedAt = Date()
        try? modelContext.save()
    }

    private func saveAndDismiss() {
        persistCurrentStep()
        dismiss()
    }

    private func repeatChallenge() {
        do {
            _ = try WellnessChallengeProgressionService.begin(challenge, in: modelContext)
            dismiss()
        } catch {
            completionError = "A new attempt could not be created. Please try again."
        }
    }
}

private extension WellnessStepKind {
    var accessibilityName: String {
        switch self {
        case .guidedReading: return "Guidance"
        case .singleChoice: return "Choose one"
        case .multipleChoice: return "Choose several"
        case .guidedTimer: return "Guided timer"
        case .reflection: return "Reflection"
        case .rating: return "Rating"
        case .interactiveCards: return "Interactive cards"
        case .stagedActivity: return "Guided activity"
        case .sensoryExploration: return "Sensory exploration"
        case .activityChoice: return "Activity choice"
        }
    }
}
