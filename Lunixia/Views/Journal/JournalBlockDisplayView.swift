//
//  JournalBlockDisplayView.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import UIKit
import PencilKit

struct JournalBlockDisplayView: View {
    let entry: JournalEntry
    /// When set, renders just this one block flat — used by JournalPagedContentView.
    var singleBlock: JournalBlock? = nil
    @Environment(\.modelContext) private var modelContext
    var onMentionTapped: ((String) -> Void)? = nil

    private var resolvedTextColor: UIColor {
        let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hex.isEmpty,
              let r = UInt8(hex.prefix(2), radix: 16),
              let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) else {
            return UIColor(LColors.textPrimary)
        }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    /// Resolves the body font to use for this entry, honoring the entry's
    /// custom `bodyFontName` when one is set (falls back to system font).
    private func bodyUIFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        entry.resolvedBodyUIFont(size: size, weight: weight)
    }

    private func indentPadding(for block: JournalBlock) -> CGFloat {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout:
            return CGFloat(block.indentLevel) * 20
        case .divider, .code, .image, .drawing, .table:
            return 0
        }
    }

    private var wrapperSupportedTypes: [JournalBlockType] {
        [.paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
         .toggle, .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
         .bulletedList, .numberedList, .checklist]
    }

    private func prefixWrapperAlignmentPadding(for block: JournalBlock) -> CGFloat {
        block.isBlockquoteStyle || block.isCalloutStyle ? 12 : 0
    }

    var body: some View {
        if let block = singleBlock {
            // Single block mode — flat render, no card wrapping
            renderBlock(block)
        } else {
        // Full paged mode — each page gets its own glass card
        let pages = blockPages
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(page) { block in
                            renderBlock(block)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.34))
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

                if index < pages.count - 1 {
                    Color.clear.frame(maxWidth: .infinity).frame(height: 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.bottom, 160)
        } // end full paged mode
    }

    // MARK: - Block pages — split at .pageBreak dividers

    private var blockPages: [[JournalBlock]] {
        var pages: [[JournalBlock]] = [[]]
        for block in visibleBlocks {
            if block.type == .divider,
               (DividerStyle(rawValue: block.languageHint) ?? .line) == .pageBreak {
                pages.append([])
            } else {
                pages[pages.count - 1].append(block)
            }
        }
        return pages
    }

    @ViewBuilder
    private func renderBlock(_ block: JournalBlock) -> some View {
        switch block.type {
        case .paragraph:
            styledContent(block) {
                journalTextBlock(block, font: bodyUIFont(size: 16, weight: .regular))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading1:
            styledContent(block) {
                journalTextBlock(block, font: bodyUIFont(size: 28, weight: .bold))
                    .padding(.top, 2)
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading2:
            styledContent(block) {
                journalTextBlock(block, font: bodyUIFont(size: 22, weight: .bold))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading3:
            styledContent(block) {
                journalTextBlock(block, font: bodyUIFont(size: 18, weight: .semibold))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading4:
            styledContent(block) {
                journalTextBlock(block, font: bodyUIFont(size: 16, weight: .semibold))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading5:
            styledContent(block) {
                journalTextBlock(block, font: bodyUIFont(size: 14, weight: .semibold))
                    .padding(.leading, indentPadding(for: block))
            }
        case .heading6:
            styledContent(block) {
                journalTextBlock(block, font: bodyUIFont(size: 13, weight: .medium))
                    .padding(.leading, indentPadding(for: block))
            }
        case .blockquote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(blockGradient(block.blockquoteColorHex)).frame(width: 4)
                journalTextBlock(block, font: bodyUIFont(size: 16, weight: .regular))
            }
            .padding(12)
            .background(Color.white.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.24), lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, indentPadding(for: block))
        case .callout:
            HStack(alignment: .center, spacing: 12) {
                calloutIconView(for: activeCalloutIconItem(for: block))
                    .frame(width: 20, height: 20, alignment: Alignment.center)
                journalTextBlock(block, font: bodyUIFont(size: 15, weight: .regular))
            }
            .padding(12)
            .background(Color.white.opacity(0.14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(blockGradient(block.calloutColorHex), lineWidth: 5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, indentPadding(for: block))
        case .toggle:
            Button { block.isExpanded.toggle() } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LGradients.blue)
                        .frame(width: 22, alignment: .leading)
                        .padding(.top, prefixWrapperAlignmentPadding(for: block))

                    styledContent(block) {
                        journalTextBlock(block, font: bodyUIFont(size: 16, weight: .regular))
                    }
                }
                .padding(.leading, indentPadding(for: block))
            }
            .buttonStyle(.plain)
        case .toggleHeading1:
            toggleHeadingBlock(block, font: bodyUIFont(size: 28, weight: .bold))
        case .toggleHeading2:
            toggleHeadingBlock(block, font: bodyUIFont(size: 22, weight: .bold))
        case .toggleHeading3:
            toggleHeadingBlock(block, font: bodyUIFont(size: 18, weight: .semibold))
        case .toggleHeading4:
            toggleHeadingBlock(block, font: bodyUIFont(size: 16, weight: .semibold))
        case .toggleHeading5:
            toggleHeadingBlock(block, font: bodyUIFont(size: 14, weight: .semibold))
        case .toggleHeading6:
            toggleHeadingBlock(block, font: bodyUIFont(size: 13, weight: .medium))
        case .bulletedList:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: bulletSymbolName(for: block.indentLevel))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, 6 + prefixWrapperAlignmentPadding(for: block))

                styledContent(block) {
                    journalTextBlock(block, font: bodyUIFont(size: 16, weight: .regular))
                }
            }
            .padding(.leading, indentPadding(for: block))
        case .numberedList:
            HStack(alignment: .top, spacing: 10) {
                Text(numberPrefix(for: block))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 28, alignment: .leading)
                    .padding(.top, prefixWrapperAlignmentPadding(for: block))

                styledContent(block) {
                    journalTextBlock(block, font: bodyUIFont(size: 16, weight: .regular))
                }
            }
            .padding(.leading, indentPadding(for: block))
        case .checklist:
            HStack(alignment: .top, spacing: 10) {
                checklistPrefixButton(for: block)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, 4 + prefixWrapperAlignmentPadding(for: block))

                styledContent(block) {
                    journalTextBlock(block, font: bodyUIFont(size: 16, weight: .regular))
                }
            }
            .padding(.leading, indentPadding(for: block))
        case .divider:
            dividerView(block: block, style: DividerStyle(rawValue: block.languageHint) ?? .line)
        case .code:
            let lang = CodeLanguage.from(block.languageHint)
            let theme = CodeTheme.from(block.calloutEmoji)
            let highlighted = CodeHighlighter.highlight(block.text, language: lang, theme: theme)
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(Array(block.text.components(separatedBy: "\n").enumerated()), id: \.offset) { i, _ in
                            Text("\(i + 1)")
                                .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color(theme.colors.comment))
                                .frame(minWidth: 24, alignment: .trailing)
                        }
                    }
                    .padding(.trailing, 8)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)

                    Text(AttributedString(highlighted))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 10)
                }
                .padding(12)

                Button {
                    UIPasteboard.general.string = block.text
                } label: {
                    Image("copy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.white)
                        .frame(width: 15, height: 15)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(theme.colors.background)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        case .image:
            if let data = block.imageData, let uiImage = UIImage(data: data) {
                let size = block.imageSize; let mode = block.imageDisplayMode
                Group {
                    if let maxH = size.maxHeight {
                        if mode == .fill {
                            Image(uiImage: uiImage).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: maxH)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(uiImage: uiImage).resizable().scaledToFit()
                                .frame(maxWidth: .infinity).frame(maxHeight: maxH)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Image(uiImage: uiImage).resizable().scaledToFit()
                            .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(maxWidth: .infinity, alignment: block.imageAlignment == .center ? .center : .leading)
            }
        case .drawing:
            JournalPencilDrawingPreview(block: block)
        case .table:
            JournalTablePreviewView(block: block, resolvedTextColor: resolvedTextColor)
        }
    }

    // MARK: - Divider

    private func blockGradient(_ hex: String) -> AnyShapeStyle {
        let parts = hex.components(separatedBy: ":")
        if parts.count == 2,
           let c1 = uiColorFromHex(parts[0]),
           let c2 = uiColorFromHex(parts[1]) {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(c1), Color(c2)],
                startPoint: .leading, endPoint: .trailing
            ))
        }
        return AnyShapeStyle(LGradients.blue)
    }

    @ViewBuilder
    private func dividerView(block: JournalBlock, style: DividerStyle) -> some View {
        let grad = blockGradient(block.dividerColorHex)
        switch style {
        case .pageBreak:
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .padding(.vertical, 4)
        case .line:
            Capsule()
                .fill(grad)
                .frame(maxWidth: .infinity)
                .frame(height: 3)
                .padding(.vertical, 4)
        case .dotted:
            let dotSize: CGFloat = 4
            let gap: CGFloat = 8
            GeometryReader { geo in
                let count = max(1, Int(geo.size.width / (dotSize + gap)))
                HStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle().fill(grad).frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity).frame(height: dotSize)
            .padding(.vertical, 4)
        case .dash:
            Capsule()
                .fill(grad)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: 0.5)
                .frame(height: 2)
                .padding(.vertical, 4)
        case .dots:
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in Circle().fill(grad).frame(width: 7, height: 7) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Toggle Heading

    @ViewBuilder
    private func toggleHeadingBlock(_ block: JournalBlock, font: UIFont) -> some View {
        Button { block.isExpanded.toggle() } label: {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: font.pointSize * 0.7, weight: .bold))
                    .foregroundStyle(LGradients.blue)
                    .frame(width: 16, alignment: .center)

                journalTextBlock(block, font: font)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, indentPadding(for: block))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Styled Content Wrapper

    @ViewBuilder
    private func styledContent<Content: View>(_ block: JournalBlock, @ViewBuilder content: () -> Content) -> some View {
        if !wrapperSupportedTypes.contains(block.type) {
            content()
        } else if block.isCalloutStyle {
            calloutStyleWrapper(block) {
                if block.isBlockquoteStyle {
                    blockquoteStyleWrapper(block: block) { content() }
                } else {
                    content()
                }
            }
        } else if block.isBlockquoteStyle {
            blockquoteStyleWrapper(block: block) { content() }
        } else {
            content()
        }
    }

    private func blockquoteStyleWrapper<Content: View>(block: JournalBlock, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(blockGradient(block.blockquoteColorHex)).frame(width: 4)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func calloutStyleWrapper<Content: View>(_ block: JournalBlock, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            calloutIconView(for: activeCalloutIconItem(for: block))
                .frame(width: 20, height: 20, alignment: Alignment.center)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(blockGradient(block.calloutColorHex), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Callout Icon

    private func activeCalloutIconItem(for block: JournalBlock) -> LunixiaIconItem? {
        let trimmed = block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LunixiaIconLibrary.allIcons.first(where: { $0.name == "sparkles" })
        }

        if let item = LunixiaIconLibrary.allIcons.first(where: { $0.id == trimmed || $0.name == trimmed }) {
            return item
        }

        return LunixiaIconLibrary.allIcons.first(where: { $0.name == "sparkles" })
    }

    @ViewBuilder
    private func calloutIconView(for item: LunixiaIconItem?) -> some View {
        if let item {
            switch item.source {
            case .asset:
                Image(item.name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.white)
            case .sfSymbol:
                Image(systemName: item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
        }
    }

    // MARK: - Text Block Builder

    private func journalTextBlock(_ block: JournalBlock, font: UIFont) -> AnyView {
        let mutable = NSMutableAttributedString(string: block.text, attributes: [
            .font: font,
            .foregroundColor: resolvedTextColor
        ])
        let fullLength = (block.text as NSString).length

        if fullLength > 0 {
            for style in block.sortedInlineStyles {
                let raw = style.safeRange
                let maxLen = max(0, fullLength - raw.location)
                let clamped = min(raw.length, maxLen)
                guard raw.location >= 0, raw.location < fullLength, clamped > 0 else { continue }
                let range = NSRange(location: raw.location, length: clamped)

                switch style.type {
                case .bold:
                    mutable.enumerateAttribute(.font, in: range) { v, r, _ in
                        let f = (v as? UIFont) ?? font
                        if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitBold)) {
                            mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: r)
                        }
                    }
                case .italic:
                    mutable.enumerateAttribute(.font, in: range) { v, r, _ in
                        let f = (v as? UIFont) ?? font
                        if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                            mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: r)
                        }
                    }
                case .underline:
                    mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                case .strikethrough:
                    mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                case .link:
                    let t = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty, let url = URL(string: t) {
                        mutable.addAttribute(.link, value: url, range: range)
                        mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    }
                case .inlineCode:
                    let mono = UIFont.monospacedSystemFont(ofSize: font.pointSize * 0.9, weight: .regular)
                    mutable.addAttribute(.font, value: mono, range: range)
                    mutable.addAttribute(.backgroundColor, value: UIColor.white.withAlphaComponent(0.1), range: range)
                case .highlight:
                    let parts = style.urlString.components(separatedBy: ":")
                    guard parts.count == 2,
                          let color1 = uiColorFromHex(parts[0]),
                          let color2 = uiColorFromHex(parts[1]),
                          range.length > 0 else { continue }
                    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
                    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
                    color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                    color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
                    let count = CGFloat(range.length)
                    for i in 0..<range.length {
                        let t = count > 1 ? CGFloat(i) / (count - 1) : 0
                        let blended = UIColor(red: r1+(r2-r1)*t, green: g1+(g2-g1)*t, blue: b1+(b2-b1)*t, alpha: 1)
                        mutable.addAttribute(.foregroundColor, value: blended, range: NSRange(location: range.location + i, length: 1))
                    }
                case .mention:
                    mutable.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
                    mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    // Embed the mention target ID so RichBlockTextView can fire the tap callback
                    let mentionID = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !mentionID.isEmpty {
                        mutable.addAttribute(JournalMentionIDAttributeName, value: mentionID, range: range)
                    }
                }
            }
        }

        if block.type == .checklist && !checklistState(for: block).isEmpty && fullLength > 0 {
            let fullRange = NSRange(location: 0, length: fullLength)
            mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.textSecondary), range: fullRange)
        }

        return AnyView(
            RichBlockTextView(attributedText: mutable, isSelectable: false, linkTintColor: UIColor.systemBlue, onMentionTapped: onMentionTapped)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        )
    }

    // MARK: - Checklist

    private func checklistPrefixButton(for block: JournalBlock) -> some View {
        checklistPrefixIcon(for: block)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                block.languageHint = "xmark"
                block.touch()
                try? modelContext.save()
            }
            .onTapGesture {
                let state = checklistState(for: block)
                block.languageHint = state == "checked" ? "" : "checked"
                block.touch()
                try? modelContext.save()
            }
    }

    @ViewBuilder
    private func checklistPrefixIcon(for block: JournalBlock) -> some View {
        switch checklistState(for: block) {
        case "checked":
            ZStack {
                Circle().fill(LGradients.blue).frame(width: 17, height: 17)
                Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Color.white)
            }
        case "xmark":
            ZStack {
                Circle().fill(Color.white.opacity(0.18)).frame(width: 17, height: 17)
                    .overlay(Circle().stroke(LGradients.blue, lineWidth: 1.3))
                Image(systemName: "xmark").font(.system(size: 9, weight: .black)).foregroundStyle(Color.white)
            }
        default:
            Circle().stroke(LColors.textSecondary, lineWidth: 1.4).frame(width: 17, height: 17)
        }
    }

    private func checklistState(for block: JournalBlock) -> String {
        block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Visible Blocks

    private var visibleBlocks: [JournalBlock] {
        var hiddenParentIDs = Set<UUID>()
        var result: [JournalBlock] = []
        for block in entry.sortedBlocks {
            if let parentID = block.parentBlockID, hiddenParentIDs.contains(parentID) {
                if block.isToggleBlock || block.type.isToggleHeading { hiddenParentIDs.insert(block.id) }
                continue
            }
            result.append(block)
            if (block.isToggleBlock || block.type.isToggleHeading) && !block.isExpanded {
                hiddenParentIDs.insert(block.id)
            }
        }
        return result
    }

    // MARK: - Numbered List

    private func numberPrefix(for block: JournalBlock) -> String {
        guard block.type == .numberedList, let groupID = block.listGroupID else { return "1." }
        let siblings = entry.sortedBlocks.filter {
            $0.type == .numberedList && $0.listGroupID == groupID && $0.indentLevel == block.indentLevel
        }
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return "1." }
        return "\(index + 1)."
    }

    private func bulletSymbolName(for indentLevel: Int) -> String {
        indentLevel % 2 == 1 ? "circle" : "circle.fill"
    }
}

