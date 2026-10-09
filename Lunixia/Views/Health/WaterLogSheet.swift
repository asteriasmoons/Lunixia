//
//  WaterLogSheet.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct WaterLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var customOz: String = ""
    let currentGoalOz: Double
    let onSave: (Double) -> Void

    private var canSave: Bool { (Double(customOz) ?? 0) > 0 }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
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
                    Text("Log Water")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 22, height: 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)

                VStack(spacing: 20) {
                    // Quick amounts
                    HStack(spacing: 14) {
                        ForEach([8.0, 20.0], id: \.self) { oz in
                            Button {
                                saveWater(oz)
                            } label: {
                                VStack(spacing: 6) {
                                    Image("bottle")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .foregroundStyle(LGradients.header)
                                    Text("\(Int(oz)) oz")
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 22)
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
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    Text("or enter a custom amount")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.5))

                    // Custom input
                    HStack {
                        TextField("amount", text: $customOz)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        Text("oz")
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
                                        LinearGradient(
                                            colors: [LColors.gradientBlue, LColors.gradientPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.35
                                    )
                            )
                    )
                    .padding(.horizontal, 20)

                    Button {
                        if canSave {
                            saveWater(Double(customOz) ?? 0)
                        }
                    } label: {
                        Text("Log Custom Amount")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
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
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    private func saveWater(_ oz: Double) {
        guard oz > 0 else { return }
        
        onSave(oz)
        _ = try? LunixiaPointsManager.awardWaterLog(
            in: modelContext,
            entryId: UUID().uuidString,
            at: Date()
        )
        dismiss()
    }
}
