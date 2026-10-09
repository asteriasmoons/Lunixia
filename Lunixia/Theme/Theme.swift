//
//  Theme.swift
//  Lunixia
//

import SwiftUI

// MARK: - Color Tokens

enum LColors {
    private static let palette = AppPalette.lunixia

    // Base
    static let bg = palette.background
    static let bgSoft = palette.background
    
    // Text
    static let textPrimary = palette.textPrimary
    static let textSecondary = palette.textSecondary
    
    // Accent
    static let accent = palette.primaryAction
    static let accentHover = palette.secondaryAccent
    // Legacy name retained for existing callers; this is the exact solid token.
    static let accentGradient = palette.primaryAction
    
    // Status
    static let success = palette.indicators
    static let danger = palette.secondaryAccent
    static let warning = palette.primaryAction
    
    // Glass surfaces
    static let glassSurface = palette.surface
    static let glassSurface2 = palette.raisedSurface
    static let glassBorder = palette.raisedSurface
    static let glassBorderStrong = palette.raisedSurface
    
    // Legacy accent aliases
    static let gradientPurple = palette.secondaryAccent
    static let gradientBlue = palette.primaryAction
    static let gradientPink = palette.secondaryAccent
    static let gradientCyan = palette.indicators
    static let gradientYellow = palette.indicators
    static let gradientDeepPurple = palette.secondaryAccent
    
    // Badge colors
    static let badgeOnce = palette.secondaryAccent
    static let badgeDaily = palette.primaryAction
    static let badgeWeekly = palette.indicators
    static let badgeInterval = palette.secondaryAccent
}

// MARK: - Legacy Shape-Style Names

enum LGradients {
    static let blue = LColors.gradientBlue
    static let header = LColors.accent
    static let tag = LColors.gradientPurple
    
    // Ambient gradient compatibility hooks no longer add color variants.
    static let bgPurple = Color.clear
    static let bgCyan = Color.clear
    static let bgYellow = Color.clear
}

// MARK: - Spacing & Radius

enum LSpacing {
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 12
    static let inputRadius: CGFloat = 12
    static let pillRadius: CGFloat = 999
    static let pageHorizontal: CGFloat = 16
    static let sectionGap: CGFloat = 24
}

// MARK: - Color Extension

extension Color {
    init(lunixiaHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        
        switch hex.count {
        case 6:
            (a, r, g, b) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8:
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
