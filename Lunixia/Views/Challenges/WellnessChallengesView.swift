//
//  WellnessChallengesView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct WellnessChallengesView: View {
    @Environment(\.appTheme) private var theme
    @Query(sort: \WellnessChallengeParticipation.startedAt, order: .reverse)
    private var participations: [WellnessChallengeParticipation]

    @State private var selectedCategory: WellnessChallengeCategory?

    private let exploreColumns = [
        GridItem(.adaptive(minimum: 270, maximum: 420), spacing: 14)
    ]

    private var activeParticipations: [WellnessChallengeParticipation] {
        participations.filter { $0.status == .active }
    }

    private var filteredChallenges: [WellnessChallengeDefinition] {
        guard let selectedCategory else { return WellnessChallengeLibrary.all }
        return WellnessChallengeLibrary.all.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    pageHeader
                    activeSection
                    categorySection
                    exploreSection
                    historyLink
                }
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 150)
            }
            .scrollIndicators(.hidden)
            .background { LunixiaBackground() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fontDesign(.rounded)
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Wellness Challenges")
                    .font(theme.typography.pageTitle)
                    .foregroundStyle(theme.palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Explore experiences that nurture you.")
                    .font(.body)
                    .foregroundStyle(theme.palette.textSecondary)
            }

            Spacer(minLength: 8)

            WellnessTintedIcon(
                name: "heartsparkle",
                tint: theme.palette.primaryAction,
                size: 34,
                containerSize: 46
            )
            .accessibilityLabel("Wellness")
        }
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            WellnessSectionHeader(
                title: "Active Challenges",
                icon: "playwavy",
                tint: theme.palette.primaryAction,
                trailingText: activeParticipations.isEmpty ? nil : "\(activeParticipations.count)"
            )

            if activeParticipations.isEmpty {
                WellnessEmptyState(
                    icon: "heartsparkle",
                    title: "No active challenge",
                    message: "Choose an experience from the library whenever you are ready to begin."
                )
            } else {
                ForEach(activeParticipations) { participation in
                    if let challenge = WellnessChallengeLibrary.challenge(id: participation.challengeID) {
                        activeChallengeCard(challenge: challenge, participation: participation)
                    }
                }
            }
        }
    }

    private func activeChallengeCard(
        challenge: WellnessChallengeDefinition,
        participation: WellnessChallengeParticipation
    ) -> some View {
        let currentIndex = min(
            max(0, participation.currentExperienceIndex),
            max(0, challenge.experiences.count - 1)
        )
        let currentExperience = challenge.experiences.indices.contains(currentIndex)
            ? challenge.experiences[currentIndex]
            : nil

        return WellnessSurface(borderColor: theme.palette.primaryAction) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    WellnessTintedIcon(
                        name: challenge.icon,
                        tint: theme.palette.primaryAction,
                        size: 30,
                        containerSize: 38
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(theme.palette.textPrimary)
                        Text(challenge.category.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.palette.primaryAction)
                    }

                    Spacer(minLength: 8)
                    WellnessStatusBadge(status: participation.status)
                }

                if let currentExperience {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("EXPERIENCE \(currentIndex + 1) OF \(challenge.experiences.count)")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(theme.palette.textSecondary)
                        Text(currentExperience.title)
                            .font(.headline)
                            .foregroundStyle(theme.palette.textPrimary)
                    }
                }

                WellnessProgressBar(value: participation.progressFraction)

                HStack {
                    Text("\(participation.completedExperienceCount) completed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.palette.textSecondary)
                    Spacer()
                    Text("\(challenge.experiences.count) total")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.palette.textSecondary)
                }

                NavigationLink {
                    WellnessChallengeDetailView(
                        challenge: challenge,
                        preferredParticipationID: participation.id
                    )
                } label: {
                    HStack(spacing: 7) {
                        Text("Continue")
                            .font(.headline)
                        Image("chevright")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    }
                    .foregroundStyle(theme.palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.palette.primaryAction)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue \(challenge.title)")
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            WellnessSectionHeader(
                title: "Categories",
                icon: "tagsparkle",
                tint: theme.palette.secondaryAccent
            )

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    categoryButton(title: "All", icon: "starsbox", category: nil, index: 0)

                    ForEach(Array(WellnessChallengeCategory.allCases.enumerated()), id: \.element.id) { index, category in
                        categoryButton(
                            title: category.rawValue,
                            icon: category.icon,
                            category: category,
                            index: index + 1
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func categoryButton(
        title: String,
        icon: String,
        category: WellnessChallengeCategory?,
        index: Int
    ) -> some View {
        let isSelected = selectedCategory == category
        let tint = theme.palette.rotation[index % theme.palette.rotation.count]

        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 7) {
                WellnessTintedIcon(name: icon, tint: tint, size: 16)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.palette.textPrimary)
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 44)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? theme.palette.raisedSurface : theme.palette.surface)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? tint : theme.palette.raisedSurface, lineWidth: isSelected ? 1.25 : 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            WellnessSectionHeader(
                title: "Explore Challenges",
                icon: "sparklesearch",
                tint: theme.palette.indicators,
                trailingText: "\(filteredChallenges.count)"
            )

            if filteredChallenges.isEmpty {
                WellnessEmptyState(
                    icon: selectedCategory?.icon ?? "sparklesearch",
                    title: "More experiences are coming",
                    message: "There are no challenges in this category yet. Your existing challenge history is unchanged."
                )
            } else {
                LazyVGrid(columns: exploreColumns, alignment: .leading, spacing: 14) {
                    ForEach(Array(filteredChallenges.enumerated()), id: \.element.id) { index, challenge in
                        NavigationLink {
                            WellnessChallengeDetailView(challenge: challenge)
                        } label: {
                            exploreCard(challenge, index: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func exploreCard(
        _ challenge: WellnessChallengeDefinition,
        index: Int
    ) -> some View {
        let tint = theme.palette.rotation[index % theme.palette.rotation.count]
        let latest = participations.first { $0.challengeID == challenge.id }

        return WellnessSurface(cornerRadius: 19, padding: 16, borderColor: tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    WellnessTintedIcon(name: challenge.icon, tint: tint, size: 28, containerSize: 34)
                    Spacer()
                    WellnessStatusBadge(status: latest?.status)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(challenge.title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(theme.palette.textPrimary)
                    Text(challenge.summary)
                        .font(.subheadline)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    exploreMetadata(icon: challenge.category.icon, text: challenge.category.rawValue, tint: tint)
                    exploreMetadata(icon: "clockwavy", text: challenge.estimatedTimeDescription, tint: tint)
                }

                HStack {
                    Text(challenge.durationDescription)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.palette.textSecondary)
                    Spacer()
                    WellnessTintedIcon(name: "chevright", tint: tint, size: 16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(challenge.title), \(challenge.category.rawValue), \(challenge.durationDescription), \(latest?.status.displayName ?? "Not Started")")
    }

    private func exploreMetadata(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            WellnessTintedIcon(name: icon, tint: tint, size: 13)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(1)
        }
    }

    private var historyLink: some View {
        NavigationLink {
            WellnessChallengeHistoryView()
        } label: {
            WellnessSurface(borderColor: theme.palette.secondaryAccent) {
                HStack(spacing: 12) {
                    WellnessTintedIcon(
                        name: "timebook",
                        tint: theme.palette.secondaryAccent,
                        size: 27,
                        containerSize: 34
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Challenge History")
                            .font(.headline)
                            .foregroundStyle(theme.palette.textPrimary)
                        Text("Review active, paused, completed, and previous attempts.")
                            .font(.subheadline)
                            .foregroundStyle(theme.palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    WellnessTintedIcon(name: "chevright", tint: theme.palette.secondaryAccent, size: 17)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
