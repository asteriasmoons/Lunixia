//
//  SleepHealthCard.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct SleepHealthCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingNapEntrySheet = false
    @State private var isShowingNapHistorySheet = false

    let previousNightSleepHours: Double
    let sleepGoalHours: Double
    let napCountToday: Int
    let napMinutesToday: Int
    let onNapHistory: () -> Void
    let onLogNap: () -> Void

    private var sleepProgress: Double {
        guard sleepGoalHours > 0 else { return 0 }
        return min(max(previousNightSleepHours / sleepGoalHours, 0), 1)
    }

    private var sleepDisplay: String {
        if previousNightSleepHours <= 0 { return "--" }
        return String(format: "%.1fh", previousNightSleepHours)
    }

    private var goalDisplay: String {
        String(format: "%.1fh goal", sleepGoalHours)
    }

    private var napDisplay: String {
        guard napMinutesToday > 0 else { return "No naps" }

        let hours = napMinutesToday / 60
        let minutes = napMinutesToday % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 9) {
                header

                HStack(alignment: .center, spacing: 6) {
                    VStack(spacing: 8) {
                        sleepInfoBox(
                            value: sleepDisplay,
                            label: "Sleep"
                        )

                        sleepInfoBox(
                            value: goalDisplay,
                            label: "Goal"
                        )
                    }
                    .frame(maxWidth: .infinity)

                    SleepDottedGradientRing(
                        progress: sleepProgress,
                        value: sleepDisplay,
                        subtitle: "Last Night"
                    )

                    VStack(spacing: 8) {
                        sleepInfoBox(
                            value: napDisplay,
                            label: "Naps"
                        )

                        sleepInfoBox(
                            value: "\(Int(sleepProgress * 100))%",
                            label: "Progress"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }

                Text(previousNightSleepHours > 0 ? sleepSubtitle : "Sleep will appear after HealthKit has sleep data.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.6))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .sheet(isPresented: $isShowingNapEntrySheet) {
            SleepNapEntrySheet { startDate, endDate, notes in
                let nap = NapEntry(
                    startDate: startDate,
                    endDate: endDate,
                    notes: notes
                )
                modelContext.insert(nap)
                try? modelContext.save()
                onLogNap()
            }
        }
        .sheet(isPresented: $isShowingNapHistorySheet) {
            SleepNapHistorySheet()
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image("moonzs")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(LGradients.header)

            Text("Sleep")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    isShowingNapHistorySheet = true
                    onNapHistory()
                } label: {
                    Image("clockfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)

                Button {
                    isShowingNapEntrySheet = true
                } label: {
                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sleepSubtitle: String {
        let remaining = sleepGoalHours - previousNightSleepHours

        if remaining <= 0 {
            return "Sleep goal reached from your previous night’s rest."
        }

        return String(format: "%.1f hours under your sleep goal.", remaining)
    }

    private func sleepInfoBox(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(value == "--" ? LColors.textSecondary.opacity(0.35) : LColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LColors.glassSurface)
        )
    }
}

private struct SleepDottedGradientRing: View {
    let progress: Double
    let value: String
    let subtitle: String

    private let dotCount = 42
    private let width: CGFloat = 104
    private let height: CGFloat = 88
    private let dotSize: CGFloat = 7.5
    private var horizontalRadius: CGFloat {
        (width / 2) - (dotSize / 2)
    }
    private var verticalRadius: CGFloat {
        (height / 2) - (dotSize / 2)
    }

    private var activeDots: Int {
        Int((min(max(progress, 0), 1) * Double(dotCount)).rounded(.up))
    }

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                let isActive = index < activeDots
                let angle = Double(index) / Double(dotCount) * 360
                let radians = angle * .pi / 180

                Circle()
                    .fill(
                        isActive
                        ? AnyShapeStyle(LGradients.header)
                        : AnyShapeStyle(LColors.glassSurface2)
                    )
                    .frame(width: dotSize, height: dotSize)
                    .shadow(
                        color: isActive ? LColors.gradientBlue.opacity(0.45) : .clear,
                        radius: isActive ? 3 : 0
                    )
                    .offset(
                        x: cos(radians) * horizontalRadius,
                        y: sin(radians) * verticalRadius
                    )
            }

            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LGradients.header)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(subtitle)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: height * 0.68)
        }
        .frame(width: width, height: height)
    }
}

