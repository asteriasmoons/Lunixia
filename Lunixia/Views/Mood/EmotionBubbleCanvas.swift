//
//  EmotionBubbleCanvas.swift
//  Lunixia
//

import SwiftUI
import Combine

struct EmotionBubbleItem: Identifiable {
    let id = UUID()
    let emotion: MoodEmotion
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let floatPhase: CGFloat
    let floatSpeed: CGFloat
}

struct EmotionBubbleCanvas: View {
    @Binding var selectedEmotions: [MoodEmotion]

    private let canvasWidth: CGFloat = UIScreen.main.bounds.width
    private let canvasHeight: CGFloat = UIScreen.main.bounds.height * 3.5

    @State private var bubbles: [EmotionBubbleItem] = []
    @State private var floatTick: CGFloat = 0
    private let timer = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: canvasWidth, height: canvasHeight)

                ForEach(bubbles) { bubble in
                    let isSelected = selectedEmotions.contains(where: { $0.name == bubble.emotion.name })
                    let floatY = sin(floatTick * bubble.floatSpeed + bubble.floatPhase) * 4

                    EmotionBubbleView(bubble: bubble, isSelected: isSelected) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            if let idx = selectedEmotions.firstIndex(where: { $0.name == bubble.emotion.name }) {
                                selectedEmotions.remove(at: idx)
                            } else {
                                selectedEmotions.append(bubble.emotion)
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
        let emotions = MoodEmotion.all
        let count = emotions.count
        let cols = 3
        let rows = Int(ceil(Double(count) / Double(cols)))
        let cellW = canvasWidth / CGFloat(cols)
        let cellH = canvasHeight / CGFloat(rows)
        let bubbleRadius: CGFloat = 48
        let jitter: CGFloat = 14

        var placed: [EmotionBubbleItem] = []

        for (i, emotion) in emotions.enumerated() {
            let col = i % cols
            let row = i / cols
            let baseX = cellW * CGFloat(col) + cellW / 2
            let baseY = cellH * CGFloat(row) + cellH / 2
            let jitterX = CGFloat.random(in: -jitter...jitter)
            let jitterY = CGFloat.random(in: -jitter...jitter)
            let x = min(max(bubbleRadius, baseX + jitterX), canvasWidth - bubbleRadius)
            let y = min(max(bubbleRadius, baseY + jitterY), canvasHeight - bubbleRadius)

            placed.append(EmotionBubbleItem(
                emotion: emotion,
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

// MARK: - Single Bubble

struct EmotionBubbleView: View {
    @Environment(\.appTheme) private var theme

    let bubble: EmotionBubbleItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            BubblyCardMaterial(
                tint: theme.palette.primaryAction,
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
                    color: theme.palette.primaryAction.opacity(isSelected ? 0.55 : 0.18),
                    radius: isSelected ? 16 : 8
                )

            Text(bubble.emotion.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: bubble.radius * 1.5)
        }
        .frame(width: bubble.radius * 2, height: bubble.radius * 2)
        .scaleEffect(isSelected ? 0.78 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .onTapGesture { onTap() }
    }
}
