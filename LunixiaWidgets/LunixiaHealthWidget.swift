//
//  LunixiaHealthWidget.swift
//  Lunixia
//

import WidgetKit
import SwiftUI
import OSLog


private func lunixiaHealthWidgetPrint(_ message: String) {
    print("[LunixiaHealthWidget] \(message)")
    lunixiaHealthWidgetLogger.notice("\(message, privacy: .public)")
}
private let lunixiaHealthWidgetLogger = Logger(subsystem: "com.asteriasmoons.LunixiaWidgets", category: "HealthWidget")

// MARK: - Shared Snapshot

struct LunixiaHealthWidgetSnapshot: Codable {
    var steps: Int
    var stepGoal: Int
    var waterOz: Double
    var waterGoalOz: Double
    var hrvSDNN: Double
    var lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case steps
        case stepGoal
        case waterOz
        case waterGoalOz
        case hrvSDNN
        case lastUpdated
    }

    init(
        steps: Int,
        stepGoal: Int,
        waterOz: Double,
        waterGoalOz: Double,
        hrvSDNN: Double = 0,
        lastUpdated: Date
    ) {
        self.steps = steps
        self.stepGoal = stepGoal
        self.waterOz = waterOz
        self.waterGoalOz = waterGoalOz
        self.hrvSDNN = hrvSDNN
        self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        steps = try container.decode(Int.self, forKey: .steps)
        stepGoal = try container.decode(Int.self, forKey: .stepGoal)
        waterOz = try container.decode(Double.self, forKey: .waterOz)
        waterGoalOz = try container.decode(Double.self, forKey: .waterGoalOz)
        hrvSDNN = try container.decodeIfPresent(Double.self, forKey: .hrvSDNN) ?? 0
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }
}

// MARK: - Timeline Entry

struct LunixiaHealthWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LunixiaHealthWidgetSnapshot
}

// MARK: - Provider

struct LunixiaHealthWidgetProvider: TimelineProvider {
    private let appGroupID = "group.com.asteriasmoons.Lunixia"
    private let snapshotKey = "lunixiaHealthWidgetSnapshot"

