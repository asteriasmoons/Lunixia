//
//  StreakSettingsSheet.swift
//  Lunixia
//
//  Shared streak configuration UI for both Journal and Mood. Each feature passes
//  its own StreakConfiguration record; edits are committed on Save.
//

import SwiftUI
import SwiftData

struct StreakSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let config: StreakConfiguration
    let onSave: () -> Void

    @State private var selectedType: StreakType
    @State private var selectedWeekdays: Set<Int>
    @State private var timesPerWeek: Int

    private let weekdays: [(label: String, weekday: Int)] = [
        ("Sun", 1), ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7),
    ]

    init(title: String, config: StreakConfiguration, onSave: @escaping () -> Void) {
        self.title = title
        self.config = config
        self.onSave = onSave
        _selectedType = State(initialValue: config.type)
        _selectedWeekdays = State(initialValue: Set(config.normalizedScheduledWeekdays))
        _timesPerWeek = State(initialValue: config.clampedWeeklyTarget)
    }

    private var canSave: Bool {
        if selectedType == .scheduled {
            return !selectedWeekdays.isEmpty
        }
        return true
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
                    Text(title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                    Spacer()
                    Color.clear.frame(width: 22, height: 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        streakTypeSection

                        if selectedType == .scheduled {
                            scheduledSection
                        }

                        if selectedType == .frequency {
                            frequencySection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                Spacer(minLength: 0)

                saveButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: Streak type

    private var streakTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            kicker("streak type")

            HStack(spacing: 6) {
                ForEach(StreakType.allCases, id: \.self) { type in
                    let isSelected = selectedType == type
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedType = type
                        }
                    } label: {
                        Text(type.displayName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.75) : LColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                isSelected ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassSurface2),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? AnyShapeStyle(LColors.gradientBlue.opacity(0.5)) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(selectedType.shortExplanation)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Scheduled

    private var scheduledSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            kicker("scheduled days")

            HStack(spacing: 6) {
                ForEach(weekdays, id: \.weekday) { day in
                    let isSelected = selectedWeekdays.contains(day.weekday)
                    Button {
                        if isSelected {
                            selectedWeekdays.remove(day.weekday)
                        } else {
                            selectedWeekdays.insert(day.weekday)
                        }
                    } label: {
                        Text(day.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.75) : LColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                isSelected ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassSurface2),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? AnyShapeStyle(LColors.gradientBlue.opacity(0.5)) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(selectedWeekdays.isEmpty
                 ? "Select at least one day."
                 : "Only selected days count. Other days are neutral.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(selectedWeekdays.isEmpty ? LColors.gradientPurple : LColors.textSecondary.opacity(0.6))
        }
    }

    // MARK: Frequency

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            kicker("times per week")

            HStack {
                Text("Weekly Goal")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)

                Spacer()

                HStack(spacing: 12) {
                    stepperButton(asset: "chevdown", enabled: timesPerWeek > 1) {
                        if timesPerWeek > 1 { timesPerWeek -= 1 }
                    }

                    Text("\(timesPerWeek)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .frame(minWidth: 30, alignment: .center)

                    stepperButton(asset: "chevup", enabled: timesPerWeek < 7) {
                        if timesPerWeek < 7 { timesPerWeek += 1 }
                    }
                }
            }

            Text("Complete on any \(timesPerWeek) \(timesPerWeek == 1 ? "day" : "days") each week.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.6))
        }
    }

    @ViewBuilder
    private func stepperButton(asset: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(enabled ? Color.black.opacity(0.8) : LColors.textSecondary.opacity(0.3))
                .frame(width: 32, height: 32)
                .background(
                    enabled ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassSurface2),
                    in: RoundedRectangle(cornerRadius: 9)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: Save

    private var saveButton: some View {
        Button {
            config.type = selectedType
            config.scheduledWeekdays = selectedWeekdays.sorted()
            config.weeklyTarget = min(max(timesPerWeek, 1), 7)
            config.updatedAt = Date()
            onSave()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image("checkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text("Save")
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
        .disabled(!canSave)
    }

    // MARK: Helpers

    @ViewBuilder
    private func kicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(LColors.textSecondary)
            .tracking(0.5)
    }
}
