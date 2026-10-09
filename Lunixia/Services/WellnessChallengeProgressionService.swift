//
//  WellnessChallengeProgressionService.swift
//  Lunixia
//

import Foundation
import SwiftData

@MainActor
enum WellnessChallengeProgressionService {
    static func begin(
        _ challenge: WellnessChallengeDefinition,
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws -> WellnessChallengeParticipation {
        let allParticipations = try modelContext.fetch(
            FetchDescriptor<WellnessChallengeParticipation>()
        )
        let attemptNumber = allParticipations
            .filter { $0.challengeID == challenge.id }
            .map(\.attemptNumber)
            .max()
            .map { $0 + 1 } ?? 1

        let participation = WellnessChallengeParticipation(
            challengeID: challenge.id,
            attemptNumber: attemptNumber,
            totalExperienceCount: challenge.experiences.count,
            startedAt: now
        )
        modelContext.insert(participation)
        try modelContext.save()
        return participation
    }

    static func progress(
        for participation: WellnessChallengeParticipation,
        experience: WellnessExperienceDefinition,
        experienceIndex: Int,
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws -> WellnessExperienceProgress {
        let allProgress = try modelContext.fetch(
            FetchDescriptor<WellnessExperienceProgress>()
        )

        if let existing = allProgress.first(where: {
            $0.participationID == participation.id && $0.experienceID == experience.id
        }) {
            return existing
        }

        let progress = WellnessExperienceProgress(
            participationID: participation.id,
            experienceID: experience.id,
            experienceIndex: experienceIndex,
            startedAt: now
        )
        modelContext.insert(progress)
        participation.currentExperienceIndex = experienceIndex
        participation.updatedAt = now
        try modelContext.save()
        return progress
    }

    static func pause(
        _ participation: WellnessChallengeParticipation,
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws {
        guard participation.status == .active else { return }
        participation.status = .paused
        participation.updatedAt = now
        try modelContext.save()
    }

    static func resume(
        _ participation: WellnessChallengeParticipation,
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws {
        guard participation.status == .paused else { return }
        participation.status = .active
        participation.updatedAt = now
        try modelContext.save()
    }

    static func abandon(
        _ participation: WellnessChallengeParticipation,
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws {
        guard participation.status == .active || participation.status == .paused else { return }
        participation.status = .abandoned
        participation.updatedAt = now
        try modelContext.save()
    }

    static func saveStep(
        response: WellnessStepResponse,
        stepID: String,
        stepIndex: Int,
        progress: WellnessExperienceProgress,
        participation: WellnessChallengeParticipation,
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws {
        progress.setResponse(response, for: stepID)
        progress.currentStepIndex = max(0, stepIndex)
        progress.updatedAt = now
        participation.updatedAt = now
        try modelContext.save()
    }

    @discardableResult
    static func completeExperience(
        _ progress: WellnessExperienceProgress,
        participation: WellnessChallengeParticipation,
        challenge: WellnessChallengeDefinition,
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws -> Bool {
        guard !progress.isCompleted else { return false }

        progress.isCompleted = true
        progress.completionDate = now
        progress.updatedAt = now

        let allProgress = try modelContext.fetch(
            FetchDescriptor<WellnessExperienceProgress>()
        )
        let completedCount = allProgress.filter {
            $0.participationID == participation.id && ($0.isCompleted || $0.id == progress.id)
        }.count

        participation.completedExperienceCount = min(
            challenge.experiences.count,
            completedCount
        )
        participation.totalExperienceCount = challenge.experiences.count
        participation.updatedAt = now

        if participation.completedExperienceCount >= challenge.experiences.count {
            participation.currentExperienceIndex = max(0, challenge.experiences.count - 1)
            participation.status = .completed
            participation.completionDate = now
        } else {
            participation.currentExperienceIndex = participation.completedExperienceCount
            participation.status = .active
        }

        try modelContext.save()
        return true
    }

    static func delete(
        _ participation: WellnessChallengeParticipation,
        in modelContext: ModelContext
    ) throws {
        let allProgress = try modelContext.fetch(
            FetchDescriptor<WellnessExperienceProgress>()
        )
        for progress in allProgress where progress.participationID == participation.id {
            modelContext.delete(progress)
        }
        modelContext.delete(participation)
        try modelContext.save()
    }
}
