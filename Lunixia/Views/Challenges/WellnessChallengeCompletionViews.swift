//
//  WellnessChallengeCompletionViews.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct WellnessDailyExperienceCompletionView: View {
    @Environment(\.appTheme) private var theme

    let challenge: WellnessChallengeDefinition
    let experience: WellnessExperienceDefinition
    let participation: WellnessChallengeParticipation
    let nextExperience: WellnessExperienceDefinition?
    let onReturn: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WellnessTintedIcon(
                    name: "checkwavy",
                    tint: theme.palette.indicators,
                    size: 46,
                    containerSize: 64
                )
                .padding(.top, 42)

                VStack(spacing: 9) {
                    Text("Experience Complete")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(theme.palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(experience.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.palette.indicators)
                        .multilineTextAlignment(.center)
                }

                WellnessSurface(borderColor: theme.palette.indicators) {
                    Text(experience.completionMessage)
                        .font(.body)
                        .foregroundStyle(theme.palette.textPrimary)
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundStyle(theme.palette.textPrimary)
                        Spacer()
                        Text("\(participation.completedExperienceCount) of \(participation.totalExperienceCount)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(theme.palette.textSecondary)
                    }
                    WellnessProgressBar(value: participation.progressFraction)
                }

                if let nextExperience {
                    WellnessSurface(borderColor: theme.palette.primaryAction) {
                        HStack(alignment: .top, spacing: 12) {
                            WellnessTintedIcon(
                                name: challenge.icon,
                                tint: theme.palette.primaryAction,
                                size: 24,
                                containerSize: 30
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Next Available Experience")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(theme.palette.primaryAction)
                                Text(nextExperience.title)
                                    .font(.headline)
                                    .foregroundStyle(theme.palette.textPrimary)
                                Text(nextExperience.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(theme.palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                WellnessActionButton(
                    title: "Return to Challenge",
                    icon: "chevleft",
                    tint: theme.palette.primaryAction,
                    action: onReturn
                )
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }
}

struct WellnessFinalChallengeCompletionView: View {
    @Environment(\.appTheme) private var theme
    @Query private var allProgress: [WellnessExperienceProgress]

    let challenge: WellnessChallengeDefinition
    let participation: WellnessChallengeParticipation
    let onReview: () -> Void
    let onRepeat: () -> Void
    let onReturnToLibrary: () -> Void

    private var progressRecords: [WellnessExperienceProgress] {
        allProgress
            .filter { $0.participationID == participation.id }
            .sorted { $0.experienceIndex < $1.experienceIndex }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WellnessTintedIcon(
                    name: challenge.icon,
                    tint: theme.palette.indicators,
                    size: 52,
                    containerSize: 72
                )
                .padding(.top, 34)

                VStack(spacing: 9) {
                    Text("Challenge Complete")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(theme.palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(challenge.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.palette.indicators)
                        .multilineTextAlignment(.center)
                }

                WellnessSurface(borderColor: theme.palette.indicators) {
                    VStack(spacing: 12) {
                        Text(challenge.completionMessage)
                            .font(.body)
                            .foregroundStyle(theme.palette.textPrimary)
                            .lineSpacing(5)
                            .multilineTextAlignment(.center)

                        Divider().overlay(theme.palette.raisedSurface)

                        HStack(spacing: 20) {
                            completionStat(
                                value: "\(participation.completedExperienceCount)",
                                label: "Experiences"
                            )
                            completionStat(
                                value: participation.completionDate?.wellnessDateText ?? "Today",
                                label: "Completed"
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    WellnessSectionHeader(
                        title: "Your Participation",
                        icon: "lovewrite",
                        tint: theme.palette.secondaryAccent
                    )

                    WellnessParticipationSummaryView(
                        challenge: challenge,
                        progressRecords: progressRecords,
                        condensed: true
                    )
                }

                VStack(spacing: 12) {
                    WellnessActionButton(
                        title: "Review Completed Experiences",
                        icon: "openbook",
                        tint: theme.palette.primaryAction,
                        action: onReview
                    )
                    WellnessSecondaryButton(
                        title: "Repeat Challenge",
                        icon: "repeat",
                        tint: theme.palette.secondaryAccent,
                        action: onRepeat
                    )
                    WellnessSecondaryButton(
                        title: "Return to Challenge Library",
                        icon: "starcard",
                        tint: theme.palette.indicators,
                        action: onReturnToLibrary
                    )
                }
                .padding(.bottom, 36)
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func completionStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(theme.palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WellnessParticipationSummaryView: View {
    @Environment(\.appTheme) private var theme

    let challenge: WellnessChallengeDefinition
    let progressRecords: [WellnessExperienceProgress]
    var condensed: Bool = false

    private var completedItems: [(WellnessExperienceDefinition, WellnessExperienceProgress)] {
        challenge.experiences.compactMap { experience in
            guard let progress = progressRecords.first(where: { $0.experienceID == experience.id }),
                  progress.isCompleted
            else { return nil }
            return (experience, progress)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(completedItems.enumerated()), id: \.element.0.id) { index, item in
                let experience = item.0
                let progress = item.1

                WellnessSurface(
                    cornerRadius: 16,
                    padding: 14,
                    borderColor: theme.palette.rotation[index % theme.palette.rotation.count]
                ) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.black).monospacedDigit())
                                .foregroundStyle(theme.palette.textPrimary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(theme.palette.rotation[index % theme.palette.rotation.count]))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(experience.title)
                                    .font(.headline)
                                    .foregroundStyle(theme.palette.textPrimary)
                                if let completionDate = progress.completionDate {
                                    Text(completionDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(theme.palette.textSecondary)
                                }
                            }
                        }

                        let highlights = WellnessResponseFormatter.highlights(
                            for: experience,
                            responses: progress.responses
                        )
                        ForEach(Array(highlights.prefix(condensed ? 2 : highlights.count)), id: \.self) { highlight in
                            Text(highlight)
                                .font(.subheadline)
                                .foregroundStyle(theme.palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

struct WellnessExperienceReviewView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let challenge: WellnessChallengeDefinition
    let experience: WellnessExperienceDefinition
    let progress: WellnessExperienceProgress

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.palette.primaryAction)
                        Text(experience.title)
                            .font(.largeTitle.weight(.black))
                            .foregroundStyle(theme.palette.textPrimary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        ZStack {
                            Color.clear
                            WellnessTintedIcon(
                                name: "xmarkwavy",
                                tint: theme.palette.primaryAction,
                                size: 22,
                                containerSize: 44
                            )
                        }
                        .frame(width: 52, height: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close review")
                }

                if let completionDate = progress.completionDate {
                    Text("Completed \(completionDate.formatted(date: .long, time: .shortened))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.palette.textSecondary)
                }

                ForEach(Array(experience.steps.enumerated()), id: \.element.id) { index, step in
                    let lines = WellnessResponseFormatter.lines(
                        for: step,
                        response: progress.response(for: step.id)
                    )
                    if !lines.isEmpty {
                        WellnessSurface(
                            borderColor: theme.palette.rotation[index % theme.palette.rotation.count]
                        ) {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(step.title)
                                    .font(.headline)
                                    .foregroundStyle(theme.palette.textPrimary)
                                ForEach(lines, id: \.self) { line in
                                    Text(line)
                                        .font(.body)
                                        .foregroundStyle(theme.palette.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background { LunixiaBackground() }
        .toolbar(.hidden, for: .navigationBar)
    }
}

enum WellnessResponseFormatter {
    static func highlights(
        for experience: WellnessExperienceDefinition,
        responses: [String: WellnessStepResponse]
    ) -> [String] {
        experience.steps.flatMap { step in
            lines(for: step, response: responses[step.id] ?? WellnessStepResponse())
        }
    }

    static func lines(
        for step: WellnessStepDefinition,
        response: WellnessStepResponse
    ) -> [String] {
        switch step.kind {
        case .guidedReading:
            return []
        case .singleChoice, .multipleChoice, .activityChoice:
            let titles = step.options
                .filter { response.selectedOptionIDs.contains($0.id) }
                .map(\.title)
            return titles.isEmpty ? [] : [titles.joined(separator: ", ")]
        case .guidedTimer:
            guard response.isFinished else { return [] }
            let minutes = max(1, Int(ceil(response.timerElapsed / 60)))
            return ["Guided activity completed for about \(minutes) minute\(minutes == 1 ? "" : "s")."]
        case .reflection:
            let trimmed = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        case .rating:
            guard let rating = response.rating,
                  step.scaleLabels.indices.contains(rating - 1)
            else { return [] }
            return ["\(rating) of \(step.scaleLabels.count): \(step.scaleLabels[rating - 1])"]
        case .interactiveCards:
            let selected = step.cards
                .filter { response.selectedOptionIDs.contains($0.id) }
                .map(\.title)
            if !selected.isEmpty {
                return ["Chosen card: \(selected.joined(separator: ", "))"]
            }
            let revealed = step.cards
                .filter { response.revealedCardIDs.contains($0.id) }
                .map(\.title)
            return revealed.isEmpty ? [] : ["Explored: \(revealed.joined(separator: ", "))"]
        case .stagedActivity:
            return response.isFinished ? ["Guided activity completed."] : []
        case .sensoryExploration:
            let selectedSenses = step.senses.filter {
                response.sensorySelections.contains($0.id)
            }
            return selectedSenses.compactMap { sense in
                let observation = response.sensoryObservations[sense.id]?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return observation.isEmpty ? sense.title : "\(sense.title): \(observation)"
            }
        }
    }
}
