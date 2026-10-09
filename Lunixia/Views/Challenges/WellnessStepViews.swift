//
//  WellnessStepViews.swift
//  Lunixia
//

import SwiftUI
import Combine

struct WellnessStepRenderer: View {
    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse
    let allResponses: [String: WellnessStepResponse]

    var body: some View {
        switch step.kind {
        case .guidedReading:
            WellnessGuidedReadingStep(step: step)
        case .singleChoice:
            WellnessChoiceStep(step: step, response: $response, allowsMultiple: false)
        case .multipleChoice:
            WellnessChoiceStep(step: step, response: $response, allowsMultiple: true)
        case .guidedTimer:
            WellnessGuidedTimerStep(step: step, response: $response)
        case .reflection:
            WellnessReflectionStep(step: step, response: $response)
        case .rating:
            WellnessRatingStep(step: step, response: $response)
        case .interactiveCards:
            WellnessInteractiveCardsStep(step: step, response: $response)
        case .stagedActivity:
            WellnessStagedActivityStep(
                step: step,
                response: $response,
                allResponses: allResponses
            )
        case .sensoryExploration:
            WellnessSensoryExplorationStep(step: step, response: $response)
        case .activityChoice:
            WellnessActivityChoiceStep(step: step, response: $response)
        }
    }
}

private struct WellnessGuidedReadingStep: View {
    @Environment(\.appTheme) private var theme
    let step: WellnessStepDefinition