// MARK: - Drawing Preview

private struct JournalPencilDrawingPreview: View {
    let block: JournalBlock

    var body: some View {
        Group {
            if let data = block.drawingData,
               let drawing = try? PKDrawing(data: data),
               !drawing.bounds.isEmpty {
                Image(uiImage: drawing.image(
                    from: drawing.bounds,
                    scale: UIScreen.main.scale
                ))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 180)
                    .overlay(
                        Text("Empty Drawing")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Table Preview

struct JournalTablePreviewView: View {
    let block: JournalBlock
    let resolvedTextColor: UIColor

    private var tableData: JournalTableData {
        JournalTableData.from(block.text)
    }

    private func cellBackground(row: Int, col: Int, isHeader: Bool) -> Color {
        let bgHex = tableData.cellBgColor(row: row, col: col)
        if !bgHex.isEmpty, let bg = uiColorFromHex(bgHex) {
            return Color(bg)
        }
        return isHeader ? Color.white.opacity(0.06) : Color.clear
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<tableData.rowCount, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<tableData.colCount, id: \.self) { col in
                            let isHeader = row == 0
                            let baseFont: UIFont = isHeader
                                ? .systemFont(ofSize: 13, weight: .bold)
                                : .systemFont(ofSize: 13, weight: .regular)
                            let attributed = tableData.attributedText(
                                row: row, col: col,
                                baseFont: baseFont,
                                textColor: resolvedTextColor
                            )
                            JournalAttributedTextView(attributed: attributed)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(minWidth: 80, maxWidth: 200, alignment: .leading)
                                .background(cellBackground(row: row, col: col, isHeader: isHeader))

                            if col < tableData.colCount - 1 {
                                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if row < tableData.rowCount - 1 {
                        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                    }
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

// MARK: - Minimal read-only UITextView wrapper

private struct JournalAttributedTextView: UIViewRepresentable {
    let attributed: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let tv = JournalTableCellTextView()
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributed {
            uiView.attributedText = attributed
            uiView.invalidateIntrinsicContentSize()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = min(proposal.width ?? 120, 200)
        let fitting = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return CGSize(width: max(80, w), height: max(1, fitting.height))
    }

    final class JournalTableCellTextView: UITextView {
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let velocity = pan.velocity(in: self)
                if abs(velocity.y) > abs(velocity.x) * 2 { return false }
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }
}


private func uiColorFromHex(_ hex: String) -> UIColor? {
    var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)

    if cleaned.hasPrefix("#") {
        cleaned.removeFirst()
    }

    if cleaned.count == 3 {
        cleaned = cleaned.map { "\($0)\($0)" }.joined()
    }

    guard cleaned.count == 6,
          let value = UInt64(cleaned, radix: 16) else {
        return nil
    }

    let red = CGFloat((value & 0xFF0000) >> 16) / 255
    let green = CGFloat((value & 0x00FF00) >> 8) / 255
    let blue = CGFloat(value & 0x0000FF) / 255

    return UIColor(red: red, green: green, blue: blue, alpha: 1)
}
