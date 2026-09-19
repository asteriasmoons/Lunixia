//
//  HealthTabView.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import HealthKit
import Combine

struct HealthTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query(sort: \VitalsEntry.timestamp, order: .reverse) private var vitalsEntries: [VitalsEntry]
    @Query(sort: \ExerciseEntry.timestamp, order: .reverse) private var exerciseEntries: [ExerciseEntry]
    @Query(sort: \WaterEntry.timestamp, order: .reverse) private var waterEntries: [WaterEntry]
    @Query(sort: \HealthMetricHistoryEntry.timestamp, order: .reverse) private var healthMetricHistoryEntries: [HealthMetricHistoryEntry]
    @Query(sort: \NapEntry.startDate, order: .reverse) private var napEntries: [NapEntry]
    @Query private var goals: [HealthGoals]

    @State private var showVitalsLog = false
    @State private var showExerciseLog = false
    @State private var showWaterLog = false
    @State private var showWaterClear = false
    @State private var showWaterHistory = false
    @State private var showStepsHistory = false
    @State private var inlineWaterAddText = ""
    @State private var inlineWaterClearText = ""
    @State private var isInlineWaterAddActive = false
    @State private var isInlineWaterClearActive = false
    @FocusState private var focusedWaterInput: WaterInlineInputField?
    @State private var showGoalSheet = false
    @State private var selectedVitals: VitalsEntry? = nil
    @State private var selectedExercise: ExerciseEntry? = nil
    @State private var showBanner = false
    @State private var bannerMessage = ""
    @State private var todaySteps: Int = 0
    @State private var healthKitWaterOz: Double = 0
    @State private var showWaterGoalCelebration = false
    @State private var displayedHealthDay = Calendar.current.startOfDay(for: Date())
    @State private var todayHRVSDNN: Double = 0
    @State private var previousNightSleepHours: Double = 0

    private enum WaterInlineInputField: Hashable {
        case add
        case clear
    }

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var currentGoals: HealthGoals {
        goals.first ?? HealthGoals()
    }

    private var localWaterOz: Double {
        let today = Calendar.current.startOfDay(for: Date())
        return waterEntries
            .filter { $0.timestamp >= today }
            .reduce(0) { $0 + $1.oz }
    }

    private var todayWaterOz: Double {
        max(localWaterOz, healthKitWaterOz)
    }

    private var waterMetricHistoryEntries: [HealthMetricHistoryEntry] {
        healthMetricHistoryEntries.filter { $0.metric == .water }
    }

    private var stepsMetricHistoryEntries: [HealthMetricHistoryEntry] {
        healthMetricHistoryEntries.filter { $0.metric == .steps }
    }

    private var hasWaterHistory: Bool {
        !waterEntries.isEmpty || !waterMetricHistoryEntries.isEmpty
    }

    private var hasStepsHistory: Bool {
        !stepsMetricHistoryEntries.isEmpty
    }

    private var todayExercises: [ExerciseEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return exerciseEntries.filter { $0.timestamp >= today }
    }

    private var todayNaps: [NapEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return napEntries.filter { $0.startDate >= today }
    }

    private var napCountToday: Int {
        todayNaps.count
    }

    private var napMinutesToday: Int {
        todayNaps.reduce(0) { $0 + $1.durationMinutes }
    }

    private var todayExerciseLogCount: Int {
        todayExercises.count
    }

    private var canCreateExerciseLog: Bool {
        LunixiaLimitsManager.canCreateExerciseLog(
            todayCount: todayExerciseLogCount,
            isPremium: isPremium
        )
    }

    private var visibleExerciseEntries: [ExerciseEntry] {
        if isPremium {
            return exerciseEntries
        }

        let cutoff = LunixiaLimitsManager.historyCutoffDate(
            days: LunixiaLimitsManager.exerciseHistoryDaysLimit(isPremium: false)
        )

        return exerciseEntries.filter { $0.timestamp >= cutoff }
    }

    private var todayVitals: VitalsEntry? {
        let today = Calendar.current.startOfDay(for: Date())
        return vitalsEntries.first { $0.timestamp >= today }
    }

    private var todayVitalsEntries: [VitalsEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return vitalsEntries.filter { $0.timestamp >= today }
    }

    private var todayVitalsEntryCount: Int {
        todayVitalsEntries.count
    }

    private var canCreateVitalsEntry: Bool {
        LunixiaLimitsManager.canCreateCompleteVitalsEntry(
            todayCount: todayVitalsEntryCount,
            isPremium: isPremium
        )
    }

    private var visibleVitalsEntries: [VitalsEntry] {
        if isPremium {
            return vitalsEntries
        }

        let cutoff = LunixiaLimitsManager.historyCutoffDate(
            days: LunixiaLimitsManager.vitalsHistoryDaysLimit(isPremium: false)
        )

        return vitalsEntries.filter { $0.timestamp >= cutoff }
    }
    
