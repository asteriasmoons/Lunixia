//
//  JournalBodyFontPicker.swift
//  Lunixia
//
//  Custom, in-place font picker for a journal entry's body text.
//  100% custom controls — no system Picker/Menu, no SF Symbols.
//  Matches the visual language of JournalEntryDateTimePicker.
//

import SwiftUI
import UIKit

// MARK: - Body Font Catalog

/// Fonts the user can pick for a journal entry's body text.
/// PostScript names correspond to the .otf/.ttf files bundled under Lunixia/Fonts
/// and registered in Info.plist under UIAppFonts.
enum JournalBodyFontCatalog {

    struct Option: Identifiable, Hashable {
        /// Human-readable label shown in the dropdown row.
        let displayName: String
        /// PostScript name for `UIFont(name:size:)` / `Font.custom(_:size:)`.
        /// Empty string means "use the default system font".
        let postScriptName: String

        var id: String { postScriptName }
        var isSystemDefault: Bool { postScriptName.isEmpty }
    }

    static let systemDefault = Option(displayName: "Default", postScriptName: "")

    static let all: [Option] = [
        systemDefault,
        Option(displayName: "Balistia",           postScriptName: "Balistia-Regular"),
        Option(displayName: "Beautiful Rainbow",  postScriptName: "BeautifulRainbow"),
        Option(displayName: "Cloudy Cloud",       postScriptName: "CloudyCloud"),
        Option(displayName: "Funny Hippo",       postScriptName: "FunnyHippo-Regular"),
        Option(displayName: "Handwritten",       postScriptName: "HandwrittenRegular"),
        Option(displayName: "Lovely Puppy",      postScriptName: "LovelyPuppySans"),
        Option(displayName: "Unicorn Magic",     postScriptName: "UnicornMagicRegular"),
        Option(displayName: "Zodiac Simple",     postScriptName: "ZodiacSimple"),
        Option(displayName: "Zodiac",            postScriptName: "ZodiacRegular"),
        Option(displayName: "Fate of Love",       postScriptName: "FateOfLoveRegular"),
        Option(displayName: "Looper",             postScriptName: "LooperRegular"),
        Option(displayName: "Marigold Flowers",   postScriptName: "MarigoldFlowers"),
        Option(displayName: "Quirky Loving",      postScriptName: "QuirkyLoving"),
        Option(displayName: "Strawberry Junkies", postScriptName: "StrawberryJunkies-Regular"),
        Option(displayName: "Together Forever",   postScriptName: "TogetherForeverRegular"),
        Option(displayName: "Cenila",             postScriptName: "Cenila"),
        Option(displayName: "Cheeky Smile",       postScriptName: "CheekySmileAltRegular"),
        Option(displayName: "Chibi Dinosaur",     postScriptName: "ChibiDinosaurRegular"),
        Option(displayName: "Childow Everyday",   postScriptName: "ChildowEveryday"),
        Option(displayName: "Chubby Lines",       postScriptName: "ChubbyLines-Regular"),
        Option(displayName: "Chunky Bear",        postScriptName: "ChunkyBear"),
        Option(displayName: "Fox Lollipop",       postScriptName: "FoxLollipopRegular"),
        Option(displayName: "Hachi Maru Pop",     postScriptName: "HachiMaruPop-Regular"),
        Option(displayName: "Hand Drawn",         postScriptName: "HandDrawnRegular"),
        Option(displayName: "In Love",            postScriptName: "InLoveRegular"),
        Option(displayName: "Live On The Moon",   postScriptName: "LiveonTheMoon"),
        Option(displayName: "Love Monday",        postScriptName: "LoveMonday"),
        Option(displayName: "Lumilkys",           postScriptName: "Lumilkys"),
        Option(displayName: "Mighty Fine",        postScriptName: "ZPMightyFineDemibold"),
        Option(displayName: "Rainbow Club",       postScriptName: "RainbowClubRegular"),
        Option(displayName: "Santa Jolly",        postScriptName: "SantaJollyRegular"),
        Option(displayName: "Soul Dreams",        postScriptName: "SoulDreams"),
        Option(displayName: "Sugar Donut Heart",  postScriptName: "SugarDonutHeart"),
    ]

