//
//  JournalBlockPreviewPage.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import UIKit

struct JournalBlockPreviewPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let entry: JournalEntry

    @State private var showDeleteConfirmation = false
    @State private var showEditorPage = false
    @State private var isCompletingAction = false
    @State private var hasPreparedPreview = false
    @State private var showBackgroundSettingsSheet = false
    @State private var showInnerPageSettingsSheet = false
    @State private var showTextColorSheet = false
    @State private var textColorPickerSelection: Color = .white

    private var previewInnerPageMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : 410
    }

    var body: some View {
        ZStack {
            LunixiaBackground()
            JournalEntryBackground(entry: entry)

            VStack(spacing: 0) {
                previewHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollView {
                    JournalPagedContentView(entry: entry, onMentionTapped: handleMentionTap)
                        .frame(maxWidth: previewInnerPageMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                        .padding(.bottom, 180)
                }
                .scrollIndicators(.visible)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showEditorPage) {
            Group {
                if let book = entry.book, entry.deletedAt == nil {
                    JournalBlockEditorPage(book: book, existingEntry: entry)
                } else {
                    Color.clear.navigationBarBackButtonHidden(true)
                }
            }
        }

        .sheet(isPresented: $showBackgroundSettingsSheet) {
            JournalBackgroundSettingsSheet(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showInnerPageSettingsSheet) {
            JournalInnerPageSettingsSheet(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showTextColorSheet) {
            NavigationStack {
                ZStack {
                    LunixiaBackground().ignoresSafeArea()
                    VStack(spacing: 24) {
                        ColorPicker("Text Color", selection: $textColorPickerSelection, supportsOpacity: false)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, LSpacing.pageHorizontal)
                        if !entry.textColorHex.isEmpty {
                            Button {
                                entry.textColorHex = ""
                                entry.touch()
                                showTextColorSheet = false
                            } label: {
                                Text("Reset to Default")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.top, 24)
                }
                .navigationTitle("Text Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Apply") {
                            let uiColor = UIColor(textColorPickerSelection)
                            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                            entry.textColorHex = String(format: "%02X%02X%02X",
                                Int(r * 255), Int(g * 255), Int(b * 255))
                            entry.touch()
                            showTextColorSheet = false
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Entry", role: .destructive) { deleteEntry() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the entry from your journal.")
        }
        .task {
            guard !hasPreparedPreview else { return }
            hasPreparedPreview = true
            if entry.book == nil || entry.deletedAt != nil {
                isCompletingAction = true
                dismiss()
                return
            }
            entry.ensureStarterBlock()
            entry.normalizeBlockSortOrders()
            try? modelContext.save()
        }
        .onDisappear { isCompletingAction = false }
    }
    
    private var resolvedToolbarColor: Color {
        let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            hex.count == 6,
            let r = UInt8(hex.prefix(2), radix: 16),
            let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
            let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16)
        else {
            return .white
        }

        return Color(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }

    private var previewHeader: some View {
        let actionsDisabled = isCompletingAction || entry.deletedAt != nil || entry.book == nil
        let deleteDisabled = isCompletingAction || entry.deletedAt != nil

        return HStack(spacing: 8) {
            Menu {
                Button {
                    showBackgroundSettingsSheet = true
                } label: {
                    Label("Background", systemImage: "photo")
                }
                Button {
                    showInnerPageSettingsSheet = true
                } label: {
                    Label("Inner Page", systemImage: "rectangle.inset.filled")
                }
                Button {
                    let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !hex.isEmpty,
                       let r = UInt8(hex.prefix(2), radix: 16),
                       let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
                       let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) {
                        textColorPickerSelection = Color(
                            red: Double(r) / 255,
                            green: Double(g) / 255,
                            blue: Double(b) / 255
                        )
                    } else {
                        textColorPickerSelection = .white
                    }
                    showTextColorSheet = true
                } label: {
                    Label("Text Color", systemImage: "textformat")
                }
            } label: {
                headerCircle("paintdrop")
            }
            .disabled(actionsDisabled)
            .opacity(actionsDisabled ? 0.5 : 1)

            Button {
                guard !actionsDisabled else { return }
                showEditorPage = true
            } label: {
                headerCircle("pencilfill")
            }
            .disabled(actionsDisabled)
            .opacity(actionsDisabled ? 0.5 : 1)

            Button(role: .destructive) {
                guard !deleteDisabled else { return }
                showDeleteConfirmation = true
            } label: {
                headerCircle("trash")
            }
            .disabled(deleteDisabled)
            .opacity(deleteDisabled ? 0.5 : 1)

            Spacer()

            Button { dismiss() } label: {
                headerCircle("xmarkwavy")
            }
        }
    }

    private func headerCircle(_ asset: String) -> some View {
        Circle()
            .fill(.thinMaterial)
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(resolvedToolbarColor.opacity(0.25), lineWidth: 0.5))
            .overlay {
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(resolvedToolbarColor)
            }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private func handleMentionTap(_ idString: String) {
        // Mention navigation is intentionally disabled in Lunixia until book-detail routing is centralized.
    }

    private func deleteEntry() {
        guard !isCompletingAction, entry.deletedAt == nil else { return }
        isCompletingAction = true
        showDeleteConfirmation = false
        showEditorPage = false
        entry.deletedAt = Date()
        entry.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Unified paged content view
// Identity (cover + title + tags) + first content page share ONE glass card.
// Subsequent pages each get their own glass card, matching the editor exactly.

private struct JournalPagedContentView: View {
    let entry: JournalEntry
    var onMentionTapped: ((String) -> Void)? = nil

    private var blockPages: [[JournalBlock]] {
        var pages: [[JournalBlock]] = [[]]
        var hiddenParentIDs = Set<UUID>()
        for block in entry.sortedBlocks {
            if let parentID = block.parentBlockID, hiddenParentIDs.contains(parentID) {
                if block.isToggleBlock || block.type.isToggleHeading { hiddenParentIDs.insert(block.id) }
                continue
            }
            if (block.isToggleBlock || block.type.isToggleHeading) && !block.isExpanded {
                hiddenParentIDs.insert(block.id)
            }
            if block.type == .divider,
               (DividerStyle(rawValue: block.languageHint) ?? .line) == .pageBreak {
                pages.append([])
            } else {
                pages[pages.count - 1].append(block)
            }
        }
        return pages
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let style = JournalInnerPageStyle(entry: entry)

        return content()
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(style.shouldShowMaterial ? 1 : 0)
                    )
                    .overlay {
                        style.fillView
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(style.borderColor, lineWidth: 1)
                    )
            }
            .shadow(color: style.shadowColor, radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
    }

    var body: some View {
        let pages = blockPages
        VStack(alignment: .leading, spacing: 0) {
            // First card: identity + first page of content in ONE glass card
            glassCard {
                VStack(alignment: .leading, spacing: 0) {
                    JournalIdentityHeaderView(entry: entry)
                    if let firstPage = pages.first, !firstPage.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(firstPage) { block in
                                JournalBlockDisplayView(entry: entry, singleBlock: block, onMentionTapped: onMentionTapped)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    }
                }
            }
            .padding(.top, 16)

            // Subsequent pages: each get their own glass card
            if pages.count > 1 {
                ForEach(Array(pages.dropFirst().enumerated()), id: \.offset) { _, page in
                    glassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(page) { block in
                                JournalBlockDisplayView(entry: entry, singleBlock: block, onMentionTapped: onMentionTapped)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
