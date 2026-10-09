//
//  SpiritualView.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import AVFoundation
import AudioToolbox

struct SpiritualView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DailyTarotRecord.updatedAt, order: .reverse)
    private var tarotRecords: [DailyTarotRecord]

    @Query(sort: \DailyLenormandRecord.updatedAt, order: .reverse)
    private var lenormandRecords: [DailyLenormandRecord]

    @State private var isDrawingTarot = false
    @State private var isDrawingLenormand = false
    @State private var tarotError: String? = nil
    @State private var lenormandError: String? = nil

    @State private var selectedHoroscopeTab: HoroscopeTab = .daily
    @State private var selectedHoroscopeSign = ""
    @State private var dailyHoroscope: DailyHoroscope? = nil
    @State private var previewHoroscope: DailyHoroscope? = nil
    @State private var isLoadingHoroscope = false
    @State private var horoscopeError: String? = nil
    @State private var horoscopeDayKey: String = ""
    @State private var horoscopeMidnightRefreshTask: Task<Void, Never>? = nil
    private let storedDailyHoroscopeKey = "storedDailyHoroscope"

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var zodiacSigns: [String] {
        [
            "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
            "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"
        ]
    }

    private var currentDailyTarotTip: DailyTarotTip? {
        guard let record = tarotRecords.first(where: { $0.dayKey == todayKey }) else { return nil }
        return DailyTarotTip(id: record.tipId, title: record.title, keywords: record.keywords, message: record.message)
    }

    private var currentDailyLenormandTip: DailyLenormandTip? {
        guard let record = lenormandRecords.first(where: { $0.dayKey == todayKey }) else { return nil }
        return DailyLenormandTip(id: record.tipId, title: record.title, keywords: record.keywords, message: record.message)
    }

    // MARK: - Draw Tarot

    private func drawDailyTarotTip() {
        guard currentDailyTarotTip == nil, !isDrawingTarot else { return }
        guard let card = localDailyTarotTips.randomElement() else { return }

        isDrawingTarot = true
        tarotError = nil

        Task {
            do {
                let response = try await SpiritualService.shared.fetchTarotInterpretation(cardName: card.title)
                await MainActor.run {
                    let record = DailyTarotRecord(
                        dayKey: todayKey,
                        tipId: card.id,
                        cardName: card.title,
                        title: response.title,
                        keywords: response.keywords,
                        message: response.message
                    )
                    modelContext.insert(record)
                    try? modelContext.save()
                    _ = try? LunixiaPointsManager.awardDailyTarot(
                        in: modelContext,
                        id: record.dayKey,
                        at: record.updatedAt
                    )
                    isDrawingTarot = false
                }
            } catch {
                await MainActor.run {
                    tarotError = "Couldn't draw your card right now."
                    isDrawingTarot = false
                }
            }
        }
    }

    // MARK: - Draw Lenormand

    private func drawDailyLenormandTip() {
        guard currentDailyLenormandTip == nil, !isDrawingLenormand else { return }
        guard let card = localDailyLenormandTips.randomElement() else { return }

        isDrawingLenormand = true
        lenormandError = nil

        Task {
            do {
                let response = try await SpiritualService.shared.fetchLenormandInterpretation(cardName: card.title)
                await MainActor.run {
                    let record = DailyLenormandRecord(
                        dayKey: todayKey,
                        tipId: card.id,
                        cardName: card.title,
                        title: response.title,
                        keywords: response.keywords,
                        message: response.message
                    )
                    modelContext.insert(record)
                    try? modelContext.save()
                    _ = try? LunixiaPointsManager.awardDailyLenormand(
                        in: modelContext,
                        id: record.dayKey,
                        at: record.updatedAt
                    )
                    isDrawingLenormand = false
                }
            } catch {
                await MainActor.run {
                    lenormandError = "Couldn't draw your card right now."
                    isDrawingLenormand = false
                }
            }
        }
    }
    
    // MARK: - Horoscope

    private func fetchHoroscope() {
        let trimmedSign = selectedHoroscopeSign.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSign.isEmpty else {
            horoscopeError = "Choose a zodiac sign first."
            return
        }

        horoscopeError = nil
        isLoadingHoroscope = true

        Task {
            do {
                let horoscope = try await HoroscopeService.shared.fetchHoroscope(for: trimmedSign)

                await MainActor.run {
                    if selectedHoroscopeTab == .daily {
                        dailyHoroscope = horoscope
                        horoscopeDayKey = todayKey
                        saveDailyHoroscope(horoscope)
                    } else {
                        previewHoroscope = horoscope
                    }

                    isLoadingHoroscope = false
                }
            } catch {
                await MainActor.run {
                    horoscopeError = "Couldn't load your horoscope right now."
                    isLoadingHoroscope = false
                }
            }
        }
    }

    private func resetDailyHoroscopeIfNeeded() {
        guard let stored = loadStoredDailyHoroscope() else {
            dailyHoroscope = nil
            horoscopeDayKey = todayKey
            return
        }

        if stored.dayKey == todayKey {
            dailyHoroscope = stored.horoscope
            horoscopeDayKey = stored.dayKey
        } else {
            clearStoredDailyHoroscope()
            dailyHoroscope = nil
            previewHoroscope = nil
            horoscopeError = nil
            isLoadingHoroscope = false
            selectedHoroscopeTab = .daily
            horoscopeDayKey = todayKey
        }
    }

    private func scheduleHoroscopeMidnightRefresh() {
        horoscopeMidnightRefreshTask?.cancel()

        horoscopeMidnightRefreshTask = Task { @MainActor in
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

                clearStoredDailyHoroscope()
                dailyHoroscope = nil
                previewHoroscope = nil
                horoscopeError = nil
                isLoadingHoroscope = false
                selectedHoroscopeTab = .daily
                horoscopeDayKey = todayKey
            }
        }
    }

    private func saveDailyHoroscope(_ horoscope: DailyHoroscope) {
        let stored = StoredDailyHoroscope(dayKey: todayKey, horoscope: horoscope)

        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: storedDailyHoroscopeKey)
    }

    private func loadStoredDailyHoroscope() -> StoredDailyHoroscope? {
        guard let data = UserDefaults.standard.data(forKey: storedDailyHoroscopeKey) else {
            return nil
        }

        return try? JSONDecoder().decode(StoredDailyHoroscope.self, from: data)
    }

    private func clearStoredDailyHoroscope() {
        UserDefaults.standard.removeObject(forKey: storedDailyHoroscopeKey)
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Nav
                HStack {
                    Text("Spiritual")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        MoonPhaseView(moonPhaseData: MoonPhaseCalculator.calculate())
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                        
                        MeditationTimerCard()
                            .padding(.horizontal, 16)

                        SpiritualTarotCard(
                            tip: currentDailyTarotTip,
                            isLoading: isDrawingTarot,
                            error: tarotError,
                            onDraw: drawDailyTarotTip
                        )
                        .padding(.horizontal, 16)

                        SpiritualLenormandCard(
                            tip: currentDailyLenormandTip,
                            isLoading: isDrawingLenormand,
                            error: lenormandError,
                            onDraw: drawDailyLenormandTip
                        )
                        .padding(.horizontal, 16)

                        HoroscopeView(
                            selectedTab: $selectedHoroscopeTab,
                            selectedSign: $selectedHoroscopeSign,
                            zodiacSigns: zodiacSigns,
                            dailyHoroscope: dailyHoroscope,
                            previewHoroscope: previewHoroscope,
                            isLoading: isLoadingHoroscope,
                            errorText: horoscopeError,
                            onFetch: fetchHoroscope,
                            onClearPreview: {
                                previewHoroscope = nil
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            resetDailyHoroscopeIfNeeded()
            scheduleHoroscopeMidnightRefresh()
            LunixiaMoonPhaseWidgetWriter.write()
        }
        .onDisappear {
            horoscopeMidnightRefreshTask?.cancel()
            horoscopeMidnightRefreshTask = nil
        }
    }
}

// MARK: - Meditation Timer Card

private struct MeditationTimerCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme
    
    @State private var customMinutesText = ""
    @State private var isEnteringCustomTime = false
    @State private var validationMessage: String? = nil
    
    @State private var totalSeconds = 5 * 60
    @State private var remainingSeconds = 5 * 60
    
    @State private var isRunning = false
    @State private var isPaused = false
    
    @State private var endDate: Date?
    @State private var timerTask: Task<Void, Never>?
    
    @State private var completionPlayer: AVAudioPlayer?
    
    private let dotCount = 42
    
    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        
        return min(
            1,
            max(
                0,
                Double(totalSeconds - remainingSeconds)
                / Double(totalSeconds)
            )
        )
    }
    
    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        
        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }
    
    var body: some View {
        GlassCard(padding: 20) {
            VStack(spacing: 18) {
                
                HStack(spacing: 10) {
                    
                    Image("zenlove")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: 19,
                            height: 19
                        )
                        .foregroundStyle(theme.palette.secondaryAccent)
                        .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                    
                    Text("Meditation Timer")
                        .font(
                            .system(
                                size: 20,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                    
                    Spacer()
                }
                
                dottedProgressCircle
                
                if isRunning || isPaused {
                    runningControls
                } else {
                    setupControls
                }
                
                if let validationMessage {
                    Text(validationMessage)
                        .font(
                            .system(
                                size: 12,
                                weight: .medium,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            
            guard newPhase == .active else { return }
            guard isRunning else { return }
            guard !isPaused else { return }
            
            updateRemainingTime()
            
            if remainingSeconds <= 0 {
                completeTimer()
            } else {
                startCountdownTask()
            }
        }
    }
    
    // MARK: Circle
    
    private var dottedProgressCircle: some View {
        
        ZStack {
            
            GeometryReader { geo in
                
                let diameter = min(
                    geo.size.width,
                    geo.size.height
                )
                
                let radius = diameter / 2 - 8
                
                let center = CGPoint(
                    x: geo.size.width / 2,
                    y: geo.size.height / 2
                )
                
                ForEach(0..<dotCount, id: \.self) { index in
                    
                    let fraction =
                    Double(index)
                    / Double(dotCount)
                    
                    let angle =
                    fraction * (.pi * 2)
                    - (.pi / 2)
                    
                    let x =
                    center.x
                    + CGFloat(cos(angle))
                    * radius
                    
                    let y =
                    center.y
                    + CGFloat(sin(angle))
                    * radius
                    
                    let threshold =
                    Double(index + 1)
                    / Double(dotCount)
                    
                    let dotTint = threshold <= progress
                        ? theme.palette.secondaryAccent
                        : Color.white.opacity(0.14)

                    BubblyIconMaterial(tint: dotTint)
                        .frame(
                            width: 9,
                            height: 9
                        )
                        .clipShape(Circle())
                        .position(
                            x: x,
                            y: y
                        )
                }
            }
            
            VStack(spacing: 4) {
                
                Text(formattedTime)
                    .font(
                        .system(
                            size: 31,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                
                Text(
                    isPaused
                    ? "Paused"
                    : isRunning
                    ? "Breathe"
                    : "Ready"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(LColors.textSecondary)
            }
        }
        .frame(
            width: 174,
            height: 174
        )
        .frame(maxWidth: .infinity)
    }
    
    // MARK: Setup Controls
    
    private var setupControls: some View {
        
        HStack(spacing: 10) {
            
            presetButton(minutes: 5)
            
            presetButton(minutes: 10)
            
            if isEnteringCustomTime {
                customTimeControl
            } else {
                
                Button {
                    
                    validationMessage = nil
                    customMinutesText = ""
                    isEnteringCustomTime = true
                    
                } label: {
                    
                    Text("Custom")
                        .font(
                            .system(
                                size: 13,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .bubblyIconMaterial(tint: theme.palette.secondaryAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            Color.white.opacity(0.07)
                        )
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func presetButton(
        minutes: Int
    ) -> some View {
        
        Button {
            
            startTimer(minutes: minutes)
            
        } label: {
            
            Text("\(minutes) min")
                .font(
                    .system(
                        size: 13,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                        .clipShape(Capsule())
                }
        }
        .buttonStyle(.plain)
    }
    
    private var customTimeControl: some View {
        
        HStack(spacing: 6) {
            
            TextField(
                "Min",
                text: $customMinutesText
            )
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(
                .system(
                    size: 13,
                    weight: .bold,
                    design: .rounded
                )
            )
            .foregroundStyle(LColors.textPrimary)
            .frame(
                width: 54,
                height: 40
            )
            .background(
                Color.white.opacity(0.07)
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            }
            
            Button {
                
                startCustomTimer()
                
            } label: {
                
                Image("rightwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 18,
                        height: 18
                    )
                    .foregroundStyle(.white)
                    .frame(
                        width: 40,
                        height: 40
                    )
                    .background {
                        BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                            .clipShape(Circle())
                    }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: Running Controls
    
    private var runningControls: some View {
        
        HStack(spacing: 12) {
            
            Button {
                
                if isPaused {
                    resumeTimer()
                } else {
                    pauseTimer()
                }
                
            } label: {
                
                Text(
                    isPaused
                    ? "Resume"
                    : "Pause"
                )
                .font(
                    .system(
                        size: 13,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    BubblyIconMaterial(tint: theme.palette.secondaryAccent)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            
            Button {
                
                resetTimer()
                
            } label: {
                
                Text("End")
                    .font(
                        .system(
                            size: 13,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        LColors.textPrimary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        Color.white.opacity(0.07)
                    )
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: Timer Actions
    
    private func startCustomTimer() {
        let trimmed =
        customMinutesText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        
        guard let minutes = Int(trimmed),
              (1...180).contains(minutes) else {
            
            validationMessage =
            "Enter a time from 1 to 180 minutes."
            
            return
        }
        
        startTimer(minutes: minutes)
    }
    
    private func startTimer(
        minutes: Int
    ) {
        timerTask?.cancel()
        
        let seconds = minutes * 60
        
        totalSeconds = seconds
        remainingSeconds = seconds
        
        endDate =
        Date()
            .addingTimeInterval(
                TimeInterval(seconds)
            )
        
        isRunning = true
        isPaused = false
        isEnteringCustomTime = false
        
        validationMessage = nil
        
        startCountdownTask()
    }
    
    private func startCountdownTask() {
        timerTask?.cancel()
        
        timerTask = Task { @MainActor in
            
            while !Task.isCancelled {
                
                guard isRunning else {
                    return
                }
                
                guard !isPaused else {
                    return
                }
                
                updateRemainingTime()
                
                if remainingSeconds <= 0 {
                    completeTimer()
                    return
                }
                
                do {
                    try await Task.sleep(
                        for: .milliseconds(250)
                    )
                } catch {
                    return
                }
            }
        }
    }
    
    private func updateRemainingTime() {
        guard let endDate else {
            return
        }
        
        remainingSeconds = max(
            0,
            Int(
                ceil(
                    endDate.timeIntervalSinceNow
                )
            )
        )
    }
    
    private func pauseTimer() {
        updateRemainingTime()
        
        timerTask?.cancel()
        timerTask = nil
        
        endDate = nil
        
        isPaused = true
        isRunning = true
    }
    
    private func resumeTimer() {
        guard remainingSeconds > 0 else {
            return
        }
        
        endDate =
        Date()
            .addingTimeInterval(
                TimeInterval(
                    remainingSeconds
                )
            )
        
        isPaused = false
        isRunning = true
        
        startCountdownTask()
    }
    
    private func resetTimer() {
        timerTask?.cancel()
        timerTask = nil
        
        totalSeconds = 5 * 60
        remainingSeconds = 5 * 60
        
        endDate = nil
        
        isRunning = false
        isPaused = false
        isEnteringCustomTime = false
        
        customMinutesText = ""
        validationMessage = nil
    }
    
    private func completeTimer() {
        timerTask?.cancel()
        timerTask = nil
        
        remainingSeconds = 0
        
        endDate = nil
        
        isRunning = false
        isPaused = false
        
        playCompletionTune()
    }
    
    // MARK: Completion Sound
    
    private func playCompletionTune() {
        AudioServicesPlaySystemSound(1031) // Minuet
    }
}

// MARK: - Tarot Card

private struct SpiritualTarotCard: View {
    @Environment(\.appTheme) private var theme

    let tip: DailyTarotTip?
    let isLoading: Bool
    let error: String?
    let onDraw: () -> Void

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("crystalball")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(theme.palette.indicators)
                        .bubblyIconMaterial(tint: theme.palette.indicators)

                    Text("Daily Tarot")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .bubblyIconMaterial(tint: theme.palette.indicators)
                    Spacer()
                }

                if let tip {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tip.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)

                        if !tip.keywords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("KEYWORDS")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                SpiritualKeywordWrap(keywords: tip.keywords, tint: theme.palette.indicators)
                            }
                        }

                        Text(tip.message)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if isLoading {
                    drawingState(label: "Drawing your card...", tint: theme.palette.indicators)
                } else if let error {
                    errorState(message: error, tint: theme.palette.indicators, onRetry: onDraw)
                } else {
                    emptyState(
                        prompt: "Pull your daily tarot card for today.",
                        buttonLabel: "Get Daily Card",
                        tint: theme.palette.indicators,
                        onDraw: onDraw
                    )
                }
            }
        }
    }
}

// MARK: - Lenormand Card

private struct SpiritualLenormandCard: View {
    @Environment(\.appTheme) private var theme

    let tip: DailyLenormandTip?
    let isLoading: Bool
    let error: String?
    let onDraw: () -> Void

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image("wand")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(theme.palette.primaryAction)
                        .bubblyIconMaterial(tint: theme.palette.primaryAction)

                    Text("Daily Lenormand")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .bubblyIconMaterial(tint: theme.palette.primaryAction)
                    Spacer()
                }

                if let tip {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tip.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)

                        if !tip.keywords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("KEYWORDS")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)

                                SpiritualKeywordWrap(keywords: tip.keywords, tint: theme.palette.primaryAction)
                            }
                        }

                        Text(tip.message)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if isLoading {
                    drawingState(label: "Drawing your card...", tint: theme.palette.primaryAction)
                } else if let error {
                    errorState(message: error, tint: theme.palette.primaryAction, onRetry: onDraw)
                } else {
                    emptyState(
                        prompt: "Draw your daily Lenormand insight for today.",
                        buttonLabel: "Draw Lenormand",
                        tint: theme.palette.primaryAction,
                        onDraw: onDraw
                    )
                }
            }
        }
    }
}

// MARK: - Shared sub-views

@ViewBuilder
private func drawingState(label: String, tint: Color) -> some View {
    HStack(spacing: 10) {
        ProgressView()
            .tint(tint)
            .bubblyIconMaterial(tint: tint)
        Text(label)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(LColors.textSecondary)
    }
    .padding(.vertical, 8)
}

@ViewBuilder
private func errorState(message: String, tint: Color, onRetry: @escaping () -> Void) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(message)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(LColors.textSecondary.opacity(0.7))

        Button { onRetry() } label: {
            Text("Try again")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    BubblyIconMaterial(tint: tint)
                        .clipShape(Capsule())
                }
        }
        .buttonStyle(.plain)
    }
}

@ViewBuilder
private func emptyState(prompt: String, buttonLabel: String, tint: Color, onDraw: @escaping () -> Void) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(prompt)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(LColors.textSecondary)

        Button { onDraw() } label: {
            Text(buttonLabel)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background {
                    BubblyIconMaterial(tint: tint)
                        .clipShape(Capsule())
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keyword Wrap

private struct SpiritualKeywordWrap: View {
    let keywords: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunkedKeywords, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { keyword in
                        Text(keyword)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .bubblyIconMaterial(tint: tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
                            .overlay {
                                BubblyIconMaterial(tint: tint)
                                    .mask {
                                        Capsule()
                                            .strokeBorder(lineWidth: 1)
                                    }
                            }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var chunkedKeywords: [[String]] {
        stride(from: 0, to: keywords.count, by: 3).map {
            Array(keywords[$0..<min($0 + 3, keywords.count)])
        }
    }
}
