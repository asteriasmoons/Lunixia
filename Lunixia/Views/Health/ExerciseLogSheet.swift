//
//  ExerciseLogSheet.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct ExerciseLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: LunixiaStoreManager

    @State private var name: String = ""
    @State private var duration: String = ""
    @State private var reps: String = ""

    let todayExerciseLogCount: Int
    let onPremiumRequired: () -> Void
    let onSave: (ExerciseEntry) -> Void

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var isLockedByLimit: Bool {
        !LunixiaLimitsManager.canCreateExerciseLog(
            todayCount: todayExerciseLogCount,
            isPremium: isPremium
        )
    }

    private var canSave: Bool {
        !isLockedByLimit &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(duration) ?? 0) > 0
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("Log Exercise")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                    Spacer()
                    Color.clear.frame(width: 22, height: 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                VStack(spacing: 14) {
                    exerciseField(label: "Exercise Name", placeholder: "e.g. Bench Press", text: $name, keyboardType: .default)
                    exerciseField(label: "Duration (minutes)", placeholder: "e.g. 30", text: $duration, keyboardType: .numberPad)
                    exerciseField(label: "Reps", placeholder: "e.g. 12", text: $reps, keyboardType: .numberPad)
                }
                .padding(.horizontal, 20)

                Spacer()

                ZStack {
                    Button {
                        if canSave { save() }
                    } label: {
                        HStack(spacing: 8) {
                            Image("checkwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text("Save Exercise")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                .fill(LColors.accentGradient)
                                .shadow(color: LColors.gradientPurple.opacity(0.35), radius: 12, y: 6)
                        )
                        .opacity(canSave ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLockedByLimit)

                    if isLockedByLimit {
                        Button {
                            onPremiumRequired()
                        } label: {
                            LunixiaPremiumBlurOverlay(cornerRadius: LSpacing.buttonRadius)
                                .frame(height: 56)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    @ViewBuilder
    private func exerciseField(label: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LColors.glassSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
        }
    }

    private func save() {
        guard canSave else {
            if isLockedByLimit {
                onPremiumRequired()
            }
            return
        }

        let entry = ExerciseEntry(
            name: name.trimmingCharacters(in: .whitespaces),
            durationMinutes: Int(duration) ?? 0,
            reps: Int(reps) ?? 0
        )
        onSave(entry)
        _ = try? LunixiaPointsManager.awardExerciseLog(
            in: modelContext,
            id: entry.id.uuidString,
            at: entry.timestamp
        )
        dismiss()
    }
}
