//
//  GoalSheet.swift
//  Lunixia
//

import SwiftUI

struct GoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @Bindable var goals: HealthGoals
    let onSave: () -> Void

    @State private var waterInput: String = ""
    @State private var stepsInput: String = ""
    @State private var sleepInput: String = ""

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Set Goals")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)

                VStack(spacing: 14) {
                    goalField(label: "Daily Water Goal", unit: "oz", text: $waterInput, placeholder: "\(Int(goals.dailyWaterOz))", borderColor: theme.palette.primaryAction)
                    goalField(label: "Daily Steps Goal", unit: "steps", text: $stepsInput, placeholder: "\(goals.dailySteps)", borderColor: theme.palette.secondaryAccent)
                    goalField(label: "Sleep Goal", unit: "hours", text: $sleepInput, placeholder: String(format: "%.1f", goals.sleepGoalHours), borderColor: theme.palette.indicators)
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    if let oz = Double(waterInput), oz > 0 { goals.dailyWaterOz = oz }
                    if let steps = Int(stepsInput), steps > 0 { goals.dailySteps = steps }
                    if let sleep = Double(sleepInput), sleep > 0 { goals.sleepGoalHours = sleep }
                    onSave()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image("checkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("Save Goals")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .bubblyCardMaterial(
                        tint: theme.palette.primaryAction,
                        cornerRadius: LSpacing.buttonRadius
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    @ViewBuilder
    private func goalField(label: String, unit: String, text: Binding<String>, placeholder: String, borderColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            HStack {
                TextField(placeholder, text: text)
                    .keyboardType(unit == "hours" ? .decimalPad : .numberPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Text(unit)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LColors.glassSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                borderColor,
                                lineWidth: 1.35
                            )
                    )
            )
        }
    }
}
