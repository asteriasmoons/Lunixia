//
//  MoodTabView.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import WidgetKit

struct MoodTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var entries: [MoodEntry]
    @Query private var streakConfigs: [StreakConfiguration]

    @State private var showLogSheet = false
    @State private var selectedTab: Int = 0
    @State private var selectedEntry: MoodEntry? = nil
    @State private var showBanner = false
    @State private var visibleHistoryCount = 4
    
    @State private var showPremiumBanner = false
    @State private var premiumBannerMessage = ""
    @State private var editingStreakConfig: StreakConfiguration? = nil
    
#if canImport(UIKit)
private var shouldUseFullScreenSheets: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}
#else
private var shouldUseFullScreenSheets: Bool {
    false
}
#endif

    private var isPremium: Bool {
        storeManager.isPremium
    }

    // MARK: Computed

    private var todayEntry: MoodEntry? {
        entries.first(where: { Calendar.current.isDateInToday($0.timestamp) })
    }
    
    private var todayMoodLogCount: Int {
        entries.filter { Calendar.current.isDateInToday($0.timestamp) }.count
    }

    private var canCreateMoodLog: Bool {
        LunixiaLimitsManager.canCreateMoodLog(
            todayCount: todayMoodLogCount,
            isPremium: isPremium
        )
    }

    private var visibleHistoryEntries: [MoodEntry] {
        if isPremium { return entries }

        let cutoff = LunixiaLimitsManager.historyCutoffDate(
            days: LunixiaLimitsManager.moodHistoryDaysLimit(isPremium: false)
        )

        return entries.filter { $0.timestamp >= cutoff }
    }

    private var moodStreakConfig: StreakConfiguration {
        streakConfigs.first(where: { $0.featureRawValue == StreakFeature.mood.rawValue })
            ?? StreakConfiguration(feature: .mood)
    }

    private var moodStreakUnitLabel: String {
        moodStreakConfig.type == .frequency ? "Week Streak" : "Day Streak"
    }

    private var streak: Int {
        StreakCalculator.currentStreak(
            type: moodStreakConfig.type,
            completionDates: entries.map { $0.timestamp },
            scheduledWeekdays: moodStreakConfig.normalizedScheduledWeekdays,
            weeklyTarget: moodStreakConfig.clampedWeeklyTarget
        )
    }

    private var completedMoodGoalMarkersThisWeek: Int {
        min(
            moodStreakConfig.weeklyGoalMarkerCount,
            StreakCalculator.currentWeekCompletionCount(
                type: moodStreakConfig.type,
                completionDates: entries.map { $0.timestamp },
                scheduledWeekdays: moodStreakConfig.normalizedScheduledWeekdays
            )
        )
    }

    private var uniqueEmotionCount: Int {
        Set(entries.flatMap { $0.emotionNames }).count
    }

    // MARK: Stats — Wellness Momentum

    private static let wellnessActivities: Set<String> = [
        "self-care", "meditation", "mindfulness", "therapy", "fitness",
        "exercise", "yoga", "swimming", "health", "hygiene", "medication",
        "sleep", "rest", "healing"
    ]

    private static let socialActivities: Set<String> = [
        "friends", "family", "dating", "community", "calls", "texting", "party"
    ]

    private static let enrichmentActivities: Set<String> = [
        "reading", "art", "music", "writing", "journaling", "hobby",
        "education", "creative", "spirituality", "religion", "mindfulness"
    ]

    private func momentumScore(for entry: MoodEntry) -> Int {
        let emotions = entry.resolvedEmotions
        let supportiveEmotionScore = emotions.reduce(0) { acc, emotion in
            switch emotion.category {
            case .positive: return acc + 2
            case .neutral:  return acc + 1
            case .negative: return acc
            }
        }
        let negativeEmotionPenalty = emotions.reduce(0) { acc, emotion in
            emotion.category == .negative ? acc + 2 : acc
        }
        let activityScore = entry.activityNames.reduce(0) { acc, name in
            let normalizedName = name.lowercased()
            if Self.wellnessActivities.contains(normalizedName)    { return acc + 2 }
            if Self.socialActivities.contains(normalizedName)      { return acc + 1 }
            if Self.enrichmentActivities.contains(normalizedName)  { return acc + 1 }
            return acc
        }
        let cappedSupportiveScore = min(supportiveEmotionScore + activityScore, 20)
        return max(cappedSupportiveScore - negativeEmotionPenalty, 0)
    }

    private var sevenDayEntries: [MoodEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return entries.filter { $0.timestamp >= cutoff }
    }

    /// 0–100 normalized score over the last 7 days. Supportive points are capped
    /// at 20 per entry before negative-emotion penalties are applied.
    private var sevenDayMomentum: Int {
        guard !sevenDayEntries.isEmpty else { return 0 }
        let maxPerEntry = 20
        let total = sevenDayEntries.reduce(0) { $0 + momentumScore(for: $1) }
        let maxPossible = sevenDayEntries.count * maxPerEntry
        return Int((Double(total) / Double(maxPossible)) * 100)
    }

    private var momentumLabel: String {
        guard !sevenDayEntries.isEmpty else { return "Nothing logged yet" }
        switch sevenDayMomentum {
        case 0..<25:  return "Low energy"
        case 25..<50: return "Building up"
        case 50..<70: return "Steady flow"
        case 70..<90: return "Strong momentum"
        default:      return "Thriving"
        }
    }

    // Emotion breakdown for last 7 days
    private var sevenDayEmotionBreakdown: (positive: Int, neutral: Int, negative: Int) {
        let emotions = sevenDayEntries.flatMap { $0.resolvedEmotions }
        guard !emotions.isEmpty else { return (0, 0, 0) }
        let total = emotions.count
        let pos = emotions.filter { $0.category == .positive }.count
        let neu = emotions.filter { $0.category == .neutral }.count
        let neg = emotions.filter { $0.category == .negative }.count
        // Return as percentages
        return (
            Int(Double(pos) / Double(total) * 100),
            Int(Double(neu) / Double(total) * 100),
            Int(Double(neg) / Double(total) * 100)
        )
    }

    private var topEmotion: String? {
        let names = sevenDayEntries.flatMap { $0.emotionNames }
        guard !names.isEmpty else { return nil }

        let counts = names.reduce(into: [String: Int]()) { result, name in
            result[name.lowercased(), default: 0] += 1
        }

        guard let maxCount = counts.values.max() else { return nil }
        guard let topName = counts.filter({ $0.value == maxCount }).keys.sorted().first else { return nil }

        return MoodEmotion.all.first {
            $0.name.caseInsensitiveCompare(topName) == .orderedSame
        }?.name ?? topName.capitalized
    }

    private var topActivity: String? {
        let names = sevenDayEntries.flatMap { $0.activityNames }
        guard !names.isEmpty else { return nil }

        let counts = names.reduce(into: [String: Int]()) { result, name in
            result[name.lowercased(), default: 0] += 1
        }

        guard let maxCount = counts.values.max() else { return nil }
        guard let topName = counts.filter({ $0.value == maxCount }).keys.sorted().first else { return nil }

        return MoodActivity.all.first {
            $0.name.caseInsensitiveCompare(topName) == .orderedSame
        }?.name ?? topName.capitalized
    }
    
    private func showPremiumRequiredMessage() {
        premiumBannerMessage = "Premium unlocks more mood logs."
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showPremiumBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                showPremiumBanner = false
            }
        }
    }

    var body: some View {
        ZStack {
            theme.palette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Nav bar
                HStack {
                    Text("Mood")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button {
                        editingStreakConfig = StreakConfiguration.fetchOrCreate(.mood, in: modelContext)
                    } label: {
                        Image("settingswavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(theme.palette.secondaryAccent)
                            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 14)
                    Button {
                        if canCreateMoodLog {
                            showLogSheet = true
                        } else {
                            showPremiumRequiredMessage()
                        }
                    } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(canCreateMoodLog ? theme.palette.primaryAction : theme.palette.textSecondary.opacity(0.45))
                            .bubblyIconMaterial(
                                tint: canCreateMoodLog
                                    ? theme.palette.primaryAction
                                    : theme.palette.textSecondary.opacity(0.45)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        statsCard
                            .padding(.horizontal, 16)

                        breakdownCard
                            .padding(.horizontal, 16)

                        tabPicker
                            .padding(.horizontal, 16)

                        if selectedTab == 0 {
                            todayContent
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                        } else {
                            historyContent
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 4)
                }
            }

            if showPremiumBanner {
                VStack {
                    Text(premiumBannerMessage)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(theme.palette.primaryAction)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                        .padding(.top, 18)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .completionBanner(isShowing: showBanner, message: "Mood logged!")
        .fullScreenCover(isPresented: $showLogSheet) {
            MoodLogSheet(
                todayMoodLogCount: todayMoodLogCount,
                onPremiumRequired: {
                    showPremiumRequiredMessage()
                },
                onSave: {
                    refreshMoodWidgetSoon()
                    withAnimation { showBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation { showBanner = false }
                    }
                }
            )
        }
        .sheet(item: Binding(
            get: { shouldUseFullScreenSheets ? nil : selectedEntry },
            set: { selectedEntry = $0 }
        )) { entry in
            MoodDetailView(entry: entry)
        }
        .fullScreenCover(item: Binding(
            get: { shouldUseFullScreenSheets ? selectedEntry : nil },
            set: { selectedEntry = $0 }
        )) { entry in
            MoodDetailView(entry: entry)
        }
        .onChange(of: entries) { _, newEntries in
            LunixiaMoodWidgetWriter.write(allEntries: newEntries, streakConfig: moodStreakConfig)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                LunixiaMoodWidgetWriter.write(allEntries: entries, streakConfig: moodStreakConfig)
            }
        }
        .onAppear {
            StreakConfiguration.fetchOrCreate(.mood, in: modelContext)
        }
        .sheet(item: Binding(
            get: { shouldUseFullScreenSheets ? nil : editingStreakConfig },
            set: { editingStreakConfig = $0 }
        )) { config in
            StreakSettingsSheet(
                title: "Mood Streak",
                config: config,
                onSave: { refreshMoodWidgetSoon() }
            )
        }
        .fullScreenCover(item: Binding(
            get: { shouldUseFullScreenSheets ? editingStreakConfig : nil },
            set: { editingStreakConfig = $0 }
        )) { config in
            StreakSettingsSheet(
                title: "Mood Streak",
                config: config,
                onSave: { refreshMoodWidgetSoon() }
            )
        }
    }

    // MARK: Stats card

    private var statsCard: some View {
        MoodSurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    // Momentum
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(sevenDayMomentum)")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(theme.palette.primaryAction)
                                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                            Text("%")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(theme.palette.primaryAction)
                                .bubblyIconMaterial(tint: theme.palette.primaryAction)
                                .offset(y: -2)
                        }
                        Text(momentumLabel)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(width: 1, height: 44)

                    Spacer()

                    // Streak
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(streak)")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(theme.palette.secondaryAccent)
                                .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            Text(moodStreakUnitLabel)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                                .offset(y: -2)
                        }
                        Text(moodStreakConfig.displaySummary)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(width: 1, height: 44)

                    Spacer()

                    // Total logs
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(entries.count)")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(theme.palette.indicators)
                                .bubblyIconMaterial(tint: theme.palette.indicators)
                            Text("Logs")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                                .offset(y: -2)
                        }
                        Text("All time")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.6))
                    }
                }

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                HStack(spacing: 10) {
                    Text("This Week:")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)

                    HStack(spacing: 7) {
                        ForEach(0..<moodStreakConfig.weeklyGoalMarkerCount, id: \.self) { index in
                            moodWeeklyGoalMarker(
                                index: index,
                                isCompleted: index < completedMoodGoalMarkersThisWeek
                            )
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func moodWeeklyGoalMarker(index: Int, isCompleted: Bool) -> some View {
        let tint = theme.palette.rotation[index % theme.palette.rotation.count]

        if isCompleted {
            BubblyIconMaterial(tint: tint)
                .frame(width: 12, height: 12)
                .clipShape(Circle())
        } else {
            Circle()
                .stroke(theme.palette.textPrimary, lineWidth: 2)
                .frame(width: 12, height: 12)
                .bubblyIconMaterial(tint: tint)
        }
    }

    // MARK: Breakdown card

    private var breakdownCard: some View {
        MoodSurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {

                // Header row
                HStack {
                    Text("7-Day Snapshot")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                    Spacer()
                    if sevenDayEntries.isEmpty {
                        Text("No data yet")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.45))
                    } else {
                        Text("\(sevenDayEntries.count) log\(sevenDayEntries.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.45))
                    }
                }

                // Emotion bar
                if !sevenDayEntries.isEmpty {
                    let breakdown = sevenDayEmotionBreakdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emotional Range")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.5))

                        GeometryReader { geo in
                            HStack(spacing: 3) {
                                if breakdown.positive > 0 {
                                    BubblyCardMaterial(
                                        tint: theme.palette.primaryAction,
                                        cornerRadius: 4
                                    )
                                        .frame(width: geo.size.width * CGFloat(breakdown.positive) / 100)
                                }
                                if breakdown.neutral > 0 {
                                    BubblyCardMaterial(
                                        tint: theme.palette.secondaryAccent,
                                        cornerRadius: 4
                                    )
                                        .frame(width: geo.size.width * CGFloat(breakdown.neutral) / 100)
                                }
                                if breakdown.negative > 0 {
                                    BubblyCardMaterial(
                                        tint: theme.palette.indicators,
                                        cornerRadius: 4
                                    )
                                        .frame(width: geo.size.width * CGFloat(breakdown.negative) / 100)
                                }
                            }
                            .frame(height: 10)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .frame(height: 10)

                        HStack(spacing: 14) {
                            breakdownLegendDot(color: theme.palette.primaryAction, label: "Positive", value: breakdown.positive)
                            breakdownLegendDot(color: theme.palette.secondaryAccent, label: "Neutral", value: breakdown.neutral)
                            breakdownLegendDot(color: theme.palette.indicators, label: "Negative", value: breakdown.negative)
                        }
                    }

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(height: 1)
                }

                // Top emotion + activity row
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Most Felt")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.5))
                        Text(topEmotion ?? "—")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(theme.palette.primaryAction)
                            .bubblyIconMaterial(tint: theme.palette.primaryAction)
                            .contentTransition(.identity)
                    }

                    Spacer()

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(width: 1, height: 36)

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Activity")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.5))
                        Text(topActivity ?? "—")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(theme.palette.secondaryAccent)
                            .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            .contentTransition(.identity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func breakdownLegendDot(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: 5) {
            BubblyCardMaterial(tint: color, cornerRadius: 3.5)
                .frame(width: 7, height: 7)
            Text("\(value)% \(label)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.55))
        }
    }

    // MARK: Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(["Today", "History"], id: \.self) { tab in
                let index = tab == "Today" ? 0 : 1
                let isSelected = selectedTab == index
                let selectedTint = index == 0
                    ? theme.palette.primaryAction
                    : theme.palette.secondaryAccent

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                } label: {
                    Text(tab)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : LColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if isSelected {
                                    BubblyCardMaterial(
                                        tint: selectedTint,
                                        cornerRadius: 10
                                    )
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.palette.raisedSurface, lineWidth: 1)
                )
        )
    }

    // MARK: Today

    @ViewBuilder
    private var todayContent: some View {
        if let entry = todayEntry {
            MoodLogCard(
                entry: entry,
                onTap: { selectedEntry = entry },
                onDelete: { deleteMoodEntry(entry) }
            )
        } else {
            emptyState(message: "No mood logged today yet")
        }
    }

    // MARK: History

    @ViewBuilder
    private var historyContent: some View {
        if visibleHistoryEntries.isEmpty {
            emptyState(message: "Your mood logs will appear here")
        } else {
            let displayedEntries = Array(visibleHistoryEntries.prefix(visibleHistoryCount))

            VStack(spacing: 12) {
                ForEach(displayedEntries) { entry in
                    MoodLogCard(
                        entry: entry,
                        onTap: { selectedEntry = entry },
                        onDelete: { deleteMoodEntry(entry) }
                    )
                }

                if visibleHistoryCount > 4 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            visibleHistoryCount = max(4, visibleHistoryCount - 4)
                        }
                    } label: {
                        Text("See Less")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                BubblyCardMaterial(
                                    tint: theme.palette.secondaryAccent,
                                    cornerRadius: 999
                                )
                            }
                    }
                    .buttonStyle(.plain)
                }

                if visibleHistoryCount < visibleHistoryEntries.count {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            visibleHistoryCount = min(visibleHistoryEntries.count, visibleHistoryCount + 4)
                        }
                    } label: {
                        Text("Load More")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                BubblyCardMaterial(
                                    tint: theme.palette.primaryAction,
                                    cornerRadius: 999
                                )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Empty state

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        VStack(spacing: 14) {
            Image("xsmile")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(theme.palette.textSecondary)
                .bubblyIconMaterial(tint: theme.palette.textSecondary)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(theme.palette.textSecondary)
                .bubblyIconMaterial(tint: theme.palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func refreshMoodWidgetSoon() {
        DispatchQueue.main.async {
            LunixiaMoodWidgetWriter.write(allEntries: entries, streakConfig: moodStreakConfig)
        }
    }

    private func deleteMoodEntry(_ entry: MoodEntry) {
        if selectedEntry?.id == entry.id {
            selectedEntry = nil
        }

        modelContext.delete(entry)
        try? modelContext.save()
        refreshMoodWidgetSoon()
    }


}

// MARK: - Mood Log Card

struct MoodLogCard: View {
    @Environment(\.appTheme) private var theme

    let entry: MoodEntry
    let onTap: () -> Void
    let onDelete: () -> Void

    private var displayEmotions: [MoodEmotion] {
        if !entry.resolvedEmotions.isEmpty { return entry.resolvedEmotions }

        return entry.emotionNames.map { savedName in
            MoodEmotion.all.first {
                $0.name.caseInsensitiveCompare(savedName) == .orderedSame
            } ?? MoodEmotion(name: savedName.capitalized, category: .neutral)
        }
    }

    private var displayActivities: [MoodActivity] {
        if !entry.resolvedActivities.isEmpty { return entry.resolvedActivities }

        return entry.activityNames.map { savedName in
            MoodActivity.all.first {
                $0.name.caseInsensitiveCompare(savedName) == .orderedSame
            } ?? MoodActivity(name: savedName.capitalized, icon: "sparkle", isCustomAsset: true)
        }
    }

    var body: some View {
        Button(action: onTap) {
            MoodSurfaceCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                        Spacer()
                        Image("chevright")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(LColors.textSecondary.opacity(0.5))
                            .bubblyIconMaterial(tint: LColors.textSecondary.opacity(0.5))
                    }

                    if !displayEmotions.isEmpty {
                        FlowLayout(spacing: 5) {
                            ForEach(displayEmotions.prefix(6)) { emotion in
                                Text(emotion.name)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background {
                                        BubblyCardMaterial(
                                            tint: theme.palette.primaryAction,
                                            cornerRadius: 999
                                        )
                                    }
                            }
                            if displayEmotions.count > 6 {
                                Text("+\(displayEmotions.count - 6)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.5))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(LColors.glassSurface2))
                            }
                        }
                    }

                    if !displayActivities.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(displayActivities.prefix(8)) { activity in
                                Group {
                                    if activity.isCustomAsset {
                                        Image(activity.icon)
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: activity.icon)
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background {
                                    BubblyCardMaterial(
                                        tint: theme.palette.secondaryAccent,
                                        cornerRadius: 8
                                    )
                                }
                            }
                            if displayActivities.count > 8 {
                                Text("+\(displayActivities.count - 8)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                    }

                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.7))
                            .lineLimit(2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", image: "trash")
            }
        }
    }
}

private struct MoodSurfaceCard<Content: View>: View {
    @Environment(\.appTheme) private var theme

    var cornerRadius: CGFloat = 24
    var padding: CGFloat = LSpacing.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(theme.palette.raisedSurface, lineWidth: 1)
                    }
            }
            .shadow(color: theme.palette.background.opacity(0.34), radius: 14, y: 8)
    }
}
