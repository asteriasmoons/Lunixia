//
//  LunixiaComponents.swift
//  Lunixia
//

import SwiftUI

// MARK: - Alternative Lunixia Background

struct LunixiaBackgroundAlt: View {
    var body: some View {
        ZStack {
            LColors.bgSoft
                .ignoresSafeArea()
            
            LGradients.bgPurple
                .blendMode(.screen)
                .ignoresSafeArea()
            
            LGradients.bgCyan
                .blendMode(.screen)
                .ignoresSafeArea()
            
            LGradients.bgYellow
                .blendMode(.screen)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.clear,
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            Rectangle()
                .fill(Color.white.opacity(0.015))
                .blendMode(.softLight)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Premium Blur Overlay

struct LunixiaPremiumBlurOverlay: View {
    var cornerRadius: CGFloat = LSpacing.cardRadius
    var blurOpacity: Double = 0.72
    var showBadge: Bool = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(blurOpacity)

            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.34))

            if showBadge {
                HStack(spacing: 6) {
                    Image("heartlock")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)

                    Text("Premium")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.42))
                )
                .overlay(
                    Capsule()
                        .stroke(LColors.accentGradient, lineWidth: 1)
                )
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(true)
    }
}

// MARK: - FAB (Floating Action Button)

struct FloatingActionButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LGradients.header
                )
                .clipShape(Circle())
                .shadow(color: LColors.accentHover.opacity(0.22), radius: 15, y: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Tile

struct GlassTile<Content: View>: View {
    @Environment(\.appTheme) private var theme

    var cornerRadius: CGFloat = 10
    var borderColor: Color? = nil
    var borderWidth: CGFloat = 1
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.palette.raisedSurface)
            }
            .overlay {
                if let borderColor {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                }
            }
    }
}

// MARK: - Glass Text Field

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    
    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .foregroundStyle(LColors.textPrimary)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.46), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous))
    }
}

// MARK: - Load More Button

struct LoadMoreButton: View {
    var title: String = "Load More"
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(AnyShapeStyle(LGradients.header))
                .clipShape(Capsule())
                .shadow(color: LColors.accent.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lunixia Button

struct LButton: View {
    let title: String
    var icon: String? = nil
    var style: LButtonStyle = .primary
    var action: () -> Void
    
    enum LButtonStyle {
        case primary, secondary, success, danger, gradient
    }
    
    private var bgColor: AnyShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(LColors.accent)
            
        case .secondary:
            return AnyShapeStyle(Color.white.opacity(0.1))
            
        case .success:
            return AnyShapeStyle(LColors.success)
            
        case .danger:
            return AnyShapeStyle(LColors.danger)
            
        case .gradient:
            return AnyShapeStyle(LGradients.header)
        }
    }
    
    private var fgColor: Color {
        switch style {
        case .secondary:
            return LColors.textPrimary
            
        default:
            return .white
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(fgColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                bgColor,
                in: RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                    .stroke(
                        style == .secondary
                        ? LColors.glassBorder
                        : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DELETE CONFIRMATION DIALOGUE

struct LunixiaAlertConfirm: ViewModifier {
    @Binding var isPresented: Bool

    let title: String
    let message: String
    let confirmTitle: String
    let confirmRole: ButtonRole?
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button(confirmTitle, role: confirmRole) {
                    onConfirm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(message)
            }
    }
}

extension View {
    func lunixiaAlertConfirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "Delete",
        confirmRole: ButtonRole? = .destructive,
        onConfirm: @escaping () -> Void
    ) -> some View {
        self.modifier(
            LunixiaAlertConfirm(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                confirmRole: confirmRole,
                onConfirm: onConfirm
            )
        )
    }
}

// MARK: - Gradient Title

struct GradientTitle: View {
    let text: String
    var size: CGFloat = 28
    var fontName: String = "LilyScriptOne-Regular"

    var body: some View {
        Text(text)
            .font(.custom(fontName, size: size))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        LColors.gradientBlue,
                        LColors.gradientPurple
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(
                color: LColors.gradientPurple.opacity(0.18),
                radius: 8,
                y: 4
            )
    }
}

// MARK: - Lunixia Color Pop Up Container

struct LunixiaColorPopup<Header: View, Content: View, Footer: View>: View {
    let onClose: () -> Void
    let width: CGFloat
    let heightRatio: CGFloat
    let noteColor: Color

    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            onClose()
                        }
                    }

                VStack(alignment: .leading, spacing: 18) {
                    header()

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            content()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .scrollBounceBehavior(.basedOnSize)

                    footer()
                }
                .padding(22)
                .frame(
                    width: max(
                        0,
                        min(
                            proxy.size.width.isFinite
                                ? proxy.size.width - 40
                                : width,
                            width
                        )
                    ),
                    alignment: .topLeading
                )
                .frame(
                    maxHeight: proxy.size.height * heightRatio,
                    alignment: .topLeading
                )
                .background(noteColor)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center
            )
        }
    }
}

