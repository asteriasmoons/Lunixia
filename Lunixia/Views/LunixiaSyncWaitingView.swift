//
//  LunixiaSyncWaitingView.swift
//  Lunixia
//

import SwiftUI

struct LunixiaSyncWaitingView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            theme.palette.background
                .ignoresSafeArea()

            VStack(spacing: 14) {
                LunixiaSyncLoadingRing()

                Text("Syncing your Lunixia data...")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
    }
}

private struct LunixiaSyncLoadingRing: View {
    @Environment(\.appTheme) private var theme

    private let dotCount = 15

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(0..<dotCount, id: \.self) { index in
                    let tint = theme.palette.rotation[index % theme.palette.rotation.count]
                    let pulse = 0.72 + (
                        0.28 * (
                            cos((elapsed * 5.2) - (Double(index) * 0.48)) + 1
                        ) / 2
                    )

                    BubblyIconMaterial(tint: tint)
                        .frame(width: 13, height: 13)
                        .clipShape(Circle())
                        .scaleEffect(pulse)
                        .offset(y: -39)
                        .rotationEffect(
                            .degrees(Double(index) * (360 / Double(dotCount)))
                        )
                }
            }
            .frame(width: 96, height: 96)
            .rotationEffect(.degrees(elapsed * 42))
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel("Syncing your Lunixia data")
    }
}
