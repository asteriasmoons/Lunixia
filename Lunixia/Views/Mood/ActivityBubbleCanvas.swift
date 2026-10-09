//
//  ActivityBubbleCanvas.swift
//  Lunixia
//

import SwiftUI
import Combine

struct ActivityBubbleItem: Identifiable {
    let id = UUID()
    let activity: MoodActivity
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let floatPhase: CGFloat
    let floatSpeed: CGFloat
}

struct ActivityBubbleCanvas: View {
    @Binding var selectedActivities: [MoodActivity]

    private let canvasWidth: CGFloat = UIScreen.main.bounds.width
    private let canvasHeight: CGFloat = UIScreen.main.bounds.height * 3.5

    @State private var bubbles: [ActivityBubbleItem] = []
    @State private var floatTick: CGFloat = 0
    private let timer = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: canvasWidth, height: canvasHeight)

                ForEach(bubbles) { bubble in
                    let isSelected = selectedActivities.contains(where: { $0.name == bubble.activity.name })
                    let floatY = sin(floatTick * bubble.floatSpeed + bubble.floatPhase) * 4

                    ActivityBubbleView(bubble: bubble, isSelected: isSelected) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            if let idx = selectedActivities.firstIndex(where: { $0.name == bubble.activity.name }) {
                                selectedActivities.remove(at: idx)
                            } else {
                                selectedActivities.append(bubble.activity)
                            }
                        }
                    }
                    .position(x: bubble.x, y: bubble.y + floatY)
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
        }
        .onAppear { buildLayout() }
        .onReceive(timer) { _ in floatTick += 1 }
    }

    private func buildLayout() {
        let activities = MoodActivity.all
        let count = activities.count
        let cols = 3
        let rows = Int(ceil(Double(count) / Double(cols)))
        let cellW = canvasWidth / CGFloat(cols)
        let cellH = canvasHeight / CGFloat(rows)
        let bubbleRadius: CGFloat = 50
        let jitter: CGFloat = 12

        var placed: [ActivityBubbleItem] = []

        for (i, activity) in activities.enumerated() {
            let col = i % cols
            let row = i / cols
            let baseX = cellW * CGFloat(col) + cellW / 2
            let baseY = cellH * CGFloat(row) + cellH / 2
            let jitterX = CGFloat.random(in: -jitter...jitter)
            let jitterY = CGFloat.random(in: -jitter...jitter)
            let x = min(max(bubbleRadius, baseX + jitterX), canvasWidth - bubbleRadius)
            let y = min(max(bubbleRadius, baseY + jitterY), canvasHeight - bubbleRadius)

            placed.append(ActivityBubbleItem(
                activity: activity,
                x: x,
                y: y,
                radius: bubbleRadius,
                floatPhase: CGFloat.random(in: 0...(2 * .pi)),
                floatSpeed: CGFloat.random(in: 0.03...0.06)
            ))
        }

        bubbles = placed
    }
}

// MARK: - Single Activity Bubble

struct ActivityBubbleView: View {
    @Environment(\.appTheme) private var theme

    let bubble: ActivityBubbleItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            BubblyCardMaterial(
                tint: theme.palette.secondaryAccent,
                cornerRadius: bubble.radius
            )
                .overlay(
                    Circle()
                        .strokeBorder(
                            theme.palette.textPrimary.opacity(isSelected ? 0.9 : 0.3),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .shadow(
                    color: theme.palette.secondaryAccent.opacity(isSelected ? 0.55 : 0.18),
                    radius: isSelected ? 16 : 8
                )

            VStack(spacing: 4) {
                if bubble.activity.isCustomAsset {
                    Image(bubble.activity.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: bubble.radius * 0.42, height: bubble.radius * 0.42)
                } else {
                    Image(systemName: bubble.activity.icon)
                        .font(.system(size: bubble.radius * 0.36, weight: .semibold))
                }

                Text(bubble.activity.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: bubble.radius * 1.5)
            }
            .foregroundStyle(.white)
        }
        .frame(width: bubble.radius * 2, height: bubble.radius * 2)
        .scaleEffect(isSelected ? 0.78 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .onTapGesture { onTap() }
    }
}