// MARK: - Lunixia Popup (Reusable)

struct LunixiaPopup<Header: View, Content: View, Footer: View>: View {
    let onClose: () -> Void
    let width: CGFloat
    let heightRatio: CGFloat
    
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            onClose()
                        }
                    }

                VStack(alignment: .leading, spacing: 18) {
                    header()

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            content()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .scrollBounceBehavior(.basedOnSize)

                    footer()
                }
                .padding(LSpacing.cardPadding)
                .frame(
                    width: max(
                        0,
                        min(
                            proxy.size.width.isFinite
                            ? proxy.size.width - 40
                            : width,
                            width
                        )
                    ),
                    alignment: .topLeading
                )
                .frame(
                    maxHeight: proxy.size.height * heightRatio,
                    alignment: .topLeading
                )
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LColors.bgSoft)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            LColors.gradientBlue.opacity(0.22),
                                            LColors.gradientPurple.opacity(0.26),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            LColors.gradientBlue.opacity(0.92),
                                            LColors.gradientPurple.opacity(0.92),
                                            Color.white.opacity(0.38)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.05
                                )
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: LColors.gradientBlue.opacity(0.18), radius: 16, y: 8)
                .shadow(color: LColors.gradientPurple.opacity(0.14), radius: 18, y: 10)
                .transition(
                    .opacity.combined(with: .scale(scale: 0.96))
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Lunixia Background

struct LunixiaBackground: View {
    var body: some View {
        LColors.bg
            .ignoresSafeArea()
    }
}

// MARK: - Gradient Time Drum Picker

struct LunixiaGradientTimeDrumPicker: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var tint: Color? = nil
    var usesDarkTypography: Bool = false

    private let isCompact: Bool
    
    @State private var displayHour: Int = 9
    @State private var meridiem: String = "AM"
    
    private let meridiems = ["AM", "PM"]

    init(
        hour: Binding<Int>,
        minute: Binding<Int>,
        tint: Color? = nil,
        usesDarkTypography: Bool = false,
        isCompact: Bool = false
    ) {
        _hour = hour
        _minute = minute
        self.tint = tint
        self.usesDarkTypography = usesDarkTypography
        self.isCompact = isCompact
    }

    private var pickerTextColor: Color {
        usesDarkTypography ? .black : LColors.textPrimary
    }
    
    private var formattedPreview: String {
        String(format: "%d:%02d %@", displayHour, minute, meridiem)
    }

    private var displayHourBinding: Binding<Int> {
        Binding(
            get: { displayHour },
            set: { newValue in
                let clamped = max(1, min(12, newValue))
                guard displayHour != clamped else { return }
                displayHour = clamped
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { max(0, min(59, minute)) },
            set: { newValue in
                let clamped = max(0, min(59, newValue))
                guard minute != clamped else { return }
                minute = clamped
            }
        )
    }

    private var meridiemBinding: Binding<String> {
        Binding(
            get: { meridiem },
            set: { newValue in
                guard meridiems.contains(newValue), meridiem != newValue else { return }
                meridiem = newValue
            }
        )
    }
    
    var body: some View {
        VStack(spacing: isCompact ? 8 : 12) {
            HStack(spacing: isCompact ? 6 : 8) {
                timePreviewIcon
                
                Text(formattedPreview)
                    .font(.system(size: isCompact ? 12 : 18, weight: .black, design: .rounded))
                    .foregroundStyle(pickerTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                
                Spacer()
            }
            .padding(.horizontal, isCompact ? 9 : 14)
            .padding(.vertical, isCompact ? 7 : 10)
            .background {
                pickerSurface(cornerRadius: isCompact ? 12 : 16, prominence: .lens)
            }
            
            ZStack {
                pickerSurface(cornerRadius: isCompact ? 16 : 24)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    pickerSelectionSurface(cornerRadius: isCompact ? 9 : 12)
                        .frame(height: isCompact ? 30 : 38)
                    
                    Spacer()
                }
                .padding(.horizontal, isCompact ? 5 : 12)
                
                HStack(spacing: isCompact ? 1 : 6) {
                    LunixiaDrumPickerColumn(
                        values: Array(1...12),
                        labels: Array(1...12).map { "\($0)" },
                        selection: displayHourBinding,
                        textColor: pickerTextColor,
                        itemHeight: isCompact ? 30 : 38,
                        textSize: isCompact ? 15 : 20
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 90 : 120)
                    .clipped()

                    Text(":")
                        .font(.system(size: isCompact ? 17 : 24, weight: .black, design: .rounded))
                        .foregroundStyle(pickerTextColor)

                    LunixiaDrumPickerColumn(
                        values: Array(0..<60),
                        labels: Array(0..<60).map { String(format: "%02d", $0) },
                        selection: minuteBinding,
                        textColor: pickerTextColor,
                        itemHeight: isCompact ? 30 : 38,
                        textSize: isCompact ? 15 : 20
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 90 : 120)
                    .clipped()

                    LunixiaDrumPickerColumn(
                        values: meridiems,
                        labels: meridiems,
                        selection: meridiemBinding,
                        textColor: pickerTextColor,
                        itemHeight: isCompact ? 30 : 38,
                        textSize: isCompact ? 14 : 20
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 90 : 120)
                    .clipped()
                }
                .padding(.horizontal, isCompact ? 3 : 8)
            }
            .frame(height: isCompact ? 104 : 138)
        }
        .onAppear {
            syncDisplayValuesFromStoredHour()
        }
        .onChange(of: displayHour) { _, _ in
            syncStoredHour()
        }
        .onChange(of: meridiem) { _, _ in
            syncStoredHour()
        }
        .onChange(of: hour) { _, _ in
            syncDisplayValuesFromStoredHour()
        }
    }

    @ViewBuilder
    private var timePreviewIcon: some View {
        if let tint {
            Image("clockwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: isCompact ? 10 : 13, height: isCompact ? 10 : 13)
                .foregroundStyle(usesDarkTypography ? Color.black : tint)
                .bubblyIconMaterial(tint: usesDarkTypography ? .black : tint)
        } else {
            Image("clockwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: isCompact ? 10 : 13, height: isCompact ? 10 : 13)
                .foregroundStyle(LGradients.header)
        }
    }

    @ViewBuilder
    private func pickerSurface(
        cornerRadius: CGFloat,
        prominence: LunixiaNeutralGlassProminence = .surface
    ) -> some View {
        if let tint {
            BubblyCardMaterial(
                tint: tint,
                cornerRadius: cornerRadius
            )
        } else {
            LunixiaNeutralGlassSurface(
                cornerRadius: cornerRadius,
                prominence: prominence
            )
        }
    }

    @ViewBuilder
    private func pickerSelectionSurface(cornerRadius: CGFloat) -> some View {
        if let tint {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(usesDarkTypography ? Color.white.opacity(0.24) : Color.black.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(tint.opacity(0.78), lineWidth: 1)
                }
        } else {
            LunixiaNeutralGlassSurface(
                cornerRadius: cornerRadius,
                prominence: .active
            )
        }
    }
    
    private func syncDisplayValuesFromStoredHour() {
        let normalizedHour = max(0, min(23, hour))
        let newDisplayHour: Int
        let newMeridiem: String

        if normalizedHour == 0 {
            newDisplayHour = 12
            newMeridiem = "AM"
        } else if normalizedHour < 12 {
            newDisplayHour = normalizedHour
            newMeridiem = "AM"
        } else if normalizedHour == 12 {
            newDisplayHour = 12
            newMeridiem = "PM"
        } else {
            newDisplayHour = normalizedHour - 12
            newMeridiem = "PM"
        }

        guard displayHour != newDisplayHour || meridiem != newMeridiem else { return }

        displayHour = newDisplayHour
        meridiem = newMeridiem
    }

    private func syncStoredHour() {
        let newHour: Int
        if meridiem == "AM" {
            newHour = displayHour == 12 ? 0 : displayHour
        } else {
            newHour = displayHour == 12 ? 12 : displayHour + 12
        }

        guard hour != newHour else { return }
        hour = newHour
    }
}

struct LunixiaCompactTimeDrumPicker: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var tint: Color? = nil
    var usesDarkTypography: Bool = false

    var body: some View {
        LunixiaGradientTimeDrumPicker(
            hour: $hour,
            minute: $minute,
            tint: tint,
            usesDarkTypography: usesDarkTypography,
            isCompact: true
        )
    }
}


// MARK: - Pure SwiftUI Drum Picker Column

private struct LunixiaDrumPickerColumn<Value: Hashable>: View {
    let values: [Value]
    let labels: [String]
    @Binding var selection: Value
    var textColor: Color = .white
    var itemHeight: CGFloat = 38
    var textSize: CGFloat = 20

    @State private var dragOffset: CGFloat = 0
    @State private var baseOffset: CGFloat = 0
    @State private var isDragging = false

    private var selectedIndex: Int {
        values.firstIndex(of: selection) ?? 0
    }

    private var totalOffset: CGFloat {
        baseOffset + dragOffset
    }

    private var currentIndex: Int {
        let raw = -totalOffset / itemHeight
        return max(0, min(values.count - 1, Int(raw.rounded())))
    }

    var body: some View {
        GeometryReader { geo in
            let centerY = (geo.size.height - itemHeight) / 2

            ZStack {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let offsetY = centerY + CGFloat(index) * itemHeight + totalOffset
                    let distanceFromCenter = abs(offsetY - centerY)
                    let normalized = max(0, 1 - distanceFromCenter / (itemHeight * 1.5))

                    Text(labels.indices.contains(index) ? labels[index] : "")
                        .font(.system(size: textSize, weight: .bold, design: .rounded))
                        .foregroundStyle(textColor.opacity(0.3 + 0.65 * normalized))
                        .scaleEffect(0.85 + 0.2 * normalized)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(height: itemHeight)
                        .frame(maxWidth: .infinity)
                        .offset(y: offsetY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        isDragging = false
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        let projected = totalOffset + velocity * 0.3
                        let rawIndex = -projected / itemHeight
                        let snapped = max(0, min(values.count - 1, Int(rawIndex.rounded())))
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            baseOffset = -CGFloat(snapped) * itemHeight
                            dragOffset = 0
                        }
                        if values.indices.contains(snapped) {
                            selection = values[snapped]
                        }
                    }
            )
            .onAppear {
                baseOffset = -CGFloat(selectedIndex) * itemHeight
            }
            .onChange(of: selection) { _, _ in
                guard !isDragging else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    baseOffset = -CGFloat(selectedIndex) * itemHeight
                    dragOffset = 0
                }
            }
        }
    }
}


