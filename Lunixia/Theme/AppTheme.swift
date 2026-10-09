//
//  AppTheme.swift
//  Lunixia
//
//  STRICT palette. The eight semantic colors below are the source of truth.
//

import SwiftUI

// MARK: - Hex helper

extension Color {
    /// Build a Color from a 6-digit hex string. Only used by strict palettes.
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Palette

struct AppPalette: Sendable {
    let background: Color
    let surface: Color
    let raisedSurface: Color
    let primaryAction: Color
    let secondaryAccent: Color
    let indicators: Color
    let textPrimary: Color
    let textSecondary: Color

    /// Ordered rotation used to color-code categories with no explicit color.
    /// Cycles through the three brand accents, in that order.
    var rotation: [Color] { [primaryAction, secondaryAccent, indicators] }

    static let lunixia = AppPalette(
        background:      Color(hex: "#0D0C12"),
        surface:         Color(hex: "#17151E"),
        raisedSurface:   Color(hex: "#211E2A"),
        primaryAction:   Color(hex: "#527d95"),
        secondaryAccent: Color(hex: "#625687"),
        indicators:      Color(hex: "#9a4786"),
        textPrimary:     Color(hex: "#F7F5FA"),
        textSecondary:   Color(hex: "#AAA4B5")
    )

    static let `default` = AppPalette.lunixia
}

// MARK: - Typography

struct AppTypography: Sendable {
    var pageTitle: Font = .system(size: 34, weight: .black, design: .rounded)
    var sectionTitle: Font = .system(size: 20, weight: .heavy, design: .rounded)
    var cardTitle: Font = .system(size: 17, weight: .semibold, design: .rounded)
    var body: Font = .system(size: 15, weight: .regular, design: .rounded)
    var caption: Font = .system(size: 12, weight: .medium, design: .rounded)
    var amount: Font = .system(size: 22, weight: .heavy, design: .rounded)
    var amountLarge: Font = .system(size: 28, weight: .black, design: .rounded)
    var bubble: Font = .system(size: 15, weight: .heavy, design: .rounded)
    var bubbleWeekday: Font = .system(size: 10, weight: .semibold, design: .rounded)
}

// MARK: - Metrics

struct AppMetrics: Sendable {
    var cornerCard: CGFloat = 22
    var cornerBubble: CGFloat = 16
    var cornerButton: CGFloat = 18
    var cornerChip: CGFloat = 14
    var spacingXS: CGFloat = 4
    var spacingS: CGFloat = 8
    var spacingM: CGFloat = 12
    var spacingL: CGFloat = 16
    var spacingXL: CGFloat = 24
    var pageHPadding: CGFloat = 18
    var cardHPadding: CGFloat = 14
    var cardVPadding: CGFloat = 12
}

// MARK: - Theme

struct AppTheme: Sendable {
    var palette: AppPalette
    var typography: AppTypography
    var metrics: AppMetrics

    static let lunixia = AppTheme(
        palette: .lunixia,
        typography: AppTypography(),
        metrics: AppMetrics()
    )

    static let `default` = AppTheme.lunixia

    /// Cycles through the three brand accents so categories get a stable color.
    func categoryColor(for key: String?) -> Color {
        guard let key, !key.isEmpty else { return palette.primaryAction }
        var h: UInt64 = 5381
        for b in key.utf8 { h = (h &* 33) &+ UInt64(b) }
        let rotation = palette.rotation
        return rotation[Int(h % UInt64(rotation.count))]
    }
}

// MARK: - Environment

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .default
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
