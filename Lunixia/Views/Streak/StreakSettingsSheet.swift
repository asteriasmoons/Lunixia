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
    @Environment(\.appTheme) private var theme

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
            theme.palette.background
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
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
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
                ForEach(Array(StreakType.allCases.enumerated()), id: \.offset) { index, type in
                    let isSelected = selectedType == type
                    let tint = theme.palette.rotation[index % theme.palette.rotation.count]
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedType = type
                        }
                    } label: {
                        Text(type.displayName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                selectionBackground(
                                    isSelected: isSelected,
                                    tint: tint,
                                    cornerRadius: 8
                                )
                            }
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
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                    let isSelected = selectedWeekdays.contains(day.weekday)
                    let tint = theme.palette.rotation[index % theme.palette.rotation.count]
                    Button {
                        if isSelected {
                            selectedWeekdays.remove(day.weekday)
                        } else {
                            selectedWeekdays.insert(day.weekday)
                        }
                    } label: {
                        Text(day.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                selectionBackground(
                                    isSelected: isSelected,
                                    tint: tint,
                                    cornerRadius: 8
                                )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(selectedWeekdays.isEmpty
                 ? "Select at least one day."
                : "Only selected days count. Other days are neutral.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(selectedWeekdays.isEmpty ? theme.palette.secondaryAccent : theme.palette.textSecondary.opacity(0.6))
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
                .frame(width: 20, height: 20)
                .foregroundStyle(theme.palette.primaryAction)
                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                .opacity(enabled ? 1 : 0.3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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
            .background {
                BubblyCardMaterial(
                    tint: theme.palette.primaryAction,
                    cornerRadius: LSpacing.buttonRadius
                )
            }
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

    @ViewBuilder
    private func selectionBackground(
        isSelected: Bool,
        tint: Color,
        cornerRadius: CGFloat
    ) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(theme.palette.textPrimary)
                .bubblyIconMaterial(tint: tint)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(theme.palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(theme.palette.raisedSurface, lineWidth: 1)
                }
        }
    }
}
