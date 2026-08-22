//
// JournalTabView.swift
// Lunixia
//

import SwiftUI
import SwiftData
import Combine

struct JournalTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: LunixiaStoreManager
    @State private var showBookEditor = false
    @State private var mindfulMinutes = 0
    @State private var mindfulMinutesMidnightRefreshTask: Task<Void, Never>? = nil
    @State private var showPremiumBanner = false
    @State private var premiumBannerMessage = ""

    private var isPremium: Bool {
        storeManager.isPremium
    }
    
    @Query(filter: #Predicate<JournalBook> { $0.deletedAt == nil }, sort: \JournalBook.createdAt, order: .reverse) private var books: [JournalBook]
    @Query(filter: #Predicate<JournalEntry> { $0.deletedAt == nil }, sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry] // for migration + counts

    private var activeBooks: [JournalBook] {
        books.filter { $0.deletedAt == nil }
    }

    private var canCreateJournalBook: Bool {
        LunixiaLimitsManager.canCreateJournalBook(
            currentCount: activeBooks.count,
            isPremium: isPremium
        )
    }

    private var themeInsightsUserId: String? {
        guard let userId = appState.currentAppleUserId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty else {
            return nil
        }
        return userId
    }

    @Query private var journalStatsRecords: [JournalStats]
    
    @State private var editingBook: JournalBook? = nil
    
    @ViewBuilder
    private func journalEmptyState(icon: String, message: String) -> some View {
        VStack(spacing: 14) {
            LunixiaIconView(iconId: icon, size: 44)
                .foregroundStyle(LColors.textSecondary.opacity(0.45))
            
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(LColors.glassBorder, lineWidth: 1)
                )
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        header

                        DailyIntentionView()
                            .padding(.horizontal, LSpacing.pageHorizontal)
                            .padding(.top, 0)
                            .padding(.bottom, 10)

                        MindfulMinutesBanner(minutes: mindfulMinutes)
                            .padding(.horizontal, LSpacing.pageHorizontal)
                            .padding(.bottom, 12)

                        if let themeInsightsUserId {
                            NavigationLink {
                                ThemeInsightsView(userId: themeInsightsUserId)
                            } label: {
                                ThemeInsightsCard()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, LSpacing.pageHorizontal)
                            .padding(.bottom, 12)
                        }

                        JournalStreakCard(
                            currentStreak: currentJournalStreak,
                            bestStreak: bestJournalStreak,
                            journaledToday: journaledToday
                        )
                        .padding(.horizontal, LSpacing.pageHorizontal)
                        .padding(.bottom, 16)
                        
                        bookshelf
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)

                if showPremiumBanner {
                    VStack {
                        Text(premiumBannerMessage)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(LColors.accentGradient)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                            .padding(.top, 18)

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            
            .overlay {
                if showBookEditor {
                    JournalBookEditorSheet(
                        book: editingBook,
                        onClose: {
                            showBookEditor = false
                            editingBook = nil
                        }
                    )
                    .preferredColorScheme(.dark)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(50)
                }
            }
            .onAppear {
                migrateEntriesIntoDefaultBookIfNeeded()
                migrateBookUUIDsIfNeeded()
                loadMindfulMinutesIfNeeded()
                scheduleMindfulMinutesMidnightRefresh()
                updateBestStreakIfNeeded()

                if let themeInsightsUserId {
                    ThemeInsightsBackfillManager.backfillIfNeeded(
                        modelContext: modelContext,
                        userId: themeInsightsUserId
                    )
                }
            }
            .onDisappear {
                mindfulMinutesMidnightRefreshTask?.cancel()
                mindfulMinutesMidnightRefreshTask = nil
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showBookEditor)
            // Prevent the NavigationStack default backgrounds from covering the custom background
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Journal")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(LGradients.header)

                Spacer()

                Button {
                    if canCreateJournalBook {
                        editingBook = nil
                        showBookEditor = true
                    } else {
                        showPremiumRequiredMessage()
                    }
                } label: {
                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(canCreateJournalBook ? LGradients.header : LinearGradient(colors: [LColors.textSecondary.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                }
                .buttonStyle(.plain)
                .overlay(alignment: .center) {
                    if !canCreateJournalBook && !isPremium {
                        LunixiaPremiumBlurOverlay(cornerRadius: 14)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)
        }
    }
    
    // MARK: - Bookshelf
    
    private var bookshelf: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 26 : 12) {
            if books.isEmpty {
                journalEmptyState(icon: "starnote", message: "No entries in this book yet.\nTap + to create one.")
                    .padding(.top, 20)
                    .padding(.horizontal, LSpacing.pageHorizontal)
            } else {
                LazyVGrid(columns: gridColumns, spacing: bookshelfGridSpacing) {
                    ForEach(sortedBooks, id: \.persistentModelID) { book in
                        NavigationLink {
                            JournalBookDetailView(book: book)
                        } label: {
                            JournalBookCard(
                                title: book.title,
                                coverHex: book.coverHex,
                                entryCount: entryCount(for: book),
                                lastDate: lastEntryDate(for: book),
                                isPinned: book.pinOrder > 0
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if book.pinOrder > 0 {
                                Button("Unpin Book") {
                                    unpinBook(book)
                                }
                            } else {
                                Button("Pin Book") {
                                    pinBook(book)
                                }
                            }
                            
                            Button("Edit Book") {
                                editingBook = book
                                showBookEditor = true
                            }
                            Button(role: .destructive) {
                                deleteBook(book)
                            } label: {
                                Text("Delete Book")
                            }
                        }
                    }
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, horizontalSizeClass == .regular ? 42 : 4)
            }
        }
    }
    
    private var bookshelfGridSpacing: CGFloat {
        horizontalSizeClass == .regular ? 52 : 14
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: bookshelfGridSpacing),
            GridItem(.flexible(), spacing: bookshelfGridSpacing)
        ]
    }
    
    private var sortedBooks: [JournalBook] {
        books.sorted { lhs, rhs in
            let lhsPinned = lhs.pinOrder > 0
            let rhsPinned = rhs.pinOrder > 0
            
            if lhsPinned != rhsPinned {
                return lhsPinned && !rhsPinned
            }
            
            if lhsPinned && rhsPinned, lhs.pinOrder != rhs.pinOrder {
                return lhs.pinOrder < rhs.pinOrder
            }
            
            return lhs.createdAt > rhs.createdAt
        }
    }
    
    // MARK: - Journal Streaks
    
    private var streakCalendar: Calendar {
        Calendar.autoupdatingCurrent
    }
    
    private var journaledDayStarts: Set<Date> {
        Set(allEntries.map { streakCalendar.startOfDay(for: $0.createdAt) })
    }
    
    private var journaledToday: Bool {
        journaledDayStarts.contains(streakCalendar.startOfDay(for: Date()))
    }
    
    private var currentJournalStreak: Int {
        let todayStart = streakCalendar.startOfDay(for: Date())
        let startDay: Date
        
        if journaledDayStarts.contains(todayStart) {
            startDay = todayStart
        } else if let yesterday = streakCalendar.date(byAdding: .day, value: -1, to: todayStart),
                  journaledDayStarts.contains(yesterday) {
            startDay = yesterday
        } else {
            return 0
        }
        
        var streak = 0
        var cursor = startDay
        
        while journaledDayStarts.contains(cursor) {
            streak += 1
            guard let previous = streakCalendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        
        return streak
    }
    
    /// The best streak ever seen. Computed from live entries, but the result is
    /// persisted to `JournalStats` so it can never drop below its historical high
    /// (e.g. due to a book deletion removing backing entries).
    private var bestJournalStreak: Int {
        let computed = computedBestStreak
        guard let record = journalStatsRecords.first else { return computed }
        return max(computed, record.bestStreakEver)
    }

    private func updateBestStreakIfNeeded() {
        let computed = computedBestStreak
        let record = journalStatsRecord
        let result = max(computed, record.bestStreakEver)
        guard result > record.bestStreakEver else { return }
        record.bestStreakEver = result
        record.updatedAt = Date()
        try? modelContext.save()
    }
    
    private var computedBestStreak: Int {
        let sortedDays = journaledDayStarts.sorted()
        guard !sortedDays.isEmpty else { return currentJournalStreak }
        
        var best = 1
        var current = 1
        
        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let currentDay = sortedDays[index]
            
            if let nextExpected = streakCalendar.date(byAdding: .day, value: 1, to: previous),
               streakCalendar.isDate(nextExpected, inSameDayAs: currentDay) {
                current += 1
            } else {
                current = 1
            }
            
            best = max(best, current)
        }
        
        return max(best, currentJournalStreak)
    }
    
    /// Returns the single `JournalStats` record, creating it if it doesn't exist yet.
    private var journalStatsRecord: JournalStats {
        if let existing = journalStatsRecords.first {
            return existing
        }
        let record = JournalStats()
        modelContext.insert(record)
        try? modelContext.save()
        return record
    }
    
    // MARK: - Helpers

    private func loadMindfulMinutesIfNeeded() {
        guard !HealthKitManager.shared.hasFetchedToday else {
            mindfulMinutes = HealthKitManager.shared.meditationMinutes
            return
        }

        Task.detached(priority: .userInitiated) {
            await HealthKitManager.shared.requestAuthorization()
            await HealthKitManager.shared.fetchAll()

            await MainActor.run {
                mindfulMinutes = HealthKitManager.shared.meditationMinutes
            }
        }
    }

    private func scheduleMindfulMinutesMidnightRefresh() {
        mindfulMinutesMidnightRefreshTask?.cancel()

        mindfulMinutesMidnightRefreshTask = Task { @MainActor in
            while !Task.isCancelled {
                let now = Date()
                let calendar = Calendar.autoupdatingCurrent

                guard let nextMidnight = calendar.nextDate(
                    after: now,
                    matching: DateComponents(hour: 0, minute: 0, second: 0),
                    matchingPolicy: .nextTime
                ) else {
                    return
                }

                let secondsUntilMidnight = max(1, nextMidnight.timeIntervalSince(now))

                do {
                    try await Task.sleep(for: .seconds(secondsUntilMidnight))
                } catch {
                    return
                }

                guard !Task.isCancelled else { return }

                mindfulMinutes = 0
                loadMindfulMinutesIfNeeded()
            }
        }
    }

    private func entryCount(for book: JournalBook) -> Int {
        allEntries.filter { $0.book?.persistentModelID == book.persistentModelID }.count
    }
    
    private func lastEntryDate(for book: JournalBook) -> Date? {
        allEntries
            .filter { $0.book?.persistentModelID == book.persistentModelID }
            .first?.createdAt
    }
    
    private func deleteBook(_ book: JournalBook) {
        let entriesInBook = (book.entries ?? []).filter { $0.deletedAt == nil }
        for e in entriesInBook {
            e.deletedAt = Date()
        }
        book.deletedAt = Date()
        try? modelContext.save()
    }
    
    private func pinBook(_ book: JournalBook) {
        let currentPinned = books.filter { $0.pinOrder > 0 }
        let nextPinOrder = (currentPinned.map(\.pinOrder).max() ?? 0) + 1
        book.pinOrder = nextPinOrder
        try? modelContext.save()
    }
    
    private func unpinBook(_ book: JournalBook) {
        book.pinOrder = 0
        try? modelContext.save()
    }
    
    private func migrateBookUUIDsIfNeeded() {
        // All existing books got the same UUID default from SwiftData schema migration.
        // Assign each book a unique UUID if it shares the same one as another book.
        var seen = Set<UUID>()
        var needsSave = false
        for book in books {
            if seen.contains(book.uuid) {
                book.uuid = UUID()
                needsSave = true
            } else {
                seen.insert(book.uuid)
            }
        }
        if needsSave {
            try? modelContext.save()
        }
    }
    
    private func migrateEntriesIntoDefaultBookIfNeeded() {
        // Goal: if user already had entries (old system), they shouldn't become "homeless".
        // We auto-create a default book and assign any entries with nil book to it.
        
        let hasHomelessEntries = allEntries.contains { $0.book == nil }
        guard hasHomelessEntries else { return }
        
        let defaultTitle = "General Journal"
        
        // Try find existing default book
        if let existing = books.first(where: { $0.title == defaultTitle }) {
            for e in allEntries where e.book == nil {
                e.book = existing
                e.updatedAt = Date()
            }
            return
        }
        
        // Create it
        let created = JournalBook(title: defaultTitle, coverHex: "#6A5CFF")
        modelContext.insert(created)
        
        // Assign
        for e in allEntries where e.book == nil {
            e.book = created
            e.updatedAt = Date()
        }
    }
    
    
    private func showPremiumRequiredMessage() {
        premiumBannerMessage = "Premium unlocks more journal books."
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showPremiumBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                showPremiumBanner = false
            }
        }
    }
    
    // MARK: - Mindful Minutes Banner

    struct MindfulMinutesBanner: View {
        let minutes: Int

        var body: some View {
            GlassCard {
                HStack(spacing: 12) {
                    Image("thought")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(LGradients.header)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mindful Minutes")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(minutes == 1 ? "1 minute logged today" : "\(minutes) minutes logged today")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }

                    Spacer()

                    Text("\(minutes)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                }
            }
        }
    }

    struct ThemeInsightsCard: View {
        var body: some View {
            GlassCard {
                HStack(spacing: 12) {
                    Image("starchart")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(LGradients.header)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme Insights")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Patterns from your journal themes and tags")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image("chevright")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }
            }
        }
    }

    // MARK: - Journal Streak Card
    
    struct JournalStreakCard: View {
        let currentStreak: Int
        let bestStreak: Int
        let journaledToday: Bool
        
        var body: some View {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 10) {
                        Image("pencilwrite")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LGradients.header)
                        
                        Text("Journal Streak")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                        Spacer()
                        
                        Text(journaledToday ? "Written today" : "Not written today")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    
                    HStack(spacing: 10) {
                        streakBubble(
                            title: currentStreak == 1 ? "Day in a row" : "Days in a row",
                            value: "\(currentStreak)"
                        )
                        
                        streakBubble(
                            title: bestStreak == 1 ? "Best day" : "Best days",
                            value: "\(bestStreak)"
                        )
                    }
                    
                    
                    Text(journaledToday ? "You've already journaled today — your streak is safe." : "Write today to keep your streak going.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                }
            }
        }
        
        @ViewBuilder
        private func streakBubble(title: String, value: String) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LColors.textSecondary)
                    .tracking(0.5)
                
                Text(value)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Overview Card
    
    struct JournalOverviewCard: View {
        let entriesThisWeek: Int
        let entriesThisYear: Int
        
        var body: some View {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image("heartsum")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.white)
                        
                        Text("Overview")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                    }
                    
                    HStack(spacing: 10) {
                        overviewBubble(label: "This Week", value: entriesThisWeek)
                        overviewBubble(label: "This Year", value: entriesThisYear)
                    }
                }
            }
        }
        
        @ViewBuilder
        private func overviewBubble(label: String, value: Int) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LColors.textSecondary)
                    .tracking(0.5)
                
                Text("\(value)")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Load More Button
    
    struct LoadMoreButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Text("Load More")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    
                    Image("chevdown")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LColors.accentGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(LGradients.header, lineWidth: 1.5)
                )
                .shadow(color: LColors.gradientPurple.opacity(0.32), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Book Card (realistic book rendering)
    
    struct JournalBookCard: View {
        let title: String
        let coverHex: String
        let entryCount: Int
        let lastDate: Date?
        let isPinned: Bool
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        
        private var coverColor: Color { Color(lunixiaHex: coverHex) }
        
        private var bookMaxWidth: CGFloat {
            horizontalSizeClass == .regular ? 330 : .infinity
        }
        
        private var bookHeight: CGFloat {
            horizontalSizeClass == .regular ? 330 : 230
        }
        
        private var bookScale: CGFloat {
            horizontalSizeClass == .regular ? 1.0 : 0.85
        }
        
        var body: some View {
            bookGraphic
                .frame(maxWidth: bookMaxWidth)
                .frame(height: bookHeight)
                .scaleEffect(bookScale)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        
        // MARK: - Book Graphic
        
        private var bookGraphic: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                ZStack {
                    // Shadow behind the whole book
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.28))
                        .blur(radius: 14)
                        .offset(x: 10, y: 12)
                    
                    // Page block (right side) — gives thickness
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.92), Color.white.opacity(0.72)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: w * 0.18, height: horizontalSizeClass == .regular ? h * 0.78 : h * 0.88)
                        .overlay(
                            VStack(spacing: 2) {
                                ForEach(0..<14, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.black.opacity(0.06))
                                        .frame(height: 1)
                                }
                                Spacer(minLength: 0)
                            }
                                .padding(.vertical, 10)
                                .opacity(0.55)
                        )
                        .offset(x: w * 0.34, y: horizontalSizeClass == .regular ? h * 0.02 : 0)
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 8, y: 8)
                    
                    // Cover (slightly narrower so pages peek out)
                    ZStack(alignment: .leading) {
                        // Base cover with subtle depth gradient
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        coverColor.opacity(0.92),
                                        coverColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Spine strip
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.35),
                                        Color.black.opacity(0.05)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: w * 0.16)
                            .overlay(
                                VStack(spacing: 6) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.10))
                                            .frame(height: 3)
                                    }
                                }
                                    .padding(.vertical, 14)
                                    .padding(.leading, 10)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    .opacity(0.7)
                            )
                        
                        
                        // Cover content
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text(title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if isPinned {
                                    Image("pin")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(.white)
                                        .padding(.top, 2)
                                }
                            }
                            
                            Text("\(entryCount) entries")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.88))
                            
                            Spacer(minLength: 0)
                            
                            // Tiny "label plate" near bottom
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 28)
                                .overlay(
                                    HStack(spacing: 8) {
                                        Image(systemName: "book.closed")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.white.opacity(0.8))
                                        Text(lastDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "New")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.85))
                                        Spacer()
                                    }
                                        .padding(.horizontal, 10)
                                )
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    }
                    .frame(width: horizontalSizeClass == .regular ? w * 0.66 : w * 0.86, height: horizontalSizeClass == .regular ? h * 0.86 : h)
                    .offset(y: horizontalSizeClass == .regular ? h * 0.02 : 0)
                    .shadow(color: Color(lunixiaHex: "#6111b8").opacity(0.24), radius: 16, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.22), radius: 14, x: 10, y: 12)
                    .rotation3DEffect(.degrees(-10), axis: (x: 0, y: 1, z: 0))
                    .offset(x: -w * 0.06)
                }
            }
        }
    }
    
    // MARK: - Book Detail View (entries inside the book)
    
    struct JournalBookDetailView: View {
        @Environment(\.modelContext) private var modelContext
        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject private var appState: AppState
        let book: JournalBook
        
        @Query private var entries: [JournalEntry]
        @Query private var prompts: [JournalPrompt]
        @Query(filter: #Predicate<JournalBook> { $0.deletedAt == nil }, sort: \JournalBook.createdAt, order: .reverse) private var allBooks: [JournalBook]
        
        @State private var showPromptSheet = false
        @State private var showStoredPromptsPopup = false
        @State private var showPromptEditorPopup = false
        @State private var previewEntryTarget: JournalEntry? = nil
        @State private var navigateToPreviewPage = false
        @State private var tagFilter: String? = nil
        @State private var editingStoredPrompt: JournalPrompt? = nil
        @State private var storedPromptDraft: String = ""
        
        // AI prompt overlay state
        @State private var promptText: String = ""
        @State private var promptLoading = false
        @State private var promptError: String?
        
        // AI analysis sheet state
        @State private var showAnalysisSheet = false
        @State private var analysisState: JournalAnalysisSheet.AnalysisState = .idle
        @State private var analysisDateKeys: [String] = []
        @State private var selectedAnalysisDateKey: String = ""
        @State private var selectedEntryForAnalysis: JournalEntry? = nil

        // Analysis screen routing
        private enum AnalysisSheetScreen {
            case landing
            case viewRecent
            case entryPicker
            case result
        }
        @State private var analysisScreen: AnalysisSheetScreen = .landing
        
        // Stored prompt feedback state
        @State private var promptShowCopied = false
        @State private var visibleEntryCount: Int = 4
        @State private var visiblePromptCount: Int = 4
        
        init(book: JournalBook) {
            self.book = book
            
            let bookID = book.persistentModelID
            _entries = Query(
                filter: #Predicate<JournalEntry> { entry in
                    entry.book?.persistentModelID == bookID &&
                    entry.deletedAt == nil
                },
                sort: \JournalEntry.createdAt,
                order: .reverse
            )
            _prompts = Query(
                filter: #Predicate<JournalPrompt> { prompt in
                    prompt.book?.persistentModelID == bookID &&
                    prompt.deletedAt == nil
                },
                sort: \JournalPrompt.createdAt,
                order: .reverse
            )
        }

        
        private var filteredEntries: [JournalEntry] {
            guard let tag = tagFilter, !tag.isEmpty else { return entries }
            return entries.filter { $0.tags.contains(tag) }
        }
        
        private var visibleEntries: [JournalEntry] {
            Array(filteredEntries.prefix(visibleEntryCount))
        }
        
        private var visiblePrompts: [JournalPrompt] {
            Array(prompts.prefix(visiblePromptCount))
        }
        
        private var shouldUseFullScreenSheets: Bool {
            UIDevice.current.userInterfaceIdiom == .pad
        }

        var body: some View {
            ZStack {
                LunixiaBackground()
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        header

                        if let tag = tagFilter {
                            tagFilterBar(tag)
                        }

                        entriesList
                            .padding(.top, tagFilter == nil ? 0 : 6)
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarBackButtonHidden(true)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: Binding(
                    get: { showStoredPromptsPopup && !shouldUseFullScreenSheets },
                    set: { if !$0 { showStoredPromptsPopup = false } }
                )) {
                    storedJournalPromptsSheet
                        .preferredColorScheme(.dark)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                .fullScreenCover(isPresented: Binding(
                    get: { showStoredPromptsPopup && shouldUseFullScreenSheets },
                    set: { if !$0 { showStoredPromptsPopup = false } }
                )) {
                    storedJournalPromptsSheet
                        .preferredColorScheme(.dark)
                }
                .sheet(isPresented: Binding(
                    get: { showPromptEditorPopup && !shouldUseFullScreenSheets },
                    set: { if !$0 { showPromptEditorPopup = false } }
                )) {
                    storedJournalPromptEditorSheet
                        .preferredColorScheme(.dark)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                .fullScreenCover(isPresented: Binding(
                    get: { showPromptEditorPopup && shouldUseFullScreenSheets },
                    set: { if !$0 { showPromptEditorPopup = false } }
                )) {
                    storedJournalPromptEditorSheet
                        .preferredColorScheme(.dark)
                }
                
                // MARK: - Journal Prompt Overlay
                if showPromptSheet {
                    journalPromptOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(10)
                }
            }
            .navigationDestination(isPresented: $navigateToPreviewPage) {
                Group {
                    if let entry = previewEntryTarget {
                        JournalBlockPreviewPage(entry: entry)
                    } else {
                        Color.clear
                            .navigationBarBackButtonHidden(true)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { showAnalysisSheet && !shouldUseFullScreenSheets },
                set: { if !$0 { showAnalysisSheet = false } }
            )) {
                analysisMasterSheet
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .preferredColorScheme(.dark)
            }
            .fullScreenCover(isPresented: Binding(
                get: { showAnalysisSheet && shouldUseFullScreenSheets },
                set: { if !$0 { showAnalysisSheet = false } }
            )) {
                analysisMasterSheet
                    .preferredColorScheme(.dark)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showPromptSheet)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showStoredPromptsPopup)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showPromptEditorPopup)
            .onAppear {
            }
            .onChange(of: tagFilter) { _, _ in
                visibleEntryCount = 4
            }
            .onChange(of: prompts) { _, _ in
                visiblePromptCount = 4
            }
        }

        private var header: some View {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                        Text(totalEntryCount == 1 ? "1 entry" : "\(totalEntryCount) entries")
                            .font(.system(size: 12, weight: .semibold))
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
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button {
                            showStoredPromptsPopup = true
                        } label: {
                            Label("Collection", image: "inbox")
                                .foregroundStyle(.white)
                        }

                        Button {
                            analysisScreen = .landing
                            selectedEntryForAnalysis = nil
                            selectedAnalysisDateKey = ""
                            analysisState = .idle
                            analysisDateKeys = []
                            showAnalysisSheet = true
                        } label: {
                            Label("Analyze", image: "dotswavy")
                                .foregroundStyle(.white)
                        }

                        Button {
                            showPromptSheet = true
                        } label: {
                            Label("Prompt", image: "linespencil")
                                .foregroundStyle(.white)
                        }
                    } label: {
                        Image("dotswavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        JournalEditorRoutePage(
                            book: book,
                            existingEntry: nil
                        )
                    } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 10)
            }
        }
        
        private func tagFilterBar(_ tag: String) -> some View {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LColors.textSecondary)
                    
                    Text("Filtered by #\(tag)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                }
                
                Spacer()
                
                Button { withAnimation { tagFilter = nil } } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(LColors.glassSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
            .padding(.horizontal, LSpacing.pageHorizontal)
            .padding(.top, 14).padding(.bottom, 8)
        }
        
        // MARK: - Overview Stats
        
        private var totalEntryCount: Int {
            entries.count
        }
        
        private var entriesThisWeek: Int {
            let cal = Calendar.autoupdatingCurrent
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
            return entries.filter { $0.createdAt >= weekStart }.count
        }
        
        private var entriesThisYear: Int {
            let cal = Calendar.autoupdatingCurrent
            let year = cal.component(.year, from: Date())
            return entries.filter { cal.component(.year, from: $0.createdAt) == year }.count
        }
        
        @ViewBuilder
        private func journalEmptyState(icon: String, message: String) -> some View {
            VStack(spacing: 14) {
                LunixiaIconView(iconId: icon, size: 44)
                    .foregroundStyle(LColors.textSecondary.opacity(0.45))
                
                Text(message)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 46)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LColors.glassSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(LColors.glassBorder, lineWidth: 1)
                    )
            )
        }
        
        private var entriesList: some View {
            VStack(spacing: 12) {
                if filteredEntries.isEmpty {
                    journalEmptyState(icon: "starnote", message: "No entries in this book yet.\nTap + to create one.")
                        .padding(.top, 20)
                } else {
                    JournalOverviewCard(entriesThisWeek: entriesThisWeek, entriesThisYear: entriesThisYear)
                        .padding(.horizontal, LSpacing.pageHorizontal)
                    
                    ForEach(visibleEntries, id: \.persistentModelID) { entry in
                        JournalCard(
                            entry: entry,
                            onView: {
                                previewEntryTarget = $0
                                navigateToPreviewPage = true
                            },
                            onTagSelect: { tagFilter = $0 },
                            onMove: { entry, destination in
                                entry.book = destination
                                entry.updatedAt = Date()
                                try? modelContext.save()
                            },
                            moveableBooks: allBooks.filter { $0.persistentModelID != entry.book?.persistentModelID }
                        )
                        .padding(.horizontal, LSpacing.pageHorizontal)
                    }
                    
                    if filteredEntries.count > visibleEntryCount {
                        LoadMoreButton {
                            visibleEntryCount += 4
                        }
                        .padding(.horizontal, LSpacing.pageHorizontal)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.top, 0)
        }
        
        // MARK: - Stored Journal Prompts Sheet
        private var storedJournalPromptsSheet: some View {
            ZStack(alignment: .top) {
                LunixiaBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Journal Prompts")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(LGradients.header)

                            Text(book.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }

                        Spacer()

                        Button {
                            editingStoredPrompt = nil
                            storedPromptDraft = ""
                            showStoredPromptsPopup = false
                            showPromptEditorPopup = true
                        } label: {
                            Text("Add")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            if prompts.isEmpty {
                                VStack(spacing: 14) {
                                    Image("sparkle")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 34, height: 34)
                                        .foregroundStyle(.white)

                                    Text("No saved prompts yet")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text("Add your first journal prompt to keep inspiration close by.")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                            } else {
                                ForEach(visiblePrompts, id: \.persistentModelID) { prompt in
                                    GlassCard(padding: 14) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Button {
                                                prompt.isCompleted.toggle()
                                                prompt.updatedAt = Date()
                                                try? modelContext.save()
                                            } label: {
                                                Image(systemName: prompt.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(prompt.isCompleted ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.textSecondary))
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.top, 1)

                                            Text(prompt.text)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(LColors.textPrimary)
                                                .multilineTextAlignment(.leading)
                                                .strikethrough(prompt.isCompleted, color: .white.opacity(0.7))
                                                .opacity(prompt.isCompleted ? 0.72 : 1)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Button {
                                                copyStoredPrompt(prompt.text)
                                            } label: {
                                                Image("copy")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundStyle(.white)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.top, 1)
                                        }
                                    }
                                    .contextMenu {
                                        Button {
                                            editingStoredPrompt = prompt
                                            storedPromptDraft = prompt.text
                                            showStoredPromptsPopup = false
                                            showPromptEditorPopup = true
                                        } label: {
                                            Text("Edit")
                                        }

                                        Button(role: .destructive) {
                                            deleteStoredPrompt(prompt)
                                        } label: {
                                            Text("Delete")
                                        }
                                    }
                                }

                                if prompts.count > visiblePromptCount {
                                    HStack {
                                        Spacer()
                                        LoadMoreButton {
                                            visiblePromptCount += 4
                                        }
                                        Spacer()
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }

                    HStack(spacing: 12) {
                        Button {
                            visiblePromptCount = 4
                            showStoredPromptsPopup = false
                        } label: {
                            Text("Close")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.18))
                }

                if promptShowCopied {
                    Text("Copied")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                        .padding(.top, 34)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        
        private var storedJournalPromptEditorSheet: some View {
            ZStack {
                LunixiaBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Text(editingStoredPrompt == nil ? "Add Prompt" : "Edit Prompt")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Prompt")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)

                            TextEditor(text: $storedPromptDraft)
                                .scrollContentBackground(.hidden)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(minHeight: 220)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }

                    HStack(spacing: 12) {
                        Button {
                            storedPromptDraft = ""
                            editingStoredPrompt = nil
                            showPromptEditorPopup = false
                            showStoredPromptsPopup = true
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            saveStoredPrompt()
                        } label: {
                            Text(editingStoredPrompt == nil ? "Save Prompt" : "Save Changes")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(storedPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(storedPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.18))
                }
            }
        }
        
        private func copyStoredPrompt(_ text: String) {
            UIPasteboard.general.string = text
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                promptShowCopied = true
            }
            
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        promptShowCopied = false
                    }
                }
            }
        }
        
        private func saveStoredPrompt() {
            let trimmed = storedPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            if let prompt = editingStoredPrompt {
                prompt.text = trimmed
                prompt.updatedAt = Date()
            } else {
                let prompt = JournalPrompt(text: trimmed, book: book)
                modelContext.insert(prompt)
            }
            
            try? modelContext.save()
            
            storedPromptDraft = ""
            editingStoredPrompt = nil
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showPromptEditorPopup = false
                showStoredPromptsPopup = true
            }
        }
        
        private func deleteStoredPrompt(_ prompt: JournalPrompt) {
            prompt.deletedAt = Date()
            prompt.updatedAt = Date()
            try? modelContext.save()
        }
        
        // MARK: - Journal Prompt Overlay
        private var journalPromptOverlay: some View {
            ZStack(alignment: .top) {
                LunixiaPopup(
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showPromptSheet = false
                        }
                    },
                    width: 460,
                    heightRatio: 0.52,
                    header: {
                        HStack {
                            Text("Journal Prompt")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(LGradients.header)

                            Spacer()
                        }
                    },
                    content: {
                        if promptLoading {
                            VStack(spacing: 14) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(1.15)

                                Text("Generating prompt…")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 26)
                        } else if let error = promptError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.red.opacity(0.8))

                                Text(error)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else if promptText.isEmpty {
                            VStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 68, height: 68)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(LColors.glassBorder, lineWidth: 1)
                                        )

                                    Image("linespencil")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .foregroundStyle(.white)
                                }

                                VStack(spacing: 6) {
                                    Text("Generate a Journal Prompt")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text("Tap the button below to receive a thoughtful writing prompt for your journal.")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 34)
                        } else if !promptText.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .center) {
                                    Text("Prompt")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(LColors.textSecondary)

                                    Spacer()

                                    Button {
                                        UIPasteboard.general.string = promptText
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            promptShowCopied = true
                                        }
                                        Task {
                                            try? await Task.sleep(for: .seconds(2))
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                promptShowCopied = false
                                            }
                                        }
                                    } label: {
                                        Image("copy")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(.white)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Text(promptText)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                    },
                    footer: {
                        HStack(spacing: 12) {
                            Button {
                                Task { await generatePrompt() }
                            } label: {
                                Text("Generate Prompt")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(LGradients.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showPromptSheet = false
                                }
                            } label: {
                                Text("Close")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                )

                if promptShowCopied {
                    Text("Copied to Clipboard")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        .padding(.top, 34)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        
        private var formattedAnalysisDateLabel: String {
            let todayKey = Self.todayAnalysisDateKey()
            guard selectedAnalysisDateKey != todayKey else { return "Today" }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: selectedAnalysisDateKey) else { return selectedAnalysisDateKey }
            
            let display = DateFormatter()
            display.dateFormat = "MMM d"
            return display.string(from: date)
        }
        
        private var analysisNavigationKeys: [String] {
            return analysisDateKeys.sorted(by: >)
        }
        
        private var selectedAnalysisDateIndex: Int? {
            analysisNavigationKeys.firstIndex(of: selectedAnalysisDateKey)
        }
        
        private var previousAnalysisDateKey: String? {
            guard let index = selectedAnalysisDateIndex else { return nil }
            let previousIndex = index + 1
            guard previousIndex < analysisNavigationKeys.count else { return nil }
            return analysisNavigationKeys[previousIndex]
        }
        
        private var nextAnalysisDateKey: String? {
            guard let index = selectedAnalysisDateIndex else { return nil }
            let nextIndex = index - 1
            guard nextIndex >= 0 else { return nil }
            return analysisNavigationKeys[nextIndex]
        }
        
        private static func todayAnalysisDateKey() -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.calendar = Calendar.autoupdatingCurrent
            formatter.timeZone = TimeZone.autoupdatingCurrent
            return formatter.string(from: Date())
        }
        
        private func loadAnalysisDates() async {
            guard let userId = appState.currentAppleUserId,
                  !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            
            let bookId = book.uuid.uuidString
            
            do {
                let dates = try await JournalAnalysisService.shared.fetchAnalysisDates(userId: userId, bookId: bookId)
                await MainActor.run {
                    analysisDateKeys = dates
                }
            } catch {
                // Silently ignore — date list failing shouldn't break the sheet
            }
        }
        
        private func loadAnalysisForSelectedDate() async {
            guard let userId = appState.currentAppleUserId,
                  !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            
            let bookId = book.uuid.uuidString
            let dateKey = selectedAnalysisDateKey.isEmpty ? Self.todayAnalysisDateKey() : selectedAnalysisDateKey
            
            await MainActor.run { analysisState = .loading }
            
            do {
                if let result = try await JournalAnalysisService.shared.fetchAnalysis(userId: userId, bookId: bookId, dateKey: dateKey) {
                    await MainActor.run {
                        analysisState = .result(
                            themes: result.themes,
                            mood: result.mood,
                            reflection: result.reflection
                        )
                    }
                } else {
                    await MainActor.run { analysisState = .empty }
                }
            } catch {
                await MainActor.run { analysisState = .error(error.localizedDescription) }
            }
        }

        private func loadMostRecentAnalysis() async {
            guard let userId = appState.currentAppleUserId,
                  !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run { analysisState = .error("You need to be signed in with Apple to use this feature.") }
                return
            }

            let bookId = book.uuid.uuidString

            do {
                let dates = try await JournalAnalysisService.shared.fetchAnalysisDates(userId: userId, bookId: bookId)
                await MainActor.run { analysisDateKeys = dates }

                guard let mostRecent = dates.sorted(by: >).first else {
                    await MainActor.run { analysisState = .empty }
                    return
                }

                await MainActor.run { selectedAnalysisDateKey = mostRecent }

                if let result = try await JournalAnalysisService.shared.fetchAnalysis(userId: userId, bookId: bookId, dateKey: mostRecent) {
                    await MainActor.run {
                        analysisState = .result(themes: result.themes, mood: result.mood, reflection: result.reflection)
                    }
                } else {
                    await MainActor.run { analysisState = .empty }
                }
            } catch {
                await MainActor.run { analysisState = .error(error.localizedDescription) }
            }
        }
        
        private func runAnalysis() async {
            await MainActor.run {
                analysisState = .loading
            }
            
            guard let userId = appState.currentAppleUserId,
                  !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run {
                    analysisState = .error("You need to be signed in with Apple to use this feature.")
                }
                return
            }
            
            guard let entry = selectedEntryForAnalysis else {
                await MainActor.run {
                    analysisState = .error("No entry selected for analysis.")
                }
                return
            }
            
            let bookId = book.uuid.uuidString
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.calendar = Calendar.autoupdatingCurrent
            formatter.timeZone = TimeZone.autoupdatingCurrent
            let targetDateKey = formatter.string(from: entry.createdAt)
            
            do {
                let result = try await JournalAnalysisService.shared.analyze(
                    userId: userId,
                    bookId: bookId,
                    dateKey: targetDateKey,
                    entries: [entry]
                )
                await MainActor.run {
                    analysisState = .result(
                        themes: result.themes,
                        mood: result.mood,
                        reflection: result.reflection
                    )
                }
                // Refresh date list so arrows update after a new generate
                if let dates = try? await JournalAnalysisService.shared.fetchAnalysisDates(userId: userId, bookId: bookId) {
                    await MainActor.run {
                        analysisDateKeys = dates
                        selectedAnalysisDateKey = targetDateKey
                    }
                }
            } catch {
                await MainActor.run {
                    let message = (error as NSError).localizedDescription
                    analysisState = .error(message.isEmpty ? "Something went wrong. Please try again." : message)
                }
            }
        }

        // MARK: - Analysis Master Sheet (landing → view recent OR pick entry → result)

        private var analysisMasterSheet: some View {
            ZStack {
                LunixiaBackground().ignoresSafeArea()

                switch analysisScreen {
                case .landing:
                    analysisLandingScreen

                case .viewRecent:
                    JournalAnalysisSheet(
                        state: analysisState,
                        onRetry: { Task { await runAnalysis() } },
                        onClose: { analysisScreen = .landing },
                        onDone: { showAnalysisSheet = false },
                        dateLabel: formattedAnalysisDateLabel,
                        hasPrevious: previousAnalysisDateKey != nil,
                        hasNext: nextAnalysisDateKey != nil,
                        onPrevious: {
                            guard let k = previousAnalysisDateKey else { return }
                            selectedAnalysisDateKey = k
                            Task { await loadAnalysisForSelectedDate() }
                        },
                        onNext: {
                            guard let k = nextAnalysisDateKey else { return }
                            selectedAnalysisDateKey = k
                            Task { await loadAnalysisForSelectedDate() }
                        }
                    )

                case .entryPicker:
                    analysisEntryPickerScreen

                case .result:
                    JournalAnalysisSheet(
                        state: analysisState,
                        onRetry: { Task { await runAnalysis() } },
                        onClose: { analysisScreen = .entryPicker },
                        onDone: { showAnalysisSheet = false },
                        dateLabel: formattedAnalysisDateLabel,
                        hasPrevious: previousAnalysisDateKey != nil,
                        hasNext: nextAnalysisDateKey != nil,
                        onPrevious: {
                            guard let k = previousAnalysisDateKey else { return }
                            selectedAnalysisDateKey = k
                            Task { await loadAnalysisForSelectedDate() }
                        },
                        onNext: {
                            guard let k = nextAnalysisDateKey else { return }
                            selectedAnalysisDateKey = k
                            Task { await loadAnalysisForSelectedDate() }
                        }
                    )
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: analysisScreen)
        }

        // ── Landing ──

        private var analysisLandingScreen: some View {
            VStack(spacing: 0) {
                HStack {
                    Text("Analysis")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                    Spacer()
                    Button { showAnalysisSheet = false } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(LGradients.header)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)

                Rectangle().fill(LColors.glassBorder).frame(height: 1)

                VStack(spacing: 14) {
                    // View Analysis button
                    Button {
                        analysisState = .loading
                        analysisScreen = .viewRecent
                        Task { await loadMostRecentAnalysis() }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LGradients.blue.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(LGradients.blue.opacity(0.5), lineWidth: 1)
                                    )
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(LGradients.header)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("View Analysis")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Load your most recent saved analysis")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            Spacer()
                            Image("chevright")
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LColors.glassSurface))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // New Analysis button
                    Button {
                        selectedEntryForAnalysis = nil
                        analysisScreen = .entryPicker
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LGradients.blue.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(LGradients.blue.opacity(0.5), lineWidth: 1)
                                    )
                                Image("pencilwrite")
                                    .renderingMode(.template)
                                    .resizable().scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(LGradients.header)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("New Analysis")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Pick an entry to generate a new analysis")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            Spacer()
                            Image("chevright")
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LColors.glassSurface))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)

                Spacer()
            }
        }

        // ── Entry Picker ──

        private var analysisEntryPickerScreen: some View {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        analysisScreen = .landing
                    } label: {
                        Image("chevleft")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(LGradients.header)
                    }.buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("New Analysis")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                        Text("Pick an entry to reflect on")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }

                    Spacer()

                    Button { showAnalysisSheet = false } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(LGradients.header)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)

                Rectangle().fill(LColors.glassBorder).frame(height: 1)

                if entries.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundStyle(LColors.textSecondary)
                        Text("No entries yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Write your first journal entry to generate an analysis.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 30)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(entries, id: \.persistentModelID) { entry in
                                entryPickerRow(entry)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .padding(.bottom, 20)
                    }
                }
            }
        }

        private func entryPickerRow(_ entry: JournalEntry) -> some View {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d, yyyy"
            let dateStr = fmt.string(from: entry.createdAt)
            let preview = entry.blockPreviewText.isEmpty ? entry.body : entry.blockPreviewText

            return Button {
                let keyFmt = DateFormatter()
                keyFmt.dateFormat = "yyyy-MM-dd"
                keyFmt.calendar = Calendar.autoupdatingCurrent
                keyFmt.timeZone = TimeZone.autoupdatingCurrent
                selectedAnalysisDateKey = keyFmt.string(from: entry.createdAt)
                analysisState = .idle
                selectedEntryForAnalysis = entry
                analysisScreen = .result
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(dateStr)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                        if !preview.isEmpty {
                            Text(preview)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(LColors.textSecondary.opacity(0.8))
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image("chevright")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(LColors.textSecondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LColors.glassSurface))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }

        private func generatePrompt() async {
            do {
                await MainActor.run {
                    promptLoading = true
                    promptError = nil
                }
                
                guard let userId = appState.currentAppleUserId,
                      !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw NSError(
                        domain: "JournalPromptService",
                        code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "You need to be signed in with Apple to generate a prompt."]
                    )
                }
                let response = try await JournalPromptService.shared.generatePrompt(userId: userId, modelContext: modelContext)
                
                await MainActor.run {
                    promptText = response.prompt
                    promptLoading = false
                }
            } catch {
                await MainActor.run {
                    promptLoading = false
                    promptError = error.localizedDescription
                }
            }
        }
    }
}