#if canImport(UIKit)
private var shouldUseFullScreenSheets: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}
#else
private var shouldUseFullScreenSheets: Bool {
    false
}
#endif

    var body: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: Nav
                    HStack {
                        Text("Health")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                        Spacer()
                        Button {
                            ensureGoalsExist()
                            showGoalSheet = true
                        } label: {
                            Image("goalsparkle")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(LGradients.header)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {

                            // MARK: Medications and Symptoms shortcuts
                            HStack(spacing: 12) {
                                NavigationLink(destination: MedicationPageView()) {
                                    medicationsEntryCard
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .frame(height: 108)

                                NavigationLink(destination: SymptomLoggerView()) {
                                    symptomLoggerEntryCard
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .frame(height: 108)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 16)
                            
                            // MARK: Body & Emotional State card
                            bodyEmotionalStateCard
                                .padding(.horizontal, 16)
                            
                            // MARK: Sleep card
                            SleepHealthCard(
                                previousNightSleepHours: previousNightSleepHours,
                                sleepGoalHours: currentGoals.sleepGoalHours,
                                napCountToday: napCountToday,
                                napMinutesToday: napMinutesToday,
                                onNapHistory: {},
                                onLogNap: {
                                    flash("Nap logged!")
                                }
                            )
                            .padding(.horizontal, 16)
                            
                            // MARK: Vitals card
                            vitalsCard
                                .padding(.horizontal, 16)
                            
                            // MARK: Exercise card
                            exerciseCard
                                .padding(.horizontal, 16)
                            
                            // MARK: Water card
                            waterCard
                                .padding(.horizontal, 16)
                            
                            // MARK: Steps card
                            stepsCard
                                .padding(.horizontal, 16)
                            
                            Spacer(minLength: 120)
                        }
                        .padding(.top, 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissInlineWaterControls()
                    }
                }
            }
            .completionBanner(isShowing: showBanner, message: bannerMessage)
            .overlay {
                if showWaterGoalCelebration {
                    WaterGoalCelebrationOverlay()
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .modifier(AdaptiveBooleanHealthSheet(isPresented: $showVitalsLog, useFullScreen: shouldUseFullScreenSheets) {
                vitalsLogSheetContent
            })
            .modifier(AdaptiveBooleanHealthSheet(isPresented: $showExerciseLog, useFullScreen: shouldUseFullScreenSheets) {
                exerciseLogSheetContent
            })
            .modifier(AdaptiveBooleanHealthSheet(isPresented: $showWaterLog, useFullScreen: shouldUseFullScreenSheets) {
                waterLogSheetContent
            })
            .modifier(AdaptiveBooleanHealthSheet(isPresented: $showWaterClear, useFullScreen: shouldUseFullScreenSheets) {
                waterClearSheetContent
            })
            .modifier(AdaptiveBooleanHealthSheet(isPresented: $showWaterHistory, useFullScreen: shouldUseFullScreenSheets) {
                waterHistorySheetContent
            })
            .modifier(AdaptiveBooleanHealthSheet(isPresented: $showStepsHistory, useFullScreen: shouldUseFullScreenSheets) {
                stepsHistorySheetContent
            })
            .modifier(AdaptiveBooleanHealthSheet(isPresented: $showGoalSheet, useFullScreen: shouldUseFullScreenSheets) {
                goalSheetContent
            })
            .modifier(AdaptiveItemHealthSheet(item: $selectedVitals, useFullScreen: shouldUseFullScreenSheets) { entry in
                vitalsDetailSheetContent(entry)
            })
            .modifier(AdaptiveItemHealthSheet(item: $selectedExercise, useFullScreen: shouldUseFullScreenSheets) { entry in
                exerciseDetailSheetContent(entry)
            })
            .task {
                refreshMedicationAutomation()
                ensureGoalsExist()
                resetDisplayedHealthTotalsIfNeeded()
                _ = await HealthKitWriteManager.shared.backfillVitals(entries: vitalsEntries)
                _ = await HealthKitWriteManager.shared.backfillExercise(entries: exerciseEntries)
                await refreshHealthKitTotals()
                await HealthKitManager.shared.startStepUpdates {
                    Task { @MainActor in
                        await refreshHealthKitTotals()
                    }
                }
                if let latest = vitalsEntries.first {
                   HealthKitManager.shared.saveVitalsWidgetSnapshot(from: latest)
                 }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                refreshMedicationAutomation()
                resetDisplayedHealthTotalsIfNeeded()
                refreshHealthKitTotalsSoon()
                if let latest = vitalsEntries.first {
                    HealthKitManager.shared.saveVitalsWidgetSnapshot(from: latest)
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                refreshMedicationAutomation()
                resetDisplayedHealthTotalsIfNeeded()
            }
        } // end NavigationStack
    }
    

    // MARK: - Body & Emotional State Card

    private var bodyEmotionalStateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                cardLabel(icon: "heartfill", text: "Body & Emotional State")

                HStack(alignment: .top, spacing: 12) {
                    stateTile(
                        title: "Body State",
                        state: bodyState.title,
                        message: bodyState.message,
                        accent: bodyStateAccent
                    )

                    stateTile(
                        title: "Emotional State",
                        state: emotionalState.title,
                        message: emotionalState.message,
                        accent: emotionalStateAccent
                    )
                }

                Text(todayHRVSDNN > 0 ? "Based on today’s HRV rhythm." : "HRV will appear after HealthKit has a reading for today.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var bodyStateAccent: Color {
        Color(lunixiaHex: "#4388C5")
    }

    private var emotionalStateAccent: Color {
        Color(lunixiaHex: "#6111b8")
    }

    private var bodyState: HealthStateInfo {
        stateInfo(
            for: todayHRVSDNN,
            labels: (
                high: "Rested",
                steady: "Steady",
                soft: "Tender",
                low: "Rest-Oriented",
                waiting: "Waiting"
            ),
            messages: (
                high: "Your body seems well-supported today.",
                steady: "Your body looks fairly balanced right now.",
                soft: "Your body may appreciate a gentler pace.",
                low: "Your body may be asking for extra care today.",
                waiting: "Waiting for today’s HRV reading."
            )
        )
    }

    private var emotionalState: HealthStateInfo {
        stateInfo(
            for: todayHRVSDNN,
            labels: (
                high: "Settled",
                steady: "Balanced",
                soft: "Sensitive",
                low: "Soothe Mode",
                waiting: "Waiting"
            ),
            messages: (
                high: "Your system seems calm and grounded.",
                steady: "Your emotional rhythm looks steady.",
                soft: "You may be feeling things a little more deeply today.",
                low: "A slower, kinder pace may feel supportive.",
                waiting: "Waiting for today’s HRV reading."
            )
        )
    }

    private func stateInfo(
        for hrv: Double,
        labels: (high: String, steady: String, soft: String, low: String, waiting: String),
        messages: (high: String, steady: String, soft: String, low: String, waiting: String)
    ) -> HealthStateInfo {
        guard hrv > 0 else {
            return HealthStateInfo(title: labels.waiting, message: messages.waiting)
        }

        switch hrv {
        case 70...:
            return HealthStateInfo(title: labels.high, message: messages.high)
        case 45..<70:
            return HealthStateInfo(title: labels.steady, message: messages.steady)
        case 25..<45:
            return HealthStateInfo(title: labels.soft, message: messages.soft)
        default:
            return HealthStateInfo(title: labels.low, message: messages.low)
        }
    }

    @ViewBuilder
    private func stateTile(title: String, state: String, message: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(state)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.22), radius: 4, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(message)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.65))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 7)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.055),
                                    accent.opacity(0.026),
                                    Color.white.opacity(0.018)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LColors.glassBorder.opacity(0.65), lineWidth: 1)
        )
    }

    // MARK: - Vitals Card

    private var vitalsCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    cardLabel(icon: "scope", text: "Vitals")
                    Spacer()
                    HStack(spacing: 10) {
                        if !visibleVitalsEntries.isEmpty {
                            Button {
                                selectedVitals = visibleVitalsEntries.first
                            } label: {
                                Image("clockfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            if canCreateVitalsEntry {
                                showVitalsLog = true
                            } else {
                                showPremiumRequiredMessage()
                            }
                        } label: {
                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(canCreateVitalsEntry ? LGradients.header : LinearGradient(colors: [LColors.textSecondary.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let v = todayVitals {
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            vitalsTile(label: "SpO2", value: v.bloodOxygen == 0 ? "--" : "\(Int(v.bloodOxygen))%")
                            vitalsTile(label: "Systolic", value: v.systolic == 0 ? "--" : "\(Int(v.systolic))")
                            vitalsTile(label: "Diastolic", value: v.diastolic == 0 ? "--" : "\(Int(v.diastolic))")
                        }

                        GridRow {
                            vitalsTile(label: "BPM", value: v.bpm == 0 ? "--" : "\(Int(v.bpm)) bpm")
                            vitalsTile(label: "Temp", value: v.bodyTemp == 0 ? "--" : String(format: "%.1f°F", v.bodyTemp))
                            vitalsTile(label: "Weight", value: v.weight == 0 ? "--" : String(format: "%.1f lbs", v.weight))
                        }
                    }
                } else {
                    emptyRow(message: "No vitals logged today")
                }
            }
        }
    }

    // MARK: - Exercise Card

    private var exerciseCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    cardLabel(icon: "dumbbell", text: "Exercise")
                    Spacer()
                    HStack(spacing: 10) {
                        if visibleExerciseEntries.count > 0 {
                            Button {
                                selectedExercise = visibleExerciseEntries.first
                            } label: {
                                Image("clockfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            if canCreateExerciseLog {
                                showExerciseLog = true
                            } else {
                                showPremiumRequiredMessage()
                            }
                        } label: {
                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(canCreateExerciseLog ? LGradients.header : LinearGradient(colors: [LColors.textSecondary.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if todayExercises.isEmpty {
                    emptyRow(message: "No exercise logged today")
                } else {
                    VStack(spacing: 8) {
                        ForEach(todayExercises.prefix(3)) { entry in
                            HStack {
                                Text(entry.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                                Spacer()
                                Text("\(entry.durationMinutes)m · \(entry.reps) reps")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LColors.glassSurface)
                            )
                        }
                        if todayExercises.count > 3 {
                            Text("+\(todayExercises.count - 3) more")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Water Card

    private var waterCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    cardLabel(icon: "bottle", text: "Water")
                    Spacer()
                    HStack(spacing: 10) {
                        if hasWaterHistory {
                            Button {
                                showWaterHistory = true
                            } label: {
                                Image("clockfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Button { showWaterLog = true } label: {
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

                // Progress bar
                let progress = min(todayWaterOz / currentGoals.dailyWaterOz, 1.0)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(format: "%.0f oz", todayWaterOz))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                        Text("/ \(Int(currentGoals.dailyWaterOz)) oz goal")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                            .padding(.top, 4)
                    }

                    DottedHorizontalProgressBar(progress: progress)
                }

                // Custom water controls
                HStack(spacing: 10) {
                    if isInlineWaterAddActive {
                        inlineWaterControl(
                            text: $inlineWaterAddText,
                            placeholder: "Add oz",
                            icon: "addwavy",
                            focus: .add,
                            action: logInlineWaterAmount
                        )
                    } else {
                        waterCustomButton(icon: "addwavy") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isInlineWaterAddActive = true
                                isInlineWaterClearActive = false
                            }
                            focusedWaterInput = .add
                        }
                    }

                    if isInlineWaterClearActive {
                        inlineWaterControl(
                            text: $inlineWaterClearText,
                            placeholder: "Clear oz",
                            icon: "minuswavy",
                            focus: .clear,
                            action: clearInlineWaterAmount
                        )
                    } else {
                        waterCustomButton(icon: "minuswavy") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isInlineWaterAddActive = false
                                isInlineWaterClearActive = true
                            }
                            focusedWaterInput = .clear
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: isInlineWaterAddActive)
                .animation(.easeInOut(duration: 0.18), value: isInlineWaterClearActive)
            }
        }
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    cardLabel(icon: "shoe", text: "Steps")
                    Spacer()
                    if hasStepsHistory {
                        Button {
                            showStepsHistory = true
                        } label: {
                            Image("clockfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                let progress = min(Double(todaySteps) / Double(currentGoals.dailySteps), 1.0)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(todaySteps)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                        Text("/ \(currentGoals.dailySteps) goal")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                            .padding(.top, 4)
                    }

                    DottedHorizontalProgressBar(progress: progress)

                    Text(stepsSubtitle(steps: todaySteps, goal: currentGoals.dailySteps))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Medications Entry Card

    private var medicationsEntryCard: some View {
        topNavigationCard(icon: "doublepills", title: "Medications")
    }

    // MARK: - Symptom Logger Entry Card

    private var symptomLoggerEntryCard: some View {
        topNavigationCard(icon: "medhouse", title: "Symptom Log")
    }

    private func topNavigationCard(icon: String, title: String) -> some View {
        GlassCard(padding: 8) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(LColors.glassSurface2)
                        .overlay(
                            Circle()
                                .strokeBorder(LColors.glassBorder.opacity(0.85), lineWidth: 1)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(LGradients.header, lineWidth: 1)
                                .opacity(0.35)
                        )

                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(LGradients.header)
                }
                .frame(width: 42, height: 42)

                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func refreshMedicationAutomation() {
        MedicationAutomationManager.run(in: modelContext)
    }

    private func dismissInlineWaterControls() {
        guard isInlineWaterAddActive || isInlineWaterClearActive || focusedWaterInput != nil else { return }

        focusedWaterInput = nil
        withAnimation(.easeInOut(duration: 0.18)) {
            isInlineWaterAddActive = false
            isInlineWaterClearActive = false
        }
    }
    
    private func vitalsDetailSheetContent(_ entry: VitalsEntry) -> some View {
        VitalsDetailView(entry: entry)
    }

    private func exerciseDetailSheetContent(_ entry: ExerciseEntry) -> some View {
        ExerciseDetailView(entry: entry)
    }
    
    private var vitalsLogSheetContent: some View {
        VitalsLogSheet(
            todayVitalsEntryCount: todayVitalsEntryCount,
            onPremiumRequired: { showPremiumRequiredMessage() },
            onSave: handleVitalsSave
        )
    }

    private func handleVitalsSave(_ entry: VitalsEntry) {
        guard canCreateVitalsEntry else {
            showPremiumRequiredMessage()
            return
        }

        modelContext.insert(entry)
        try? modelContext.save()
        writeVitalsToHealthKit(entry)
        HealthKitManager.shared.saveVitalsWidgetSnapshot(from: entry)
        _ = try? LunixiaPointsManager.awardVitalsLog(
            in: modelContext,
            id: entry.id.uuidString,
            at: entry.timestamp
        )
        flash("Vitals logged!")
    }
    
    private var exerciseLogSheetContent: some View {
        ExerciseLogSheet(
            todayExerciseLogCount: todayExerciseLogCount,
            onPremiumRequired: { showPremiumRequiredMessage() },
            onSave: handleExerciseSave
        )
    }

    private func handleExerciseSave(_ entry: ExerciseEntry) {
        modelContext.insert(entry)
        try? modelContext.save()

        let calendar = Calendar.current
        let sameDayEntries = (exerciseEntries + [entry])
            .reduce(into: [UUID: ExerciseEntry]()) { result, item in
                result[item.id] = item
            }
            .values
            .filter { calendar.isDate($0.timestamp, inSameDayAs: entry.timestamp) }

        syncExerciseDayToHealthKit(Array(sameDayEntries))

        _ = try? LunixiaPointsManager.awardExerciseLog(
            in: modelContext,
            id: entry.id.uuidString,
            at: entry.timestamp
        )
        flash("Exercise logged!")
    }
    
    private var waterLogSheetContent: some View {
        WaterLogSheet(currentGoalOz: currentGoals.dailyWaterOz) { oz in
            handleWaterLogSave(oz)
        }
    }

    private func handleWaterLogSave(_ oz: Double) {
        let previousWaterOz = todayWaterOz
        let entry = WaterEntry(oz: oz)
        modelContext.insert(entry)
        try? modelContext.save()
        writeWaterToHealthKit(oz)
        checkWaterGoalCelebration(
            previousWaterOz: previousWaterOz,
            addedWaterOz: oz
        )
        HealthHistoryManager.recordWaterCompletionIfNeeded(
            in: modelContext,
            totalOz: previousWaterOz + oz,
            goalOz: currentGoals.dailyWaterOz,
            at: entry.timestamp
        )
        refreshHealthKitTotalsSoon()
        _ = try? LunixiaPointsManager.awardWaterLog(
            in: modelContext,
            entryId: entry.id.uuidString
        )
        flash("\(Int(oz))oz logged!")
    }
    
    private var waterClearSheetContent: some View {
        WaterClearSheet(currentWaterOz: todayWaterOz) { oz in
            handleWaterClear(oz)
        }
    }

    private var waterHistorySheetContent: some View {
        WaterHistoryView()
    }

    private var stepsHistorySheetContent: some View {
        StepsHistoryView()
    }

    private func handleWaterClear(_ oz: Double) {
        let previousWaterOz = todayWaterOz
        let clearedOz = min(max(oz, 0), previousWaterOz)
        clearWaterAmount(clearedOz)
        HealthHistoryManager.recordWaterCleared(
            in: modelContext,
            amountOz: clearedOz,
            previousTotalOz: previousWaterOz,
            currentTotalOz: max(0, previousWaterOz - clearedOz),
            goalOz: currentGoals.dailyWaterOz
        )
        refreshHealthKitTotalsSoon()
        flash("\(Int(clearedOz))oz cleared!")
    }
    
    private var goalSheetContent: some View {
        GoalSheet(goals: currentGoals) {
            handleGoalSave()
        }
    }

    private func handleGoalSave() {
        ensureGoalsExist()
        try? modelContext.save()
        HealthKitManager.shared.saveHealthWidgetGoals(
            stepGoal: currentGoals.dailySteps,
            waterGoalOz: currentGoals.dailyWaterOz
        )
        flash("Goals saved!")
    }

    @ViewBuilder
    private func DottedHorizontalProgressBar(progress: Double) -> some View {
        let clampedProgress = min(max(progress, 0), 1)
        let dotCount = 34
        let activeDots = Int((clampedProgress * Double(dotCount)).rounded(.up))

        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                let isActive = index < activeDots

                Capsule(style: .continuous)
                    .fill(
                        isActive
                        ? AnyShapeStyle(LColors.accentGradient)
                        : AnyShapeStyle(LColors.glassSurface2)
                    )
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
                    .shadow(
                        color: isActive ? LColors.gradientBlue.opacity(0.28) : .clear,
                        radius: isActive ? 2 : 0
                    )
            }
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func waterCustomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)

                Text("Custom")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LColors.accentGradient)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func inlineWaterControl(
        text: Binding<String>,
        placeholder: String,
        icon: String,
        focus: WaterInlineInputField,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .focused($focusedWaterInput, equals: focus)

            Button(action: action) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(LColors.accentGradient)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LColors.glassSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(LColors.glassBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func cardLabel(icon: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(LGradients.header)
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
        }
    }

    @ViewBuilder
    private func vitalsTile(label: String, value: String) -> some View {
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
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LColors.glassSurface)
        )
    }

    @ViewBuilder
    private func emptyRow(message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(LColors.textSecondary.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private func stepsSubtitle(steps: Int, goal: Int) -> String {
        let remaining = goal - steps
        if remaining <= 0 { return "goal reached" }
        return "\(remaining) steps to go"
    }

    private func ensureGoalsExist() {
        guard goals.isEmpty else { return }
        modelContext.insert(HealthGoals())
        try? modelContext.save()
    }

    private func resetDisplayedHealthTotalsIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard displayedHealthDay != today else { return }

        displayedHealthDay = today
        todaySteps = 0
        healthKitWaterOz = 0
        todayHRVSDNN = 0
        previousNightSleepHours = 0
    }

    private func refreshHealthKitTotals() async {
        async let steps = HealthKitManager.shared.fetchStepsToday()
        async let stepSamples = HealthKitManager.shared.fetchStepSamplesToday()
        async let water = HealthKitManager.shared.fetchWaterToday()
        async let hrv = HealthKitManager.shared.fetchHRVToday()
        async let sleep = HealthKitManager.shared.fetchSleepLastNight()

        let totals = await (steps, stepSamples, water, hrv, sleep)

        await MainActor.run {
            displayedHealthDay = Calendar.current.startOfDay(for: Date())
            todaySteps = totals.0
            healthKitWaterOz = totals.2
            todayHRVSDNN = totals.3
            previousNightSleepHours = totals.4

            // Always write the correct goals into the widget snapshot
            HealthKitManager.shared.saveHealthWidgetGoals(
                stepGoal: currentGoals.dailySteps,
                waterGoalOz: currentGoals.dailyWaterOz
            )

            let dk = LunixiaPointsManager.dayKey()

            // Water goal points are awarded from refreshed totals.
            let waterGoal = currentGoals.dailyWaterOz
            let waterTotal = max(localWaterOz, totals.2)
            if waterGoal > 0 && waterTotal >= Double(waterGoal) {
                _ = try? LunixiaPointsManager.awardWaterGoal(in: modelContext, dayKey: dk)
                HealthHistoryManager.recordWaterCompletionIfNeeded(
                    in: modelContext,
                    totalOz: waterTotal,
                    goalOz: waterGoal
                )
            }

            // Step goal
            let stepGoal = currentGoals.dailySteps
            HealthHistoryManager.recordStepSamples(
                totals.1,
                in: modelContext,
                totalSteps: totals.0,
                goalSteps: stepGoal
            )
            if stepGoal > 0 && totals.0 >= stepGoal {
                _ = try? LunixiaPointsManager.awardStepGoal(in: modelContext, dayKey: dk)
            }
            _ = HealthHistoryManager.recordStepCompletionIfNeeded(
                in: modelContext,
                steps: totals.0,
                goalSteps: stepGoal
            )
        }
    }
    
    private func logInlineWaterAmount() {
        guard let oz = Double(inlineWaterAddText), oz > 0 else { return }
        let previousWaterOz = todayWaterOz
        let entry = WaterEntry(oz: oz)
        modelContext.insert(entry)
        try? modelContext.save()
        writeWaterToHealthKit(oz)
        checkWaterGoalCelebration(
            previousWaterOz: previousWaterOz,
            addedWaterOz: oz
        )
        HealthHistoryManager.recordWaterCompletionIfNeeded(
            in: modelContext,
            totalOz: previousWaterOz + oz,
            goalOz: currentGoals.dailyWaterOz,
            at: entry.timestamp
        )
        refreshHealthKitTotalsSoon()
        _ = try? LunixiaPointsManager.awardWaterLog(in: modelContext, entryId: entry.id.uuidString)
        inlineWaterAddText = ""
        withAnimation(.easeInOut(duration: 0.18)) {
            isInlineWaterAddActive = false
        }
        flash("\(Int(oz))oz logged!")
    }

    private func clearInlineWaterAmount() {
        guard let oz = Double(inlineWaterClearText), oz > 0 else { return }
        let previousWaterOz = todayWaterOz
        let clearedOz = min(max(oz, 0), previousWaterOz)
        clearWaterAmount(clearedOz)
        HealthHistoryManager.recordWaterCleared(
            in: modelContext,
            amountOz: clearedOz,
            previousTotalOz: previousWaterOz,
            currentTotalOz: max(0, previousWaterOz - clearedOz),
            goalOz: currentGoals.dailyWaterOz
        )
        refreshHealthKitTotalsSoon()
        inlineWaterClearText = ""
        withAnimation(.easeInOut(duration: 0.18)) {
            isInlineWaterClearActive = false
        }
        flash("\(Int(clearedOz))oz cleared!")
    }

    private func checkWaterGoalCelebration(previousWaterOz: Double, addedWaterOz: Double) {
        let waterGoal = currentGoals.dailyWaterOz
        guard waterGoal > 0 else { return }

        let newTotal = previousWaterOz + addedWaterOz
        let reachedGoal = previousWaterOz < Double(waterGoal) && newTotal >= Double(waterGoal)

        if reachedGoal {
            showWaterGoalCelebrationNow()
        }
    }

    private func showWaterGoalCelebrationNow() {
        withAnimation(.easeOut(duration: 0.25)) {
            showWaterGoalCelebration = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showWaterGoalCelebration = false
            }
        }
    }

    private func refreshHealthKitTotalsSoon() {
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await refreshHealthKitTotals()
        }
    }

    private func clearWaterAmount(_ oz: Double) {
        guard oz > 0 else { return }
        let today = Calendar.current.startOfDay(for: Date())
        var remaining = oz
        
        let todaysEntries = waterEntries
            .filter { $0.timestamp >= today }
            .sorted { $0.timestamp > $1.timestamp }
        
        for entry in todaysEntries where remaining > 0 {
            if entry.oz <= remaining + 0.001 {
                remaining -= entry.oz
                modelContext.delete(entry)
            } else {
                entry.oz -= remaining
                remaining = 0
            }
        }
        
        try? modelContext.save()
        deleteWaterFromHealthKit(oz)
    }

    private func deleteWaterFromHealthKit(_ oz: Double) {
        guard oz > 0,
              HKHealthStore.isHealthDataAvailable(),
              let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let store = HKHealthStore()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: waterType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, error in
            guard error == nil,
                  let quantitySamples = samples as? [HKQuantitySample] else { return }
            
            let unit = HKUnit.fluidOunceUS()
            var remaining = oz
            var samplesToDelete: [HKQuantitySample] = []
            
            for sample in quantitySamples where remaining > 0 {
                let sampleOz = sample.quantity.doubleValue(for: unit)
                samplesToDelete.append(sample)
                remaining -= sampleOz
            }
            
            guard !samplesToDelete.isEmpty else { return }
            store.delete(samplesToDelete) { success, error in
                if let error {
                    print("HealthKit water delete error: \(error)")
                } else {
                    print("HealthKit water delete success: \(success)")
                }
            }
        }
        
        store.execute(query)
    }

    private func writeVitalsToHealthKit(_ entry: VitalsEntry) {
        Task {
            await HealthKitWriteManager.shared.writeVitals(entry: entry)
        }
    }

    private func syncExerciseDayToHealthKit(_ entries: [ExerciseEntry]) {
        Task {
            _ = await HealthKitWriteManager.shared.syncExerciseDay(entries: entries)
        }
    }

    private func writeWaterToHealthKit(_ oz: Double) {
        Task {
            await HealthKitWriteManager.shared.writeWater(oz: oz)
        }
    }

    private func showPremiumRequiredMessage() {
        flash("Premium unlocks more health logs.")
    }

    private func flash(_ message: String) {
        bannerMessage = message
        withAnimation { showBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { showBanner = false }
        }
    }
}
private struct HealthStateInfo {
    let title: String
    let message: String
}

// MARK: - Water Clear Sheet

struct WaterClearSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentWaterOz: Double
    let onClear: (Double) -> Void
    
    @State private var amountText = ""
    
    private var amount: Double {
        Double(amountText) ?? 0
    }
    
    private var clampedAmount: Double {
        min(max(amount, 0), currentWaterOz)
    }
    
    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clear Water")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Remove a custom amount from today’s water total.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                            .foregroundStyle(LGradients.header)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(LColors.glassSurface2))
                    }
                    .buttonStyle(.plain)
                }
                
                GlassCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Current water")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                        
                        Text("\(Int(currentWaterOz)) oz")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                        
                        TextField("Amount to clear", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                                    .fill(LColors.glassSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
                            )
                        
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 88), spacing: 10)],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach([8.0, 16.0, 20.0, currentWaterOz], id: \.self) { oz in
                                Button {
                                    amountText = String(Int(oz))
                                } label: {
                                    Text(oz == currentWaterOz ? "Clear All" : "\(Int(oz)) oz")
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(LColors.glassSurface2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    guard clampedAmount > 0 else { return }
                    onClear(clampedAmount)
                    dismiss()
                } label: {
                    Text("Clear \(Int(clampedAmount)) oz")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LColors.accentGradient)
                        )
                }
                .buttonStyle(.plain)
                .opacity(clampedAmount > 0 ? 1 : 0.45)
                .disabled(clampedAmount <= 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Water Goal Celebration

struct WaterGoalCelebrationOverlay: View {
    @State private var animate = false

    private let confettiPieces = Array(0..<42)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.opacity(0.001)
                    .ignoresSafeArea()

                ForEach(confettiPieces, id: \.self) { index in
                    let x = CGFloat.random(in: 20...(geo.size.width - 20))
                    let delay = Double.random(in: 0...0.8)
                    let width = CGFloat.random(in: 5...10)
                    let height = CGFloat.random(in: 12...24)
                    let cornerRadius = CGFloat.random(in: 2...5)
                    let rotation = Double.random(in: -240...240)
                    let duration = Double.random(in: 1.5...2.4)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue,
                                    LColors.gradientPurple,
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: width, height: height)
                        .rotationEffect(.degrees(animate ? rotation : 0))
                        .position(
                            x: x,
                            y: animate
                                ? geo.size.height + 80
                                : -60
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeIn(duration: duration)
                            .delay(delay),
                            value: animate
                        )
                }

                VStack(spacing: 10) {
                    Text("Water Goal Reached")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)

                    Text("You hydrated like a legend today.")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(LColors.glassBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
            }
            .onAppear {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AdaptiveBooleanHealthSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let useFullScreen: Bool
    let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { isPresented && !useFullScreen },
                set: { if !$0 { isPresented = false } }
            )) {
                sheetContent()
            }
            .fullScreenCover(isPresented: Binding(
                get: { isPresented && useFullScreen },
                set: { if !$0 { isPresented = false } }
            )) {
                sheetContent()
            }
    }
}

private struct AdaptiveItemHealthSheet<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let useFullScreen: Bool
    let sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        content
            .sheet(item: Binding<Item?>(
                get: { useFullScreen ? nil : item },
                set: { item = $0 }
            )) { selectedItem in
                sheetContent(selectedItem)
            }
            .fullScreenCover(item: Binding<Item?>(
                get: { useFullScreen ? item : nil },
                set: { item = $0 }
            )) { selectedItem in
                sheetContent(selectedItem)
            }
    }
}
