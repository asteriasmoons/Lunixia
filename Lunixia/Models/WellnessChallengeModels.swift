//
//  WellnessChallengeModels.swift
//  Lunixia
//

import Foundation
import SwiftData

// MARK: - Authored Definitions

enum WellnessChallengeCategory: String, CaseIterable, Identifiable {
    case mindfulness = "Mindfulness"
    case relaxation = "Relaxation"
    case selfCare = "Self-Care"
    case emotionalWellness = "Emotional Wellness"
    case physicalWellness = "Physical Wellness"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mindfulness: return "cloudmind"
        case .relaxation: return "zentime"
        case .selfCare: return "hearthand"
        case .emotionalWellness: return "heartpulse"
        case .physicalWellness: return "dumbbell"
        }
    }
}

struct WellnessChallengeDefinition: Identifiable {
    let id: String
    let title: String
    let summary: String
    let category: WellnessChallengeCategory
    let icon: String
    let estimatedMinutesLower: Int
    let estimatedMinutesUpper: Int
    let purpose: String
    let expectedExperience: String
    let completionMessage: String
    let experiences: [WellnessExperienceDefinition]

    var durationDescription: String {
        "\(experiences.count) experiences"
    }

    var estimatedTimeDescription: String {
        "\(estimatedMinutesLower)-\(estimatedMinutesUpper) min each"
    }
}

struct WellnessExperienceDefinition: Identifiable {
    let id: String
    let challengeID: String
    let title: String
    let summary: String
    let completionMessage: String
    let steps: [WellnessStepDefinition]
}

enum WellnessStepKind: String {
    case guidedReading
    case singleChoice
    case multipleChoice
    case guidedTimer
    case reflection
    case rating
    case interactiveCards
    case stagedActivity
    case sensoryExploration
    case activityChoice
}

struct WellnessStepOption: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let icon: String

    init(_ id: String, _ title: String, _ detail: String, icon: String = "sparkle") {
        self.id = id
        self.title = title
        self.detail = detail
        self.icon = icon
    }
}

struct WellnessInteractiveCardDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let front: String
    let back: String
    let icon: String

    init(_ id: String, _ title: String, front: String, back: String, icon: String = "starcard") {
        self.id = id
        self.title = title
        self.front = front
        self.back = back
        self.icon = icon
    }
}

struct WellnessSensoryPrompt: Identifiable, Hashable {
    let id: String
    let title: String
    let prompt: String
    let icon: String

    init(_ id: String, _ title: String, _ prompt: String, icon: String) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.icon = icon
    }
}

struct WellnessStepDefinition: Identifiable {
    let id: String
    let kind: WellnessStepKind
    let title: String
    let prompt: String
    let body: String
    let options: [WellnessStepOption]
    let durationSeconds: Int
    let scaleLabels: [String]
    let cards: [WellnessInteractiveCardDefinition]
    let stages: [String]
    let adaptiveStages: [String: [String]]
    let sourceStepID: String
    let senses: [WellnessSensoryPrompt]
    let isRequired: Bool
    let minimumSelection: Int
    let allowsCardSelection: Bool

    init(
        id: String,
        kind: WellnessStepKind,
        title: String,
        prompt: String = "",
        body: String = "",
        options: [WellnessStepOption] = [],
        durationSeconds: Int = 0,
        scaleLabels: [String] = [],
        cards: [WellnessInteractiveCardDefinition] = [],
        stages: [String] = [],
        adaptiveStages: [String: [String]] = [:],
        sourceStepID: String = "",
        senses: [WellnessSensoryPrompt] = [],
        isRequired: Bool = true,
        minimumSelection: Int = 1,
        allowsCardSelection: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.prompt = prompt
        self.body = body
        self.options = options
        self.durationSeconds = durationSeconds
        self.scaleLabels = scaleLabels
        self.cards = cards
        self.stages = stages
        self.adaptiveStages = adaptiveStages
        self.sourceStepID = sourceStepID
        self.senses = senses
        self.isRequired = isRequired
        self.minimumSelection = minimumSelection
        self.allowsCardSelection = allowsCardSelection
    }

    static func reading(id: String, title: String, body: String) -> Self {
        Self(id: id, kind: .guidedReading, title: title, body: body, isRequired: false)
    }

    static func single(
        id: String,
        title: String,
        prompt: String,
        options: [WellnessStepOption],
        required: Bool = true
    ) -> Self {
        Self(
            id: id,
            kind: .singleChoice,
            title: title,
            prompt: prompt,
            options: options,
            isRequired: required
        )
    }

    static func multiple(
        id: String,
        title: String,
        prompt: String,
        options: [WellnessStepOption],
        minimum: Int = 1,
        required: Bool = true
    ) -> Self {
        Self(
            id: id,
            kind: .multipleChoice,
            title: title,
            prompt: prompt,
            options: options,
            isRequired: required,
            minimumSelection: minimum
        )
    }

    static func timer(id: String, title: String, prompt: String, seconds: Int) -> Self {
        Self(
            id: id,
            kind: .guidedTimer,
            title: title,
            prompt: prompt,
            durationSeconds: seconds
        )
    }

    static func reflection(
        id: String,
        title: String,
        prompt: String,
        required: Bool = false
    ) -> Self {
        Self(
            id: id,
            kind: .reflection,
            title: title,
            prompt: prompt,
            isRequired: required
        )
    }