private struct SleepNapEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Date, Date, String) -> Void

    @State private var startDate: Date = Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var startHour: Int = 0
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 0
    @State private var endMinute: Int = 0
    @State private var notes: String = ""

    private var durationMinutes: Int {
        max(Int(endDate.timeIntervalSince(startDate) / 60), 0)
    }

    private var durationDisplay: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            GlassCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "moon.zzz.fill")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(LGradients.header)

                                        Text("Nap Start")
                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    LunixiaGradientTimeDrumPicker(
                                        hour: $startHour,
                                        minute: $startMinute
                                    )
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sunset.fill")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(LGradients.header)

                                        Text("Nap End")
                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    LunixiaGradientTimeDrumPicker(
                                        hour: $endHour,
                                        minute: $endMinute
                                    )
                                }
                            }
                        }

                        GlassCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Duration")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)

                                Text(durationDisplay)
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(LGradients.header)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GlassCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)

                                TextField("Optional nap notes", text: $notes, axis: .vertical)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                                    .lineLimit(3...5)
                            }
                        }

                        Button {
                            guard endDate > startDate else { return }
                            onSave(startDate, endDate, notes.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image("addwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)

                                Text("Save Nap")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(LGradients.header)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(LColors.glassSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(endDate <= startDate)
                        .opacity(endDate <= startDate ? 0.45 : 1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            syncTimePickersFromDates()
        }
        .onChange(of: startHour) { updateStartDateFromPicker() }
        .onChange(of: startMinute) { updateStartDateFromPicker() }
        .onChange(of: endHour) { updateEndDateFromPicker() }
        .onChange(of: endMinute) { updateEndDateFromPicker() }
    }

    private func syncTimePickersFromDates() {
        let calendar = Calendar.current
        startHour = calendar.component(.hour, from: startDate)
        startMinute = calendar.component(.minute, from: startDate)
        endHour = calendar.component(.hour, from: endDate)
        endMinute = calendar.component(.minute, from: endDate)
    }

    private func updateStartDateFromPicker() {
        startDate = dateForToday(hour: startHour, minute: startMinute)
    }

    private func updateEndDateFromPicker() {
        endDate = dateForToday(hour: endHour, minute: endMinute)
    }

    private func dateForToday(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: today
        ) ?? Date()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("moonzs")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(LGradients.header)

            VStack(alignment: .leading, spacing: 2) {
                Text("Log Nap")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(LGradients.header)

                Text("Add a nap to your sleep history.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.7))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(LGradients.header)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SleepNapHistorySheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext

        @Query(sort: \NapEntry.startDate, order: .reverse) private var naps: [NapEntry]

        private var totalMinutes: Int {
            naps.reduce(0) { $0 + $1.durationMinutes }
        }

        private var averageMinutes: Int {
            guard !naps.isEmpty else { return 0 }
            return totalMinutes / naps.count
        }

        private var totalDisplay: String {
            durationDisplay(totalMinutes)
        }

        private var averageDisplay: String {
            durationDisplay(averageMinutes)
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    LunixiaBackground()
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                            .padding(.bottom, 12)

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 10) {
                                    historySummaryBox(value: "\(naps.count)", label: "Naps")
                                    historySummaryBox(value: totalDisplay, label: "Total")
                                    historySummaryBox(value: averageDisplay, label: "Average")
                                }

                                if naps.isEmpty {
                                    emptyState
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(naps) { nap in
                                            napRow(nap)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }

        private var header: some View {
            HStack(spacing: 10) {
                Image("clockfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(LColors.textSecondary.opacity(0.75))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nap History")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)

                    Text("Review your logged rest moments.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image("xmarkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)
            }
        }

        private func historySummaryBox(value: String, label: String) -> some View {
            GlassCard(cornerRadius: 12, padding: 8) {
                VStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(value == "0" ? LColors.textSecondary.opacity(0.35) : LColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text(label)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }

        private var emptyState: some View {
            GlassCard(padding: 18) {
                VStack(spacing: 10) {
                    Image("moonzs")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(LGradients.header)

                    Text("No naps logged yet")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)

                    Text("Logged naps will appear here with their start time, end time, duration, and notes.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }

        private func napRow(_ nap: NapEntry) -> some View {
            GlassCard(padding: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image("moonzs")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(nap.startDate, style: .time)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)

                            Text("–")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.65))

                            Text(nap.endDate, style: .time)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)

                            Spacer(minLength: 0)

                            Text(nap.durationDisplay)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(LGradients.header)
                                .lineLimit(1)
                        }

                        Text(nap.startDate, style: .date)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.62))

                        if !nap.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(nap.notes)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.78))
                                .lineLimit(3)
                        }
                    }
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    modelContext.delete(nap)
                    try? modelContext.save()
                } label: {
                    Label("Delete Nap", systemImage: "trash")
                }
            }
        }

        private func durationDisplay(_ minutes: Int) -> String {
            let safeMinutes = max(minutes, 0)
            let hours = safeMinutes / 60
            let mins = safeMinutes % 60

            if hours > 0 && mins > 0 {
                return "\(hours)h \(mins)m"
            } else if hours > 0 {
                return "\(hours)h"
            } else {
                return "\(mins)m"
            }
        }
    }
