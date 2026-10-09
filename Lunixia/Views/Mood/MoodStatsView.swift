//
//  MoodStatsView.swift
//  Lunixia
//

import SwiftUI
import DeviceActivity
import FamilyControls
import SwiftData

struct MoodStatsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @StateObject private var deviceActivityManager = DeviceActivityManager.shared
    @StateObject private var behaviorTracker = LunixiaBehaviorTracker.shared
    @State private var hasLoadedAuthorization = false
    @State private var showActivityPicker = false
    @State private var reportRefreshID = UUID()
    @State private var livePhoneSnapshot: SharedMoodPhoneStatsSnapshot? = nil
    @State private var generatedPhoneContext: MoodStatsContextResponse?
    @State private var generatedPhoneContextCacheKey: String?
    @State private var isGeneratingPhoneContext = false
    @State private var phoneContextErrorMessage: String?
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var entries: [MoodEntry]
    @Query(sort: \MoodPhoneStatsSnapshot.date, order: .reverse) private var phoneSnapshots: [MoodPhoneStatsSnapshot]

    private var dailyMoodSummaries: [DailyMoodSummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }

        return grouped.compactMap { date, entries in
            let scores = entries.flatMap { $0.resolvedEmotions }.map(Self.score)
            guard !scores.isEmpty else { return nil }

            return DailyMoodSummary(
                date: date,
                averageScore: scores.reduce(0, +) / Double(scores.count),
                checkInCount: entries.count
            )
        }
        .sorted { $0.date > $1.date }
    }

    private var emotionScores: [Double] {
        entries.flatMap { $0.resolvedEmotions }.map(Self.score)
    }

    private var averageMoodPercent: Int? {
        guard !emotionScores.isEmpty else { return nil }
        let average = emotionScores.reduce(0, +) / Double(emotionScores.count)
        return Int((average / 5.0 * 100).rounded())
    }

    private var bestDay: DailyMoodSummary? {
        dailyMoodSummaries.max { $0.averageScore < $1.averageScore }
    }

    private var hardestDay: DailyMoodSummary? {
        dailyMoodSummaries.min { $0.averageScore < $1.averageScore }
    }

    private var todayCheckInCount: Int {
        entries.filter { Calendar.current.isDateInToday($0.timestamp) }.count
    }

    private var todayPhoneSnapshot: MoodPhoneStatsSnapshot? {
        phoneSnapshots.first { Calendar.current.isDateInToday($0.date) }
    }

    private var latestPhoneSnapshot: MoodPhoneStatsSnapshot? {
        todayPhoneSnapshot ?? phoneSnapshots.first
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

                    headerSection

                    authorizationSection

                    overviewSection

                    phoneBehaviorTrackingSection

                    deviceActivityReportSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            deviceActivityManager.refreshAuthorizationStatus()
            print("[MoodStats] task — authorizationStatus: \(deviceActivityManager.authorizationStatus)")
            hasLoadedAuthorization = true

            if deviceActivityManager.isAuthorized {
                print("[MoodStats] task — already authorized, starting monitoring")
                deviceActivityManager.startMoodStatsMonitoringIfNeeded()
            } else {
                print("[MoodStats] task — not authorized, showing permission card")
            }

            loadLiveSnapshot()
            syncLatestPhoneSnapshot()
            behaviorTracker.restartMonitoringIfNeeded()
            behaviorTracker.loadTodayScreenTime()

            try? await Task.sleep(for: .seconds(4))
            loadLiveSnapshot()
            syncLatestPhoneSnapshot()
            await refreshGeneratedMoodStatsContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("lunixia.moodStatsReportDidUpdate"))) { notification in
            guard
                let screenTime = notification.userInfo?["screenTimeMinutes"] as? Double,
                let social = notification.userInfo?["socialAppMinutes"] as? Double,
                let night = notification.userInfo?["nighttimePhoneMinutes"] as? Double,
                let pickups = notification.userInfo?["pickupCount"] as? Int,
                let notifications = notification.userInfo?["notificationCount"] as? Int,
                let date = notification.userInfo?["date"] as? Date
            else { return }

            print("[MoodStats] received report notification — screen=\(screenTime) pickups=\(pickups)")
            livePhoneSnapshot = SharedMoodPhoneStatsSnapshot(
                date: date,
                screenTimeMinutes: screenTime,
                socialAppMinutes: social,
                nighttimePhoneMinutes: night,
                pickupCount: pickups,
                notificationCount: notifications
            )
            syncLatestPhoneSnapshot()
            Task { await refreshGeneratedMoodStatsContext() }
        }
        .onChange(of: reportRefreshID) { _, _ in
            Task {
                try? await Task.sleep(for: .seconds(4))
                loadLiveSnapshot()
                syncLatestPhoneSnapshot()
                try? await Task.sleep(for: .seconds(4))
                loadLiveSnapshot()
                syncLatestPhoneSnapshot()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                deviceActivityManager.refreshAuthorizationStatus()
                print("[MoodStats] scenePhase active — authorizationStatus: \(deviceActivityManager.authorizationStatus)")
                hasLoadedAuthorization = true
                reportRefreshID = UUID()
                loadLiveSnapshot()
                syncLatestPhoneSnapshot()
                behaviorTracker.loadTodayScreenTime()
                Task {
                    await refreshGeneratedMoodStatsContext()
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mood Stats")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                Text("Explore how your phone behavior may connect with your emotional patterns.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(LGradients.header)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Authorization

    private var authorizationSection: some View {
        Group {
            if hasLoadedAuthorization,
               (!deviceActivityManager.isAuthorized || deviceActivityManager.isRequestingAuthorization) {
                Button {
                    Task {
                        await deviceActivityManager.requestAuthorization()
                        deviceActivityManager.refreshAuthorizationStatus()

                        if deviceActivityManager.isAuthorized {
                            deviceActivityManager.startMoodStatsMonitoringIfNeeded()
                            reportRefreshID = UUID()
                        }
                    }
                } label: {
                    insightCard(
                        icon: "lockwavy",
                        title: deviceActivityManager.isRequestingAuthorization ? "Requesting Screen Time" : "Screen Time Permission Needed",
                        text: deviceActivityManager.errorMessage ?? "Tap here to approve Screen Time access so Lunixia can show live screen time, pickup, and notification data here."
                    )
                }
                .buttonStyle(.plain)
                .disabled(deviceActivityManager.isRequestingAuthorization)
            }
        }
    }

    // MARK: - Phone Behavior Tracking

    @ViewBuilder
    private var phoneBehaviorTrackingSection: some View {
        if deviceActivityManager.isAuthorized || behaviorTracker.hasSelection {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionTitle("App Tracking")
                    Spacer()
                    if behaviorTracker.hasSelection {
                        Button {
                            showActivityPicker = true
                        } label: {
                            Text("Change Apps")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(LGradients.header)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if behaviorTracker.hasSelection {
                    // Show estimated screen time for tracked apps
                    GlassCard(padding: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image("lovemobile")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(LGradients.header)
                                .frame(width: 46, height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Tracked App Usage")
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(formatMinutes(behaviorTracker.estimatedScreenTimeMinutes))
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .foregroundStyle(LGradients.header)
                                }
                                Text("Estimated from selected apps today")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                                Text(screenTimeTrackingInsight)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } else {
                    // Setup card
                    Button {
                        showActivityPicker = true
                    } label: {
                        GlassCard(padding: 18) {
                            HStack(spacing: 14) {
                                Image("tapicon")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(LGradients.header)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Set Up App Tracking")
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Choose which apps Lunixia tracks to estimate your daily usage and connect it to your mood.")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .familyActivityPicker(
                isPresented: $showActivityPicker,
                selection: $behaviorTracker.activitySelection
            )
            .onChange(of: behaviorTracker.activitySelection) { _, newSelection in
                if showActivityPicker == false { return }
                behaviorTracker.saveSelection(newSelection)
            }
            .onChange(of: showActivityPicker) { _, isPresented in
                if !isPresented && behaviorTracker.hasSelection {
                    behaviorTracker.saveSelection(behaviorTracker.activitySelection)
                }
            }
        }
    }

    private var screenTimeTrackingInsight: String {
        let h = behaviorTracker.estimatedScreenTimeMinutes / 60
        if h >= 8 { return "Very high tracked usage today." }
        if h >= 5 { return "Above average usage for selected apps." }
        if h >= 2 { return "Moderate tracked usage today." }
        if h > 0  { return "Low tracked usage so far today." }
        return "Tracking active. Usage will appear as you use selected apps."
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Mood Overview")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {
                statCard(
                    icon: "xsmile",
                    title: "Average Mood",
                    value: averageMoodPercent.map { "\($0)%" } ?? "—",
                    caption: emotionScores.isEmpty ? "Waiting for mood data" : "\(emotionScores.count) emotion tags"
                )

                statCard(
                    icon: "lovejournal",
                    title: "Check-Ins",
                    value: "\(entries.count)",
                    caption: todayCheckInCount == 0 ? "No logs today" : "\(todayCheckInCount) today"
                )

                statCard(
                    icon: "sparkle",
                    title: "Best Day",
                    value: bestDay.map { dayTitle(for: $0.date) } ?? "—",
                    caption: bestDay.map { "\(moodPercent(for: $0.averageScore))% across \($0.checkInCount) log\($0.checkInCount == 1 ? "" : "s")" } ?? "Highest mood average"
                )

                statCard(
                    icon: "timebook",
                    title: "Hardest Day",
                    value: hardestDay.map { dayTitle(for: $0.date) } ?? "—",
                    caption: hardestDay.map { "\(moodPercent(for: $0.averageScore))% across \($0.checkInCount) log\($0.checkInCount == 1 ? "" : "s")" } ?? "Lowest mood average"
                )
            }
        }
    }

    // MARK: - Phone Behavior

    private var phoneBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Phone Behavior")

            phoneContextSummary

            VStack(spacing: 14) {
                behaviorCard(
                    icon: "lovemobile",
                    title: "Screen Time",
                    value: livePhoneSnapshot.map { formatMinutes($0.screenTimeMinutes) } ?? "—",
                    caption: "Total daily device usage",
                    insight: phoneBehaviorInsight(
                        for: "screenTime",
                        fallback: "Higher screen time may align with lower mood patterns."
                    )
                )

                behaviorCard(
                    icon: "socialicon",
                    title: "Social App Usage",
                    value: livePhoneSnapshot.map { formatMinutes($0.socialAppMinutes) } ?? "—",
                    caption: "Selected social apps/categories",
                    insight: phoneBehaviorInsight(
                        for: "socialUsage",
                        fallback: "Social usage is estimated from Screen Time categories when available."
                    )
                )

                behaviorCard(
                    icon: "moonzs",
                    title: "Nighttime Phone Use",
                    value: livePhoneSnapshot.map { formatMinutes($0.nighttimePhoneMinutes) } ?? "—",
                    caption: "Late-night device activity",
                    insight: phoneBehaviorInsight(
                        for: "nighttimeUse",
                        fallback: "Night use counts hourly activity from 9 PM through early morning."
                    )
                )

                behaviorCard(
                    icon: "tapicon",
                    title: "Pickups / Unlocks",
                    value: livePhoneSnapshot.map { "\($0.pickupCount)" } ?? "—",
                    caption: "Checking behavior",
                    insight: phoneBehaviorInsight(
                        for: "pickups",
                        fallback: "Frequent pickups may correlate with anxious or restless moods."
                    )
                )

                behaviorCard(
                    icon: "bellfill",
                    title: "Notifications",
                    value: livePhoneSnapshot.map { "\($0.notificationCount)" } ?? "—",
                    caption: "Interruption volume",
                    insight: phoneBehaviorInsight(
                        for: "notifications",
                        fallback: "Heavy notification days may correlate with overstimulation."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var phoneContextSummary: some View {
        if let generatedPhoneContext {
            insightCard(
                icon: "sparklesearch",
                title: "AI Context",
                text: generatedPhoneContext.summary
            )
        } else if isGeneratingPhoneContext {
            insightCard(
                icon: "sparklesearch",
                title: "AI Context",
                text: "Lunixia is reading today’s mood and phone totals for a gentle pattern note."
            )
        }
    }


    // MARK: - Components

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(LGradients.header)
    }

    private func statCard(
        icon: String,
        title: String,
        value: String,
        caption: String
    ) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(LGradients.header)

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)

                    Text(caption)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func behaviorCard(
        icon: String,
        title: String,
        value: String,
        caption: String,
        insight: String
    ) -> some View {
        GlassCard(padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(LGradients.header)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Text(value)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                    }

                    Text(caption)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)

                    Text(insight)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textPrimary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func insightCard(
        icon: String,
        title: String,
        text: String
    ) -> some View {
        GlassCard(padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(LGradients.header)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(text)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }

    // MARK: - Device Activity Report

    private var deviceActivityReportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Phone Behavior")

            GlassCard(padding: 16) {
                DeviceActivityReport(.lunixiaMoodStats, filter: todayDeviceActivityFilter)
                    .id(reportRefreshID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 330)
                    .allowsHitTesting(false)
            }
        }
    }

    private var todayDeviceActivityFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .day, for: Date()) ?? DateInterval(
            start: calendar.startOfDay(for: Date()),
            duration: 86_400
        )

        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }


    @MainActor
    private func refreshGeneratedMoodStatsContext() async {
        guard let snapshot = livePhoneSnapshot,
              let cacheKey = currentMoodStatsContextCacheKey else {
            generatedPhoneContext = nil
            generatedPhoneContextCacheKey = nil
            isGeneratingPhoneContext = false
            return
        }

        if generatedPhoneContextCacheKey == cacheKey, generatedPhoneContext != nil {
            return
        }

        if let cachedContext = cachedMoodStatsContext(for: cacheKey) {
            generatedPhoneContext = cachedContext
            generatedPhoneContextCacheKey = cacheKey
            phoneContextErrorMessage = nil
            return
        }

        isGeneratingPhoneContext = true
        phoneContextErrorMessage = nil
        defer { isGeneratingPhoneContext = false }

        do {
            let payload = makeMoodStatsContextRequest(for: snapshot)
            let response = try await MoodStatsContextService.shared.generateContext(payload)

            guard currentMoodStatsContextCacheKey == cacheKey else { return }

            generatedPhoneContext = response
            generatedPhoneContextCacheKey = cacheKey
            cacheMoodStatsContext(response, for: cacheKey)
        } catch {
            phoneContextErrorMessage = error.localizedDescription
        }
    }

    private var currentMoodStatsContextCacheKey: String? {
        guard let snapshot = livePhoneSnapshot else { return nil }

        let parts = [
            dateKey(for: snapshot.date),
            "\(Int(snapshot.screenTimeMinutes.rounded()))",
            "\(Int(snapshot.socialAppMinutes.rounded()))",
            "\(Int(snapshot.nighttimePhoneMinutes.rounded()))",
            "\(snapshot.pickupCount)",
            "\(snapshot.notificationCount)",
            "\(averageMoodPercent ?? 0)",
            "\(entries.count)",
            "\(todayCheckInCount)"
        ]

        return "lunixia.moodStats.aiContext.\(parts.joined(separator: "."))"
    }

    private func makeMoodStatsContextRequest(for snapshot: SharedMoodPhoneStatsSnapshot) -> MoodStatsContextRequest {
        MoodStatsContextRequest(
            userId: appState.currentAppleUserId,
            date: dateKey(for: snapshot.date),
            moodSummary: .init(
                averageMoodPercent: averageMoodPercent ?? 0,
                checkInCount: entries.count,
                bestDay: bestDay.map { dayTitle(for: $0.date) } ?? "No mood data yet",
                hardestDay: hardestDay.map { dayTitle(for: $0.date) } ?? "No mood data yet"
            ),
            phoneBehavior: .init(
                screenTimeMinutes: snapshot.screenTimeMinutes,
                socialAppMinutes: snapshot.socialAppMinutes,
                nighttimePhoneMinutes: snapshot.nighttimePhoneMinutes,
                pickupCount: snapshot.pickupCount,
                notificationCount: snapshot.notificationCount
            ),
            recentSnapshots: phoneSnapshots.prefix(14).map { snapshot in
                MoodStatsContextRequest.RecentSnapshot(
                    date: dateKey(for: snapshot.date),
                    averageMoodPercent: moodPercent(for: snapshot.averageMoodScore),
                    checkInCount: snapshot.moodCheckInCount,
                    screenTimeMinutes: snapshot.screenTimeMinutes,
                    socialAppMinutes: snapshot.socialAppMinutes,
                    nighttimePhoneMinutes: snapshot.nighttimePhoneMinutes,
                    pickupCount: snapshot.pickupCount,
                    notificationCount: snapshot.notificationCount
                )
            }
        )
    }

    private func phoneBehaviorInsight(for key: String, fallback: String) -> String {
        generatedPhoneContext?.behaviors.first { $0.key == key }?.insight ?? fallback
    }

    private func cachedMoodStatsContext(for key: String) -> MoodStatsContextResponse? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MoodStatsContextResponse.self, from: data)
    }

    private func cacheMoodStatsContext(_ context: MoodStatsContextResponse, for key: String) {
        guard let data = try? JSONEncoder().encode(context) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func loadLiveSnapshot() {
        let defaults = UserDefaults(suiteName: MoodStatsSharedStore.appGroupIdentifier)
        defaults?.synchronize()
        let raw = defaults?.data(forKey: MoodStatsSharedStore.latestSnapshotKey)
        print("[MoodStats] loadLiveSnapshot — App Group defaults: \(defaults == nil ? "NIL" : "OK")")
        print("[MoodStats] loadLiveSnapshot — raw data bytes: \(raw?.count ?? 0)")

        // Check if the extension wrote the debug file
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: MoodStatsSharedStore.appGroupIdentifier) {
            let fileURL = containerURL.appendingPathComponent("moodstats_debug.txt")
            if let debugContent = try? String(contentsOf: fileURL) {
                print("[MoodStats] loadLiveSnapshot — DEBUG FILE EXISTS: \(debugContent)")
            } else {
                print("[MoodStats] loadLiveSnapshot — debug file NOT found (extension never wrote)")
            }
        }

        if let data = raw {
            if let snapshot = try? JSONDecoder().decode(SharedMoodPhoneStatsSnapshot.self, from: data) {
                print("[MoodStats] loadLiveSnapshot — decoded OK: screen=\(snapshot.screenTimeMinutes) pickups=\(snapshot.pickupCount) date=\(snapshot.date)")
                livePhoneSnapshot = snapshot
            } else {
                print("[MoodStats] loadLiveSnapshot — DECODE FAILED")
            }
        } else {
            print("[MoodStats] loadLiveSnapshot — no data found for key: \(MoodStatsSharedStore.latestSnapshotKey)")
        }
    }

    private func syncLatestPhoneSnapshot() {
        guard let sharedSnapshot = MoodStatsSharedStore.latestSnapshot() else { return }

        let calendar = Calendar.current
        let snapshotDate = calendar.startOfDay(for: sharedSnapshot.date)
        let phoneUsage = MoodPhoneUsageTotals(
            screenTimeMinutes: sharedSnapshot.screenTimeMinutes,
            socialAppMinutes: sharedSnapshot.socialAppMinutes,
            nighttimePhoneMinutes: sharedSnapshot.nighttimePhoneMinutes,
            pickupCount: sharedSnapshot.pickupCount,
            notificationCount: sharedSnapshot.notificationCount
        )
        let moodInputs = moodInputsForSnapshots()

        if let existing = phoneSnapshots.first(where: { calendar.isDate($0.date, inSameDayAs: snapshotDate) }) {
            MoodStatsAggregator.shared.updateSnapshot(
                existing,
                moodLogs: moodInputs,
                phoneUsage: phoneUsage
            )
        } else {
            let snapshot = MoodStatsAggregator.shared.buildDailySnapshot(
                for: snapshotDate,
                moodLogs: moodInputs,
                phoneUsage: phoneUsage
            )
            modelContext.insert(snapshot)
        }

        try? modelContext.save()
    }

    private func moodInputsForSnapshots() -> [MoodStatsMoodInput] {
        entries.map { entry in
            let score = entry.resolvedEmotions.map(Self.score).average ?? 0
            let title = entry.emotionNames.first ?? "None"

            return MoodStatsMoodInput(
                date: entry.timestamp,
                moodTitle: title,
                moodIcon: "xsmile",
                moodScore: score
            )
        }
    }

    private static func score(for emotion: MoodEmotion) -> Double {
        switch emotion.category {
        case .positive: return 5
        case .neutral: return 3
        case .negative: return 1
        }
    }

    private func moodPercent(for score: Double) -> Int {
        Int((score / 5.0 * 100).rounded())
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let roundedMinutes = Int(minutes.rounded())
        let hours = roundedMinutes / 60
        let remainingMinutes = roundedMinutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)m"
    }

    private func dayTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private struct DailyMoodSummary {
        let date: Date
        let averageScore: Double
        let checkInCount: Int
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
