//
//  JournalEntryDateTimePicker.swift
//  Lunixia
//
//  Custom, in-place date & time picker for a journal entry.
//  100% custom controls — no system DatePicker, no SF Symbols.
//

import SwiftUI

// MARK: - Public Picker

struct JournalEntryDateTimePicker: View {
    @Binding var date: Date
    var tint: Color = .white
    var onChange: () -> Void = {}

    @State private var expanded: Bool = false

    // Drum-backed state, kept in sync with `date`
    @State private var monthIndex: Int = 0     // 0..11
    @State private var day: Int = 1
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var hour12: Int = 12        // 1..12
    @State private var minute: Int = 0         // 0..59
    @State private var isAM: Bool = true

    @State private var suppressWriteBack: Bool = false

    private let monthNames = ["Jan","Feb","Mar","Apr","May","Jun",
                              "Jul","Aug","Sep","Oct","Nov","Dec"]

    private var yearRange: [Int] {
        let now = Calendar.current.component(.year, from: Date())
        return Array((now - 25)...(now + 5))
    }

    private var daysInSelectedMonth: Int {
        var comps = DateComponents(); comps.year = year; comps.month = monthIndex + 1
        let cal = Calendar.current
        if let d = cal.date(from: comps),
           let r = cal.range(of: .day, in: .month, for: d) {
            return r.count
        }
        return 31
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryBar

            if expanded {
                drumPanel
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .onAppear { syncStateFromDate() }
        .onChange(of: date) { _, _ in
            if !suppressWriteBack { syncStateFromDate() }
        }
    }

    // MARK: Summary bar

    private var summaryBar: some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image("calhearts")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(tint)

                Text(dateText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)

                Circle()
                    .fill(tint.opacity(0.5))
                    .frame(width: 3, height: 3)

                Image("clockwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(tint)

                Text(timeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)

                Spacer(minLength: 6)

                Image(expanded ? "chevup" : "chevdown")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
                    .foregroundStyle(tint.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(tint.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Drum panel

    private var drumPanel: some View {
        VStack(spacing: 12) {
            // Date row
            drumRow {
                WheelDrum(
                    items: Array(monthNames.indices),
                    selection: Binding(
                        get: { monthIndex },
                        set: { newValue in
                            monthIndex = newValue
                            clampDay()
                            writeBack()
                        }
                    ),
                    label: { monthNames[$0] },
                    width: 78,
                    tint: tint
                )
                drumDivider
                WheelDrum(
                    items: Array(1...daysInSelectedMonth),
                    selection: Binding(
                        get: { min(day, daysInSelectedMonth) },
                        set: { newValue in day = newValue; writeBack() }
                    ),
                    label: { String(format: "%02d", $0) },
                    width: 58,
                    tint: tint
                )
                drumDivider
                WheelDrum(
                    items: yearRange,
                    selection: Binding(
                        get: { year },
                        set: { newValue in
                            year = newValue
                            clampDay()
                            writeBack()
                        }
                    ),
                    label: { String($0) },
                    width: 74,
                    tint: tint
                )
            }

            // Time row
            drumRow {
                WheelDrum(
                    items: Array(1...12),
                    selection: Binding(
                        get: { hour12 },
                        set: { hour12 = $0; writeBack() }
                    ),
                    label: { String(format: "%d", $0) },
                    width: 58,
                    tint: tint
                )
                Text(":")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 2)
                WheelDrum(
                    items: Array(0...59),
                    selection: Binding(
                        get: { minute },
                        set: { minute = $0; writeBack() }
                    ),
                    label: { String(format: "%02d", $0) },
                    width: 58,
                    tint: tint
                )
                drumDivider
                WheelDrum(
                    items: [true, false],
                    selection: Binding(
                        get: { isAM },
                        set: { isAM = $0; writeBack() }
                    ),
                    label: { $0 ? "AM" : "PM" },
                    width: 56,
                    tint: tint
                )
            }

            // Now button
            Button {
                let now = Date()
                suppressWriteBack = true
                date = now
                syncStateFromDate()
                suppressWriteBack = false
                onChange()
            } label: {
                Text("Now")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    private func drumRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            // Center-row highlight
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .frame(height: 36)
                .padding(.horizontal, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                        .padding(.horizontal, 6)
                )

            HStack(spacing: 4) {
                content()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var drumDivider: some View {
        Rectangle()
            .fill(tint.opacity(0.18))
            .frame(width: 1, height: 22)
    }

    // MARK: Formatting

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    // MARK: Sync

    private func syncStateFromDate() {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        year = c.year ?? year
        monthIndex = max(0, min(11, (c.month ?? 1) - 1))
        day = c.day ?? 1
        let h24 = c.hour ?? 0
        isAM = h24 < 12
        let h12raw = h24 % 12
        hour12 = h12raw == 0 ? 12 : h12raw
        minute = c.minute ?? 0
    }

    private func clampDay() {
        let limit = daysInSelectedMonth
        if day > limit { day = limit }
        if day < 1 { day = 1 }
    }

    private func writeBack() {
        let cal = Calendar.current
        let hour24: Int = {
            if isAM {
                return hour12 == 12 ? 0 : hour12
            } else {
                return hour12 == 12 ? 12 : hour12 + 12
            }
        }()
        var comps = DateComponents()
        comps.year = year
        comps.month = monthIndex + 1
        comps.day = min(day, daysInSelectedMonth)
        comps.hour = hour24
        comps.minute = minute
        comps.second = 0
        if let d = cal.date(from: comps) {
            suppressWriteBack = true
            date = d
            suppressWriteBack = false
            onChange()
        }
    }
}

// MARK: - Custom Wheel Drum

struct WheelDrum<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> String
    let width: CGFloat
    var itemHeight: CGFloat = 32
    var visibleCount: Int = 5
    var tint: Color = .white

    var body: some View {
        let containerHeight = itemHeight * CGFloat(visibleCount)
        let sideMargin = (containerHeight - itemHeight) / 2

        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    Text(label(item))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint)
                        .frame(width: width, height: itemHeight)
                        .contentShape(Rectangle())
                        .scrollTransition(axis: .vertical) { view, phase in
                            view
                                .opacity(phase.isIdentity ? 1.0 : 0.28)
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.82)
                        }
                        .id(item)
                }
            }
            .scrollTargetLayout()
        }
        .frame(width: width, height: containerHeight)
        .contentMargins(.vertical, sideMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: Binding<Item?>(
            get: { selection },
            set: { new in if let new { selection = new } }
        ))
        .sensoryFeedback(.selection, trigger: selection)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.28),
                    .init(color: .black, location: 0.72),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
