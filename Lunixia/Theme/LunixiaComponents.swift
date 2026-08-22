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
    
    @State private var displayHour: Int = 9
    @State private var meridiem: String = "AM"
    @State private var isSyncingFromStoredHour = false
    
    private let meridiems = ["AM", "PM"]
    
    private var formattedPreview: String {
        String(format: "%d:%02d %@", displayHour, minute, meridiem)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LGradients.header)
                
                Text(formattedPreview)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [LColors.gradientBlue, LColors.gradientPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LColors.glassSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        LColors.gradientBlue.opacity(0.10),
                                        LColors.gradientPurple.opacity(0.14),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [LColors.gradientBlue, LColors.gradientPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                VStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.20),
                                    LColors.gradientPurple.opacity(0.20)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            LColors.gradientBlue.opacity(0.55),
                                            LColors.gradientPurple.opacity(0.55)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
                
                HStack(spacing: 6) {
                    Picker("Hour", selection: $displayHour) {
                        ForEach(1...12, id: \.self) { value in
                            Text("\(value)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                    
                    Text(":")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                    
                    Picker("Minute", selection: $minute) {
                        ForEach(0..<60, id: \.self) { value in
                            Text(String(format: "%02d", value))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                    
                    Picker("AM PM", selection: $meridiem) {
                        ForEach(meridiems, id: \.self) { value in
                            Text(value)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 138)
        }
        .onAppear { syncDisplayValuesFromStoredHour() }
        .onChange(of: displayHour) { syncStoredHour() }
        .onChange(of: meridiem) { syncStoredHour() }
        .onChange(of: hour) { syncDisplayValuesFromStoredHour() }
    }
    
    private func syncDisplayValuesFromStoredHour() {
        isSyncingFromStoredHour = true
        let normalizedHour = max(0, min(23, hour))
        if normalizedHour == 0 {
            displayHour = 12; meridiem = "AM"
        } else if normalizedHour < 12 {
            displayHour = normalizedHour; meridiem = "AM"
        } else if normalizedHour == 12 {
            displayHour = 12; meridiem = "PM"
        } else {
            displayHour = normalizedHour - 12; meridiem = "PM"
        }
        isSyncingFromStoredHour = false
    }
    
    private func syncStoredHour() {
        guard !isSyncingFromStoredHour else { return }
        if meridiem == "AM" {
            hour = displayHour == 12 ? 0 : displayHour
        } else {
            hour = displayHour == 12 ? 12 : displayHour + 12
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
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = LSpacing.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(lunixiaHex: "#09090d").opacity(0.90))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(lunixiaHex: "#4388C5").opacity(0.36),
                                        Color(lunixiaHex: "#4388C5").opacity(0.08),
                                        Color(lunixiaHex: "#07070a").opacity(0.0)
                                    ],
                                    center: UnitPoint(x: 0.22, y: 0.30),
                                    startRadius: 0,
                                    endRadius: 120
                                )
                            )
                            .blur(radius: 18)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(lunixiaHex: "#6111b8").opacity(0.38),
                                        Color(lunixiaHex: "#6111b8").opacity(0.09),
                                        Color(lunixiaHex: "#07070a").opacity(0.0)
                                    ],
                                    center: UnitPoint(x: 0.78, y: 0.70),
                                    startRadius: 0,
                                    endRadius: 120
                                )
                            )
                            .blur(radius: 18)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(lunixiaHex: "#4f45bc").opacity(0.045),
                                        Color(lunixiaHex: "#190a32").opacity(0.015),
                                        Color(lunixiaHex: "#07070a").opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 115
                                )
                            )
                            .blur(radius: 14)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(lunixiaHex: "#4388C5").opacity(0.30),
                                        Color(lunixiaHex: "#6111b8").opacity(0.24),
                                        Color.white.opacity(0.09),
                                        Color.white.opacity(0.055)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: Color.black.opacity(0.42), radius: 18, y: 10)
            .shadow(color: Color(lunixiaHex: "#4388C5").opacity(0.10), radius: 14, y: 6)
            .shadow(color: Color(lunixiaHex: "#6111b8").opacity(0.10), radius: 16, y: 8)
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