    func placeholder(in context: Context) -> LunixiaHealthWidgetEntry {
        lunixiaHealthWidgetLogger.debug("placeholder requested; family=\(String(describing: context.family), privacy: .public)")
        lunixiaHealthWidgetPrint("placeholder requested; family=\(String(describing: context.family))")

        return LunixiaHealthWidgetEntry(
            date: Date(),
            snapshot: loadSnapshot(source: "placeholder")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LunixiaHealthWidgetEntry) -> Void) {
        lunixiaHealthWidgetLogger.debug("getSnapshot requested; family=\(String(describing: context.family), privacy: .public)")
        lunixiaHealthWidgetPrint("getSnapshot requested; family=\(String(describing: context.family))")

        completion(
            LunixiaHealthWidgetEntry(
                date: Date(),
                snapshot: loadSnapshot(source: "snapshot")
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LunixiaHealthWidgetEntry>) -> Void) {
        lunixiaHealthWidgetLogger.debug("getTimeline requested; family=\(String(describing: context.family), privacy: .public)")
        lunixiaHealthWidgetPrint("getTimeline requested; family=\(String(describing: context.family))")

        let snapshot = loadSnapshot(source: "timeline")
        lunixiaHealthWidgetLogger.debug("timeline snapshot values: steps=\(snapshot.steps, privacy: .public), stepGoal=\(snapshot.stepGoal, privacy: .public), waterOz=\(snapshot.waterOz, privacy: .public), waterGoalOz=\(snapshot.waterGoalOz, privacy: .public), updated=\(snapshot.lastUpdated.description, privacy: .public)")
        lunixiaHealthWidgetPrint("timeline snapshot values: steps=\(snapshot.steps), stepGoal=\(snapshot.stepGoal), waterOz=\(snapshot.waterOz), waterGoalOz=\(snapshot.waterGoalOz), updated=\(snapshot.lastUpdated)")

        let entry = LunixiaHealthWidgetEntry(
            date: Date(),
            snapshot: snapshot
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        lunixiaHealthWidgetLogger.debug("timeline scheduled next refresh at \(nextRefresh.description, privacy: .public)")
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot(source: String) -> LunixiaHealthWidgetSnapshot {
        lunixiaHealthWidgetLogger.debug("loadSnapshot called from \(source, privacy: .public); appGroupID=\(appGroupID, privacy: .public); key=\(snapshotKey, privacy: .public)")
        lunixiaHealthWidgetPrint("loadSnapshot called from \(source); appGroupID=\(appGroupID); key=\(snapshotKey)")

        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            lunixiaHealthWidgetLogger.error("App Group UserDefaults is nil. Check App Groups entitlement on BOTH app target and widget target: \(appGroupID, privacy: .public)")
            lunixiaHealthWidgetPrint("ERROR: App Group UserDefaults is nil. Check App Groups entitlement on BOTH app target and widget target: \(appGroupID)")
            return fallbackSnapshot(reason: "missing app group defaults")
        }

        guard let data = defaults.data(forKey: snapshotKey) else {
            lunixiaHealthWidgetLogger.error("No snapshot data found for key \(snapshotKey, privacy: .public). Main app has not written widget data yet or widget is reading a different App Group.")
            lunixiaHealthWidgetPrint("ERROR: No snapshot data found for key \(snapshotKey). Main app has not written widget data yet or widget is reading a different App Group.")
            return fallbackSnapshot(reason: "missing data")
        }

        lunixiaHealthWidgetLogger.debug("Found snapshot data. byteCount=\(data.count, privacy: .public)")
        lunixiaHealthWidgetPrint("Found snapshot data. byteCount=\(data.count)")

        do {
            let snapshot = try JSONDecoder().decode(LunixiaHealthWidgetSnapshot.self, from: data)
            lunixiaHealthWidgetLogger.debug("Decoded snapshot successfully: steps=\(snapshot.steps, privacy: .public), stepGoal=\(snapshot.stepGoal, privacy: .public), waterOz=\(snapshot.waterOz, privacy: .public), waterGoalOz=\(snapshot.waterGoalOz, privacy: .public), lastUpdated=\(snapshot.lastUpdated.description, privacy: .public)")
            lunixiaHealthWidgetPrint("Decoded snapshot successfully: steps=\(snapshot.steps), stepGoal=\(snapshot.stepGoal), waterOz=\(snapshot.waterOz), waterGoalOz=\(snapshot.waterGoalOz), lastUpdated=\(snapshot.lastUpdated)")
            return snapshot
        } catch {
            lunixiaHealthWidgetLogger.error("Failed to decode snapshot: \(error.localizedDescription, privacy: .public)")
            lunixiaHealthWidgetPrint("ERROR: Failed to decode snapshot: \(error.localizedDescription)")
            return fallbackSnapshot(reason: "decode failed")
        }
    }

    private func fallbackSnapshot(reason: String) -> LunixiaHealthWidgetSnapshot {
        lunixiaHealthWidgetLogger.debug("Using fallback snapshot. reason=\(reason, privacy: .public)")
        lunixiaHealthWidgetPrint("Using fallback snapshot. reason=\(reason)")

        return LunixiaHealthWidgetSnapshot(
            steps: 0,
            stepGoal: 10_000,
            waterOz: 0,
            waterGoalOz: 64,
            hrvSDNN: 0,
            lastUpdated: Date()
        )
    }
}

// MARK: - Shared Helpers

private func healthWidgetProgress(_ current: Double, _ goal: Double) -> Double {
    guard goal > 0 else { return 0 }
    return min(max(current / goal, 0), 1)
}

private func healthWidgetCompactNumber(_ number: Int) -> String {
    if number >= 10_000 { return String(format: "%.1fk", Double(number) / 1000) }
    if number >= 1000 { return "\(number / 1000)k" }
    return "\(number)"
}

private func healthWidgetWholeOunces(_ ounces: Double) -> Int {
    guard ounces.isFinite else { return 0 }
    return max(0, Int(ounces.rounded()))
}

// MARK: - Dotted Gradient Ring

struct DottedProgressRing: View {
    let progress: Double
    let dotCount: Int
    let size: CGFloat
    let dotSize: CGFloat

    private var activeDots: Int {
        Int((progress * Double(dotCount)).rounded(.up))
    }

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                let isActive = index < activeDots
                let angle = Double(index) / Double(dotCount) * 360

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
                    .offset(y: -(size / 2 - dotSize))
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Shared Sub-Views

private struct HealthWidgetHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("medsymbol")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(LGradients.header)

            Text("Health")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)

            Spacer()
        }
    }
}


