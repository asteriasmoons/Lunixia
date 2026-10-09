//
//  WellnessChallengeDetailView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct WellnessExperienceLaunch: Identifiable {
    let challenge: WellnessChallengeDefinition
    let experience: WellnessExperienceDefinition
    let experienceIndex: Int
    let participation: WellnessChallengeParticipation
    let progress: WellnessExperienceProgress

    var id: UUID { progress.id }
}

private struct WellnessExperienceReviewRoute: Identifiable {
    let experience: WellnessExperienceDefinition
    let progress: WellnessExperienceProgress

    var id: UUID { progress.id }
}

struct WellnessChallengeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WellnessChallengeParticipation.startedAt, order: .reverse)
    private var participations: [WellnessChallengeParticipation]
    @Query private var allProgress: [WellnessExperienceProgress]

    let challenge: WellnessChallengeDefinition
    var preferredParticipationID: UUID? = nil

    @State private var experienceLaunch: WellnessExperienceLaunch?
    @State private var reviewRoute: WellnessExperienceReviewRoute?
    @State private var showAbandonConfirmation = false
    @State private var actionError: String?

    private var challengeParticipations: [WellnessChallengeParticipation] {
        participations.filter { $0.challengeID == challenge.id }
    }

    private var participation: WellnessChallengeParticipation? {
        if let preferredParticipationID,
           let preferred = challengeParticipations.first(where: { $0.id == preferredParticipationID }) {
            return preferred
        }

        if let actionable = challengeParticipations.first(where: {
            $0.status == .active || $0.status == .paused
        }) {
            return actionable
        }

        return challengeParticipations.first
    }

    private var progressRecords: [WellnessExperienceProgress] {
        guard let participation else { return [] }
        return allProgress.filter { $0.participationID == participation.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                challengeHeader
                overviewCard

                if let participation {
                    progressCard(participation)
                }

                purposeSection
                experiencesSection

                if let actionError {
                    Text(actionError)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.palette.indicators)
                }

                challengeActions
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .background { LunixiaBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .fontDesign(.rounded)
        .fullScreenCover(item: $experienceLaunch) { launch in
            WellnessExperienceView(
                challenge: launch.challenge,
                experience: launch.experience,
                experienceIndex: launch.experienceIndex,
                participation: launch.participation,
                progress: launch.progress,
                onReturnToLibrary: {
                    experienceLaunch = nil
                    DispatchQueue.main.async { dismiss() }
                }
            )
        }
        .sheet(item: $reviewRoute) { route in
            NavigationStack {
                WellnessExperienceReviewView(
                    challenge: challenge,
                    experience: route.experience,
                    progress: route.progress
                )
            }
            .presentationDragIndicator(.visible)
        }
        .alert("Abandon this challenge attempt?", isPresented: $showAbandonConfirmation) {
            Button("Keep Going", role: .cancel) {}
            Button("Abandon Attempt", role: .destructive) { abandonAttempt() }
        } message: {
            Text("Your completed experiences and saved responses will remain in Challenge History. This will not delete the attempt.")
        }
    }

    private var challengeHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(challenge.category.rawValue.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(theme.palette.primaryAction)
                Text(challenge.title)
                    .font(theme.typography.pageTitle)
                    .foregroundStyle(theme.palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)

            Button { closeChallenge() } label: {
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
            .accessibilityLabel("Close challenge")
        }
    }

    private var overviewCard: some View {
        WellnessSurface(borderColor: theme.palette.primaryAction) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 14) {
                    WellnessTintedIcon(
                        name: challenge.icon,
                        tint: theme.palette.primaryAction,
                        size: 36,
                        containerSize: 46
                    )
                    Text(challenge.summary)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    metadataPill(icon: "timebook", text: challenge.durationDescription)
                    metadataPill(icon: "clockwavy", text: challenge.estimatedTimeDescription)
                }
            }
        }
    }

    private func progressCard(_ participation: WellnessChallengeParticipation) -> some View {
        WellnessSurface(borderColor: statusTint(for: participation.status)) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    WellnessStatusBadge(status: participation.status)
                    Spacer()
                    Text(participation.wellnessAttemptLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.palette.textSecondary)
                }
                WellnessProgressBar(
                    value: participation.progressFraction,
                    tint: statusTint(for: participation.status)
                )
                Text("\(participation.completedExperienceCount) of \(challenge.experiences.count) experiences completed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.palette.textPrimary)
            }
        }
    }

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            WellnessSectionHeader(
                title: "What This Experience Offers",
                icon: "heartsparkle",
                tint: theme.palette.secondaryAccent
            )

            WellnessSurface {
                VStack(alignment: .leading, spacing: 15) {
                    detailText(title: "Purpose", text: challenge.purpose)
                    Divider().overlay(theme.palette.raisedSurface)
                    detailText(title: "What to Expect", text: challenge.expectedExperience)
                }
            }
        }
    }

    private var experiencesSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            WellnessSectionHeader(
                title: "Experiences",
                icon: "starladder",
                tint: theme.palette.indicators,
                trailingText: "In order"
            )

            ForEach(Array(challenge.experiences.enumerated()), id: \.element.id) { index, experience in
                experienceRow(experience, index: index)
            }
        }
    }

    private func experienceRow(
        _ experience: WellnessExperienceDefinition,
        index: Int
    ) -> some View {
        let progress = progressRecords.first { $0.experienceID == experience.id }
        let isCompleted = progress?.isCompleted == true
        let isCurrent = participation.map {
            ($0.status == .active || $0.status == .paused) && $0.currentExperienceIndex == index
        } ?? false
        let isAvailable = isCompleted || isCurrent
        let tint = theme.palette.rotation[index % theme.palette.rotation.count]

        return Button {
            guard isAvailable, let participation else { return }
            if isCompleted, let progress {
                reviewRoute = WellnessExperienceReviewRoute(
                    experience: experience,
                    progress: progress
                )
            } else if participation.status == .active {
                launchExperience(
                    participation: participation,
                    experience: experience,
                    index: index
                )
            } else if participation.status == .paused {
                resumeAndLaunch(
                    participation: participation,
                    experience: experience,
                    index: index
                )
            }
        } label: {
            WellnessSurface(cornerRadius: 17, padding: 14, borderColor: isAvailable ? tint : nil) {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(isAvailable ? theme.palette.textPrimary : theme.palette.textSecondary)
                        .frame(width: 34, height: 34)
                        .background {
                            Circle()
                                .fill(isAvailable ? tint : theme.palette.raisedSurface)
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(experience.title)
                            .font(.headline)
                            .foregroundStyle(isAvailable ? theme.palette.textPrimary : theme.palette.textSecondary)
                        Text(experience.summary)
                            .font(.subheadline)
                            .foregroundStyle(theme.palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(experienceStateText(isCompleted: isCompleted, isCurrent: isCurrent))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isAvailable ? tint : theme.palette.textSecondary)
                    }

                    Spacer(minLength: 8)

                    WellnessTintedIcon(
                        name: isCompleted ? "checkwavy" : (isCurrent ? "playwavy" : "lockwavy"),
                        tint: isAvailable ? tint : theme.palette.textSecondary,
                        size: 18,
                        containerSize: 26
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel("Experience \(index + 1), \(experience.title)")
        .accessibilityValue(experienceStateText(isCompleted: isCompleted, isCurrent: isCurrent))
    }

    @ViewBuilder
    private var challengeActions: some View {
        VStack(spacing: 12) {
            WellnessActionButton(
                title: primaryActionTitle,
                icon: primaryActionIcon,
                tint: theme.palette.primaryAction
            ) {
                performPrimaryAction()
            }

            if let participation, participation.status == .active {
                WellnessSecondaryButton(
                    title: "Pause Challenge",
                    icon: "pausewavy",
                    tint: theme.palette.secondaryAccent
                ) {
                    pauseAttempt()
                }
            }

            if let participation,
               participation.status == .active || participation.status == .paused {
                Button {
                    showAbandonConfirmation = true
                } label: {
                    Text("Abandon This Attempt")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.palette.textSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryActionTitle: String {
        guard let participation else { return "Begin Challenge" }
        switch participation.status {
        case .active: return "Continue Challenge"
        case .paused: return "Resume Challenge"
        case .completed: return "Repeat Challenge"
        case .abandoned: return "Begin New Attempt"
        }
    }

    private var primaryActionIcon: String {
        guard let participation else { return "playwavy" }
        switch participation.status {
        case .active, .paused: return "playwavy"
        case .completed, .abandoned: return "repeat"
        }
    }

    private func metadataPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            WellnessTintedIcon(name: icon, tint: theme.palette.secondaryAccent, size: 14)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.palette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(theme.palette.raisedSurface))
        .accessibilityElement(children: .combine)
    }

    private func detailText(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(theme.palette.secondaryAccent)
            Text(text)
                .font(.body)
                .foregroundStyle(theme.palette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func experienceStateText(isCompleted: Bool, isCurrent: Bool) -> String {
        if isCompleted { return "Completed - tap to review" }
        if isCurrent { return participation?.status == .paused ? "Paused here" : "Current experience" }
        return "Available after the previous experience"
    }

    private func closeChallenge() {
        dismiss()
    }

    private func statusTint(for status: WellnessChallengeParticipationStatus) -> Color {
        switch status {
        case .active: return theme.palette.primaryAction
        case .paused: return theme.palette.secondaryAccent
        case .completed: return theme.palette.indicators
        case .abandoned: return theme.palette.textSecondary
        }
    }

    private func performPrimaryAction() {
        actionError = nil

        guard let participation else {
            beginAndLaunch()
            return
        }

        switch participation.status {
        case .active:
            launchCurrentExperience(participation)
        case .paused:
            do {
                try WellnessChallengeProgressionService.resume(participation, in: modelContext)
                launchCurrentExperience(participation)
            } catch {
                actionError = "This challenge could not be resumed. Please try again."
            }
        case .completed, .abandoned:
            beginAndLaunch()
        }
    }

    private func beginAndLaunch() {
        do {
            let newParticipation = try WellnessChallengeProgressionService.begin(
                challenge,
                in: modelContext
            )
            launchCurrentExperience(newParticipation)
        } catch {
            actionError = "This challenge could not be started. Please try again."
        }
    }

    private func launchCurrentExperience(_ participation: WellnessChallengeParticipation) {
        let index = min(
            max(0, participation.currentExperienceIndex),
            max(0, challenge.experiences.count - 1)
        )
        guard challenge.experiences.indices.contains(index) else { return }
        launchExperience(
            participation: participation,
            experience: challenge.experiences[index],
            index: index
        )
    }

    private func launchExperience(
        participation: WellnessChallengeParticipation,
        experience: WellnessExperienceDefinition,
        index: Int
    ) {
        do {
            let progress = try WellnessChallengeProgressionService.progress(
                for: participation,
                experience: experience,
                experienceIndex: index,
                in: modelContext
            )
            experienceLaunch = WellnessExperienceLaunch(
                challenge: challenge,
                experience: experience,
                experienceIndex: index,
                participation: participation,
                progress: progress
            )
        } catch {
            actionError = "This experience could not be opened. Please try again."
        }
    }

    private func resumeAndLaunch(
        participation: WellnessChallengeParticipation,
        experience: WellnessExperienceDefinition,
        index: Int
    ) {
        do {
            try WellnessChallengeProgressionService.resume(participation, in: modelContext)
            launchExperience(
                participation: participation,
                experience: experience,
                index: index
            )
        } catch {
            actionError = "This challenge could not be resumed. Please try again."
        }
    }

    private func pauseAttempt() {
        guard let participation else { return }
        do {
            try WellnessChallengeProgressionService.pause(participation, in: modelContext)
        } catch {
            actionError = "This challenge could not be paused. Please try again."
        }
    }

    private func abandonAttempt() {
        guard let participation else { return }
        do {
            try WellnessChallengeProgressionService.abandon(participation, in: modelContext)
        } catch {
            actionError = "This attempt could not be ended. Please try again."
        }
    }
}
