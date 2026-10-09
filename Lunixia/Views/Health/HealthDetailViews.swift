//
//  VitalsDetailView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct VitalsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query(sort: \VitalsEntry.timestamp, order: .reverse) private var allEntries: [VitalsEntry]

    let entry: VitalsEntry
    @State private var visibleCount = 4
    private let pageSize = 4

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var allFiltered: [VitalsEntry] {
        if isPremium { return allEntries }
        let cutoff = LunixiaLimitsManager.historyCutoffDate(
            days: LunixiaLimitsManager.vitalsHistoryDaysLimit(isPremium: false)
        )
        return allEntries.filter { $0.timestamp >= cutoff }
    }

    private var visibleEntries: [VitalsEntry] {
        Array(allFiltered.prefix(visibleCount))
    }

    private var totalCount: Int { allFiltered.count }

    @Environment(\.appTheme) private var theme

    private var rotatingColors: [Color] {
        [theme.palette.primaryAction, theme.palette.secondaryAccent, theme.palette.indicators]
    }

    private var dayColorByEntryID: [PersistentIdentifier: Color] {
        let calendar = Calendar.current
        var dayOrder: [Date] = []
        var dayIndex: [Date: Int] = [:]

        for entry in allFiltered {
            let day = calendar.startOfDay(for: entry.timestamp)
            if dayIndex[day] == nil {
                dayIndex[day] = dayOrder.count
                dayOrder.append(day)
            }
        }

        return Dictionary(uniqueKeysWithValues: allFiltered.map { entry in
            let day = calendar.startOfDay(for: entry.timestamp)
            let index = dayIndex[day] ?? 0
            return (entry.persistentModelID, rotatingColors[index % rotatingColors.count])
        })
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Vitals History")
                        .font(.system(size: 22, weight: .black, design: .rounded))
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
                .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(visibleEntries) { e in
                            let tint = dayColorByEntryID[e.persistentModelID] ?? theme.palette.primaryAction
                            GlassCard(padding: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(e.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)

                                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                                        GridRow {
                                            vitalsTile(label: "SpO2", value: e.bloodOxygen == 0 ? "--" : "\(Int(e.bloodOxygen))%", tint: tint)
                                            vitalsTile(label: "Systolic", value: e.systolic == 0 ? "--" : "\(Int(e.systolic))", tint: tint)
                                            vitalsTile(label: "Diastolic", value: e.diastolic == 0 ? "--" : "\(Int(e.diastolic))", tint: tint)
                                        }

                                        GridRow {
                                            vitalsTile(label: "BPM", value: e.bpm == 0 ? "--" : "\(Int(e.bpm)) bpm", tint: tint)
                                            vitalsTile(label: "Temp", value: e.bodyTemp == 0 ? "--" : String(format: "%.1f°F", e.bodyTemp), tint: tint)
                                            vitalsTile(label: "Weight", value: e.weight == 0 ? "--" : String(format: "%.1f lbs", e.weight), tint: tint)
                                        }
                                    }
                                }
                            }
                        }

                        if totalCount > pageSize {
                            VStack(spacing: 10) {
                                if visibleCount < totalCount {
                                    Button {
                                        withAnimation { visibleCount = min(visibleCount + pageSize, totalCount) }
                                    } label: {
                                        Text("Load More")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background {
                                                BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                                                    .clipShape(Capsule())
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }

                                if visibleCount > pageSize {
                                    Button {
                                        withAnimation { visibleCount = pageSize }
                                    } label: {
                                        Text("See Less")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background(
                                                Capsule().fill(LColors.glassSurface)
                                                    .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    @ViewBuilder
    private func vitalsTile(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(value == "--" ? LColors.textSecondary.opacity(0.35) : LColors.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            GlassTile(borderColor: tint) {
                Color.clear
            }
        }
    }
}

// MARK: - Exercise Detail View

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query(sort: \ExerciseEntry.timestamp, order: .reverse) private var allEntries: [ExerciseEntry]

    let entry: ExerciseEntry
    @State private var visibleCount = 6
    private let pageSize = 6

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var allFiltered: [ExerciseEntry] {
        if isPremium { return allEntries }
        let cutoff = LunixiaLimitsManager.historyCutoffDate(
            days: LunixiaLimitsManager.exerciseHistoryDaysLimit(isPremium: false)
        )
        return allEntries.filter { $0.timestamp >= cutoff }
    }

    private var visibleEntries: [ExerciseEntry] {
        Array(allFiltered.prefix(visibleCount))
    }

    private var totalCount: Int { allFiltered.count }

    @Environment(\.appTheme) private var theme

    private var rotatingColors: [Color] {
        [theme.palette.primaryAction, theme.palette.secondaryAccent, theme.palette.indicators]
    }

    private var dayTintMap: [Date: Color] {
        let calendar = Calendar.current
        var map: [Date: Color] = [:]
        var distinctDayIndex = 0

        for entry in allFiltered {
            let day = calendar.startOfDay(for: entry.timestamp)
            if map[day] == nil {
                map[day] = rotatingColors[distinctDayIndex % rotatingColors.count]
                distinctDayIndex += 1
            }
        }
        return map
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Exercise History")
                        .font(.system(size: 22, weight: .black, design: .rounded))
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
                .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(visibleEntries) { e in
                            let day = Calendar.current.startOfDay(for: e.timestamp)
                            let tint = dayTintMap[day] ?? theme.palette.primaryAction
                            GlassCard(padding: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(e.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)

                                    HStack {
                                        Text(e.name)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)
                                        Spacer()
                                        HStack(spacing: 12) {
                                            HStack(spacing: 5) {
                                                Image(systemName: "clock.fill")
                                                    .foregroundStyle(LColors.textSecondary)
                                                    .bubblyIconMaterial(tint: LColors.textSecondary)
                                                Text("\(e.durationMinutes)m")
                                            }
                                            HStack(spacing: 5) {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .foregroundStyle(LColors.textSecondary)
                                                    .bubblyIconMaterial(tint: LColors.textSecondary)
                                                Text("\(e.reps) reps")
                                            }
                                        }
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                    }
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: LSpacing.cardRadius, style: .continuous)
                                    .strokeBorder(tint, lineWidth: 1.35)
                            }
                        }

                        if totalCount > pageSize {
                            VStack(spacing: 10) {
                                if visibleCount < totalCount {
                                    Button {
                                        withAnimation { visibleCount = min(visibleCount + pageSize, totalCount) }
                                    } label: {
                                        Text("Load More")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background {
                                                BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                                                    .clipShape(Capsule())
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }

                                if visibleCount > pageSize {
                                    Button {
                                        withAnimation { visibleCount = pageSize }
                                    } label: {
                                        Text("See Less")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background(
                                                Capsule().fill(LColors.glassSurface)
                                                    .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Water History View

struct WaterHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query(sort: \WaterEntry.timestamp, order: .reverse) private var waterEntries: [WaterEntry]
    @Query(sort: \HealthMetricHistoryEntry.timestamp, order: .reverse) private var metricEntries: [HealthMetricHistoryEntry]

    @State private var visibleCount = 4
    private let pageSize = 4

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var allFiltered: [HealthMetricHistoryRowModel] {
        let waterLogs = waterEntries.map { entry in
            HealthMetricHistoryRowModel(
                id: "water-log-\(entry.id.uuidString)",
                timestamp: entry.timestamp,
                badge: "LOGGED",
                title: "+\(Int(entry.oz)) oz",
                subtitle: "Water added to today’s total.",
                event: .logged
            )
        }

        let waterHistory = metricEntries
            .filter { $0.metric == .water }
            .compactMap { entry -> HealthMetricHistoryRowModel? in
                switch entry.event {
                case .cleared:
                    return HealthMetricHistoryRowModel(
                        id: entry.id.uuidString,
                        timestamp: entry.timestamp,
                        badge: "CLEARED",
                        title: "-\(Int(entry.amount)) oz",
                        subtitle: "\(Int(entry.previousValue)) → \(Int(entry.currentValue)) oz",
                        event: .cleared
                    )
                case .completed:
                    return HealthMetricHistoryRowModel(
                        id: entry.id.uuidString,
                        timestamp: entry.timestamp,
                        badge: "DONE",
                        title: "Water goal completed",
                        subtitle: "\(Int(entry.currentValue)) / \(Int(entry.goalValue)) oz",
                        event: .completed
                    )
                default:
                    return nil
                }
            }

        let combined = (waterLogs + waterHistory)
            .sorted { $0.timestamp > $1.timestamp }

        if isPremium {
            return combined
        }

        let cutoff = LunixiaLimitsManager.historyCutoffDate(
            days: LunixiaLimitsManager.waterHistoryDaysLimit(isPremium: false)
        )
        return combined.filter { $0.timestamp >= cutoff }
    }

    private var visibleEntries: [HealthMetricHistoryRowModel] {
        Array(allFiltered.prefix(visibleCount))
    }

    private var totalCount: Int {
        allFiltered.count
    }

    var body: some View {
        HealthMetricHistorySheetLayout(
            title: "Water History",
            entries: visibleEntries,
            totalCount: totalCount,
            visibleCount: $visibleCount,
            pageSize: pageSize,
            emptyMessage: "No water history yet",
            rotateColorsByDate: true,
            onClose: { dismiss() }
        )
    }
}

// MARK: - Steps History View

struct StepsHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query(sort: \HealthMetricHistoryEntry.timestamp, order: .reverse) private var metricEntries: [HealthMetricHistoryEntry]

    @State private var visibleCount = 4
    private let pageSize = 4

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var allFiltered: [HealthMetricHistoryRowModel] {
        let stepHistory = metricEntries
            .filter { $0.metric == .steps }
            .compactMap { entry -> HealthMetricHistoryRowModel? in
                switch entry.event {
                case .sample:
                    return HealthMetricHistoryRowModel(
                        id: entry.id.uuidString,
                        timestamp: entry.timestamp,
                        badge: "LOG",
                        title: "+\(Int(entry.amount)) steps",
                        subtitle: "\(Int(entry.previousValue)) → \(Int(entry.currentValue)) from HealthKit.",
                        event: .sample
                    )
                case .snapshot:
                    return nil
                case .completed:
                    return HealthMetricHistoryRowModel(
                        id: entry.id.uuidString,
                        timestamp: entry.timestamp,
                        badge: "DONE",
                        title: "Step goal completed",
                        subtitle: "\(Int(entry.currentValue)) / \(Int(entry.goalValue)) steps",
                        event: .completed
                    )
                default:
                    return nil
                }
            }
            .sorted { $0.timestamp > $1.timestamp }

        if isPremium {
            return stepHistory
        }

        let cutoff = LunixiaLimitsManager.historyCutoffDate(
            days: LunixiaLimitsManager.stepsHistoryDaysLimit(isPremium: false)
        )
        return stepHistory.filter { $0.timestamp >= cutoff }
    }

    private var visibleEntries: [HealthMetricHistoryRowModel] {
        Array(allFiltered.prefix(visibleCount))
    }

    private var totalCount: Int {
        allFiltered.count
    }

    var body: some View {
        HealthMetricHistorySheetLayout(
            title: "Steps History",
            entries: visibleEntries,
            totalCount: totalCount,
            visibleCount: $visibleCount,
            pageSize: pageSize,
            emptyMessage: "No step history yet",
            rotateColorsByDate: true,
            onClose: { dismiss() }
        )
    }
}

private struct HealthMetricHistorySheetLayout: View {
    let title: String
    let entries: [HealthMetricHistoryRowModel]
    let totalCount: Int
    @Binding var visibleCount: Int
    let pageSize: Int
    let emptyMessage: String
    var rotateColorsByDate: Bool = false
    let onClose: () -> Void

    @Environment(\.appTheme) private var theme

    private var rotatingColors: [Color] {
        [theme.palette.primaryAction, theme.palette.secondaryAccent, theme.palette.indicators]
    }

    private var dayTintMap: [Date: Color] {
        let calendar = Calendar.current
        var map: [Date: Color] = [:]
        var distinctDayIndex = 0
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            if map[day] == nil {
                map[day] = rotatingColors[distinctDayIndex % rotatingColors.count]
                distinctDayIndex += 1
            }
        }
        return map
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button(action: onClose) {
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
                .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        if entries.isEmpty {
                            GlassCard(padding: 18) {
                                Text(emptyMessage)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.55))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                        } else {
                            ForEach(entries) { entry in
                                let day = Calendar.current.startOfDay(for: entry.timestamp)
                                let tint = rotateColorsByDate
                                    ? (dayTintMap[day] ?? theme.palette.primaryAction)
                                    : theme.palette.primaryAction
                                HealthMetricHistoryRow(
                                    entry: entry,
                                    tint: tint,
                                    useRotatingStyle: rotateColorsByDate
                                )
                            }
                        }

                        if totalCount > pageSize {
                            VStack(spacing: 10) {
                                if visibleCount < totalCount {
                                    Button {
                                        withAnimation { visibleCount = min(visibleCount + pageSize, totalCount) }
                                    } label: {
                                        Text("Load More")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background {
                                                BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                                                    .clipShape(Capsule())
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }

                                if visibleCount > pageSize {
                                    Button {
                                        withAnimation { visibleCount = pageSize }
                                    } label: {
                                        Text("See Less")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background(
                                                Capsule().fill(LColors.glassSurface)
                                                    .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

private struct HealthMetricHistoryRow: View {
    let entry: HealthMetricHistoryRowModel
    let tint: Color
    let useRotatingStyle: Bool

    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(entry.badge)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 1.5, x: 0, y: 1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            if useRotatingStyle {
                                Capsule(style: .continuous)
                                    .fill(tint)
                                    .bubblyIconMaterial(tint: tint)
                            } else {
                                Capsule(style: .continuous)
                                    .fill(entry.badgeStyle)
                            }
                        }
                }

                Text(entry.subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.74))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay {
            if useRotatingStyle {
                RoundedRectangle(cornerRadius: LSpacing.cardRadius, style: .continuous)
                    .strokeBorder(tint, lineWidth: 1.35)
            }
        }
    }
}

private struct HealthMetricHistoryRowModel: Identifiable {
    let id: String
    let timestamp: Date
    let badge: String
    let title: String
    let subtitle: String
    let event: HealthMetricHistoryEntry.EventType

    var badgeStyle: AnyShapeStyle {
        switch event {
        case .completed:
            return AnyShapeStyle(LColors.accentGradient)
        case .cleared:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [LColors.gradientPurple, LColors.gradientBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        default:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [LColors.gradientBlue, LColors.gradientPurple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}
