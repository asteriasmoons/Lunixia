//
//  BubblyIconMaterial.swift
//  Lunixia
//
//  Compact Liquid Glass material tuned for tiny icon masks.
//

import SwiftUI

struct BubblyIconMaterial: View {
    @Environment(\.appTheme) private var theme

    var tint: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let materialTint = tint.opacity(0.75)

            ZStack {
                materialTint

                if #available(iOS 26.0, *) {
                    Rectangle()
                        .fill(materialTint)
                        .glassEffect(.regular.tint(materialTint), in: Rectangle())
                }

                RadialGradient(
                    colors: [
                        theme.palette.textPrimary.opacity(0.408),
                        theme.palette.textPrimary.opacity(0.136),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.22, y: 0.18),
                    startRadius: 0,
                    endRadius: min(w, h) * 0.78
                )
                .blendMode(.screen)

                LinearGradient(
                    colors: [
                        theme.palette.textPrimary.opacity(0.289),
                        theme.palette.textPrimary.opacity(0.085),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)

                LinearGradient(
                    colors: [
                        Color.clear,
                        materialTint,
                        theme.palette.background.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
                .blendMode(.multiply)
            }
            .frame(width: w, height: h)
            .compositingGroup()
        }
    }
}

private struct BubblyIconMaterialModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.clear)
            .overlay {
                BubblyIconMaterial(tint: tint)
                    .mask {
                        content
                    }
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func bubblyIconMaterial(tint: Color) -> some View {
        modifier(BubblyIconMaterialModifier(tint: tint))
    }

    @ViewBuilder
    func bubblyIconMaterial(tint: Color, isEnabled: Bool) -> some View {
        if isEnabled {
            modifier(BubblyIconMaterialModifier(tint: tint))
        } else {
            self
        }
    }
}