    var body: some View {
        WellnessSurface(borderColor: theme.palette.primaryAction) {
            VStack(alignment: .leading, spacing: 16) {
                WellnessTintedIcon(
                    name: "openbook",
                    tint: theme.palette.primaryAction,
                    size: 30,
                    containerSize: 40
                )

                Text(step.title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(theme.palette.textPrimary)

                Text(step.body)
                    .font(.body)
                    .foregroundStyle(theme.palette.textSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WellnessChoiceStep: View {
    @Environment(\.appTheme) private var theme

    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse
    let allowsMultiple: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepPrompt

            ForEach(Array(step.options.enumerated()), id: \.element.id) { index, option in
                let isSelected = response.selectedOptionIDs.contains(option.id)
                let tint = theme.palette.rotation[index % theme.palette.rotation.count]

                Button {
                    toggle(option.id)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        WellnessTintedIcon(name: option.icon, tint: tint, size: 21, containerSize: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .font(.headline)
                                .foregroundStyle(theme.palette.textPrimary)
                            Text(option.detail)
                                .font(.subheadline)
                                .foregroundStyle(theme.palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(isSelected ? "checkwavy" : "circlefingerprint")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .bubblyIconMaterial(tint: isSelected ? tint : theme.palette.textSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(isSelected ? theme.palette.raisedSurface : theme.palette.surface)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(isSelected ? tint : theme.palette.raisedSurface, lineWidth: isSelected ? 1.25 : 0.75)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityHint(option.detail)
            }
        }
    }

    private var stepPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(theme.palette.textPrimary)
            Text(step.prompt)
                .font(.body)
                .foregroundStyle(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if allowsMultiple {
                Text("Select all that apply")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.palette.indicators)
            }
        }
    }

    private func toggle(_ optionID: String) {
        if allowsMultiple {
            if response.selectedOptionIDs.contains(optionID) {
                response.selectedOptionIDs.removeAll { $0 == optionID }
            } else {
                response.selectedOptionIDs.append(optionID)
            }
        } else {
            response.selectedOptionIDs = [optionID]
        }
    }
}

private struct WellnessActivityChoiceStep: View {
    @Environment(\.appTheme) private var theme

    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(theme.palette.textPrimary)
            Text(step.prompt)
                .font(.body)
                .foregroundStyle(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(Array(step.options.enumerated()), id: \.element.id) { index, option in
                    let isSelected = response.selectedOptionIDs.contains(option.id)
                    let tint = theme.palette.rotation[index % theme.palette.rotation.count]

                    Button {
                        response.selectedOptionIDs = [option.id]
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                WellnessTintedIcon(name: option.icon, tint: tint, size: 25)
                                Spacer()
                                if isSelected {
                                    WellnessTintedIcon(name: "checkwavy", tint: tint, size: 18)
                                }
                            }

                            Text(option.title)
                                .font(.headline)
                                .foregroundStyle(theme.palette.textPrimary)
                            Text(option.detail)
                                .font(.subheadline)
                                .foregroundStyle(theme.palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 134, alignment: .topLeading)
                        .padding(15)
                        .background {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(isSelected ? theme.palette.raisedSurface : theme.palette.surface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(isSelected ? tint : theme.palette.raisedSurface, lineWidth: isSelected ? 1.25 : 0.75)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .accessibilityHint(option.detail)
                }
            }
        }
    }
}

private struct WellnessGuidedTimerStep: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse

    @State private var now = Date()
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval {
        let runningTime: TimeInterval
        if response.timerIsRunning, let startedAt = response.timerStartedAt {
            runningTime = max(0, now.timeIntervalSince(startedAt))
        } else {
            runningTime = 0
        }
        return min(TimeInterval(step.durationSeconds), response.timerElapsed + runningTime)
    }

    private var remaining: TimeInterval {
        max(0, TimeInterval(step.durationSeconds) - elapsed)
    }

    private var timeText: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 7) {
                Text(step.title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(theme.palette.textPrimary)
                Text(step.prompt)
                    .font(.body)
                    .foregroundStyle(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack {
                Circle()
                    .stroke(theme.palette.raisedSurface, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(
                        theme.palette.indicators,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(timeText)
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(theme.palette.textPrimary)
                        .monospacedDigit()
                    Text(response.isFinished ? "Finished" : timerStateText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.palette.textSecondary)
                }
            }
            .frame(width: 210, height: 210)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Guided timer")
            .accessibilityValue("\(timeText) remaining, \(timerStateText)")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { timerButtons }
                VStack(spacing: 10) { timerButtons }
            }
        }
        .frame(maxWidth: .infinity)
        .onReceive(ticker) { date in
            now = date
            completeIfNeeded()
        }
        .onChange(of: scenePhase) { _, _ in
            now = Date()
            completeIfNeeded()
        }
    }

    @ViewBuilder
    private var timerButtons: some View {
        Button(response.timerIsRunning ? "Pause" : (elapsed > 0 ? "Resume" : "Start")) {
            response.timerIsRunning ? pause() : start()
        }
        .buttonStyle(WellnessTimerButtonStyle(tint: theme.palette.primaryAction))
        .disabled(response.isFinished)

        Button("Restart") {
            var updated = response
            updated.timerElapsed = 0
            updated.timerStartedAt = nil
            updated.timerIsRunning = false
            updated.isFinished = false
            response = updated
            now = Date()
        }
        .buttonStyle(WellnessTimerButtonStyle(tint: theme.palette.secondaryAccent))

        Button("Finish") {
            finish()
        }
        .buttonStyle(WellnessTimerButtonStyle(tint: theme.palette.indicators))
        .disabled(response.isFinished)
    }

    private var timerStateText: String {
        if response.timerIsRunning { return "In progress" }
        if elapsed > 0 { return "Paused" }
        return "Ready"
    }

    private var progressFraction: Double {
        guard step.durationSeconds > 0 else { return 0 }
        return min(1, max(0, elapsed / TimeInterval(step.durationSeconds)))
    }

    private func start() {
        guard !response.isFinished else { return }
        var updated = response
        updated.timerStartedAt = Date()
        updated.timerIsRunning = true
        response = updated
        now = Date()
    }

    private func pause() {
        var updated = response
        updated.timerElapsed = elapsed
        updated.timerStartedAt = nil
        updated.timerIsRunning = false
        response = updated
        now = Date()
    }

    private func finish() {
        var updated = response
        updated.timerElapsed = TimeInterval(step.durationSeconds)
        updated.timerStartedAt = nil
        updated.timerIsRunning = false
        updated.isFinished = true
        response = updated
        now = Date()
    }

    private func completeIfNeeded() {
        guard response.timerIsRunning,
              elapsed >= TimeInterval(step.durationSeconds)
        else { return }
        var updated = response
        updated.timerElapsed = TimeInterval(step.durationSeconds)
        updated.timerStartedAt = nil
        updated.timerIsRunning = false
        updated.isFinished = true
        response = updated
    }
}

private struct WellnessTimerButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.7 : 1))
            }
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct WellnessReflectionStep: View {
    @Environment(\.appTheme) private var theme

    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(step.title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(theme.palette.textPrimary)

            Text(step.prompt)
                .font(.body)
                .foregroundStyle(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $response.text)
                .font(.body)
                .foregroundStyle(theme.palette.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 190)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.palette.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.palette.primaryAction, lineWidth: 1)
                }
                .accessibilityLabel(step.title)

            if !step.isRequired {
                Text("Optional. You can continue without writing.")
                    .font(.caption)
                    .foregroundStyle(theme.palette.textSecondary)
            }
        }
    }
}

