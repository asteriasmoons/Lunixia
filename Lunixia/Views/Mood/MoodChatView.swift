//
//  MoodChatView.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct MoodChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: MoodChatSession

    // MARK: State
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // Timer — 10 minutes
    @State private var secondsRemaining: Int = 600
    @State private var timer: Timer? = nil
    @State private var sessionEnded: Bool = false

    private let service = MoodChatService()

    // MARK: Body

    var body: some View {
        ZStack {
            LunixiaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                timerBar
                messageList
                inputBar
            }
        }
        .onAppear {
            startSession()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: Nav bar

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(LColors.glassSurface))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Talk it out")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Timer bar

    private var timerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(timerColor)

            Text(timerLabel)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(timerColor)

            Spacer()

            if sessionEnded {
                Text("Session complete")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            } else {
                Text("This space is just for you")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(LColors.glassSurface)
    }

    // MARK: Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if isLoading {
                        TypingIndicator()
                            .id("typing")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(LColors.danger)
                            .padding(.horizontal, 20)
                            .id("error")
                    }

                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.top, 16)
            }
            .onChange(of: messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isLoading) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(LColors.glassBorder)

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Say what's on your mind...", text: $inputText, axis: .vertical)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .tint(LColors.accent)
                    .lineLimit(1...5)
                    .disabled(sessionEnded || isLoading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LColors.glassSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
                            )
                    )

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(
                                    canSend
                                    ? AnyShapeStyle(LColors.accentGradient)
                                    : AnyShapeStyle(LColors.glassSurface2)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.2), value: canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(LColors.bg)
    }

    // MARK: Helpers

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isLoading
        && !sessionEnded
    }

    private var timerLabel: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private var timerColor: Color {
        if sessionEnded { return LColors.textSecondary }
        if secondsRemaining <= 60 { return LColors.danger }
        if secondsRemaining <= 120 { return LColors.warning }
        return LColors.accent
    }

    // MARK: Session logic

    private func startSession() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timer?.invalidate()
                endSession()
            }
        }

        Task { await sendOpener() }
    }

    private func endSession() {
        sessionEnded = true
        let closing = ChatMessage(
            role: "model",
            text: "Our time together today is up. I hope you're feeling a little lighter. Whatever you shared here mattered — you showed up for yourself, and that's enough."
        )
        withAnimation { messages.append(closing) }
    }

    private func sendOpener() async {
        isLoading = true
        let opener = [ChatMessage(role: "user", text: "I'm here to talk.")]
        do {
            let reply = try await service.send(messages: opener)
            await MainActor.run {
                // Only stamp the cooldown once we know the API is working
                session.lastChatDate = Date()
                try? modelContext.save()
                messages.append(ChatMessage(role: "model", text: reply))
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = ChatMessage(role: "user", text: trimmed)
        messages.append(userMsg)
        inputText = ""
        errorMessage = nil
        isLoading = true

        let history = messages

        Task {
            do {
                let reply = try await service.send(messages: history)
                await MainActor.run {
                    messages.append(ChatMessage(role: "model", text: reply))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            Text(message.text)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(isUser ? .white : LColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isUser
                            ? AnyShapeStyle(LColors.accentGradient)
                            : AnyShapeStyle(LColors.glassSurface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    isUser ? Color.clear : LColors.glassBorder,
                                    lineWidth: 1
                                )
                        )
                )
                .multilineTextAlignment(isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(LColors.textSecondary.opacity(phase == i ? 0.9 : 0.3))
                    .frame(width: 7, height: 7)
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LColors.glassSurface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(LColors.glassBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                phase = 1
            }
        }
    }
}
