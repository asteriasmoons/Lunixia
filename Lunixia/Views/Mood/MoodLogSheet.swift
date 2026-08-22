//
//  MoodLogSheet.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct MoodLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: LunixiaStoreManager

    // 0 = emotions, 1 = activities, 2 = note
    @State private var page: Int = 0
    @State private var selectedEmotions: [MoodEmotion] = []
    @State private var selectedActivities: [MoodActivity] = []
    @State private var note: String = ""
    @State private var entryDate: Date = Date()

    private let hk = HealthKitManager.shared

    let todayMoodLogCount: Int
    let onPremiumRequired: () -> Void
    var onSave: () -> Void

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var isLockedByLimit: Bool {
        !LunixiaLimitsManager.canCreateMoodLog(
            todayCount: todayMoodLogCount,
            isPremium: isPremium
        )
    }

    private var pageTitle: String {
        switch page {
        case 0: return "How Are You Feeling?"
        case 1: return "What Have You Been Up To?"
        case 2: return "Anything To Add?"
        default: return ""
        }
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Header
                HStack {
                    Text(pageTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)

                    Spacer()

                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // MARK: Selected pills
                if page == 0 && !selectedEmotions.isEmpty {
                    selectedEmotionPills
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if page == 1 && !selectedActivities.isEmpty {
                    selectedActivityPills
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: Page content
                if page == 0 {
                    EmotionBubbleCanvas(selectedEmotions: $selectedEmotions)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else if page == 1 {
                    ActivityBubbleCanvas(selectedActivities: $selectedActivities)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                } else {
                    notePage
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }

                Spacer(minLength: 8)

                // MARK: Navigation buttons
                HStack(spacing: 14) {
                    if page > 0 {
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                page -= 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image("chevleft")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                Text(page == 1 ? "Emotions" : "Activities")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(LColors.textSecondary)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                    .fill(LColors.glassSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                            .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ZStack {
                        Button {
                            if page < 2 {
                                guard page == 1 || !selectedEmotions.isEmpty else { return }
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    page += 1
                                }
                            } else {
                                guard !isLockedByLimit else {
                                    onPremiumRequired()
                                    return
                                }

                                Task {
                                    await save()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(page == 0 ? "Activities" : page == 1 ? "Note" : "Save")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                if page < 2 {
                                    Image("chevright")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(.white)
                                } else {
                                    Image("checkwavy")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .frame(maxWidth: page > 0 ? .infinity : nil)
                            .background(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                    .fill(LColors.accentGradient)
                                    .shadow(color: LColors.gradientPurple.opacity(0.35), radius: 12, y: 6)
                            )
                            .opacity((page == 0 && selectedEmotions.isEmpty) || (page == 2 && isLockedByLimit) ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(page == 2 && isLockedByLimit)
                        .animation(.easeInOut(duration: 0.2), value: selectedEmotions.isEmpty)

                        if page == 2 && isLockedByLimit {
                            Button {
                                onPremiumRequired()
                            } label: {
                                LunixiaPremiumBlurOverlay(cornerRadius: LSpacing.buttonRadius)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .task {
            await hk.requestAuthorization()
            await hk.fetchAll()
        }
    }

    // MARK: Note page

    private var notePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image("writenote")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(LGradients.header)
                    Text("note")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }

                TextField("write something...", text: $note, axis: .vertical)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(6...12)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LColors.glassSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [LColors.gradientBlue, LColors.gradientPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.35
                                    )
                            )
                    )

                // Custom date & time picker — sits below the note box.
                JournalEntryDateTimePicker(date: $entryDate)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)

            Text("optional — skip if you have nothing to add")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.45))
                .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Selected emotion pills

    private var selectedEmotionPills: some View {
        FlowLayout(spacing: 6) {
            ForEach(selectedEmotions) { emotion in
                let colors = emotion.category.bubbleColors
                Text(emotion.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(lunixiaHex: colors.Color1),
                                        Color(lunixiaHex: colors.Color2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(0.85)
                    )
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }

    // MARK: Selected activity pills

    private var selectedActivityPills: some View {
        FlowLayout(spacing: 6) {
            ForEach(selectedActivities) { activity in
                HStack(spacing: 5) {
                    if activity.isCustomAsset {
                        Image(activity.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 11, height: 11)
                    } else {
                        Image(systemName: activity.icon)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(activity.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(LColors.accentGradient)
                        .opacity(0.85)
                )
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }

    // MARK: Save

    private func save() async {
        print("[MoodLogSheet] save started")

        guard !isLockedByLimit else {
            onPremiumRequired()
            return
        }

        let entry = MoodEntry(
            emotions: selectedEmotions,
            activities: selectedActivities,
            note: note,
            timestamp: entryDate
        )

        // Write HealthKit values
        entry.sleepHours = hk.sleepHours
        entry.exerciseMinutes = hk.exerciseMinutes
        entry.steps = hk.steps
        entry.meditationMinutes = hk.meditationMinutes
        entry.waterOz = hk.waterOz

        modelContext.insert(entry)
        try? modelContext.save()
        _ = try? LunixiaPointsManager.awardMoodLog(in: modelContext, id: entry.id.uuidString, at: entry.timestamp)
        onSave()
        dismiss()
    }
}
