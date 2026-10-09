//
//  WellnessChallengeComponents.swift
//  Lunixia
//

import SwiftUI

struct WellnessTintedIcon: View {
    let name: String
    let tint: Color
    var size: CGFloat = 22
    var containerSize: CGFloat? = nil

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .bubblyIconMaterial(tint: tint)
            .frame(
                width: containerSize ?? size,
                height: containerSize ?? size
            )
            .accessibilityHidden(true)
    }
}

struct WellnessSurface<Content: View>: View {
    @Environment(\.appTheme) private var theme

    var cornerRadius: CGFloat = 18
    var padding: CGFloat = 16
    var borderColor: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.palette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        borderColor ?? theme.palette.raisedSurface,
                        lineWidth: borderColor == nil ? 0.75 : 1
                    )
            }
    }
}

struct WellnessSectionHeader: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let icon: String
    let tint: Color
    var trailingText: String? = nil

    var body: some View {
        HStack(spacing: 9) {
            WellnessTintedIcon(name: icon, tint: tint, size: 19)

            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(theme.palette.textPrimary)

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct WellnessProgressBar: View {
    @Environment(\.appTheme) private var theme

    let value: Double
    var tint: Color? = nil
    var height: CGFloat = 8

    private var clampedValue: Double {
        min(1, max(0, value))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(theme.palette.raisedSurface)

                Capsule(style: .continuous)
                    .fill(tint ?? theme.palette.indicators)
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((clampedValue * 100).rounded())) percent")
    }
}

struct WellnessActionButton: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let icon: String
    let tint: Color
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(theme.palette.textPrimary)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.palette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? tint : theme.palette.raisedSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isEnabled ? theme.palette.textPrimary.opacity(0.12) : theme.palette.raisedSurface,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.58)
        .accessibilityLabel(title)
    }
}

struct WellnessSecondaryButton: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let icon: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                WellnessTintedIcon(
                    name: icon,
                    tint: tint ?? theme.palette.secondaryAccent,
                    size: 15
                )

                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.palette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.palette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint ?? theme.palette.secondaryAccent, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct WellnessStatusBadge: View {
    @Environment(\.appTheme) private var theme

    let status: WellnessChallengeParticipationStatus?

    private var title: String {
        status?.displayName ?? "Not Started"
    }

    private var tint: Color {
        switch status {
        case .active: return theme.palette.primaryAction
        case .paused: return theme.palette.secondaryAccent
        case .completed: return theme.palette.indicators
        case .abandoned: return theme.palette.textSecondary
        case nil: return theme.palette.raisedSurface
        }
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(theme.palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(tint))
            .accessibilityLabel("Status: \(title)")
    }
}

struct WellnessEmptyState: View {
    @Environment(\.appTheme) private var theme

    let icon: String
    let title: String
    let message: String

    var body: some View {
        WellnessSurface(borderColor: theme.palette.secondaryAccent) {
            VStack(spacing: 10) {
                WellnessTintedIcon(
                    name: icon,
                    tint: theme.palette.secondaryAccent,
                    size: 30,
                    containerSize: 38
                )
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

extension WellnessChallengeParticipation {
    var wellnessAttemptLabel: String {
        "Attempt \(attemptNumber)"
    }
}

extension Date {
    var wellnessDateText: String {
        formatted(date: .abbreviated, time: .omitted)
    }
}
