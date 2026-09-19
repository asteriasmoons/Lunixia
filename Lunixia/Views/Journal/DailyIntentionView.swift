//
// DailyIntentionView.swift
//
// Created by Asteria Moon
//

import SwiftUI
import SwiftData
import Combine

struct DailyIntentionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \DailyIntention.updatedAt, order: .reverse)
    private var intentions: [DailyIntention]

    @State private var text: String = ""
    @State private var isEditing: Bool = true
    @State private var lastSyncedText: String = ""
    @State private var dayChangeChecksEnabled: Bool = false
    @State private var isGeneratingIntention: Bool = false
    @State private var generationError: String?
    @FocusState private var isTextEditorFocused: Bool

    private let dayChangeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var todayKey: String {
        DailyIntentionWriter.todayKey()
    }

    private var todayRecord: DailyIntention? {
        intentions.first(where: { $0.dateKey == todayKey })
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image("starfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)

                    Text("Daily Intention")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)

                    Spacer()

                    if isEditing {
                        Button(action: {
                            isTextEditorFocused = false
                            save()
                        }) {
                            Text("Save")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(LColors.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Type in context and get an intention or type your intention and hit save")
                                    .font(.system(size: 14))
                                    .foregroundStyle(LColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }

                            TextEditor(text: $text)
                                .focused($isTextEditorFocused)
                                .scrollContentBackground(.hidden)
                                .font(.system(size: 14))
                                .foregroundStyle(LColors.textPrimary)
                                .frame(height: 48)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(LColors.glassSurface2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                        )
                                )
                        }

                        Button {
                            Task {
                                await getGeneratedIntention()
                            }
                        } label: {
                            Text(isGeneratingIntention ? "Getting..." : "Get Intention")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(LColors.accentGradient)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeneratingIntention)
                        .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                        if let generationError {
                            Text(generationError)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(LColors.accentGradient)
                                .frame(width: 5)

                            Text(text)
                                .font(.system(size: 14))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(LColors.glassSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(LColors.glassBorder, lineWidth: 1)
                        )

                        HStack(spacing: 10) {
                            Button {
                                isEditing = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextEditorFocused = true
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Image("pencil")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 13, height: 13)

                                    Text("Edit")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(LColors.glassSurface2)
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                clear()
                            } label: {
                                HStack(spacing: 7) {
                                    Image("trash")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 13, height: 13)

                                    Text("Clear")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(LColors.accentGradient)
                                )
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isTextEditorFocused {
                    isTextEditorFocused = false
                }
            }
        }
        .onAppear {
            ensureTodayRecordExists()
            syncFromModel()

            dayChangeChecksEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dayChangeChecksEnabled = true
            }
        }
        .onReceive(dayChangeTimer) { _ in
            guard dayChangeChecksEnabled else { return }
            refreshForDayChangeIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, dayChangeChecksEnabled {
                refreshForDayChangeIfNeeded(forceReload: true)
                syncFromModel()
            }
        }
        .onChange(of: todayRecord?.text ?? "") { _, newValue in
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let current = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if normalized != current, !isEditing {
                text = normalized
            }

            lastSyncedText = normalized
            isEditing = normalized.isEmpty
        }
    }

    private func ensureTodayRecordExists() {
        do {
            _ = try DailyIntentionWriter.fetchOrCreateTodayRecord(modelContext: modelContext)
        } catch {
            print("Failed to ensure daily intention record exists: \(error)")
        }
    }

    private func syncFromModel() {
        let modelText = todayRecord?.text ?? ""
        let normalized = modelText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !isEditing || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text == lastSyncedText {
            text = normalized
        }

        lastSyncedText = normalized
        isEditing = normalized.isEmpty
        if !isEditing {
            isTextEditorFocused = false
        }
    }

    private func refreshForDayChangeIfNeeded(forceReload: Bool = false) {
        let currentKey = todayKey
        let currentRecordKey = todayRecord?.dateKey ?? ""

        guard forceReload || currentRecordKey != currentKey else { return }

        do {
            _ = try DailyIntentionWriter.fetchOrCreateTodayRecord(modelContext: modelContext)
            syncFromModel()
        } catch {
            print("Failed to refresh daily intention for day change: \(error)")
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try DailyIntentionWriter.setTodayIntention(
                trimmed,
                modelContext: modelContext
            )

            text = trimmed
            lastSyncedText = trimmed
            isEditing = false
            isTextEditorFocused = false
        } catch {
            print("Failed to save daily intention: \(error)")
        }
    }

    @MainActor
    private func getGeneratedIntention() async {
        let context = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.isEmpty, !isGeneratingIntention else { return }

        isGeneratingIntention = true
        generationError = nil
        isTextEditorFocused = false

        do {
            let response = try await DailyIntentionAIService.shared.generateIntention(context: context)
            text = response.intention
        } catch {
            generationError = error.localizedDescription
        }

        isGeneratingIntention = false
    }

    private func clear() {
        do {
            try DailyIntentionWriter.clearTodayIntention(modelContext: modelContext)
            text = ""
            lastSyncedText = ""
            generationError = nil
            isEditing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextEditorFocused = true
            }
        } catch {
            print("Failed to clear daily intention: \(error)")
        }
    }
}

#Preview {
    ZStack {
        LunixiaBackground()
        DailyIntentionView()
            .padding()
    }
    .preferredColorScheme(.dark)
}