    /// Look up the display name for a stored PostScript name.
    static func displayName(for postScriptName: String) -> String {
        all.first { $0.postScriptName == postScriptName }?.displayName ?? systemDefault.displayName
    }
}

// MARK: - Font Resolution Helper

extension JournalEntry {
    /// Resolve a UIFont for the entry's body text, preserving the caller's
    /// intended point size (offset by `bodyFontSizeOffset`) and system weight
    /// when no custom font is set. Falls back to the system font.
    func resolvedBodyUIFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let effectiveSize = max(6, (size + CGFloat(bodyFontSizeOffset)).rounded())
        let name = bodyFontName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, let custom = UIFont(name: name, size: effectiveSize) {
            return custom
        }
        return .systemFont(ofSize: effectiveSize, weight: weight)
    }
}

// MARK: - Picker View

struct JournalBodyFontPicker: View {
    @Binding var selectedPostScriptName: String
    var tint: Color = .white
    var onChange: () -> Void = {}

    @State private var expanded: Bool = false

    private let rowHeight: CGFloat = 36
    private let visibleRows: Int = 5

    private var currentDisplayName: String {
        JournalBodyFontCatalog.displayName(for: selectedPostScriptName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryBar

            if expanded {
                listPanel
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }

    // MARK: Summary bar

    private var summaryBar: some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image("pencilfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(tint)

                Text(currentDisplayName)
                    .font(previewFont(for: selectedPostScriptName, size: 14))
                    .foregroundStyle(tint)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Image(expanded ? "chevup" : "chevdown")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
                    .foregroundStyle(tint.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(tint.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Options list

    private var listPanel: some View {
        let containerHeight = rowHeight * CGFloat(visibleRows)

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(JournalBodyFontCatalog.all) { option in
                    optionRow(option)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: containerHeight)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    private func optionRow(_ option: JournalBodyFontCatalog.Option) -> some View {
        let isSelected = option.postScriptName == selectedPostScriptName
        return Button {
            selectedPostScriptName = option.postScriptName
            onChange()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                expanded = false
            }
        } label: {
            HStack(spacing: 10) {
                Text(option.displayName)
                    .font(previewFont(for: option.postScriptName, size: 16))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 6)

                if isSelected {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.09) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? tint.opacity(0.28) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Preview font

    /// Renders each option's label in that option's own font when available,
    /// so the dropdown doubles as a live preview.
    private func previewFont(for postScriptName: String, size: CGFloat) -> Font {
        let trimmed = postScriptName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, UIFont(name: trimmed, size: size) != nil {
            return .custom(trimmed, size: size)
        }
        return .system(size: size, weight: .semibold, design: .rounded)
    }
}


// MARK: - Body Font Size Stepper

/// Stepper control: minuswavy | current size | addwavy.
/// The center label shows the effective paragraph size (16pt base + offset),
/// so the user reads the actual point size their body text will render at.
struct JournalBodyFontSizePicker: View {
    @Binding var sizeOffset: Double
    var tint: Color = .white
    var onChange: () -> Void = {}

    /// Base paragraph size, mirrored from JournalBlockDisplayView's paragraph case.
    private let baseParagraphSize: Double = 16
    private let minSize: Double = 10
    private let maxSize: Double = 60
    private let step: Double = 1

    private var currentSize: Double {
        max(minSize, min(maxSize, baseParagraphSize + sizeOffset))
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(imageName: "minuswavy", disabled: currentSize <= minSize) {
                let next = max(minSize, currentSize - step)
                sizeOffset = next - baseParagraphSize
                onChange()
            }

            Spacer(minLength: 0)

            Text("\(Int(currentSize.rounded()))")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(.numericText(value: currentSize))
                .animation(.spring(response: 0.28, dampingFraction: 0.9), value: currentSize)
                .frame(minWidth: 44)

            Spacer(minLength: 0)

            stepButton(imageName: "addwavy", disabled: currentSize >= maxSize) {
                let next = min(maxSize, currentSize + step)
                sizeOffset = next - baseParagraphSize
                onChange()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func stepButton(imageName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(tint.opacity(disabled ? 0.28 : 1.0))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .sensoryFeedback(.increase, trigger: sizeOffset)
    }
}