// MARK: - Gradient Date Drum Picker

/// Three-drum (Month / Day / Year) date picker in the same gradient style
/// as `LunixiaGradientTimeDrumPicker`. Time-of-day components on the bound
/// `Date` are preserved — only year/month/day are edited.
struct LunixiaGradientDateDrumPicker: View {
    @Binding var date: Date
    var tint: Color? = nil
    var usesCardMaterial: Bool = false
    var usesDarkTypography: Bool = false

    private let isCompact: Bool

    @State private var year: Int
    @State private var month: Int
    @State private var day: Int

    private let calendar = Calendar.current

    private let monthShortLabels = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    private static let referenceYear = Calendar.current.component(.year, from: Date())
    private let yearRange: [Int] = Array((referenceYear - 5)...(referenceYear + 20))

    init(
        date: Binding<Date>,
        tint: Color? = nil,
        usesCardMaterial: Bool = false,
        usesDarkTypography: Bool = false,
        isCompact: Bool = false
    ) {
        self._date = date
        self.tint = tint
        self.usesCardMaterial = usesCardMaterial
        self.usesDarkTypography = usesDarkTypography
        self.isCompact = isCompact
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date.wrappedValue)
        _year = State(initialValue: comps.year ?? LunixiaGradientDateDrumPicker.referenceYear)
        _month = State(initialValue: comps.month ?? 1)
        _day = State(initialValue: comps.day ?? 1)
    }

    private var daysInMonth: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return 31 }
        return range.count
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { month },
            set: { newValue in
                let clamped = max(1, min(12, newValue))
                guard month != clamped else { return }
                month = clamped
            }
        )
    }

    private var dayBinding: Binding<Int> {
        Binding(
            get: { min(day, daysInMonth) },
            set: { newValue in
                let clamped = max(1, min(daysInMonth, newValue))
                guard day != clamped else { return }
                day = clamped
            }
        )
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { year },
            set: { newValue in
                guard yearRange.contains(newValue), year != newValue else { return }
                year = newValue
            }
        )
    }

    private var formattedPreview: String {
        let formatter = DateFormatter()
        formatter.dateFormat = isCompact ? "MMM d, yyyy" : "EEE, MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var pickerTextColor: Color {
        usesDarkTypography ? .black : LColors.textPrimary
    }

    var body: some View {
        VStack(spacing: isCompact ? 8 : 12) {
            HStack(spacing: isCompact ? 6 : 8) {
                Group {
                    if let tint {
                        Image("ringstarcal")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(usesDarkTypography ? Color.black : tint)
                            .bubblyIconMaterial(tint: usesDarkTypography ? .black : tint)
                    } else {
                        Image(systemName: "calendar")
                            .font(.system(size: isCompact ? 10 : 13, weight: .bold))
                            .foregroundStyle(LGradients.header)
                    }
                }
                .frame(
                    width: isCompact ? 11 : 15,
                    height: isCompact ? 11 : 15
                )

                Text(formattedPreview)
                    .font(.system(size: isCompact ? 12 : 18, weight: .black, design: .rounded))
                    .foregroundStyle(pickerTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer()
            }
            .padding(.horizontal, isCompact ? 9 : 14)
            .padding(.vertical, isCompact ? 7 : 10)
            .background {
                pickerSurface(cornerRadius: isCompact ? 12 : 16, prominence: .lens)
            }

            ZStack {
                pickerSurface(cornerRadius: isCompact ? 16 : 24)

                VStack(spacing: 0) {
                    Spacer()

                    selectionSurface(cornerRadius: isCompact ? 9 : 12)
                        .frame(height: isCompact ? 30 : 38)

                    Spacer()
                }
                .padding(.horizontal, isCompact ? 5 : 12)

                HStack(spacing: isCompact ? 1 : 6) {
                    LunixiaDrumPickerColumn(
                        values: Array(1...12),
                        labels: monthShortLabels,
                        selection: monthBinding,
                        textColor: pickerTextColor,
                        itemHeight: isCompact ? 30 : 38,
                        textSize: isCompact ? 14 : 20
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 90 : 120)
                    .clipped()

                    LunixiaDrumPickerColumn(
                        values: Array(1...daysInMonth),
                        labels: Array(1...daysInMonth).map { "\($0)" },
                        selection: dayBinding,
                        textColor: pickerTextColor,
                        itemHeight: isCompact ? 30 : 38,
                        textSize: isCompact ? 15 : 20
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 90 : 120)
                    .clipped()

                    LunixiaDrumPickerColumn(
                        values: yearRange,
                        labels: yearRange.map { "\($0)" },
                        selection: yearBinding,
                        textColor: pickerTextColor,
                        itemHeight: isCompact ? 30 : 38,
                        textSize: isCompact ? 13 : 20
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 90 : 120)
                    .clipped()
                }
                .padding(.horizontal, isCompact ? 3 : 8)
            }
            .frame(height: isCompact ? 104 : 138)
        }
        .onChange(of: month) { _, _ in syncDateFromDrums() }
        .onChange(of: day) { _, _ in syncDateFromDrums() }
        .onChange(of: year) { _, _ in syncDateFromDrums() }
        .onChange(of: date) { _, newValue in syncDrumsFromDate(newValue) }
    }

    @ViewBuilder
    private func pickerSurface(
        cornerRadius: CGFloat,
        prominence: LunixiaNeutralGlassProminence = .surface
    ) -> some View {
        if usesCardMaterial, let tint {
            BubblyCardMaterial(tint: tint, cornerRadius: cornerRadius)
        } else {
            LunixiaNeutralGlassSurface(cornerRadius: cornerRadius, prominence: prominence)
        }
    }

    @ViewBuilder
    private func selectionSurface(cornerRadius: CGFloat) -> some View {
        if let tint {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(usesDarkTypography ? Color.white.opacity(0.24) : tint.opacity(0.20))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(tint.opacity(0.72), lineWidth: 1)
                }
        } else {
            LunixiaNeutralGlassSurface(cornerRadius: cornerRadius, prominence: .active)
        }
    }

    private func syncDateFromDrums() {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = min(day, daysInMonth)

        let timeComps = calendar.dateComponents([.hour, .minute, .second], from: date)
        comps.hour = timeComps.hour
        comps.minute = timeComps.minute
        comps.second = timeComps.second

        guard let newDate = calendar.date(from: comps), newDate != date else { return }
        date = newDate
    }

    private func syncDrumsFromDate(_ newDate: Date) {
        let comps = calendar.dateComponents([.year, .month, .day], from: newDate)
        if let newYear = comps.year, newYear != year { year = newYear }
        if let newMonth = comps.month, newMonth != month { month = newMonth }
        if let newDay = comps.day, newDay != day { day = newDay }
    }
}

