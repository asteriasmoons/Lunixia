//
//  SelfCarePointsView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct SelfCarePointsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [LunixiaPointsProfile]
    @Query(sort: \LunixiaPointEntry.createdAt, order: .reverse) private var allEntries: [LunixiaPointEntry]
    @Query(sort: \LunixiaPointsResetLog.createdAt, order: .reverse) private var resetLogs: [LunixiaPointsResetLog]

    @State private var userId: String? = nil
    @State private var visibleEntryCount: Int = 4
    @State private var showHistorySheet    = false
    @State private var showSnapshotConfirm = false
    @State private var selectedEntry: LunixiaPointEntry? = nil
    @State private var showDeleteEntryConfirm = false
    @State private var heartPulse: Bool = false
    @State private var isHowToEarnExpanded = false

    private let pink     = Color(red: 1.0, green: 0.35, blue: 0.65)
    private let pinkSoft = Color(red: 1.0, green: 0.35, blue: 0.65).opacity(0.18)
    private let pinkGrad = LinearGradient(
        colors: [Color(red: 1.0, green: 0.4, blue: 0.7), Color(red: 1.0, green: 0.2, blue: 0.5)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private var profile: LunixiaPointsProfile? {
        guard let uid = userId else { return profiles.first }
        return profiles.first { $0.userId == uid } ?? profiles.first
    }

    private var currentPoints: Int  { profile?.currentPoints  ?? 0 }
    private var lifetimePoints: Int { profile?.lifetimePoints ?? 0 }
    private var level: Int          { LunixiaPointsManager.level(for: currentPoints) }
    private var progress: Int       { LunixiaPointsManager.progressInCurrentLevel(for: currentPoints) }
    private var needed: Int         { LunixiaPointsManager.pointsNeededToNextLevel(for: currentPoints) }

    private var todayPoints: Int {
        guard let uid = userId else { return 0 }
        return (try? LunixiaPointsManager.pointsEarnedToday(in: modelContext, userId: uid)) ?? 0
    }

    private var recentEntries: [LunixiaPointEntry] {
        guard let uid = userId else { return Array(allEntries.prefix(visibleEntryCount)) }
        let filtered = allEntries.filter { $0.userId == uid }
        return Array((filtered.isEmpty ? allEntries : filtered).prefix(visibleEntryCount))
    }

    var body: some View {
        ZStack {
            LunixiaBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Nav
                HStack(spacing: 16) {
                    Text("Self-Care Points")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {

                        // MARK: Floating heart
                        ZStack {
                            Circle()
                                .fill(pink.opacity(0.22))
                                .frame(width: 142, height: 142)
                                .blur(radius: 25)
                                .scaleEffect(heartPulse ? 1.15 : 0.9)
                                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: heartPulse)

                            Image("heartfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 92, height: 92)
                                .foregroundStyle(pinkGrad)
                                .shadow(color: pink.opacity(0.55), radius: 20, y: 8)
                                .scaleEffect(heartPulse ? 1.08 : 0.94)
                                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: heartPulse)
                        }
                        .frame(height: 130)
                        .padding(.top, 8)
                        .onAppear { heartPulse = true }

                        // MARK: Stats grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            statCard(label: "Current", value: "\(currentPoints)", icon: "heartfill")
                            statCard(label: "Level",   value: "\(level)",         icon: "levelup")
                            statCard(label: "Today",   value: "\(todayPoints)",   icon: "sparkle")
                            statCard(label: "Lifetime", value: "\(lifetimePoints)", icon: "loveflame")
                        }
                        .padding(.horizontal, 16)

                        // MARK: Level progress
                        pinkSection(title: "Level Progress") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("You need \(needed) more point\(needed == 1 ? "" : "s") to reach Level \(level + 1).")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(pink.opacity(0.85))

                                GeometryReader { geo in
                                    let ratio = CGFloat(progress) / CGFloat(max(LunixiaPointsManager.pointsPerLevel, 1))
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(pink.opacity(0.15)).frame(height: 12)
                                        Capsule().fill(pinkGrad)
                                            .frame(width: geo.size.width * min(ratio, 1), height: 12)
                                    }
                                }
                                .frame(height: 12)

                                HStack {
                                    Text("\(progress) / \(LunixiaPointsManager.pointsPerLevel)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(pink.opacity(0.7))
                                    Spacer()
                                    Text("Level \(level + 1)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(pink.opacity(0.7))
                                }
                            }
                        }

                        // MARK: Breakdown
                        pinkSection(title: "Points Breakdown") {
                            VStack(spacing: 10) {
                                breakdownRow(label: "Current Points", assetIcon: "sparkle", value: currentPoints)
                                pinkDivider
                                breakdownRow(label: "Lifetime Points", assetIcon: "infinity", value: lifetimePoints)
                                pinkDivider
                                breakdownRow(label: "Earned Today", assetIcon: "sun", value: todayPoints)
                                pinkDivider
                                breakdownRow(label: "Total Spent", assetIcon: "hashtag", value: profile?.spentPoints ?? 0)
                            }
                        }

                        // MARK: Recent activity
                        pinkSection(title: "Recent Activity") {
                            if allEntries.isEmpty {
                                Text("No activity yet. Start journaling, logging, and hitting your goals.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(pink.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(recentEntries) { entry in
                                        activityRow(entry)
                                            .onLongPressGesture {
                                                selectedEntry = entry
                                                showDeleteEntryConfirm = true
                                            }
                                    }
                                    if allEntries.count > visibleEntryCount {
                                        Button {
                                            withAnimation { visibleEntryCount += 4 }
                                        } label: {
                                            Text("Load More")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 20).padding(.vertical, 9)
                                                .background(pinkGrad, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }

                        // MARK: How to earn
                        collapsiblePinkSection(
                            title: "How to Earn",
                            isExpanded: $isHowToEarnExpanded
                        ) {
                            VStack(spacing: 10) {
                                earnRow(label: "Journal Entry",      assetIcon: "lovedocs",  sfIcon: nil,              points: LunixiaPointsManager.journalEntryPoints)
                                pinkDivider
                                earnRow(label: "Mood Log",           assetIcon: "xsmile",    sfIcon: nil,              points: LunixiaPointsManager.moodLogPoints)
                                pinkDivider
                                earnRow(label: "Daily Tarot",        assetIcon: "crystalball", sfIcon: nil,            points: LunixiaPointsManager.dailyTarotPoints)
                                pinkDivider
                                earnRow(label: "Daily Lenormand",     assetIcon: "wand",     sfIcon: nil,              points: LunixiaPointsManager.dailyLenormandPoints)
                                pinkDivider
                                earnRow(label: "Vitals Log",         assetIcon: "scope",     sfIcon: nil,              points: LunixiaPointsManager.vitalsLogPoints)
                                pinkDivider
                                earnRow(label: "Exercise Log",       assetIcon: "dumbbell",  sfIcon: nil,              points: LunixiaPointsManager.exerciseLogPoints)
                                pinkDivider
                                earnRow(label: "Medications Taken",  assetIcon: "medication", sfIcon: nil,             points: LunixiaPointsManager.medicationTakenPoints)
                                pinkDivider
                                earnRow(label: "Water Log",          assetIcon: "bottle",    sfIcon: nil,              points: LunixiaPointsManager.waterLogPoints)
                                pinkDivider
                                earnRow(label: "Daily Intention",    assetIcon: "starfill",  sfIcon: nil,              points: LunixiaPointsManager.dailyIntentionPoints)
                                pinkDivider
                                earnRow(label: "Mindful Minutes",   assetIcon: "sunflower", sfIcon: nil,              points: LunixiaPointsManager.mindfulMinutePoints, perUnit: "per min")
                                pinkDivider
                                earnRow(label: "Water Goal Reached", assetIcon: nil,         sfIcon: "target",         points: LunixiaPointsManager.waterGoalPoints)
                                pinkDivider
                                earnRow(label: "Step Goal Reached",  assetIcon: nil,         sfIcon: "target",         points: LunixiaPointsManager.stepGoalPoints)
                            }
                        }

                        // MARK: History actions
                        pinkSection(title: "History") {
                            VStack(spacing: 10) {
                                actionRow(assetIcon: "clockwavy", label: "Save Snapshot", subtitle: "Manually save your current points & level") {
                                    showSnapshotConfirm = true
                                }
                                pinkDivider
                                actionRow(assetIcon: "clockfill", label: "View History", subtitle: "See automatic and manual reset history") {
                                    showHistorySheet = true
                                }
                            }
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            userId = try? LunixiaPointsManager.resolveUserId(in: modelContext)
            if let uid = userId {
                _ = try? LunixiaPointsManager.fetchOrCreateProfile(in: modelContext, userId: uid)
            }
        }
        .confirmationDialog("Save a snapshot of your current points and level?", isPresented: $showSnapshotConfirm, titleVisibility: .visible) {
            Button("Save Snapshot") { _ = try? LunixiaPointsManager.createSnapshot(in: modelContext) }
            Button("Cancel", role: .cancel) {}
        }
        .lunixiaAlertConfirm(
            isPresented: $showDeleteEntryConfirm,
            title: "Remove Entry",
            message: "This will remove this activity entry and adjust your points totals.",
            confirmTitle: "Remove"
        ) {
            if let entry = selectedEntry {
                _ = try? LunixiaPointsManager.deleteEntryAndAdjust(in: modelContext, entry: entry)
                selectedEntry = nil
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            PointsHistorySheet(resetLogs: resetLogs, userId: userId)
        }
    }

    @ViewBuilder
    private func collapsiblePinkSection<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(pink.opacity(0.7))
                        .kerning(1.2)

                    Spacer()

                    Image(isExpanded.wrappedValue ? "chevup" : "chevdown")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(pinkGrad)
                }
                .contentShape(Rectangle())
                .padding(16)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")

            if isExpanded.wrappedValue {
                pinkDivider
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(pink.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(pink.opacity(0.25), lineWidth: 0.75)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Stat card

    @ViewBuilder
    private func statCard(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(pink.opacity(0.15)).frame(width: 30, height: 30)
                    Image(icon)
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(pinkGrad)
                }
                Spacer()
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(pink.opacity(0.7))
                    .kerning(0.8)
                    .multilineTextAlignment(.trailing)
            }
            Spacer()
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(pink)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(pink.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(pink.opacity(0.3), lineWidth: 0.75))
        )
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func pinkSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(pink.opacity(0.7))
                .kerning(1.2)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(pink.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(pink.opacity(0.25), lineWidth: 0.75))
            )
            .padding(.horizontal, 16)
        }
    }

    private var pinkDivider: some View {
        Rectangle().fill(pink.opacity(0.15)).frame(height: 0.75)
    }

    // MARK: - Breakdown row (asset icon)

    @ViewBuilder
    private func breakdownRow(label: String, assetIcon: String, value: Int) -> some View {
        HStack(spacing: 10) {
            Image(assetIcon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(pinkGrad)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(pink.opacity(0.85))

            Spacer()

            Text("\(value)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(pink)
        }
    }

    // MARK: - Activity row (per-source icon)

    @ViewBuilder
    private func activityRow(_ entry: LunixiaPointEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(pink.opacity(0.14)).frame(width: 36, height: 36)
                activityIcon(for: entry.sourceType)
                    .foregroundStyle(pinkGrad)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title.isEmpty ? entry.sourceType.label : entry.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(pink.opacity(0.9))
                    .lineLimit(1)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(pink.opacity(0.5))
            }
            Spacer()
            Text("+\(entry.points)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(pink)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(pink.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(pink.opacity(0.2), lineWidth: 0.75))
        )
    }

    @ViewBuilder
    private func activityIcon(for source: LunixiaPointSourceType) -> some View {
        switch source {
        case .journalEntry:
            Image("lovedocs")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .moodLog:
            Image("xsmile")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .dailyTarot:
            Image("crystalball")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .dailyLenormand:
            Image("wand")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .vitalsLog:
            Image("scope")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .exerciseLog:
            Image("dumbbell")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .medicationTaken:
            Image("medication")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .waterLog:
            Image("bottle")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .waterGoal:
            Image(systemName: "target")
                .font(.system(size: 15, weight: .semibold))
        case .stepGoal:
            Image(systemName: "target")
                .font(.system(size: 15, weight: .semibold))
        case .dailyIntention:
            Image("starfill")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        case .mindfulMinutes:
            Image("sunflower")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 16, height: 16)
        }
    }

    // MARK: - Earn row (asset or SF icon)

    @ViewBuilder
    private func earnRow(label: String, assetIcon: String?, sfIcon: String?, points: Int, perUnit: String? = nil) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if let asset = assetIcon {
                    Image(asset)
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundStyle(pinkGrad)
                } else if let sf = sfIcon {
                    Image(systemName: sf)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(pinkGrad)
                }
            }
            .frame(width: 20)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(pink.opacity(0.85))
            Spacer()
            if let unit = perUnit {
                Text("+\(points) \(unit)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(pink)
            } else {
                Text("+\(points)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(pink)
            }
        }
    }

    // MARK: - Action row

    @ViewBuilder
    private func actionRow(assetIcon: String, label: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(pink.opacity(0.14)).frame(width: 36, height: 36)
                    Image(assetIcon)
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(pinkGrad)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(pink.opacity(0.9))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(pink.opacity(0.5))
                }
                Spacer()
                Image("chevright")
                    .renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(pink.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - Points History Sheet
// ============================================================

struct PointsHistorySheet: View {
    let resetLogs: [LunixiaPointsResetLog]
    let userId: String?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedResetLog: LunixiaPointsResetLog? = nil
    @State private var showDeleteResetLogConfirm = false
    @State private var visibleHistoryCount = 4

    private let historyPageSize = 4

    private let pink = Color(red: 1.0, green: 0.35, blue: 0.65)
    private let pinkGrad = LinearGradient(
        colors: [Color(red: 1.0, green: 0.4, blue: 0.7), Color(red: 1.0, green: 0.2, blue: 0.5)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private var visibleResetLogs: [LunixiaPointsResetLog] {
        Array(resetLogs.prefix(visibleHistoryCount))
    }

    var body: some View {
        ZStack(alignment: .top) {
            LunixiaBackground().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {

                HStack {
                    Text("History")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)

                    Spacer()

                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(pinkGrad)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                if resetLogs.isEmpty {
                    VStack(spacing: 14) {
                        Image("clockfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                            .foregroundStyle(pinkGrad)

                        Text("No history saved yet.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(pink.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(visibleResetLogs) { log in
                                historyRow(log)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            selectedResetLog = log
                                            showDeleteResetLogConfirm = true
                                        } label: {
                                            Text("Delete")
                                        }
                                    }
                                    .onLongPressGesture {
                                        selectedResetLog = log
                                        showDeleteResetLogConfirm = true
                                    }
                            }

                            if resetLogs.count > historyPageSize {
                                HStack(spacing: 10) {
                                    if visibleHistoryCount > historyPageSize {
                                        historyPagingButton(title: "Load Less") {
                                            withAnimation(.easeInOut(duration: 0.22)) {
                                                visibleHistoryCount = historyPageSize
                                            }
                                        }
                                    }

                                    if visibleHistoryCount < resetLogs.count {
                                        historyPagingButton(title: "Load More") {
                                            withAnimation(.easeInOut(duration: 0.22)) {
                                                visibleHistoryCount = min(
                                                    visibleHistoryCount + historyPageSize,
                                                    resetLogs.count
                                                )
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .lunixiaAlertConfirm(
            isPresented: $showDeleteResetLogConfirm,
            title: "Delete History Entry",
            message: "This removes this saved history record only. It does not change your current points.",
            confirmTitle: "Delete"
        ) {
            deleteSelectedResetLog()
        }
    }

    private func deleteSelectedResetLog() {
        guard let selectedResetLog else { return }
        modelContext.delete(selectedResetLog)
        try? modelContext.save()
        self.selectedResetLog = nil
    }

    @ViewBuilder
    private func historyPagingButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(pinkGrad, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func historyRow(_ log: LunixiaPointsResetLog) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(pink.opacity(0.14)).frame(width: 36, height: 36)
                Image(systemName: log.weekStartDayKey.hasPrefix("manual-") ? "square.and.pencil" : "arrow.clockwise.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pinkGrad)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(log.weekStartDayKey.hasPrefix("manual-") ? "Manual Snapshot" : "Weekly Reset")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(pink.opacity(0.9))
                Text(log.resetAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(pink.opacity(0.5))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(log.pointsBeforeReset) pts")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(pink)
                Text("Lv \(log.levelBeforeReset)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(pink.opacity(0.5))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(pink.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(pink.opacity(0.25), lineWidth: 0.75))
        )
    }
}