private struct WellnessRatingStep: View {
    @Environment(\.appTheme) private var theme

    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(theme.palette.textPrimary)
            Text(step.prompt)
                .font(.body)
                .foregroundStyle(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 9) {
                ForEach(Array(step.scaleLabels.enumerated()), id: \.offset) { index, label in
                    let value = index + 1
                    let isSelected = response.rating == value

                    Button {
                        response.rating = value
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(value)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 26)
                            Text(label)
                                .font(.body.weight(.semibold))
                            Spacer()
                            if isSelected {
                                WellnessTintedIcon(name: "checkwavy", tint: theme.palette.indicators, size: 18)
                            }
                        }
                        .foregroundStyle(theme.palette.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? theme.palette.raisedSurface : theme.palette.surface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    isSelected ? theme.palette.indicators : theme.palette.raisedSurface,
                                    lineWidth: isSelected ? 1.25 : 0.75
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value), \(label)")
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                }
            }
        }
    }
}

private struct WellnessInteractiveCardsStep: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(theme.palette.textPrimary)
            Text(step.prompt)
                .font(.body)
                .foregroundStyle(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(step.cards.enumerated()), id: \.element.id) { index, card in
                    cardView(card, index: index)
                }
            }
        }
    }

    private func cardView(_ card: WellnessInteractiveCardDefinition, index: Int) -> some View {
        let isRevealed = response.revealedCardIDs.contains(card.id)
        let isSelected = response.selectedOptionIDs.contains(card.id)
        let tint = theme.palette.rotation[index % theme.palette.rotation.count]

        return VStack(spacing: 0) {
            Button {
                guard !isRevealed else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    response.revealedCardIDs.append(card.id)
                }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        WellnessTintedIcon(name: card.icon, tint: tint, size: 24)
                        Spacer()
                        Text(isRevealed ? card.title : "Reveal")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)
                    }

                    Text(isRevealed ? card.back : card.front)
                        .font(isRevealed ? .body : .headline)
                        .foregroundStyle(theme.palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
                .padding(15)
                .background {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(theme.palette.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(isSelected ? tint : theme.palette.raisedSurface, lineWidth: isSelected ? 1.25 : 0.75)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? card.title : "Reveal \(card.title)")

            if isRevealed && step.allowsCardSelection {
                Button {
                    response.selectedOptionIDs = [card.id]
                } label: {
                    HStack(spacing: 6) {
                        WellnessTintedIcon(name: isSelected ? "checkwavy" : "tapicon", tint: tint, size: 15)
                        Text(isSelected ? "Selected" : "Choose this")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.palette.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
            }
        }
    }
}

private struct WellnessStagedActivityStep: View {
    @Environment(\.appTheme) private var theme

    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse
    let allResponses: [String: WellnessStepResponse]

    private var activeStages: [String] {
        guard !step.sourceStepID.isEmpty,
              let selectedID = allResponses[step.sourceStepID]?.selectedOptionIDs.first,
              let adapted = step.adaptiveStages[selectedID],
              !adapted.isEmpty
        else { return step.stages }
        return adapted
    }

    private var safeIndex: Int {
        min(max(0, response.stageIndex), max(0, activeStages.count - 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(theme.palette.textPrimary)
            Text(step.prompt)
                .font(.body)
                .foregroundStyle(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            WellnessProgressBar(
                value: activeStages.isEmpty ? 0 : Double(safeIndex + 1) / Double(activeStages.count),
                tint: theme.palette.indicators,
                height: 7
            )

            if !activeStages.isEmpty {
                WellnessSurface(borderColor: theme.palette.indicators) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stage \(safeIndex + 1) of \(activeStages.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.palette.indicators)
                        Text(activeStages[safeIndex])
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.palette.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                }
            }

            HStack(spacing: 10) {
                Button("Previous") {
                    response.stageIndex = max(0, safeIndex - 1)
                    response.isFinished = false
                }
                .buttonStyle(WellnessTimerButtonStyle(tint: theme.palette.secondaryAccent))
                .disabled(safeIndex == 0)

                Button(safeIndex >= activeStages.count - 1 ? "Finish Activity" : "Next Stage") {
                    if safeIndex >= activeStages.count - 1 {
                        response.isFinished = true
                    } else {
                        response.stageIndex = safeIndex + 1
                    }
                }
                .buttonStyle(WellnessTimerButtonStyle(tint: theme.palette.primaryAction))
            }

            if response.isFinished {
                HStack(spacing: 7) {
                    WellnessTintedIcon(name: "checkwavy", tint: theme.palette.indicators, size: 17)
                    Text("Activity complete. Continue when you are ready.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.palette.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct WellnessSensoryExplorationStep: View {
    @Environment(\.appTheme) private var theme

    let step: WellnessStepDefinition
    @Binding var response: WellnessStepResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(theme.palette.textPrimary)
            Text(step.prompt)
                .font(.body)
                .foregroundStyle(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(step.senses.enumerated()), id: \.element.id) { index, sense in
                let isSelected = response.sensorySelections.contains(sense.id)
                let tint = theme.palette.rotation[index % theme.palette.rotation.count]

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        toggle(sense.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            WellnessTintedIcon(name: sense.icon, tint: tint, size: 22, containerSize: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sense.title)
                                    .font(.headline)
                                    .foregroundStyle(theme.palette.textPrimary)
                                Text(sense.prompt)
                                    .font(.subheadline)
                                    .foregroundStyle(theme.palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            WellnessTintedIcon(
                                name: isSelected ? "checkwavy" : "circlefingerprint",
                                tint: isSelected ? tint : theme.palette.textSecondary,
                                size: 19
                            )
                        }
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")

                    if isSelected {
                        TextField(
                            "Optional observation",
                            text: observationBinding(for: sense.id),
                            axis: .vertical
                        )
                        .font(.body)
                        .foregroundStyle(theme.palette.textPrimary)
                        .lineLimit(2...4)
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.palette.raisedSurface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(tint, lineWidth: 1)
                        }
                    }
                }
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.palette.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? tint : theme.palette.raisedSurface, lineWidth: isSelected ? 1.25 : 0.75)
                }
            }
        }
    }

    private func toggle(_ senseID: String) {
        if response.sensorySelections.contains(senseID) {
            response.sensorySelections.removeAll { $0 == senseID }
        } else {
            response.sensorySelections.append(senseID)
        }
    }

    private func observationBinding(for senseID: String) -> Binding<String> {
        Binding(
            get: { response.sensoryObservations[senseID] ?? "" },
            set: { response.sensoryObservations[senseID] = $0 }
        )
    }
}

extension WellnessStepDefinition {
    func canAdvance(with response: WellnessStepResponse) -> Bool {
        switch kind {
        case .guidedReading:
            return true
        case .singleChoice, .activityChoice:
            return !isRequired || !response.selectedOptionIDs.isEmpty
        case .multipleChoice:
            return !isRequired || response.selectedOptionIDs.count >= minimumSelection
        case .guidedTimer:
            return response.isFinished
        case .reflection:
            return !isRequired || !response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .rating:
            return response.rating != nil
        case .interactiveCards:
            if allowsCardSelection {
                return response.revealedCardIDs.count >= 1 && response.selectedOptionIDs.count >= minimumSelection
            }
            return response.revealedCardIDs.count >= minimumSelection
        case .stagedActivity:
            return response.isFinished
        case .sensoryExploration:
            return response.sensorySelections.count >= minimumSelection
        }
    }
}
