//
//  JournalBlockRow.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import PencilKit

struct JournalBlockRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: JournalBlock

    var onAddBelow: (JournalBlock, JournalBlockType, String) -> Void
    var onDelete: (JournalBlock) -> Void
    var onMoveUp: (JournalBlock) -> Void
    var onMoveDown: (JournalBlock) -> Void
    var onTransform: (JournalBlock, JournalBlockType) -> Void

    var isSelectionMode: Bool = false
    var isSelectedForBatchAction: Bool = false
    var selectedBlockCount: Int = 0
    var onEnterSelectionMode: (JournalBlock) -> Void = { _ in }
    var onToggleBatchSelection: (JournalBlock) -> Void = { _ in }
    var onClearBatchSelection: () -> Void = {}
    var onDeleteSelectedBlocks: () -> Void = {}
    var onIndentSelectedBlocksIn: () -> Void = {}
    var onIndentSelectedBlocksOut: () -> Void = {}
    var onTextHeightIncrease: (JournalBlock) -> Void = { _ in }
    var journalTextColor: UIColor = UIColor(LColors.textPrimary)

    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showLinkEditor = false
    @State private var linkDraft = ""
    @State private var showHighlightPicker = false
    @State private var highlightForeground: Color = .white
    @State private var highlightBackground: Color = Color(red: 1, green: 0.85, blue: 0.24)
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showCalloutIconPicker = false
    @State private var isScrollingCalloutIconPicker = false
    @State private var isImageToolbarVisible = false
    @State private var showDrawingEditor = false
    // Block accent color pickers
    @State private var showDividerColorPicker = false
    @State private var dividerColor1: Color = Color(red: 0.32, green: 0.27, blue: 0.96)
    @State private var dividerColor2: Color = Color(red: 0.71, green: 0.45, blue: 0.98)
    @State private var showBlockquoteColorPicker = false
    @State private var blockquoteColor1: Color = Color(red: 0.32, green: 0.27, blue: 0.96)
    @State private var blockquoteColor2: Color = Color(red: 0.71, green: 0.45, blue: 0.98)
    @State private var showCalloutColorPicker = false
    @State private var calloutColor1: Color = Color(red: 0.32, green: 0.27, blue: 0.96)
    @State private var calloutColor2: Color = Color(red: 0.71, green: 0.45, blue: 0.98)

    private let maxIndentLevel = 5

    private var indentPadding: CGFloat {
        CGFloat(block.indentLevel) * 20
    }

    private var paragraphTopPadding: CGFloat {
        guard block.type == .paragraph else { return 0 }
        return block.indentLevel > 0 ? 0 : 3
    }

    private var prefixWrapperAlignmentPadding: CGFloat {
        block.isBlockquoteStyle || block.isCalloutStyle ? 12 : 0
    }

    @ViewBuilder
    private func transformButton(_ title: String, icon: String, type: JournalBlockType) -> some View {
        Button {
            onTransform(block, type)
        } label: {
            Label(title, systemImage: icon)
        }
        .disabled(block.type == type)
    }

    private func toggleBlockquoteStyle() {
        guard supportsWrapperStyles else { return }
        block.isBlockquoteStyle.toggle()
        block.touch()
    }

    private func toggleCalloutStyle() {
        guard supportsWrapperStyles else { return }
        block.isCalloutStyle.toggle()
        if block.isCalloutStyle && block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            block.calloutEmoji = defaultCalloutIconID
        }
        block.touch()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if supportsInlineFormatting && selectedRange.length > 0 {
                selectionFormatMenu
            }
            VStack(alignment: .leading, spacing: block.isListBlock ? 2 : 4) {
                contentColumn
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, isSelectionMode ? 4 : 0)
        .padding(.horizontal, isSelectionMode ? 8 : 0)
        .background(batchSelectionBackground)
        .overlay(batchSelectionOverlay)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelectionMode else { return }
            onToggleBatchSelection(block)
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            guard !isSelectionMode else { return }
            onEnterSelectionMode(block)
        }
        .padding(.top, paragraphTopPadding)
        .contextMenu {
            if isSelectionMode {
                Button {
                    onToggleBatchSelection(block)
                } label: {
                    Label(isSelectedForBatchAction ? "Deselect Block" : "Select Block",
                          systemImage: isSelectedForBatchAction ? "checkmark.circle.fill" : "circle")
                }

                if selectedBlockCount > 0 {
                    Menu {
                        Button { onIndentSelectedBlocksOut() } label: {
                            Label("Indent Out", systemImage: "decrease.indent")
                        }
                        Button { onIndentSelectedBlocksIn() } label: {
                            Label("Indent In", systemImage: "increase.indent")
                        }
                        Divider()
                        Button(role: .destructive) { onDeleteSelectedBlocks() } label: {
                            Label("Delete Selected", systemImage: "trash")
                        }
                    } label: {
                        Label("Selected Actions", systemImage: "checklist")
                    }
                }

                Button { onClearBatchSelection() } label: {
                    Label("Clear Selection", systemImage: "xmark.circle")
                }

                Divider()
            } else {
                Button { onEnterSelectionMode(block) } label: {
                    Label("Select Multiple", systemImage: "checklist")
                }
                Divider()
            }

            if canIndentBlock {
                Button { indentOut() } label: {
                    Label("Indent Out", systemImage: "decrease.indent")
                }
                .disabled(block.indentLevel <= 0)

                Button { indentIn() } label: {
                    Label("Indent In", systemImage: "increase.indent")
                }
                .disabled(block.indentLevel >= maxIndentLevel)

                Divider()
            }

            Menu {
                transformButton("Paragraph", icon: "text.alignleft", type: .paragraph)

                Menu {
                    transformButton("Heading 1", icon: "textformat.size.larger", type: .heading1)
                    transformButton("Heading 2", icon: "textformat.size", type: .heading2)
                    transformButton("Heading 3", icon: "textformat", type: .heading3)
                    transformButton("Heading 4", icon: "textformat", type: .heading4)
                    transformButton("Heading 5", icon: "textformat", type: .heading5)
                    transformButton("Heading 6", icon: "textformat", type: .heading6)
                } label: { Label("Headings", systemImage: "textformat.size.larger") }

                Menu {
                    transformButton("Toggle", icon: "chevron.right.square", type: .toggle)
                    transformButton("Toggle H1", icon: "chevron.right.square", type: .toggleHeading1)
                    transformButton("Toggle H2", icon: "chevron.right.square", type: .toggleHeading2)
                    transformButton("Toggle H3", icon: "chevron.right.square", type: .toggleHeading3)
                    transformButton("Toggle H4", icon: "chevron.right.square", type: .toggleHeading4)
                    transformButton("Toggle H5", icon: "chevron.right.square", type: .toggleHeading5)
                    transformButton("Toggle H6", icon: "chevron.right.square", type: .toggleHeading6)
                } label: { Label("Toggles", systemImage: "chevron.right.square") }

                transformButton("Bullet List", icon: "list.bullet", type: .bulletedList)
                transformButton("Numbered List", icon: "list.number", type: .numberedList)
                transformButton("Checklist", icon: "checklist", type: .checklist)

                Divider()

                transformButton("Code", icon: "chevron.left.forwardslash.chevron.right", type: .code)
                transformButton("Divider", icon: "minus", type: .divider)
                transformButton("Drawing", icon: "pencil.tip", type: .drawing)
                transformButton("Table", icon: "tablecells", type: .table)
            } label: {
                Label("Turn Into", systemImage: "wand.and.stars")
            }

            if supportsWrapperStyles {
                Menu {
                    Button { toggleBlockquoteStyle() } label: {
                        Label(block.isBlockquoteStyle ? "Remove Blockquote" : "Blockquote", systemImage: "quote.opening")
                    }
                    Button { toggleCalloutStyle() } label: {
                        Label(block.isCalloutStyle ? "Remove Callout" : "Callout", systemImage: "sparkles")
                    }
                } label: {
                    Label("Apply Style", systemImage: "paintbrush")
                }
            }

            // Accent color options — shown contextually
            if block.type == .divider {
                Button {
                    loadDividerColors()
                    showDividerColorPicker = true
                } label: {
                    Label("Divider Color", systemImage: "paintpalette")
                }
            }
            if block.isBlockquoteStyle || block.type == .blockquote {
                Button {
                    loadBlockquoteColors()
                    showBlockquoteColorPicker = true
                } label: {
                    Label("Blockquote Color", systemImage: "paintpalette")
                }
            }
            if block.isCalloutStyle || block.type == .callout {
                Button {
                    loadCalloutColors()
                    showCalloutColorPicker = true
                } label: {
                    Label("Callout Color", systemImage: "paintpalette")
                }
            }

            Divider()

            Button { onMoveUp(block) } label: { Label("Move Up", systemImage: "arrow.up") }
            Button { onMoveDown(block) } label: { Label("Move Down", systemImage: "arrow.down") }
            Button(role: .destructive) { onDelete(block) } label: { Label("Delete", systemImage: "trash") }
        }
        .sheet(isPresented: $showCalloutIconPicker) {
            calloutIconPickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showDividerColorPicker) {
            blockAccentColorSheet(
                title: "Divider Color",
                color1: $dividerColor1,
                color2: $dividerColor2,
                onApply: {
                    block.dividerColorHex = hexGradientString(color1: UIColor(dividerColor1), color2: UIColor(dividerColor2))
                    block.touch()
                    showDividerColorPicker = false
                },
                onReset: {
                    block.dividerColorHex = ""
                    block.touch()
                    showDividerColorPicker = false
                },
                hasCustomColor: !block.dividerColorHex.isEmpty
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBlockquoteColorPicker) {
            blockAccentColorSheet(
                title: "Blockquote Color",
                color1: $blockquoteColor1,
                color2: $blockquoteColor2,
                onApply: {
                    block.blockquoteColorHex = hexGradientString(color1: UIColor(blockquoteColor1), color2: UIColor(blockquoteColor2))
                    block.touch()
                    showBlockquoteColorPicker = false
                },
                onReset: {
                    block.blockquoteColorHex = ""
                    block.touch()
                    showBlockquoteColorPicker = false
                },
                hasCustomColor: !block.blockquoteColorHex.isEmpty
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showCalloutColorPicker) {
            blockAccentColorSheet(
                title: "Callout Color",
                color1: $calloutColor1,
                color2: $calloutColor2,
                onApply: {
                    block.calloutColorHex = hexGradientString(color1: UIColor(calloutColor1), color2: UIColor(calloutColor2))
                    block.touch()
                    showCalloutColorPicker = false
                },
                onReset: {
                    block.calloutColorHex = ""
                    block.touch()
                    showCalloutColorPicker = false
                },
                hasCustomColor: !block.calloutColorHex.isEmpty
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .alert("Insert Link", isPresented: $showLinkEditor) {
            TextField("https://example.com", text: $linkDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { linkDraft = "" }
            Button("Apply") { applyLinkFromDraft() }
        } message: {
            Text("Select text in the block first, then add a link.")
        }
    }

    private var batchSelectionBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelectedForBatchAction
                  ? AnyShapeStyle(LGradients.blue.opacity(0.22))
                  : AnyShapeStyle(Color.white.opacity(isSelectionMode ? 0.04 : 0)))
    }

    private var batchSelectionOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isSelectedForBatchAction
                    ? AnyShapeStyle(LGradients.blue)
                    : AnyShapeStyle(Color.clear), lineWidth: 1)
    }

    // MARK: - Format Menu

    private var selectionFormatMenu: some View {
        HStack(spacing: 8) {
            Menu {
                Button(rangeHasStyle(.bold) ? "Remove Bold" : "Bold") { toggleInlineStyle(.bold) }
                Button(rangeHasStyle(.italic) ? "Remove Italic" : "Italic") { toggleInlineStyle(.italic) }
                Button(rangeHasStyle(.underline) ? "Remove Underline" : "Underline") { toggleInlineStyle(.underline) }
                Button(rangeHasStyle(.strikethrough) ? "Remove Strikethrough" : "Strikethrough") { toggleInlineStyle(.strikethrough) }
                Button(rangeHasStyle(.inlineCode) ? "Remove Code" : "Code") { toggleInlineStyle(.inlineCode) }
                Button(rangeHasStyle(.link) ? "Edit Link" : "Add Link") { prepareLinkEditor() }
            } label: {
                Text("Format")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LGradients.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(LGradients.blue, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                if let existing = (block.inlineStyles ?? []).first(where: {
                    $0.type == .highlight && NSEqualRanges($0.safeRange, selectedRange)
                }) {
                    let parts = existing.urlString.components(separatedBy: ":")
                    if parts.count == 2 {
                        highlightForeground = Color(uiColorFromHex(parts[0]) ?? .white)
                        highlightBackground = Color(uiColorFromHex(parts[1]) ?? UIColor(red: 1, green: 0.85, blue: 0.24, alpha: 1))
                    }
                }
                showHighlightPicker = true
            } label: {
                ZStack {
                    let activeHex = (block.inlineStyles ?? []).first(where: {
                        $0.type == .highlight && NSEqualRanges($0.safeRange, selectedRange)
                    })?.urlString.components(separatedBy: ":").last ?? ""
                    Circle()
                        .fill(activeHex.isEmpty
                              ? AnyShapeStyle(Color.white.opacity(0.08))
                              : AnyShapeStyle(Color(uiColorFromHex(activeHex) ?? .yellow)))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LColors.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showHighlightPicker) {
                highlightPickerSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        switch block.type {
        case .divider:   dividerEditor
        case .code:      codeEditor
        case .callout:   calloutEditor
        case .image:     imageEditor
        case .drawing:   drawingEditor
        case .table:     tableEditor
        case .toggle, .toggleHeading1, .toggleHeading2, .toggleHeading3,
             .toggleHeading4, .toggleHeading5, .toggleHeading6: textEditor
        default:         textEditor
        }
    }

    @ViewBuilder
    private func styledContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if block.isCalloutStyle {
            calloutStyleWrapper {
                if block.isBlockquoteStyle {
                    blockquoteStyleWrapper { content() }
                } else {
                    content()
                }
            }
        } else if block.isBlockquoteStyle {
            blockquoteStyleWrapper { content() }
        } else {
            content()
        }
    }

    private var resolvedBlockquoteGradient: AnyShapeStyle {
        gradientFromHex(block.blockquoteColorHex)
    }

    private var resolvedCalloutGradient: AnyShapeStyle {
        gradientFromHex(block.calloutColorHex)
    }

    private func gradientFromHex(_ hex: String) -> AnyShapeStyle {
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

    private func dividerGradientFromHex(_ hex: String) -> AnyShapeStyle {
        gradientFromHex(hex)
    }

    private func blockquoteStyleWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(resolvedBlockquoteGradient).frame(width: 4)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.24), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func calloutStyleWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            calloutIconPicker
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(resolvedCalloutGradient, lineWidth: 5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var calloutIconPicker: some View {
        Button { showCalloutIconPicker = true } label: {
            calloutIconView(for: activeCalloutIconItem)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var calloutIconPickerSheet: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground().ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(LunixiaIconLibrary.categories, id: \.self) { category in
                            calloutIconSection(
                                title: category,
                                items: LunixiaIconLibrary.icons(in: category)
                            )
                        }
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { _ in isScrollingCalloutIconPicker = true }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                isScrollingCalloutIconPicker = false
                            }
                        }
                )
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func calloutIconSection(title: String, items: [LunixiaIconItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 12)], spacing: 12) {
                ForEach(items, id: \.id) { item in
                    calloutIconGridButton(for: item)
                }
            }
        }
    }

    private func calloutIconGridButton(for item: LunixiaIconItem) -> some View {
        let isSelected = activeCalloutIconItem?.id == item.id

        return Button {
            guard !isScrollingCalloutIconPicker else { return }
            block.calloutEmoji = item.id
            block.touch()
            showCalloutIconPicker = false
        } label: {
            calloutIconView(for: item)
                .frame(width: 22, height: 22)
                .frame(width: 54, height: 54)
                .background(
                    isSelected
                    ? AnyShapeStyle(LColors.accentGradient)
                    : AnyShapeStyle(LColors.glassSurface)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(LColors.glassBorder),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var defaultCalloutIconID: String {
        LunixiaIconLibrary.allIcons.first(where: { $0.name == "sparkles" })?.id
        ?? LunixiaIconLibrary.allIcons.first?.id
        ?? "sfSymbol-sparkles"
    }

    private var activeCalloutIconItem: LunixiaIconItem? {
        let trimmed = block.calloutEmoji.trimmingCharacters(in: .whitespacesAndNewlines)

        if let item = LunixiaIconLibrary.allIcons.first(where: { $0.id == trimmed || $0.name == trimmed }) {
            return item
        }

        return LunixiaIconLibrary.allIcons.first(where: { $0.id == defaultCalloutIconID || $0.name == "sparkles" })
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

    // MARK: - Text Editor

    private var textEditor: some View {
        Group {
            if block.type == .blockquote {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(resolvedBlockquoteGradient).frame(width: 4)
                    JournalRichEditableBlockTextView(
                        block: block, selectedRange: $selectedRange,
                        baseUIFont: uiFontForBlockType(block.type),
                        textColor: journalTextColor,
                        placeholder: placeholderText, isCodeBlock: false,
                        isSelectionMode: isSelectionMode,
                        onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                        onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                        onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                        onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil,
                        onContentHeightIncrease: { onTextHeightIncrease(block) }
                    )
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.24), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.leading, indentPadding)
            } else if block.isToggleBlock || block.type == .bulletedList || block.type == .numberedList || block.type == .checklist {
                HStack(alignment: .top, spacing: 8) {
                    if block.isToggleBlock {
                        Button {
                            block.isExpanded.toggle()
                            block.touch()
                        } label: {
                            prefixView(for: block)
                                .frame(width: 22, alignment: .leading)
                                .padding(.top, prefixWrapperAlignmentPadding)
                        }
                        .buttonStyle(.plain)
                    } else if block.type == .checklist {
                        checklistPrefixButton
                            .frame(width: 22, alignment: .leading)
                            .padding(.top, prefixWrapperAlignmentPadding)
                    } else {
                        prefixView(for: block)
                            .frame(width: 22, alignment: .leading)
                            .padding(.top, prefixWrapperAlignmentPadding)
                    }
                    styledContent {
                        JournalRichEditableBlockTextView(
                            block: block, selectedRange: $selectedRange,
                            baseUIFont: uiFontForBlockType(block.type),
                            textColor: journalTextColor,
                            placeholder: placeholderText, isCodeBlock: false,
                            isSelectionMode: isSelectionMode,
                            onCreateParagraphBelow: { suffix in onAddBelow(block, nextBlockTypeOnReturn(for: block.type), suffix) },
                            onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                            onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                            onDeleteEmptyBlock: { onDelete(block) },
                            onExitList: { onAddBelow(block, .paragraph, ""); onDelete(block) },
                            onContentHeightIncrease: { onTextHeightIncrease(block) }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, indentPadding)
            } else {
                styledContent {
                    JournalRichEditableBlockTextView(
                        block: block, selectedRange: $selectedRange,
                        baseUIFont: uiFontForBlockType(block.type),
                        textColor: journalTextColor,
                        placeholder: placeholderText, isCodeBlock: false,
                        isSelectionMode: isSelectionMode,
                        onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                        onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                        onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                        onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil,
                        onContentHeightIncrease: { onTextHeightIncrease(block) }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, indentPadding)
            }
        }
    }
    
    // MARK: - Drawing Editor

    private var drawingEditor: some View {
        Button {
            showDrawingEditor = true
        } label: {
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
                    .frame(maxWidth: .infinity)

                } else {

                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 220)
                        .overlay {
                            VStack(spacing: 10) {
                                Image(systemName: "pencil.and.scribble")
                                    .font(.system(size: 40))

                                Text("Tap to Draw")
                                    .font(.headline)
                            }
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showDrawingEditor) {
            JournalDrawingView(
                drawingData: Binding(
                    get: { block.drawingData ?? Data() },
                    set: {
                        block.drawingData = $0
                        block.touch()
                    }
                )
            )
        }
    }

    // MARK: - Table Editor

    private var tableEditor: some View {
        JournalTableEditorView(block: block, journalTextColor: journalTextColor)
    }

    // MARK: - Callout Editor

    private var calloutEditor: some View {
        HStack(alignment: .center, spacing: 12) {
            calloutIconPicker
            JournalRichEditableBlockTextView(
                block: block, selectedRange: $selectedRange,
                baseUIFont: (block.entry?.resolvedBodyUIFont(size: 15, weight: .regular) ?? UIFont.systemFont(ofSize: 15, weight: .regular)),
                textColor: journalTextColor,
                placeholder: "Write callout...", isCodeBlock: false,
                isSelectionMode: isSelectionMode,
                onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil,
                onContentHeightIncrease: { onTextHeightIncrease(block) }
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(resolvedCalloutGradient, lineWidth: 5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.leading, indentPadding)
    }

    // MARK: - Divider Editor

    private var dividerEditor: some View {
        let current = DividerStyle(rawValue: block.languageHint) ?? .line
        let preview = dividerPreview(style: current)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        if isSelectionMode {
            return AnyView(preview)
        } else {
            return AnyView(preview.onTapGesture {
                let all = DividerStyle.allCases
                let next = all[(all.firstIndex(of: current)! + 1) % all.count]
                block.languageHint = next.rawValue
                block.touch()
            })
        }
    }

    @ViewBuilder
    private func dividerPreview(style: DividerStyle) -> some View {
        let grad = dividerGradientFromHex(block.dividerColorHex)
        switch style {
        case .pageBreak:
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .padding(.vertical, 4)
        case .line:
            Capsule().fill(grad).frame(maxWidth: .infinity).frame(height: 3)
        case .dotted:
            let dotSize: CGFloat = 4; let gap: CGFloat = 8
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
        case .dash:
            Capsule().fill(grad).frame(maxWidth: .infinity).scaleEffect(x: 0.5).frame(height: 2)
        case .dots:
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in Circle().fill(grad).frame(width: 7, height: 7) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Code Editor

    private var codeLanguage: CodeLanguage { CodeLanguage.from(block.languageHint) }
    private var codeTheme: CodeTheme { CodeTheme.from(block.calloutEmoji) }

    private var codeEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(CodeLanguage.allCases) { lang in
                        Button {
                            block.languageHint = lang.rawValue; block.touch()
                        } label: {
                            if codeLanguage == lang { Label(lang.rawValue, systemImage: "checkmark") }
                            else { Text(lang.rawValue) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(codeLanguage.rawValue).font(.system(size: 11, weight: .semibold)).foregroundStyle(LColors.textSecondary)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(LColors.textSecondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.06)).clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Menu {
                    ForEach(CodeTheme.allCases) { thm in
                        Button {
                            block.calloutEmoji = thm.rawValue; block.touch()
                        } label: {
                            if codeTheme == thm { Label(thm.rawValue, systemImage: "checkmark") }
                            else { Text(thm.rawValue) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paintpalette").font(.system(size: 10, weight: .semibold))
                        Text(codeTheme.rawValue).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.06)).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.08))

            HStack(alignment: .top, spacing: 0) {
                codeLineNumberGutter
                Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1).frame(maxHeight: .infinity)
                JournalRichEditableBlockTextView(
                    block: block, selectedRange: $selectedRange,
                    baseUIFont: codeEditorUIFont,
                    textColor: codeTheme.colors.text,
                    placeholder: "Write code...", isCodeBlock: true,
                    isSelectionMode: isSelectionMode,
                    codeLanguage: codeLanguage, codeTheme: codeTheme,
                    onCreateParagraphBelow: { suffix in onAddBelow(block, .paragraph, suffix) },
                    onCreateTypedBlockBelow: { type, text in onAddBelow(block, type, text) },
                    onMergeWithPrevious: { mergeWithPreviousBlock(block) },
                    onDeleteEmptyBlock: { onDelete(block) }, onExitList: nil,
                    onContentHeightIncrease: { onTextHeightIncrease(block) }
                )
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .padding(.leading, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(codeTheme.colors.background)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var codeEditorUIFont: UIFont {
        UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
    }

    private var codeLineNumberGutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...codeLineCount, id: \.self) { number in
                Text("\(number)")
                    .font(.system(size: codeEditorUIFont.pointSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(LColors.textSecondary.opacity(0.58))
                    .frame(width: codeGutterWidth, height: codeEditorUIFont.lineHeight, alignment: .trailing)
            }
        }
        .padding(.trailing, 8)
    }

    private var codeLineCount: Int { max(1, block.text.components(separatedBy: "\n").count) }
    private var codeGutterWidth: CGFloat { CGFloat(max(1, String(codeLineCount).count)) * 8 + 4 }

    // MARK: - Image Editor

    private var imageEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data = block.imageData, let uiImage = UIImage(data: data) {
                VStack(alignment: block.imageAlignment == .center ? .center : .leading, spacing: 8) {
                    let imageViewContent = imageView(uiImage: uiImage)
                        .frame(maxWidth: .infinity, alignment: block.imageAlignment == .center ? .center : .leading)
                        .contentShape(Rectangle())

                    if isSelectionMode {
                        imageViewContent
                    } else {
                        imageViewContent.onTapGesture {
                            withAnimation(.easeInOut(duration: 0.18)) { isImageToolbarVisible.toggle() }
                        }
                    }

                    if isImageToolbarVisible {
                        HStack(spacing: 8) {
                            imageControlButton(
                                icon: block.imageAlignment == .center ? "text.aligncenter" : "text.alignleft",
                                label: block.imageAlignment == .center ? "Center" : "Left"
                            ) { block.imageAlignment = block.imageAlignment == .center ? .left : .center; block.touch() }
                            imageControlButton(
                                icon: block.imageDisplayMode == .fill ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                                label: block.imageDisplayMode.label
                            ) { block.imageDisplayMode = block.imageDisplayMode == .fit ? .fill : .fit; block.touch() }
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12, weight: .semibold))
                                    Text("Replace").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule()).overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 6) {
                            ForEach(ImageBlockSize.allCases, id: \.rawValue) { size in
                                let active = block.imageSize == size
                                Button { block.imageSize = size; block.touch() } label: {
                                    Text(size.label)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(active ? .white : LColors.textPrimary)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(active ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(active ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(AnyShapeStyle(LGradients.blue))
                        Text("Add Photo")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AnyShapeStyle(LGradients.blue))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 28)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AnyShapeStyle(LGradients.blue), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let compressed = UIImage(data: data).flatMap { $0.jpegData(compressionQuality: 0.75) } ?? data
                    await MainActor.run { block.imageData = compressed; block.touch() }
                }
                await MainActor.run { selectedPhotoItem = nil }
            }
        }
    }

    @ViewBuilder
    private func imageView(uiImage: UIImage) -> some View {
        let size = block.imageSize; let mode = block.imageDisplayMode
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

    private func imageControlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(LColors.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule()).overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Highlight

    private var highlightPickerSheet: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground().ignoresSafeArea()
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        ColorPicker("Color 1", selection: $highlightForeground, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                        ColorPicker("Color 2", selection: $highlightBackground, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                            Gradient(colors: [highlightForeground, highlightBackground]),
                            startPoint: CGPoint(x: 0, y: size.height / 2),
                            endPoint: CGPoint(x: size.width, y: size.height / 2)
                        ))
                    }
                    .frame(width: 160, height: 28)
                    .mask {
                        Text("Highlight Text").font(.system(size: 20, weight: .bold)).frame(width: 160, height: 28)
                    }

                    Button {
                        applyHighlight(); showHighlightPicker = false
                    } label: {
                        Text("Apply Highlight")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LGradients.blue).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain).padding(.horizontal, LSpacing.pageHorizontal)

                    if rangeHasStyle(.highlight) {
                        Button {
                            removeHighlight(); showHighlightPicker = false
                        } label: {
                            Text("Remove Highlight").font(.system(size: 14, weight: .medium)).foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle("Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func applyHighlight() {
        guard selectedRange.length > 0 else { return }
        removeHighlight()
        let fgHex = hexString(from: UIColor(highlightForeground))
        let bgHex = hexString(from: UIColor(highlightBackground))
        let style = JournalInlineStyle(
            type: .highlight,
            rangeLocation: selectedRange.location,
            rangeLength: selectedRange.length,
            urlString: "\(fgHex):\(bgHex)"
        )
        style.block = block
        modelContext.insert(style)
        if block.inlineStyles == nil { block.inlineStyles = [] }
        block.inlineStyles?.append(style)
        block.touch()
    }

    private func removeHighlight() {
        guard let idx = block.inlineStyles?.firstIndex(where: {
            $0.type == .highlight && NSEqualRanges($0.safeRange, selectedRange)
        }) else { return }
        let old = block.inlineStyles?.remove(at: idx)
        if let old { modelContext.delete(old) }
        block.touch()
    }

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func hexGradientString(color1: UIColor, color2: UIColor) -> String {
        "\(hexString(from: color1)):\(hexString(from: color2))"
    }

    // MARK: - Block Accent Color Loader Helpers

    private func loadDividerColors() {
        let parts = block.dividerColorHex.components(separatedBy: ":")
        if parts.count == 2,
           let c1 = uiColorFromHex(parts[0]),
           let c2 = uiColorFromHex(parts[1]) {
            dividerColor1 = Color(c1); dividerColor2 = Color(c2)
        } else {
            dividerColor1 = Color(red: 0.32, green: 0.27, blue: 0.96)
            dividerColor2 = Color(red: 0.71, green: 0.45, blue: 0.98)
        }
    }

    private func loadBlockquoteColors() {
        let parts = block.blockquoteColorHex.components(separatedBy: ":")
        if parts.count == 2,
           let c1 = uiColorFromHex(parts[0]),
           let c2 = uiColorFromHex(parts[1]) {
            blockquoteColor1 = Color(c1); blockquoteColor2 = Color(c2)
        } else {
            blockquoteColor1 = Color(red: 0.32, green: 0.27, blue: 0.96)
            blockquoteColor2 = Color(red: 0.71, green: 0.45, blue: 0.98)
        }
    }

    private func loadCalloutColors() {
        let parts = block.calloutColorHex.components(separatedBy: ":")
        if parts.count == 2,
           let c1 = uiColorFromHex(parts[0]),
           let c2 = uiColorFromHex(parts[1]) {
            calloutColor1 = Color(c1); calloutColor2 = Color(c2)
        } else {
            calloutColor1 = Color(red: 0.32, green: 0.27, blue: 0.96)
            calloutColor2 = Color(red: 0.71, green: 0.45, blue: 0.98)
        }
    }

    // MARK: - Block Accent Color Sheet

    private func blockAccentColorSheet(
        title: String,
        color1: Binding<Color>,
        color2: Binding<Color>,
        onApply: @escaping () -> Void,
        onReset: @escaping () -> Void,
        hasCustomColor: Bool
    ) -> some View {
        NavigationStack {
            ZStack {
                LunixiaBackground().ignoresSafeArea()
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        ColorPicker("Color 1", selection: color1, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                        ColorPicker("Color 2", selection: color2, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(LColors.textPrimary)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    // Gradient preview bar
                    LinearGradient(
                        colors: [color1.wrappedValue, color2.wrappedValue],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(maxWidth: .infinity).frame(height: 6)
                    .clipShape(Capsule())
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    Button(action: onApply) {
                        Text("Apply")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LGradients.blue).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain).padding(.horizontal, LSpacing.pageHorizontal)

                    if hasCustomColor {
                        Button(action: onReset) {
                            Text("Reset to Default")
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Inline Style Helpers

    private var supportsInlineFormatting: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout: return true
        case .divider, .code, .image, .drawing, .table: return false
        }
    }

    private var supportsWrapperStyles: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggle, .bulletedList, .numberedList, .checklist:
            return true
        case .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
               .blockquote, .callout, .divider, .code, .image, .drawing, .table:
            return false
        }
    }

    private func rangeHasStyle(_ style: JournalInlineStyleType) -> Bool {
        guard selectedRange.length > 0 else { return false }
        return (block.inlineStyles ?? []).contains {
            $0.type == style && NSEqualRanges($0.safeRange, selectedRange)
        }
    }

    private func toggleInlineStyle(_ style: JournalInlineStyleType) {
        guard selectedRange.length > 0 else { return }
        guard block.type != .code, block.type != .divider else { return }

        if let existing = (block.inlineStyles ?? []).first(where: { $0.type == style && NSEqualRanges($0.safeRange, selectedRange) }),
           let idx = block.inlineStyles?.firstIndex(where: { $0.id == existing.id }) {
            let toDelete = block.inlineStyles?[idx]
            block.inlineStyles?.remove(at: idx)
            if let toDelete { modelContext.delete(toDelete) }
            block.touch()
            return
        }

        let newStyle = JournalInlineStyle(
            type: style, rangeLocation: selectedRange.location, rangeLength: selectedRange.length, urlString: ""
        )
        newStyle.block = block
        modelContext.insert(newStyle)
        if block.inlineStyles == nil { block.inlineStyles = [] }
        block.inlineStyles?.append(newStyle)
        block.touch()
    }

    private func prepareLinkEditor() {
        guard selectedRange.length > 0 else { return }
        if let existing = (block.inlineStyles ?? []).first(where: { $0.type == .link && NSEqualRanges($0.safeRange, selectedRange) }) {
            linkDraft = existing.urlString
        } else {
            linkDraft = ""
        }
        showLinkEditor = true
    }

    private func applyLinkFromDraft() {
        guard selectedRange.length > 0 else { linkDraft = ""; return }
        let trimmed = linkDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = (block.inlineStyles ?? []).first(where: { $0.type == .link && NSEqualRanges($0.safeRange, selectedRange) }),
           let idx = block.inlineStyles?.firstIndex(where: { $0.id == existing.id }) {
            let toDelete = block.inlineStyles?[idx]
            block.inlineStyles?.remove(at: idx)
            if let toDelete { modelContext.delete(toDelete) }
        }

        if !trimmed.isEmpty {
            let newStyle = JournalInlineStyle(
                type: .link, rangeLocation: selectedRange.location, rangeLength: selectedRange.length, urlString: trimmed
            )
            newStyle.block = block
            modelContext.insert(newStyle)
            if block.inlineStyles == nil { block.inlineStyles = [] }
            block.inlineStyles?.append(newStyle)
        }

        block.touch()
        linkDraft = ""
    }

    // MARK: - Prefix Views

    @ViewBuilder
    private func prefixView(for block: JournalBlock) -> some View {
        switch block.type {
        case .toggle:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading1:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 20, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading2:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading3:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading4:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading5:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(LGradients.blue)
        case .toggleHeading6:
            Image(systemName: block.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(LGradients.blue)
        case .bulletedList:
            Image(systemName: bulletSymbolName(for: block.indentLevel))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(LColors.textPrimary)
                .padding(.top, 5)
        case .numberedList:
            Text(numberPrefix(for: block))
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(LColors.textPrimary)
        case .checklist:
            checklistPrefixIcon
        default: EmptyView()
        }
    }

    private var checklistPrefixButton: some View {
        checklistPrefixIcon
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                block.languageHint = "xmark"
                block.touch()
            }
            .onTapGesture {
                toggleChecklistCheckedState()
            }
    }

    @ViewBuilder
    private var checklistPrefixIcon: some View {
        switch checklistState {
        case "checked":
            ZStack {
                Circle().fill(LGradients.blue).frame(width: 17, height: 17)
                Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Color.white)
            }
            .padding(.top, 4)
        case "xmark":
            ZStack {
                Circle().fill(Color.white.opacity(0.18)).frame(width: 17, height: 17)
                    .overlay(Circle().stroke(LGradients.blue, lineWidth: 1.3))
                Image(systemName: "xmark").font(.system(size: 9, weight: .black)).foregroundStyle(Color.white)
            }
            .padding(.top, 4)
        default:
            Circle().stroke(LColors.textSecondary, lineWidth: 1.4).frame(width: 17, height: 17).padding(.top, 4)
        }
    }

    private var checklistState: String { block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func toggleChecklistCheckedState() {
        block.languageHint = checklistState == "checked" ? "" : "checked"
        block.touch()
    }

    private func numberPrefix(for block: JournalBlock) -> String {
        guard let entry = block.entry, block.type == .numberedList, let groupID = block.listGroupID else { return "1." }
        let siblings = entry.sortedBlocks.filter {
            $0.type == .numberedList && $0.listGroupID == groupID && $0.indentLevel == block.indentLevel
        }
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return "1." }
        return "\(index + 1)."
    }

    private func nextBlockTypeOnReturn(for type: JournalBlockType) -> JournalBlockType {
        switch type {
        case .toggle:       return .paragraph
        case .bulletedList: return .bulletedList
        case .numberedList: return .numberedList
        case .checklist:    return .checklist
        default:            return .paragraph
        }
    }

    private var canIndentBlock: Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout:
            return true
        case .divider, .code, .image, .drawing, .table:
            return false
        }
    }

    private func indentIn() { guard canIndentBlock else { return }; block.indentLevel = min(maxIndentLevel, block.indentLevel + 1); block.touch() }
    private func indentOut() { guard canIndentBlock else { return }; block.indentLevel = max(0, block.indentLevel - 1); block.touch() }
    private func bulletSymbolName(for indentLevel: Int) -> String { indentLevel % 2 == 1 ? "circle" : "circle.fill" }

    @discardableResult
    private func mergeWithPreviousBlock(_ currentBlock: JournalBlock) -> Bool {
        guard let entry = currentBlock.entry else { return false }
        let sortedBlocks = entry.sortedBlocks
        guard let currentIndex = sortedBlocks.firstIndex(where: { $0.id == currentBlock.id }), currentIndex > 0 else { return false }

        let previousBlock = sortedBlocks[currentIndex - 1]
        guard canMergeText(into: previousBlock), canMergeText(from: currentBlock) else { return false }

        let previousLength = (previousBlock.text as NSString).length
        previousBlock.text += currentBlock.text

        if let currentStyles = currentBlock.inlineStyles, !currentStyles.isEmpty {
            if previousBlock.inlineStyles == nil { previousBlock.inlineStyles = [] }
            for style in currentStyles {
                style.rangeLocation += previousLength
                style.block = previousBlock
                previousBlock.inlineStyles?.append(style)
            }
            currentBlock.inlineStyles?.removeAll()
        }

        previousBlock.touch()
        onDelete(currentBlock)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .journalBlockRequestFocus, object: previousBlock.id)
        }

        return true
    }

    private func canMergeText(into block: JournalBlock) -> Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout, .code: return true
        case .divider, .image, .drawing, .table: return false
        }
    }

    private func canMergeText(from block: JournalBlock) -> Bool {
        switch block.type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .toggleHeading1, .toggleHeading2, .toggleHeading3, .toggleHeading4, .toggleHeading5, .toggleHeading6,
             .toggle, .bulletedList, .numberedList, .checklist, .blockquote, .callout, .code: return true
        case .divider, .image, .drawing, .table: return false
        }
    }

    private var placeholderText: String {
        switch block.type {
        case .paragraph:                         return "Write something..."
        case .heading1, .toggleHeading1:         return "Heading 1"
        case .heading2, .toggleHeading2:         return "Heading 2"
        case .heading3, .toggleHeading3:         return "Heading 3"
        case .heading4, .toggleHeading4:         return "Heading 4"
        case .heading5, .toggleHeading5:         return "Heading 5"
        case .heading6, .toggleHeading6:         return "Heading 6"
        case .toggle:                            return "Toggle"
        case .bulletedList:                      return "List item"
        case .numberedList:                      return "List item"
        case .checklist:                         return "Checklist item"
        case .blockquote:                        return "Quote"
        case .callout:                           return "Callout"
        case .divider:                           return ""
        case .code:                              return "Code"
        case .image:                             return ""
        case .drawing:                           return ""
        case .table:                             return ""
        }
    }

    private func uiFontForBlockType(_ type: JournalBlockType) -> UIFont {
        // Honor the entry's custom body font when one is set (except for code
        // blocks, which stay monospaced). Falls back to the system font.
        func bodyFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
            if let entry = block.entry {
                return entry.resolvedBodyUIFont(size: size, weight: weight)
            }
            return .systemFont(ofSize: size, weight: weight)
        }
        switch type {
        case .heading1, .toggleHeading1: return bodyFont(size: 28, weight: .bold)
        case .heading2, .toggleHeading2: return bodyFont(size: 22, weight: .bold)
        case .heading3, .toggleHeading3: return bodyFont(size: 18, weight: .semibold)
        case .heading4, .toggleHeading4: return bodyFont(size: 16, weight: .semibold)
        case .heading5, .toggleHeading5: return bodyFont(size: 14, weight: .semibold)
        case .heading6, .toggleHeading6: return bodyFont(size: 13, weight: .medium)
        case .blockquote:                return bodyFont(size: 16, weight: .medium)
        case .code:                      return .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        default:                         return bodyFont(size: 16, weight: .regular)
        }
    }
}

// MARK: - Rich Editable Text View

struct JournalRichEditableBlockTextView: UIViewRepresentable {
    @Bindable var block: JournalBlock
    @Binding var selectedRange: NSRange

    let baseUIFont: UIFont
    let textColor: UIColor
    let placeholder: String
    let isCodeBlock: Bool
    var isSelectionMode: Bool = false
    var codeLanguage: CodeLanguage = .plainText
    var codeTheme: CodeTheme = .lystaria
    let onCreateParagraphBelow: ((String) -> Void)?
    var onCreateTypedBlockBelow: ((JournalBlockType, String) -> Void)? = nil
    var onMergeWithPrevious: (() -> Bool)? = nil
    let onDeleteEmptyBlock: (() -> Void)?
    let onExitList: (() -> Void)?
    var onContentHeightIncrease: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let fallbackHeight: CGFloat = isCodeBlock ? 64 : ceil(baseUIFont.lineHeight)
        guard let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth > 0 else {
            return CGSize(width: 1, height: max(1, fallbackHeight))
        }
        let safeWidth = max(1, min(proposedWidth, UIScreen.main.bounds.width))
        let fitting = uiView.sizeThatFits(CGSize(width: safeWidth, height: .greatestFiniteMagnitude))
        let safeHeight = fitting.height.isFinite ? max(fallbackHeight, fitting.height) : fallbackHeight
        return CGSize(width: safeWidth, height: max(1, safeHeight))
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = JournalPlaceholderTextView()
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.delegate = context.coordinator
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.alwaysBounceHorizontal = false
        textView.showsHorizontalScrollIndicator = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.typingAttributes = baseAttributes()
        textView.smartInsertDeleteType = .no
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        let accessoryHost = UIHostingController(
            rootView: JournalKeyboardBlockAccessoryView(
                onAddBlockType: { type in
                    context.coordinator.addTypedBlockFromKeyboardToolbar(type)
                },
                onDone: {
                    context.coordinator.doneFromKeyboardToolbar()
                }
            )
        )
        accessoryHost.view.backgroundColor = .clear
        accessoryHost.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 64)
        textView.inputAccessoryView = accessoryHost.view

        textView.placeholderLabel.text = placeholder
        textView.placeholderLabel.textColor = UIColor(LColors.textSecondary)
        textView.placeholderLabel.font = baseUIFont
        textView.placeholderLabel.isHidden = !block.text.isEmpty

        let blockID = block.id
        NotificationCenter.default.addObserver(
            forName: .journalBlockRequestFocus, object: nil, queue: .main
        ) { [weak textView] notification in
            guard let requestedID = notification.object as? UUID, requestedID == blockID else { return }
            textView?.becomeFirstResponder()
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.onCreateParagraphBelow = self.onCreateParagraphBelow
        context.coordinator.onCreateTypedBlockBelow = self.onCreateTypedBlockBelow
        context.coordinator.onMergeWithPrevious = self.onMergeWithPrevious
        context.coordinator.onDeleteEmptyBlock = self.onDeleteEmptyBlock
        context.coordinator.onExitList = self.onExitList
        context.coordinator.onContentHeightIncrease = self.onContentHeightIncrease

        let currentPlainText = uiView.text ?? ""
        let storedPlainText = block.text
        let shouldApplyProgrammaticTextUpdate = currentPlainText != storedPlainText
        let canApplyProgrammaticTextUpdate = !(uiView.isFirstResponder && uiView.markedTextRange != nil)

        if shouldApplyProgrammaticTextUpdate && canApplyProgrammaticTextUpdate {
            let attributed = buildAttributedText()
            let priorSelection = uiView.selectedRange

            context.coordinator.isApplyingProgrammaticChange = true
            uiView.attributedText = attributed
            uiView.typingAttributes = baseAttributes()

            let maxLocation = max(0, min(priorSelection.location, attributed.length))
            let maxLength = max(0, min(priorSelection.length, attributed.length - maxLocation))
            uiView.selectedRange = NSRange(location: maxLocation, length: maxLength)
            context.coordinator.isApplyingProgrammaticChange = false
            uiView.invalidateIntrinsicContentSize()
            context.coordinator.recordMeasuredHeight(uiView)
        } else if !uiView.isFirstResponder {
            let attributed = buildAttributedText()
            if uiView.attributedText != attributed {
                let priorSelection = uiView.selectedRange

                context.coordinator.isApplyingProgrammaticChange = true
                uiView.attributedText = attributed
                uiView.typingAttributes = baseAttributes()

                let maxLocation = max(0, min(priorSelection.location, attributed.length))
                let maxLength = max(0, min(priorSelection.length, attributed.length - maxLocation))
                uiView.selectedRange = NSRange(location: maxLocation, length: maxLength)
                context.coordinator.isApplyingProgrammaticChange = false
                uiView.invalidateIntrinsicContentSize()
                context.coordinator.recordMeasuredHeight(uiView)
            }
        } else {
            let attributed = buildAttributedText()

            if uiView.markedTextRange == nil && uiView.attributedText != attributed {
                let priorSelection = uiView.selectedRange

                context.coordinator.isApplyingProgrammaticChange = true
                uiView.attributedText = attributed
                uiView.typingAttributes = baseAttributes()

                let maxLocation = max(0, min(priorSelection.location, attributed.length))
                let maxLength = max(0, min(priorSelection.length, attributed.length - maxLocation))
                uiView.selectedRange = NSRange(location: maxLocation, length: maxLength)

                context.coordinator.isApplyingProgrammaticChange = false
                uiView.invalidateIntrinsicContentSize()
                context.coordinator.recordMeasuredHeight(uiView)
            } else {
                uiView.typingAttributes = baseAttributes()
            }
        }

        if let pv = uiView as? JournalPlaceholderTextView {
            pv.placeholderLabel.text = placeholder
            pv.placeholderLabel.font = baseUIFont
            pv.placeholderLabel.textColor = UIColor(LColors.textSecondary)
            pv.placeholderLabel.isHidden = !(block.text.isEmpty && !uiView.isFirstResponder)
        }

        uiView.isEditable = !isSelectionMode
        uiView.isSelectable = !isSelectionMode
        uiView.isUserInteractionEnabled = !isSelectionMode
    }

    func baseAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .natural
        return [.font: baseUIFont, .foregroundColor: textColor, .paragraphStyle: paragraph]
    }

    func buildAttributedText() -> NSAttributedString {
        if isCodeBlock {
            return CodeHighlighter.highlight(block.text, language: codeLanguage, theme: codeTheme)
        }

        let mutable = NSMutableAttributedString(string: block.text, attributes: baseAttributes())
        let fullLength = (block.text as NSString).length
        guard fullLength > 0 else { return mutable }

        for style in block.sortedInlineStyles {
            let rawRange = style.safeRange
            let maxLength = max(0, fullLength - rawRange.location)
            let clampedLength = min(rawRange.length, maxLength)
            guard rawRange.location >= 0, rawRange.location < fullLength, clampedLength > 0 else { continue }
            let range = NSRange(location: rawRange.location, length: clampedLength)

            switch style.type {
            case .bold:
                mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    let f = (value as? UIFont) ?? baseUIFont
                    if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitBold)) {
                        mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: subrange)
                    }
                }
            case .italic:
                mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    let f = (value as? UIFont) ?? baseUIFont
                    if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                        mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: subrange)
                    }
                }
            case .underline:
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .strikethrough:
                mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .link:
                let trimmed = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let url = URL(string: trimmed) else { continue }
                mutable.addAttribute(.link, value: url, range: range)
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .inlineCode:
                let monoFont = UIFont.monospacedSystemFont(ofSize: baseUIFont.pointSize * 0.9, weight: .regular)
                mutable.addAttribute(.font, value: monoFont, range: range)
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
            }
        }

        if block.type == .checklist && !block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fullRange = NSRange(location: 0, length: fullLength)
            mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            mutable.addAttribute(.foregroundColor, value: UIColor(LColors.textSecondary), range: fullRange)
        }

        return mutable
    }

    // MARK: - Placeholder UITextView

    final class JournalPlaceholderTextView: UITextView {
        let placeholderLabel = UILabel()

        override init(frame: CGRect, textContainer: NSTextContainer?) {
            super.init(frame: frame, textContainer: textContainer)
            setup()
        }
        required init?(coder: NSCoder) { super.init(coder: coder); setup() }

        private func setup() {
            placeholderLabel.numberOfLines = 0
            placeholderLabel.backgroundColor = .clear
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(placeholderLabel)
            NSLayoutConstraint.activate([
                placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textContainerInset.left),
                placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
                placeholderLabel.topAnchor.constraint(equalTo: topAnchor)
            ])
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let velocity = pan.velocity(in: self)
                if abs(velocity.y) > abs(velocity.x) * 2 { return false }
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: JournalRichEditableBlockTextView
        var isApplyingProgrammaticChange = false
        var onCreateParagraphBelow: ((String) -> Void)?
        var onCreateTypedBlockBelow: ((JournalBlockType, String) -> Void)?
        var onMergeWithPrevious: (() -> Bool)?
        var onDeleteEmptyBlock: (() -> Void)?
        var onExitList: (() -> Void)?
        var onContentHeightIncrease: (() -> Void)?
        private var lastMeasuredHeight: CGFloat?
        private var pendingHeightIncreaseWorkItem: DispatchWorkItem?

        init(parent: JournalRichEditableBlockTextView) {
            self.parent = parent
            self.onCreateParagraphBelow = parent.onCreateParagraphBelow
            self.onCreateTypedBlockBelow = parent.onCreateTypedBlockBelow
            self.onMergeWithPrevious = parent.onMergeWithPrevious
            self.onDeleteEmptyBlock = parent.onDeleteEmptyBlock
            self.onExitList = parent.onExitList
            self.onContentHeightIncrease = parent.onContentHeightIncrease
        }

        deinit {
            pendingHeightIncreaseWorkItem?.cancel()
        }

        func recordMeasuredHeight(_ textView: UITextView) {
            lastMeasuredHeight = measuredHeight(in: textView)
        }

        func addTypedBlockFromKeyboardToolbar(_ type: JournalBlockType) {
            if let onCreateTypedBlockBelow {
                onCreateTypedBlockBelow(type, "")
            } else {
                onCreateParagraphBelow?("")
            }
        }

        @objc func doneFromKeyboardToolbar() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            parent.selectedRange = textView.selectedRange
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !isApplyingProgrammaticChange else { return true }

            if text.isEmpty && range.length == 0 && range.location == 0 {
                if onMergeWithPrevious?() == true { return false }
            }

            if text.isEmpty {
                let isEmpty = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if isEmpty { onDeleteEmptyBlock?(); return false }
            }

            guard !parent.isCodeBlock else { return true }

            if text.contains("\n") && text != "\n" {
                adjustInlineStyleRangesForTextChange(in: range, replacementText: text)
                return handleMultilinePaste(in: textView, range: range, replacementText: text)
            }

            adjustInlineStyleRangesForTextChange(in: range, replacementText: text)

            guard text == "\n", range.length == 0 else { return true }

            let isListBlock = parent.block.type == .bulletedList || parent.block.type == .numberedList
            let isEmpty = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isListBlock && isEmpty { onExitList?(); return false }

            let fullText = textView.text ?? ""
            let nsText = fullText as NSString
            let prefixText = nsText.substring(to: range.location)
            let suffixText = nsText.substring(from: range.location)

            isApplyingProgrammaticChange = true
            parent.block.text = prefixText
            parent.block.touch()
            textView.attributedText = NSAttributedString(string: prefixText, attributes: parent.baseAttributes())
            textView.invalidateIntrinsicContentSize()
            isApplyingProgrammaticChange = false

            let newLength = (prefixText as NSString).length
            if var styles = parent.block.inlineStyles {
                styles = styles.filter { $0.rangeLocation < newLength }
                for style in styles where style.rangeLocation + style.rangeLength > newLength {
                    style.rangeLength = newLength - style.rangeLocation
                }
                parent.block.inlineStyles = styles
            }

            onCreateParagraphBelow?(suffixText)
            return false
        }

        private func adjustInlineStyleRangesForTextChange(in range: NSRange, replacementText text: String) {
            guard var styles = parent.block.inlineStyles, !styles.isEmpty else { return }

            let replacementLength = (text as NSString).length
            let delta = replacementLength - range.length
            let changeStart = range.location
            let changeEnd = range.location + range.length
            var styleIDsToRemove: Set<UUID> = []

            for style in styles {
                let styleStart = style.rangeLocation
                let styleEnd = style.rangeLocation + style.rangeLength

                if changeEnd <= styleStart {
                    style.rangeLocation = max(0, style.rangeLocation + delta)
                    style.touch()
                    continue
                }
                if changeStart >= styleEnd { continue }
                if range.length == 0 && changeStart > styleStart && changeStart < styleEnd {
                    styleIDsToRemove.insert(style.id); continue
                }
                if range.length == 0 && changeStart == styleStart {
                    style.rangeLocation = max(0, style.rangeLocation + delta); style.touch(); continue
                }
                if range.length == 0 && changeStart == styleEnd { continue }
                styleIDsToRemove.insert(style.id)
            }

            guard !styleIDsToRemove.isEmpty else { return }
            styles.removeAll { styleIDsToRemove.contains($0.id) }
            parent.block.inlineStyles = styles
            parent.block.touch()
        }

        private struct PastedBlockPayload {
            let type: JournalBlockType
            let text: String
            let languageHint: String
            init(type: JournalBlockType, text: String, languageHint: String = "") {
                self.type = type; self.text = text; self.languageHint = languageHint
            }
        }

        private func handleMultilinePaste(in textView: UITextView, range: NSRange, replacementText text: String) -> Bool {
            let normalized = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            let pastedBlocks = parsePastedBlocks(from: normalized)
            guard let firstBlock = pastedBlocks.first else { return true }

            let shouldHandleSingle = pastedBlocks.count == 1 && (
                firstBlock.type != .paragraph ||
                !firstBlock.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                normalized.contains("```")
            )
            guard pastedBlocks.count > 1 || shouldHandleSingle else { return true }

            let fullText = textView.text ?? ""
            let nsText = fullText as NSString
            let safeLocation = max(0, min(range.location, nsText.length))
            let safeLength = max(0, min(range.length, nsText.length - safeLocation))
            let safeRange = NSRange(location: safeLocation, length: safeLength)

            let prefixText = nsText.substring(to: safeRange.location)
            let suffixText = nsText.substring(from: safeRange.location + safeRange.length)
            let currentBlockText = prefixText + firstBlock.text
            let trailingSuffix = suffixText.trimmingCharacters(in: .whitespacesAndNewlines)

            var blocksToInsert = Array(pastedBlocks.dropFirst())
            if !trailingSuffix.isEmpty, let last = blocksToInsert.indices.last {
                blocksToInsert[last] = PastedBlockPayload(
                    type: blocksToInsert[last].type,
                    text: blocksToInsert[last].text + "\n" + trailingSuffix,
                    languageHint: blocksToInsert[last].languageHint
                )
            } else if !trailingSuffix.isEmpty {
                blocksToInsert.append(PastedBlockPayload(type: .paragraph, text: trailingSuffix))
            }

            isApplyingProgrammaticChange = true
            parent.block.text = currentBlockText
            if prefixText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parent.block.type = firstBlock.type
                if !firstBlock.languageHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parent.block.languageHint = firstBlock.languageHint
                }
            }
            parent.block.touch()
            textView.attributedText = parent.buildAttributedText()
            textView.selectedRange = NSRange(location: (currentBlockText as NSString).length, length: 0)
            textView.invalidateIntrinsicContentSize()
            isApplyingProgrammaticChange = false

            if var styles = parent.block.inlineStyles {
                let newLength = (currentBlockText as NSString).length
                styles = styles.filter { $0.rangeLocation < newLength }
                for style in styles where style.rangeLocation + style.rangeLength > newLength {
                    style.rangeLength = newLength - style.rangeLocation
                }
                parent.block.inlineStyles = styles
            }

            for payload in blocksToInsert.reversed() {
                if let onCreateTypedBlockBelow {
                    onCreateTypedBlockBelow(payload.type, payload.text)
                } else {
                    onCreateParagraphBelow?(payload.text)
                }
            }

            return false
        }

        private func parsePastedBlocks(from text: String) -> [PastedBlockPayload] {
            let lines = text.components(separatedBy: "\n")
            var payloads: [PastedBlockPayload] = []
            var codeBuffer: [String] = []
            var codeFenceLanguageHint = ""
            var isInsideCodeFence = false
            var tableBuffer: [[String]] = []

            func flushTable() {
                guard !tableBuffer.isEmpty else { return }
                let cols = tableBuffer.map(\.count).max() ?? 1
                var data = JournalTableData(cols: cols, rows: tableBuffer)
                payloads.append(PastedBlockPayload(type: .table, text: data.toJSON()))
                tableBuffer.removeAll()
            }

            for rawLine in lines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.hasPrefix("```") {
                    flushTable()
                    if isInsideCodeFence {
                        payloads.append(PastedBlockPayload(type: .code, text: codeBuffer.joined(separator: "\n"), languageHint: codeFenceLanguageHint))
                        codeBuffer.removeAll(); codeFenceLanguageHint = ""; isInsideCodeFence = false
                    } else {
                        isInsideCodeFence = true; codeBuffer.removeAll()
                        codeFenceLanguageHint = normalizedCodeFenceLanguageHint(from: trimmed)
                    }
                    continue
                }

                if isInsideCodeFence { codeBuffer.append(rawLine); continue }
                guard !trimmed.isEmpty else { flushTable(); continue }

                if rawLine.contains("\t") {
                    tableBuffer.append(rawLine.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                    continue
                }

                if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                    let isSeparator = trimmed.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").replacingOccurrences(of: " ", with: "").isEmpty
                    if isSeparator { continue }
                    let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false).dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    tableBuffer.append(Array(cells)); continue
                }

                flushTable()
                payloads.append(classifyPastedLine(trimmed))
            }

            flushTable()
            if isInsideCodeFence, !codeBuffer.isEmpty {
                payloads.append(PastedBlockPayload(type: .code, text: codeBuffer.joined(separator: "\n"), languageHint: codeFenceLanguageHint))
            }

            return payloads
        }

        private func normalizedCodeFenceLanguageHint(from fenceLine: String) -> String {
            let raw = fenceLine.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch raw {
            case "swift", "swiftui":     return "Swift"
            case "js", "javascript":     return "JavaScript"
            case "ts", "typescript":     return "TypeScript"
            case "html":                 return "HTML"
            case "css":                  return "CSS"
            case "json":                 return "JSON"
            case "md", "markdown":       return "Markdown"
            case "bash", "sh", "shell", "zsh": return "Shell"
            case "python", "py":         return "Python"
            case "java":                 return "Java"
            case "csharp", "cs":         return "C#"
            case "cpp", "c++":           return "C++"
            case "c":                    return "C"
            case "sql":                  return "SQL"
            case "xml":                  return "XML"
            case "yaml", "yml":          return "YAML"
            default:                     return ""
            }
        }

        private func classifyPastedLine(_ line: String) -> PastedBlockPayload {
            if line == "---" || line == "***" || line == "___" { return PastedBlockPayload(type: .divider, text: "") }
            if line.hasPrefix("#### ") { return PastedBlockPayload(type: .heading4, text: String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("### ")  { return PastedBlockPayload(type: .heading3, text: String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("## ")   { return PastedBlockPayload(type: .heading2, text: String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("# ")    { return PastedBlockPayload(type: .heading1, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("> ")    { return PastedBlockPayload(type: .blockquote, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("! ")    { return PastedBlockPayload(type: .callout, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("[!NOTE]") { return PastedBlockPayload(type: .callout, text: String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("- [ ] ") || line.hasPrefix("* [ ] ") { return PastedBlockPayload(type: .checklist, text: String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") || line.hasPrefix("* [x] ") || line.hasPrefix("* [X] ") { return PastedBlockPayload(type: .checklist, text: String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") { return PastedBlockPayload(type: .bulletedList, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if let range = line.range(of: #"^\d+[\.)]\  +"#, options: .regularExpression) { return PastedBlockPayload(type: .numberedList, text: String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)) }
            return PastedBlockPayload(type: .paragraph, text: line)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if let pv = textView as? JournalPlaceholderTextView { pv.placeholderLabel.isHidden = true }
            recordMeasuredHeight(textView)
            NotificationCenter.default.post(name: .journalBlockDidFocus, object: parent.block.id)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            let newText = textView.text ?? ""
            if parent.block.text != newText {
                parent.block.text = newText
                parent.block.touch()
                textView.invalidateIntrinsicContentSize()
            }
            if let pv = textView as? JournalPlaceholderTextView { pv.placeholderLabel.isHidden = !newText.isEmpty }

            if parent.isCodeBlock && textView.markedTextRange == nil {
                let highlighted = CodeHighlighter.highlight(newText, language: parent.codeLanguage, theme: parent.codeTheme)
                let cursor = textView.selectedRange
                isApplyingProgrammaticChange = true
                textView.attributedText = highlighted
                let safeLocation = min(cursor.location, highlighted.length)
                textView.selectedRange = NSRange(location: safeLocation, length: 0)
                isApplyingProgrammaticChange = false
                textView.invalidateIntrinsicContentSize()
            }
            notifyIfHeightIncreasedNearEnd(textView, currentText: newText)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }
            if (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isApplyingProgrammaticChange = true
                parent.block.text = ""
                parent.block.touch()
                textView.attributedText = parent.buildAttributedText()
                textView.typingAttributes = parent.baseAttributes()
                isApplyingProgrammaticChange = false
                textView.invalidateIntrinsicContentSize()
            }
            if let pv = textView as? JournalPlaceholderTextView {
                pv.placeholderLabel.isHidden = !parent.block.text.isEmpty
            }
            pendingHeightIncreaseWorkItem?.cancel()
            pendingHeightIncreaseWorkItem = nil
            lastMeasuredHeight = nil
        }

        private func measuredHeight(in textView: UITextView) -> CGFloat {
            let width = textView.bounds.width.isFinite && textView.bounds.width > 0
                ? textView.bounds.width
                : max(1, UIScreen.main.bounds.width)
            let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return size.height.isFinite ? size.height : 0
        }

        private func notifyIfHeightIncreasedNearEnd(_ textView: UITextView, currentText: String) {
            let currentHeight = measuredHeight(in: textView)
            defer { lastMeasuredHeight = currentHeight }

            guard textView.isFirstResponder,
                  let previousHeight = lastMeasuredHeight,
                  currentHeight > previousHeight + 1,
                  isCaretNearEnd(of: currentText, in: textView) else { return }

            pendingHeightIncreaseWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.onContentHeightIncrease?()
            }
            pendingHeightIncreaseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
        }

        private func isCaretNearEnd(of text: String, in textView: UITextView) -> Bool {
            let textLength = (text as NSString).length
            let selectionEnd = textView.selectedRange.location + textView.selectedRange.length
            return selectionEnd >= max(0, textLength - 1)
        }
    }
}

// MARK: - Keyboard Block Accessory

private struct JournalKeyboardBlockAccessoryView: View {
    let onAddBlockType: (JournalBlockType) -> Void
    let onDone: () -> Void

    private var availableBlockTypes: [JournalBlockType] {
        [
            .paragraph,

            .heading1,
            .heading2,
            .heading3,
            .heading4,
            .heading5,
            .heading6,

            .toggle,

            .toggleHeading1,
            .toggleHeading2,
            .toggleHeading3,
            .toggleHeading4,
            .toggleHeading5,
            .toggleHeading6,

            .bulletedList,
            .numberedList,
            .checklist,

            .blockquote,
            .callout,

            .divider,
            .code,
            .image,
            .drawing,
            .table
        ]
    }

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(availableBlockTypes, id: \.rawValue) { type in
                    Button {
                        onAddBlockType(type)
                    } label: {
                        Text(blockTypeLabel(type))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)

                    Text("Add Block")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(LColors.accentGradient)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(LGradients.header, lineWidth: 1.2)
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 12)

            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(LColors.glassSurface2)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(LColors.glassBorderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 64)
        .background(Color.clear)
    }

    private func blockTypeLabel(_ type: JournalBlockType) -> String {
        switch type {
        case .paragraph: return "Paragraph"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .heading4: return "Heading 4"
        case .heading5: return "Heading 5"
        case .heading6: return "Heading 6"
        case .toggle: return "Toggle"
        case .toggleHeading1: return "Toggle Heading 1"
        case .toggleHeading2: return "Toggle Heading 2"
        case .toggleHeading3: return "Toggle Heading 3"
        case .toggleHeading4: return "Toggle Heading 4"
        case .toggleHeading5: return "Toggle Heading 5"
        case .toggleHeading6: return "Toggle Heading 6"
        case .bulletedList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .checklist: return "Checklist"
        case .blockquote: return "Quote"
        case .callout: return "Callout"
        case .divider: return "Divider"
        case .code: return "Code"
        case .image: return "Image"
        case .drawing: return "Drawing"
        case .table: return "Table"
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

struct JournalPencilCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .white, width: 4)
        canvas.delegate = context.coordinator

        if let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        guard
            let drawing = try? PKDrawing(data: drawingData),
            canvas.drawing.dataRepresentation() != drawingData
        else { return }

        canvas.drawing = drawing
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data

        init(drawingData: Binding<Data>) {
            _drawingData = drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawingData = canvasView.drawing.dataRepresentation()
        }
    }
}