struct LunixiaCompactDateDrumPicker: View {
    @Binding var date: Date
    var tint: Color? = nil
    var usesCardMaterial: Bool = false
    var usesDarkTypography: Bool = false

    var body: some View {
        LunixiaGradientDateDrumPicker(
            date: $date,
            tint: tint,
            usesCardMaterial: usesCardMaterial,
            usesDarkTypography: usesDarkTypography,
            isCompact: true
        )
    }
}


// MARK: - Compact Picker Neutral Surface Support
private enum LunixiaNeutralGlassProminence {
    case surface
    case lens
    case active
}

private struct LunixiaNeutralGlassSurface: View {
    var cornerRadius: CGFloat
    var prominence: LunixiaNeutralGlassProminence = .surface

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LColors.glassSurface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
            }
    }
}

// MARK: - Glass TextEditor

struct GlassTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    var font: Font? = nil
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundStyle(LColors.textSecondary.opacity(0.65))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $text)
                .font(font)
                .foregroundStyle(LColors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minHeight: minHeight)
        .background(
            RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.46), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous))
    }
}


// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    @Environment(\.appTheme) private var theme

    var cornerRadius: CGFloat = 24
    var padding: CGFloat = LSpacing.cardPadding
    var borderColor: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.palette.surface)
            }
    }
}

