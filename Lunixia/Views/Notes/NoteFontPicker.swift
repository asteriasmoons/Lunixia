//
//  NoteFontPicker.swift
//  Lunixia
//

import SwiftUI

struct NoteFontPicker: View {
    @Binding var selectedFontID: String
    @State private var isExpanded = false

    private var selectedOption: NoteFontOption {
        NoteFontOption.option(for: selectedFontID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Note Font")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        fontBadge(for: selectedOption)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedOption.displayName)
                                .font(selectedOption.font(size: 17))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)

                            Text("Quick thoughts and gentle plans")
                                .font(selectedOption.font(size: 12))
                                .foregroundStyle(Color.white.opacity(0.66))
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                        }

                        Spacer(minLength: 8)

                        Image(isExpanded ? "chevup" : "chevdown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selectorGradient)
                                    .allowsHitTesting(false)
                            }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(isExpanded ? 0.34 : 0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 7) {
                        ForEach(NoteFontOption.allCases) { option in
                            Button {
                                selectedFontID = option.rawValue
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                                    isExpanded = false
                                }
                            } label: {
                                fontOptionRow(option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var selectorGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                LColors.gradientPurple.opacity(0.12),
                Color.white.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func fontOptionRow(_ option: NoteFontOption) -> some View {
        let isSelected = selectedFontID == option.rawValue

        return HStack(spacing: 11) {
            fontBadge(for: option)
                .opacity(isSelected ? 1 : 0.78)

            VStack(alignment: .leading, spacing: 3) {
                Text(option.displayName)
                    .font(option.font(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("Preview your note in this style")
                    .font(option.font(size: 11))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            NoteChecklistCircle(isCompleted: isSelected, size: 20)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.16 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.10),
                    lineWidth: 1
                )
        )
    }

    private func fontBadge(for option: NoteFontOption) -> some View {
        ZStack {
            Circle()
                .fill(LGradients.header.opacity(0.82))
                .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))

            Text(fontInitials(for: option))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 32, height: 32)
    }

    private func fontInitials(for option: NoteFontOption) -> String {
        switch option {
        case .system:
            return "SY"
        case .rounded:
            return "RO"
        case .serif:
            return "SE"
        default:
            return option.displayName
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first }
                .map(String.init)
                .joined()
                .uppercased()
        }
    }
}

struct NoteFontSizeControl: View {
    @Binding var fontSize: Double
    // Must be the State's own projected binding ($draftFontID), not a plain value and
    // not a hand-built Binding closure — both read the stale captured NotesView struct.
    @Binding var fontID: String

    private var font: NoteFontOption {
        NoteFontOption.option(for: fontID)
    }

    private let minimumSize = Note.minimumFontSize
    private let maximumSize = Note.maximumFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Note Font Size")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Preview text updates live")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                }

                Spacer(minLength: 8)

                Text("\(Int(fontSize.rounded())) pt")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LGradients.header, in: Capsule(style: .continuous))
            }

            HStack(spacing: 12) {
                sizeButton(assetName: "minuswavy", accessibilityLabel: "Decrease note font size") {
                    adjustSize(by: -1)
                }

                VStack(alignment: .leading, spacing: 9) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.11))

                            Capsule(style: .continuous)
                                .fill(LGradients.header)
                                .frame(width: max(18, proxy.size.width * progress))

                            Circle()
                                .fill(.white)
                                .frame(width: 18, height: 18)
                                .shadow(color: LColors.gradientPurple.opacity(0.38), radius: 7, y: 2)
                                .offset(x: max(0, proxy.size.width * progress - 18))
                        }
                    }
                    .frame(height: 18)

                    Text("The moon left me a very specific note.")
                        .font(font.font(size: CGFloat(fontSize)))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }

                sizeButton(assetName: "addwavy", accessibilityLabel: "Increase note font size") {
                    adjustSize(by: 1)
                }
            }
        }
    }

    private var progress: CGFloat {
        CGFloat((fontSize - minimumSize) / (maximumSize - minimumSize))
    }

    private func adjustSize(by amount: Double) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            fontSize = min(maximumSize, max(minimumSize, fontSize + amount))
        }
    }

    private func sizeButton(
        assetName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
