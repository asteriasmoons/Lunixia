//
//  WellnessChallengeHistoryView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct WellnessChallengeHistoryView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WellnessChallengeParticipation.startedAt, order: .reverse)
    private var participations: [WellnessChallengeParticipation]

    private var sections: [(String, String, Color, [WellnessChallengeParticipation])] {
        [
            (
                "Active Challenges",
                "playwavy",
                theme.palette.primaryAction,
                participations.filter { $0.status == .active }
            ),
            (
                "Paused Challenges",
                "pausewavy",
                theme.palette.secondaryAccent,
                participations.filter { $0.status == .paused }
            ),
            (
                "Completed Challenges",
                "checkwavy",
                theme.palette.indicators,
                participations.filter { $0.status == .completed }
            ),
            (
                "Previous Attempts",
                "timebook",
                theme.palette.textSecondary,
                participations.filter { $0.status == .abandoned }
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                historyHeader

                if participations.isEmpty {
                    WellnessEmptyState(
                        icon: "timebook",
                        title: "No challenge history yet",
                        message: "Challenges you begin, pause, complete, or end will remain available here."
                    )
                } else {
                    ForEach(sections, id: \.0) { section in
                        historySection(
                            title: section.0,
                            icon: section.1,
                            tint: section.2,
                            records: section.3
                        )
                    }
                }
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background { LunixiaBackground() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var historyHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Wellness Challenges")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.palette.secondaryAccent)
                Text("Challenge History")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(theme.palette.textPrimary)
                Text("Review every attempt and the experiences you saved.")
                    .font(.body)
                    .foregroundStyle(theme.palette.textSecondary)
            }
            Spacer(minLength: 8)
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
            .accessibilityLabel("Close challenge history")
        }
    }

    @ViewBuilder
    private func historySection(
        title: String,
        icon: String,
        tint: Color,
        records: [WellnessChallengeParticipation]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            WellnessSectionHeader(
                title: title,
                icon: icon,
                tint: tint,
                trailingText: "\(records.count)"
            )

            if records.isEmpty {
                Text("None")
                    .font(.subheadline)
                    .foregroundStyle(theme.palette.textSecondary)
                    .padding(.horizontal, 4)
            } else {
                ForEach(records) { participation in
                    if let challenge = WellnessChallengeLibrary.challenge(id: participation.challengeID) {
                        NavigationLink {
                            WellnessChallengeAttemptDetailView(
                                challenge: challenge,
                                participation: participation
                            )
                        } label: {
                            historyRow(challenge: challenge, participation: participation, tint: tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func historyRow(
        challenge: WellnessChallengeDefinition,
        participation: WellnessChallengeParticipation,
        tint: Color
    ) -> some View {
        WellnessSurface(cornerRadius: 17, padding: 14, borderColor: tint) {
            HStack(alignment: .top, spacing: 12) {
                WellnessTintedIcon(name: challenge.icon, tint: tint, size: 26, containerSize: 34)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundStyle(theme.palette.textPrimary)
                        Spacer(minLength: 8)
                        WellnessStatusBadge(status: participation.status)
                    }

                    Text("\(participation.wellnessAttemptLabel) started \(participation.startedAt.wellnessDateText)")
                        .font(.caption)
                        .foregroundStyle(theme.palette.textSecondary)

                    WellnessProgressBar(value: participation.progressFraction, tint: tint, height: 6)

                    Text("\(participation.completedExperienceCount) of \(participation.totalExperienceCount) experiences")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.palette.textSecondary)
                }

                WellnessTintedIcon(name: "chevright", tint: tint, size: 16, containerSize: 24)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct WellnessChallengeAttemptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Query private var allProgress: [WellnessExperienceProgress]

    let challenge: WellnessChallengeDefinition
    let participation: WellnessChallengeParticipation

    @State private var showDeleteConfirmation = false
    @State private var showRestartedChallenge = false
    @State private var restartedParticipationID: UUID?
    @State private var actionError: String?

    private var progressRecords: [WellnessExperienceProgress] {
        allProgress
            .filter { $0.participationID == participation.id }
            .sorted { $0.experienceIndex < $1.experienceIndex }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                attemptHeader

                WellnessSurface(borderColor: statusTint) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            WellnessStatusBadge(status: participation.status)
                            Spacer()
                            Text(participation.wellnessAttemptLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.palette.textSecondary)
                        }
                        WellnessProgressBar(value: participation.progressFraction, tint: statusTint)
                        Text("\(participation.completedExperienceCount) of \(participation.totalExperienceCount) experiences completed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.palette.textPrimary)

                        HStack {
                            dateLabel("Started", date: participation.startedAt)
                            Spacer()
                            if let completionDate = participation.completionDate {
                                dateLabel("Completed", date: completionDate)
                            }
                        }
                    }
                }

                if participation.status == .active || participation.status == .paused {
                    NavigationLink {
                        WellnessChallengeDetailView(
                            challenge: challenge,
                            preferredParticipationID: participation.id
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image("playwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text(participation.status == .paused ? "Open and Resume" : "Open Challenge")
                                .font(.headline)
                        }
                        .foregroundStyle(theme.palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.palette.primaryAction)
                        }
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 14) {
                    WellnessSectionHeader(
                        title: "Saved Participation",
                        icon: "lovewrite",
                        tint: theme.palette.secondaryAccent
                    )

                    if progressRecords.contains(where: { !$0.responses.isEmpty || $0.isCompleted }) {
                        ForEach(Array(challenge.experiences.enumerated()), id: \.element.id) { index, experience in
                            if let progress = progressRecords.first(where: {
                                $0.experienceID == experience.id && (!$0.responses.isEmpty || $0.isCompleted)
                            }) {
                                NavigationLink {
                                    WellnessExperienceReviewView(
                                        challenge: challenge,
                                        experience: experience,
                                        progress: progress
                                    )
                                } label: {
                                    completedExperienceRow(
                                        experience: experience,
                                        progress: progress,
                                        index: index
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        WellnessEmptyState(
                            icon: "lovewrite",
                            title: "No saved responses yet",
                            message: "Responses and completed experiences from this attempt will appear here."
                        )
                    }
                }

                if let actionError {
                    Text(actionError)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.palette.indicators)
                }

                VStack(spacing: 12) {
                    WellnessSecondaryButton(
                        title: "Restart as New Attempt",
                        icon: "repeat",
                        tint: theme.palette.secondaryAccent
                    ) {
                        restartChallenge()
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image("trash")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text("Delete This Attempt")
                                .font(.headline)
                        }
                        .foregroundStyle(theme.palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.palette.surface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(theme.palette.indicators, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background { LunixiaBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Delete this challenge attempt?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAttempt() }
        } message: {
            Text("Its progress and saved responses will be removed. No other Lunixia data will be affected.")
        }
        .navigationDestination(isPresented: $showRestartedChallenge) {
            WellnessChallengeDetailView(
                challenge: challenge,
                preferredParticipationID: restartedParticipationID
            )
        }
    }

    private var attemptHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("CHALLENGE ATTEMPT")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(statusTint)
                Text(challenge.title)
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(theme.palette.textPrimary)
            }
            Spacer(minLength: 8)
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
            .accessibilityLabel("Close attempt")
        }
    }

    private var statusTint: Color {
        switch participation.status {
        case .active: return theme.palette.primaryAction
        case .paused: return theme.palette.secondaryAccent
        case .completed: return theme.palette.indicators
        case .abandoned: return theme.palette.textSecondary
        }
    }

    private func dateLabel(_ title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.palette.textSecondary)
            Text(date.wellnessDateText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.palette.textPrimary)
        }
    }

    private func completedExperienceRow(
        experience: WellnessExperienceDefinition,
        progress: WellnessExperienceProgress,
        index: Int
    ) -> some View {
        let tint = theme.palette.rotation[index % theme.palette.rotation.count]

        return WellnessSurface(cornerRadius: 16, padding: 14, borderColor: tint) {
            HStack(spacing: 12) {
                WellnessTintedIcon(
                    name: progress.isCompleted ? "checkwavy" : "lovewrite",
                    tint: tint,
                    size: 20,
                    containerSize: 28
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(experience.title)
                        .font(.headline)
                        .foregroundStyle(theme.palette.textPrimary)
                    if progress.isCompleted, let completionDate = progress.completionDate {
                        Text(completionDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(theme.palette.textSecondary)
                    } else {
                        Text("Partial responses saved")
                            .font(.caption)
                            .foregroundStyle(theme.palette.textSecondary)
                    }
                }
                Spacer()
                WellnessTintedIcon(name: "chevright", tint: tint, size: 16)
            }
        }
    }

    private func restartChallenge() {
        do {
            let newParticipation = try WellnessChallengeProgressionService.begin(
                challenge,
                in: modelContext
            )
            restartedParticipationID = newParticipation.id
            showRestartedChallenge = true
        } catch {
            actionError = "A new attempt could not be created. Please try again."
        }
    }

    private func deleteAttempt() {
        do {
            try WellnessChallengeProgressionService.delete(participation, in: modelContext)
            dismiss()
        } catch {
            actionError = "This attempt could not be deleted. Please try again."
        }
    }
}