private struct HealthWidgetUpdatedText: View {
    let date: Date
    var body: some View {
        Text("Updated \(date, style: .time)")
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(LColors.textSecondary.opacity(0.65))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SmallWidgetRing: View {
    let progress: Double
    let icon: String

    private let dotCount = 24

    private var activeDots: Int {
        Int((progress * Double(dotCount)).rounded(.up))
    }

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                let angle = Double(index) / Double(dotCount) * 360
                let isActive = index < activeDots

                Circle()
                    .fill(
                        isActive
                        ? AnyShapeStyle(LGradients.header)
                        : AnyShapeStyle(LColors.glassSurface2)
                    )
                    .frame(width: 6, height: 6)
                    .offset(y: -32)
                    .rotationEffect(.degrees(angle))
            }

            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(LGradients.header)
        }
        .frame(width: 72, height: 72)
    }
}

// showLabel: false for small/medium (icons are self-explanatory),
// true for large (extra space allows it and matches the goal rows below).
private struct HealthMetricRing: View {
    let icon: String
    let value: String
    let unit: String
    let progress: Double
    let dotCount: Int
    let size: CGFloat
    var showLabel: Bool = false
    var labelText: String = ""

    var body: some View {
        VStack(spacing: showLabel ? 5 : 2) {
            ZStack {
                DottedProgressRing(
                    progress: progress,
                    dotCount: dotCount,
                    size: size,
                    dotSize: size * 0.055
                )

                VStack(spacing: 2) {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.22, height: size * 0.22)
                        .foregroundStyle(LGradients.header)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.system(size: size * 0.20, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)

                        if !unit.isEmpty {
                            Text(unit)
                                .font(.system(size: size * 0.11, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: size * 0.10, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.75))
                }
                .frame(width: size * 0.72)
            }
            .frame(width: size, height: size)

            if showLabel {
                Text(labelText)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private let lunixiaBodyEmotionColor = Color(red: 0.3176, green: 1.0, blue: 0.8902) // #51FFE3

private struct BodyEmotionWidgetStateInfo {
    let title: String
    let message: String
    let progress: Double
}

private func bodyEmotionWidgetStateInfo(
    for hrv: Double,
    labels: (high: String, steady: String, soft: String, low: String, waiting: String),
    messages: (high: String, steady: String, soft: String, low: String, waiting: String)
) -> BodyEmotionWidgetStateInfo {
    guard hrv > 0 else {
        return BodyEmotionWidgetStateInfo(title: labels.waiting, message: messages.waiting, progress: 0.18)
    }

    switch hrv {
    case 70...:
        return BodyEmotionWidgetStateInfo(title: labels.high, message: messages.high, progress: 0.92)
    case 45..<70:
        return BodyEmotionWidgetStateInfo(title: labels.steady, message: messages.steady, progress: 0.72)
    case 25..<45:
        return BodyEmotionWidgetStateInfo(title: labels.soft, message: messages.soft, progress: 0.48)
    default:
        return BodyEmotionWidgetStateInfo(title: labels.low, message: messages.low, progress: 0.28)
    }
}

private struct BodyEmotionWidgetDottedRing: View {
    let progress: Double
    var size: CGFloat = 58
    var dotCount: Int = 30
    var dotSize: CGFloat = 4.5

    private var activeDots: Int {
        Int((min(max(progress, 0), 1) * Double(dotCount)).rounded())
    }

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                let isActive = index < activeDots
                let angle = Double(index) / Double(dotCount) * 360

                Circle()
                    .fill(isActive ? AnyShapeStyle(lunixiaBodyEmotionColor) : AnyShapeStyle(LColors.glassSurface2))
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: isActive ? lunixiaBodyEmotionColor.opacity(0.45) : .clear, radius: 2)
                    .offset(y: -(size / 2 - dotSize))
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct BodyEmotionWidgetTile: View {
    let title: String
    let state: BodyEmotionWidgetStateInfo

    var body: some View {
        VStack(spacing: 5) {
            BodyEmotionWidgetDottedRing(
                progress: state.progress,
                size: 56,
                dotCount: 30,
                dotSize: 4.5
            )

            Text(title)
                .font(.system(size: 9.5, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(state.title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(lunixiaBodyEmotionColor)
                .shadow(color: lunixiaBodyEmotionColor.opacity(0.35), radius: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(state.message)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct HealthGoalRow: View {
    let icon: String
    let title: String
    let current: String
    let goal: String

    var body: some View {
        HStack(spacing: 10) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(LGradients.header)

            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)

            Spacer()

            Text("\(current) / \(goal)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LColors.glassSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - containerBackground Helper

private extension View {
    func lunixiaContainerBackground() -> some View {
        self.containerBackground(for: .widget) {
            LColors.bg
        }
    }
}

// MARK: - Small Widget Views (systemSmall)
// Two separate small widgets — one for water, one for steps.

struct LunixiaHealthWaterSmallWidgetView: View {
    let entry: LunixiaHealthWidgetEntry
    private var s: LunixiaHealthWidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(spacing: 8) {
            SmallWidgetRing(
                progress: healthWidgetProgress(s.waterOz, s.waterGoalOz),
                icon: "wbottle"
            )

            Text("\(healthWidgetWholeOunces(s.waterOz))/\(healthWidgetWholeOunces(s.waterGoalOz))")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .containerBackground(for: .widget) { LColors.bg }
    }
}

struct LunixiaHealthStepsSmallWidgetView: View {
    let entry: LunixiaHealthWidgetEntry
    private var s: LunixiaHealthWidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(spacing: 8) {
            SmallWidgetRing(
                progress: healthWidgetProgress(Double(s.steps), Double(s.stepGoal)),
                icon: "shoefill"
            )

            Text("\(s.steps)/\(s.stepGoal)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .containerBackground(for: .widget) { LColors.bg }
    }
}

// MARK: - Medium Widget View (systemMedium)

struct LunixiaHealthMediumWidgetView: View {
    let entry: LunixiaHealthWidgetEntry
    private var s: LunixiaHealthWidgetSnapshot { entry.snapshot }

    var body: some View {
        let _ = lunixiaHealthWidgetLogger.debug("Rendering MEDIUM widget: steps=\(s.steps, privacy: .public), waterOz=\(s.waterOz, privacy: .public), updated=\(s.lastUpdated.description, privacy: .public)")
        let _ = lunixiaHealthWidgetPrint("Rendering MEDIUM widget: steps=\(s.steps), waterOz=\(s.waterOz), updated=\(s.lastUpdated)")

        VStack(spacing: 8) {
            HealthWidgetHeader()

            HStack(spacing: 0) {
                HealthMetricRing(
                    icon: "bottle",
                    value: "\(healthWidgetWholeOunces(s.waterOz))",
                    unit: "oz",
                    progress: healthWidgetProgress(s.waterOz, s.waterGoalOz),
                    dotCount: 44,
                    size: 100
                )

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(LColors.glassBorder)
                    .frame(width: 1, height: 80)

                HealthMetricRing(
                    icon: "shoe",
                    value: "\(s.steps)",
                    unit: "",
                    progress: healthWidgetProgress(Double(s.steps), Double(s.stepGoal)),
                    dotCount: 44,
                    size: 100
                )
            }

            HealthWidgetUpdatedText(date: s.lastUpdated)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .lunixiaContainerBackground()
    }
}

// MARK: - Body & Emotional State Medium Widget View (systemMedium)

struct LunixiaBodyEmotionMediumWidgetView: View {
    let entry: LunixiaHealthWidgetEntry
    private var s: LunixiaHealthWidgetSnapshot { entry.snapshot }

    private var bodyState: BodyEmotionWidgetStateInfo {
        bodyEmotionWidgetStateInfo(
            for: s.hrvSDNN,
            labels: (
                high: "Rested",
                steady: "Steady",
                soft: "Tender",
                low: "Rest-Oriented",
                waiting: "Waiting"
            ),
            messages: (
                high: "Your body seems well-supported.",
                steady: "Your body looks balanced.",
                soft: "A gentler pace may help.",
                low: "Extra care may feel good.",
                waiting: "Waiting for HRV."
            )
        )
    }

    private var emotionalState: BodyEmotionWidgetStateInfo {
        bodyEmotionWidgetStateInfo(
            for: s.hrvSDNN,
            labels: (
                high: "Settled",
                steady: "Balanced",
                soft: "Sensitive",
                low: "Soothe Mode",
                waiting: "Waiting"
            ),
            messages: (
                high: "Your system seems grounded.",
                steady: "Your rhythm looks steady.",
                soft: "Things may feel deeper.",
                low: "A slower pace may support you.",
                waiting: "Waiting for HRV."
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image("heartfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(lunixiaBodyEmotionColor)

                Text("Body & Emotional State")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(lunixiaBodyEmotionColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 2)

                Text(s.hrvSDNN > 0 ? "HRV" : "No HRV")
                    .font(.system(size: 8.5, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.6))
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 10) {
                BodyEmotionWidgetTile(title: "Body State", state: bodyState)

                Rectangle()
                    .fill(LColors.glassBorder.opacity(0.75))
                    .frame(width: 1)
                    .frame(maxHeight: 92)

                BodyEmotionWidgetTile(title: "Emotional State", state: emotionalState)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 13)
        .padding(.top, 13)
        .padding(.bottom, 10)
        .containerBackground(for: .widget) {
            LunixiaBackground()
        }
    }
}

// MARK: - Body & Emotional State Large Widget View (systemLarge)

struct LunixiaBodyEmotionLargeWidgetView: View {
    let entry: LunixiaHealthWidgetEntry
    private var s: LunixiaHealthWidgetSnapshot { entry.snapshot }

    private var bodyState: BodyEmotionWidgetStateInfo {
        bodyEmotionWidgetStateInfo(
            for: s.hrvSDNN,
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

    private var emotionalState: BodyEmotionWidgetStateInfo {
        bodyEmotionWidgetStateInfo(
            for: s.hrvSDNN,
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image("heartfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(lunixiaBodyEmotionColor)

                Text("Body & Emotional State")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(lunixiaBodyEmotionColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Text(s.hrvSDNN > 0 ? "HRV" : "No HRV")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.62))
                    .lineLimit(1)
            }

            HStack(alignment: .top, spacing: 16) {
                BodyEmotionLargeWidgetTile(title: "Body State", state: bodyState)

                Rectangle()
                    .fill(LColors.glassBorder.opacity(0.75))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)

                BodyEmotionLargeWidgetTile(title: "Emotional State", state: emotionalState)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Text(s.hrvSDNN > 0 ? "Based on today’s HRV rhythm." : "Open Lunixia Health after HealthKit has an HRV reading for today.")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.58))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .containerBackground(for: .widget) {
            LunixiaBackground()
        }
    }
}

private struct BodyEmotionLargeWidgetTile: View {
    let title: String
    let state: BodyEmotionWidgetStateInfo

    var body: some View {
        VStack(spacing: 10) {
            BodyEmotionWidgetDottedRing(
                progress: state.progress,
                size: 104,
                dotCount: 40,
                dotSize: 5.5
            )

            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(state.title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(lunixiaBodyEmotionColor)
                .shadow(color: lunixiaBodyEmotionColor.opacity(0.35), radius: 5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(state.message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Large Widget View (systemLarge) — exactly as it was when you said it was perfect

struct LunixiaHealthLargeWidgetView: View {
    let entry: LunixiaHealthWidgetEntry
    private var s: LunixiaHealthWidgetSnapshot { entry.snapshot }

    var body: some View {
        let _ = lunixiaHealthWidgetLogger.debug("Rendering LARGE widget: steps=\(s.steps, privacy: .public), stepGoal=\(s.stepGoal, privacy: .public), waterOz=\(s.waterOz, privacy: .public), waterGoalOz=\(s.waterGoalOz, privacy: .public), updated=\(s.lastUpdated.description, privacy: .public)")
        let _ = lunixiaHealthWidgetPrint("Rendering LARGE widget: steps=\(s.steps), stepGoal=\(s.stepGoal), waterOz=\(s.waterOz), waterGoalOz=\(s.waterGoalOz), updated=\(s.lastUpdated)")

        VStack(spacing: 18) {
            HealthWidgetHeader()

            HStack(spacing: 24) {
                HealthMetricRing(
                    icon: "bottle",
                    value: "\(healthWidgetWholeOunces(s.waterOz))",
                    unit: "oz",
                    progress: healthWidgetProgress(s.waterOz, s.waterGoalOz),
                    dotCount: 58,
                    size: 128,
                    showLabel: true,
                    labelText: "Water"
                )

                HealthMetricRing(
                    icon: "shoe",
                    value: "\(s.steps)",
                    unit: "",
                    progress: healthWidgetProgress(Double(s.steps), Double(s.stepGoal)),
                    dotCount: 58,
                    size: 128,
                    showLabel: true,
                    labelText: "Steps"
                )
            }

            VStack(spacing: 10) {
                HealthGoalRow(
                    icon: "bottle",
                    title: "Water Goal",
                    current: "\(healthWidgetWholeOunces(s.waterOz)) oz",
                    goal: "\(healthWidgetWholeOunces(s.waterGoalOz)) oz"
                )

                HealthGoalRow(
                    icon: "shoe",
                    title: "Step Goal",
                    current: "\(s.steps)",
                    goal: "\(s.stepGoal)"
                )
            }

            HealthWidgetUpdatedText(date: s.lastUpdated)
        }
        .padding(18)
        .lunixiaContainerBackground()
    }
}

// MARK: - Accessory Rectangular Widget View (lock screen / StandBy)

struct LunixiaHealthAccessoryRectWidgetView: View {
    let entry: LunixiaHealthWidgetEntry
    private var s: LunixiaHealthWidgetSnapshot { entry.snapshot }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label("\(healthWidgetWholeOunces(s.waterOz)) oz", systemImage: "drop.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                ProgressView(value: healthWidgetProgress(s.waterOz, s.waterGoalOz))
                    .tint(.white)
                    .scaleEffect(x: 1, y: 0.7)
            }

            VStack(alignment: .leading, spacing: 2) {
                Label("\(s.steps)", systemImage: "figure.walk")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                ProgressView(value: healthWidgetProgress(Double(s.steps), Double(s.stepGoal)))
                    .tint(.white)
                    .scaleEffect(x: 1, y: 0.7)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widget Configurations

struct LunixiaHealthWaterSmallWidget: Widget {
    let kind = "LunixiaHealthWaterSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunixiaHealthWidgetProvider()) { entry in
            LunixiaHealthWaterSmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Water")
        .description("Today's water intake at a glance.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct LunixiaHealthStepsSmallWidget: Widget {
    let kind = "LunixiaHealthStepsSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunixiaHealthWidgetProvider()) { entry in
            LunixiaHealthStepsSmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Today's step count at a glance.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct LunixiaHealthMediumWidget: Widget {
    let kind = "LunixiaHealthMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunixiaHealthWidgetProvider()) { entry in
            LunixiaHealthMediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Health — Medium")
        .description("Water and step progress.")
        .supportedFamilies([.systemMedium])
    }
}

struct LunixiaBodyEmotionMediumWidget: Widget {
    let kind = "LunixiaBodyEmotionMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunixiaHealthWidgetProvider()) { entry in
            LunixiaBodyEmotionMediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Body & Emotional State")
        .description("Kind HRV-based body and emotional state rings.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct LunixiaBodyEmotionLargeWidget: Widget {
    let kind = "LunixiaBodyEmotionLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunixiaHealthWidgetProvider()) { entry in
            LunixiaBodyEmotionLargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Body & Emotional State")
        .description("A larger HRV-based body and emotional state view with dotted rings.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct LunixiaHealthLargeWidget: Widget {
    let kind = "LunixiaHealthLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunixiaHealthWidgetProvider()) { entry in
            LunixiaHealthLargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Health — Large")
        .description("Full rings plus goal progress rows.")
        .supportedFamilies([.systemLarge])
    }
}

struct LunixiaHealthAccessoryRectWidget: Widget {
    let kind = "LunixiaHealthAccessoryRectWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunixiaHealthWidgetProvider()) { entry in
            LunixiaHealthAccessoryRectWidgetView(entry: entry)
        }
        .configurationDisplayName("Health — Lock Screen")
        .description("Compact water and step bars for the lock screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// Convenience typealias kept for LunixiaWidgets.swift compatibility.
typealias LunixiaHealthWidget = LunixiaHealthMediumWidget

// MARK: - Vitals Widget
// LunixiaVitalsWidgetSnapshot is defined in HealthKitManager.swift
// which is added to both the Lunixia and LunixiaWidgets targets.

struct LunixiaVitalsWidgetSnapshot: Codable {
    var bloodOxygen: Double
    var bpm: Double
    var systolic: Double
    var diastolic: Double
    var bodyTemp: Double
    var weight: Double
    var lastUpdated: Date
}

struct LunixiaVitalsWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LunixiaVitalsWidgetSnapshot
}

struct LunixiaVitalsMediumWidgetProvider: TimelineProvider {
    private let appGroupID  = "group.com.asteriasmoons.Lunixia"
    private let snapshotKey = "lunixiaVitalsWidgetSnapshot"

    func placeholder(in context: Context) -> LunixiaVitalsWidgetEntry {
        LunixiaVitalsWidgetEntry(date: Date(), snapshot: fallback)
    }
    func getSnapshot(in context: Context, completion: @escaping (LunixiaVitalsWidgetEntry) -> Void) {
        completion(LunixiaVitalsWidgetEntry(date: Date(), snapshot: read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LunixiaVitalsWidgetEntry>) -> Void) {
        let entry = LunixiaVitalsWidgetEntry(date: Date(), snapshot: read())
        let next  = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    private func read() -> LunixiaVitalsWidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data     = defaults.data(forKey: snapshotKey),
            let decoded  = try? JSONDecoder().decode(LunixiaVitalsWidgetSnapshot.self, from: data)
        else { return fallback }
        return decoded
    }
    private var fallback: LunixiaVitalsWidgetSnapshot {
        LunixiaVitalsWidgetSnapshot(
            bloodOxygen: 0, bpm: 0, systolic: 0,
            diastolic: 0, bodyTemp: 0, weight: 0,
            lastUpdated: Date()
        )
    }
}

// MARK: - Vitals Medium Widget View

struct LunixiaHealthVitalsMediumWidgetView: View {
    let entry: LunixiaVitalsWidgetEntry
    private var s: LunixiaVitalsWidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header
            HStack(spacing: 8) {
                Image("scope")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(LGradients.header)
                Text("Vitals")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(LGradients.header)
                Spacer()
                Text("Updated \(s.lastUpdated, style: .time)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.55))
            }

            // Metric grid — 3 columns × 2 rows
            let metrics: [(String, String)] = [
                (s.bloodOxygen == 0 ? "--" : "\(Int(s.bloodOxygen))%",  "SpO2"),
                (s.systolic    == 0 ? "--" : "\(Int(s.systolic))",       "Systolic"),
                (s.diastolic   == 0 ? "--" : "\(Int(s.diastolic))",      "Diastolic"),
                (s.bpm         == 0 ? "--" : "\(Int(s.bpm)) bpm",        "BPM"),
                (s.bodyTemp    == 0 ? "--" : String(format: "%.1f°F", s.bodyTemp), "Temp"),
                (s.weight      == 0 ? "--" : String(format: "%.1f lbs", s.weight), "Weight"),
            ]

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(metrics, id: \.1) { value, label in
                    GlassCard(cornerRadius: 12, padding: 8) {
                        VStack(spacing: 2) {
                            Text(value)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(value == "--" ? LColors.textSecondary.opacity(0.35) : LColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(label)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .containerBackground(for: .widget) {
            LunixiaBackground()
        }
    }
}

// MARK: - Vitals Medium Widget Configuration

struct LunixiaHealthVitalsMediumWidget: Widget {
    let kind = "LunixiaHealthVitalsMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunixiaVitalsMediumWidgetProvider()) { entry in
            LunixiaHealthVitalsMediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Vitals")
        .description("Your latest vitals at a glance.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