// MARK: - Glass Card Note

struct GlassCardNote<Content: View>: View {
    var cornerRadius: CGFloat = LSpacing.cardRadius
    var padding: CGFloat = LSpacing.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.38), lineWidth: 1.25)
            )
            .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = LSpacing.cardRadius,
        padding: CGFloat = LSpacing.cardPadding
    ) -> some View {
        GlassCard(cornerRadius: cornerRadius, padding: padding) {
            self
        }
    }
}


// MARK: - Completion Banner

struct LunixiaCompletionBanner: View {
    let message: String
    var isShowing: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image("checkwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(LGradients.header)
                .shadow(color: LColors.gradientPurple.opacity(0.4), radius: 16, y: 6)
        )
        .opacity(isShowing ? 1 : 0)
        .offset(y: isShowing ? 0 : -20)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isShowing)
    }
}

extension View {
    func completionBanner(isShowing: Bool, message: String = "Done!") -> some View {
        self.overlay(alignment: .top) {
            LunixiaCompletionBanner(message: message, isShowing: isShowing)
                .padding(.top, 16)
                .zIndex(999)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LunixiaBackground()

        GlassCard {
            VStack(spacing: 10) {
                Text("Lunixia")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(LGradients.header)

                Text("Glass card preview")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
        .padding(.horizontal, 24)
    }
}