    static func rating(
        id: String,
        title: String,
        prompt: String,
        labels: [String]
    ) -> Self {
        Self(
            id: id,
            kind: .rating,
            title: title,
            prompt: prompt,
            scaleLabels: labels
        )
    }

    static func cards(
        id: String,
        title: String,
        prompt: String,
        cards: [WellnessInteractiveCardDefinition],
        allowsSelection: Bool = false,
        minimum: Int = 1
    ) -> Self {
        Self(
            id: id,
            kind: .interactiveCards,
            title: title,
            prompt: prompt,
            cards: cards,
            minimumSelection: minimum,
            allowsCardSelection: allowsSelection
        )
    }

    static func stages(
        id: String,
        title: String,
        prompt: String,
        stages: [String],
        sourceStepID: String = "",
        adaptiveStages: [String: [String]] = [:]
    ) -> Self {
        Self(
            id: id,
            kind: .stagedActivity,
            title: title,
            prompt: prompt,
            stages: stages,
            adaptiveStages: adaptiveStages,
            sourceStepID: sourceStepID
        )
    }

    static func senses(
        id: String,
        title: String,
        prompt: String,
        senses: [WellnessSensoryPrompt],
        minimum: Int = 1
    ) -> Self {
        Self(
            id: id,
            kind: .sensoryExploration,
            title: title,
            prompt: prompt,
            senses: senses,
            minimumSelection: minimum
        )
    }

    static func activityChoice(
        id: String,
        title: String,
        prompt: String,
        options: [WellnessStepOption]
    ) -> Self {
        Self(
            id: id,
            kind: .activityChoice,
            title: title,
            prompt: prompt,
            options: options
        )
    }
}

// MARK: - Saved Responses

struct WellnessStepResponse: Codable, Equatable {
    var selectedOptionIDs: [String] = []
    var text: String = ""
    var rating: Int? = nil
    var timerElapsed: TimeInterval = 0
    var timerStartedAt: Date? = nil
    var timerIsRunning: Bool = false
    var revealedCardIDs: [String] = []
    var stageIndex: Int = 0
    var sensorySelections: [String] = []
    var sensoryObservations: [String: String] = [:]
    var isFinished: Bool = false
}

// MARK: - Persisted Participation

enum WellnessChallengeParticipationStatus: String, CaseIterable {
    case active
    case paused
    case abandoned
    case completed

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .abandoned: return "Abandoned"
        case .completed: return "Completed"
        }
    }
}

@Model
final class WellnessChallengeParticipation {
    var id: UUID = UUID()
    var challengeID: String = ""
    var definitionVersion: Int = 1
    var attemptNumber: Int = 1
    var startedAt: Date = Date()
    var updatedAt: Date = Date()
    var currentExperienceIndex: Int = 0
    var completedExperienceCount: Int = 0
    var totalExperienceCount: Int = 0
    var statusRaw: String = WellnessChallengeParticipationStatus.active.rawValue
    var completionDate: Date? = nil

    var status: WellnessChallengeParticipationStatus {
        get { WellnessChallengeParticipationStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var progressFraction: Double {
        guard totalExperienceCount > 0 else { return 0 }
        return min(1, max(0, Double(completedExperienceCount) / Double(totalExperienceCount)))
    }

    init(
        challengeID: String,
        attemptNumber: Int,
        totalExperienceCount: Int,
        startedAt: Date = Date()
    ) {
        self.id = UUID()
        self.challengeID = challengeID
        self.definitionVersion = 1
        self.attemptNumber = attemptNumber
        self.startedAt = startedAt
        self.updatedAt = startedAt
        self.currentExperienceIndex = 0
        self.completedExperienceCount = 0
        self.totalExperienceCount = totalExperienceCount
        self.statusRaw = WellnessChallengeParticipationStatus.active.rawValue
        self.completionDate = nil
    }
}

@Model
final class WellnessExperienceProgress {
    var id: UUID = UUID()
    var participationID: UUID = UUID()
    var experienceID: String = ""
    var experienceIndex: Int = 0
    var currentStepIndex: Int = 0
    var responsesJSON: String = "{}"
    var isCompleted: Bool = false
    var startedAt: Date = Date()
    var updatedAt: Date = Date()
    var completionDate: Date? = nil

    var responses: [String: WellnessStepResponse] {
        get {
            guard let data = responsesJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(
                    [String: WellnessStepResponse].self,
                    from: data
                  )
            else { return [:] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let string = String(data: data, encoding: .utf8)
            else {
                responsesJSON = "{}"
                return
            }
            responsesJSON = string
        }
    }

    func response(for stepID: String) -> WellnessStepResponse {
        responses[stepID] ?? WellnessStepResponse()
    }

    func setResponse(_ response: WellnessStepResponse, for stepID: String) {
        var updated = responses
        updated[stepID] = response
        responses = updated
        updatedAt = Date()
    }

    init(
        participationID: UUID,
        experienceID: String,
        experienceIndex: Int,
        startedAt: Date = Date()
    ) {
        self.id = UUID()
        self.participationID = participationID
        self.experienceID = experienceID
        self.experienceIndex = experienceIndex
        self.currentStepIndex = 0
        self.responsesJSON = "{}"
        self.isCompleted = false
        self.startedAt = startedAt
        self.updatedAt = startedAt
        self.completionDate = nil
    }
}
