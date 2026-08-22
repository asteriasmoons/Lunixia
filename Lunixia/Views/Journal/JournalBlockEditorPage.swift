//
//  JournalBlockEditorPage.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import PhotosUI

struct JournalBlockEditorPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var storeManager: LunixiaStoreManager

    let book: JournalBook
    let existingEntry: JournalEntry?
    let isNewEntryDraft: Bool

    init(book: JournalBook, existingEntry: JournalEntry?, isNewEntryDraft: Bool = false) {
        self.book = book
        self.existingEntry = existingEntry
        self.isNewEntryDraft = isNewEntryDraft
    }

    @State private var workingEntry: JournalEntry?
    @State private var hasPreparedEntry = false
    @State private var createdNewEntry = false
    @State private var hasFinishedEditorFlow = false
    @State private var isCompletingAction = false
    @State private var editorOpenedAt = Date()
    @State private var pageTitleDraft = ""
    @State private var pageTagsDraft = ""
    @State private var showBackgroundSettingsSheet = false
    @State private var showInnerPageSettingsSheet = false
    @State private var showTextColorSheet = false
    @State private var textColorPickerSelection: Color = .white
    @State private var focusedBlockID: UUID? = nil
    @State private var showBlockColorSheet = false
    @State private var blockColor1Selection: Color = Color(LColors.accent)
    @State private var blockColor2Selection: Color = Color(LColors.accent)
    
    @State private var showPremiumBanner = false
    @State private var premiumBannerMessage = ""

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private var activeEntryCountInBook: Int {
        (book.entries ?? []).filter { $0.deletedAt == nil }.count
    }

    private var canCreateJournalEntry: Bool {
        LunixiaLimitsManager.canCreateJournalEntry(
            currentCountInBook: activeEntryCountInBook,
            isPremium: isPremium
        )
    }
    
    private var editorInnerPageMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : 410
    }

    private var focusedBlock: JournalBlock? {
        guard let id = focusedBlockID else { return nil }
        return workingEntry?.sortedBlocks.first { $0.id == id }
    }

    private var focusedBlockSupportsColor: Bool {
        guard let b = focusedBlock else { return false }
        return b.type == .divider || b.type == .callout || b.type == .blockquote || b.isBlockquoteStyle || b.isCalloutStyle
    }

    private var focusedBlockColorLabel: String {
        guard let b = focusedBlock else { return "Block Color" }
        if b.type == .divider { return "Divider Color" }
        if b.type == .callout || b.isCalloutStyle { return "Callout Color" }
        return "Blockquote Color"
    }
    
    private var resolvedToolbarColor: Color {
        guard
            let entry = workingEntry,
            !entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .white
        }

        let hex = entry.textColorHex

        guard
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

    var body: some View {
        ZStack {
            LunixiaBackground()

            if let workingEntry {
                JournalEntryBackground(entry: workingEntry)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                editorHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Group {
                    if let workingEntry {
                        JournalBlockEditorView(
                            entry: workingEntry,
                            focusedBlockID: $focusedBlockID,
                            identityHeader: AnyView(
                                JournalIdentityEditorView(
                                    entry: workingEntry,
                                    pageTitleDraft: $pageTitleDraft,
                                    pageTagsDraft: $pageTagsDraft
                                )
                            )
                        )
                        .frame(maxWidth: editorInnerPageMaxWidth, alignment: .top)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .scrollDismissesKeyboard(.interactively)
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if showPremiumBanner {
                VStack {
                    Text(premiumBannerMessage)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(LColors.accentGradient)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                        .padding(.top, 18)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showBlockColorSheet) {
            if let block = focusedBlock {
                blockColorSheet(for: block)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showBackgroundSettingsSheet) {
            if let entry = workingEntry {
                JournalBackgroundSettingsSheet(entry: entry)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showInnerPageSettingsSheet) {
            if let entry = workingEntry {
                JournalInnerPageSettingsSheet(entry: entry)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showTextColorSheet) {
            if let entry = workingEntry {
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
        }
        .onAppear {
            guard !hasPreparedEntry else { return }
            hasPreparedEntry = true
            prepareEntry()
        }
        .onDisappear {
            guard !hasFinishedEditorFlow else { return }
            cleanupEmptyNewEntryIfNeeded()
            isCompletingAction = false
        }
    }

    private var editorHeader: some View {
        let disabled = isCompletingAction || workingEntry == nil

        return HStack(spacing: 8) {
            Button { dismiss() } label: {
                editorCircle("chevleft")
            }

            Spacer()

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
                    if let hex = workingEntry?.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines),
                       !hex.isEmpty,
                       let r = UInt8(hex.prefix(2), radix: 16),
                       let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
                       let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) {
                        textColorPickerSelection = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
                    } else {
                        textColorPickerSelection = .white
                    }
                    showTextColorSheet = true
                } label: {
                    Label("Text Color", systemImage: "textformat")
                }
                if focusedBlockSupportsColor, let block = focusedBlock {
                    Button {
                        loadBlockColors(from: currentBlockColorHex(for: block))
                        showBlockColorSheet = true
                    } label: {
                        Label(focusedBlockColorLabel, systemImage: "paintpalette")
                    }
                }
            } label: {
                editorCircle("paintdrop")
            }
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1)

            Button { saveAndClose() } label: {
                editorCircle("checkwavy")
            }
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1)
        }
    }

    private func editorCircle(_ asset: String) -> some View {
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

    private func prepareEntry() {
        print("[EditorPage] prepareEntry called: existingEntry=\(existingEntry == nil ? "nil" : "set"), workingEntry=\(workingEntry == nil ? "nil" : "set"), hasPreparedEntry=\(hasPreparedEntry)")
        guard workingEntry == nil else { return }

        if let existingEntry {
            workingEntry = existingEntry
            editorOpenedAt = Date()
            createdNewEntry = isNewEntryDraft
            pageTitleDraft = existingEntry.title
            pageTagsDraft = existingEntry.tags.joined(separator: ", ")
            return
        }

        print("[EditorPage] creating temporary unsaved JournalEntry")

        let entry = JournalEntry()

        print("[EditorPage] ensuring starter block for temporary entry")
        entry.ensureStarterBlock()

        print("[EditorPage] normalizing blocks for temporary entry")
        entry.normalizeBlockSortOrders()

        // Do NOT insert into modelContext here — inserting triggers @Query
        // observers on parent views causing infinite re-renders.
        // Do NOT assign entry.book here either, because assigning the relationship
        // can dirty/update the persisted book while navigation is mounting.
        // Insert and book assignment happen in saveAndClose() only.
        createdNewEntry = true
        pageTitleDraft = entry.title
        pageTagsDraft = entry.tags.joined(separator: ", ")
        workingEntry = entry
        editorOpenedAt = Date()

        print("[EditorPage] temporary unsaved entry assigned to workingEntry")
    }

    private func saveAndClose() {
        print("[EditorPage] saveAndClose called: createdNewEntry=\(createdNewEntry), workingEntry=\(workingEntry == nil ? "nil" : "set")")
        guard !isCompletingAction else { return }
        isCompletingAction = true

        guard let workingEntry else { finishAndDismiss(); return }

        if createdNewEntry && !canCreateJournalEntry {
            showPremiumRequiredMessage()
            isCompletingAction = false
            return
        }

        if createdNewEntry, isEntryEffectivelyEmpty(workingEntry) {
            // Never inserted, nothing to delete
            self.workingEntry = nil
            finishAndDismiss()
            return
        }

        if workingEntry.book == nil { workingEntry.book = book }
        workingEntry.ensureStarterBlock()
        workingEntry.normalizeBlockSortOrders()
        workingEntry.updatedAt = Date()

        if createdNewEntry {
            modelContext.insert(workingEntry)
        }
        try? modelContext.save()

        if createdNewEntry {
            let entryId = String(workingEntry.persistentModelID.hashValue)
            _ = try? LunixiaPointsManager.awardJournalEntry(
                in: modelContext,
                id: entryId,
                title: workingEntry.title.isEmpty ? "Journal Entry" : workingEntry.title,
                at: workingEntry.createdAt
            )

            let secondsSpent = max(60, Int(Date().timeIntervalSince(editorOpenedAt)))
            let mindfulMinutes = max(1, Int(round(Double(secondsSpent) / 60.0)))

            Task {
                await HealthKitManager.shared.addMindfulMinutesForJournalEntry(
                    minutes: mindfulMinutes,
                    at: Date()
                )
            }

            // Award self-care points for mindful minutes
            _ = try? LunixiaPointsManager.awardMindfulMinutes(
                in: modelContext,
                entryId: entryId,
                minutes: mindfulMinutes,
                at: Date()
            )

            // Persist mindful session to SwiftData (syncs via CloudKit)
            let session = MindfulSession(
                entryPersistentID: entryId,
                bookPersistentID: book.persistentModelID.hashValue.description,
                minutes: mindfulMinutes,
                tags: workingEntry.tags,
                date: Date()
            )
            modelContext.insert(session)
            try? modelContext.save()
        }

        finishAndDismiss()
    }

    private func cleanupEmptyNewEntryIfNeeded() {
        guard createdNewEntry, let workingEntry else { return }
        guard isEntryEffectivelyEmpty(workingEntry) else { return }
        // Temporary new entries are not inserted until Done, so there is nothing to delete here.
        self.workingEntry = nil
    }

    private func finishAndDismiss() {
        hasFinishedEditorFlow = true
        isCompletingAction = false
        dismiss()
    }

    private func showPremiumRequiredMessage() {
        premiumBannerMessage = "Premium unlocks more entries in this journal book."
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showPremiumBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                showPremiumBanner = false
            }
        }
    }

    // MARK: - Block Color Sheet

    private func blockColorSheet(for block: JournalBlock) -> some View {
        NavigationStack {
            ZStack {
                LunixiaBackground().ignoresSafeArea()
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        ColorPicker("Color 1", selection: $blockColor1Selection, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                        ColorPicker("Color 2", selection: $blockColor2Selection, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                            Gradient(colors: [blockColor1Selection, blockColor2Selection]),
                            startPoint: CGPoint(x: 0, y: size.height / 2),
                            endPoint: CGPoint(x: size.width, y: size.height / 2)
                        ))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
                    .clipShape(Capsule())
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    Button {
                        let c1 = hexStringFromColor(UIColor(blockColor1Selection))
                        let c2 = hexStringFromColor(UIColor(blockColor2Selection))
                        applyBlockColor(to: block, hex: "\(c1):\(c2)")
                        block.touch()
                        showBlockColorSheet = false
                    } label: {
                        Text("Apply Color")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LGradients.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, LSpacing.pageHorizontal)

                    if !currentBlockColorHex(for: block).isEmpty {
                        Button {
                            applyBlockColor(to: block, hex: "")
                            block.touch()
                            showBlockColorSheet = false
                        } label: {
                            Text("Reset to Default")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle(focusedBlockColorLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showBlockColorSheet = false }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func currentBlockColorHex(for block: JournalBlock) -> String {
        if block.type == .divider { return block.dividerColorHex }
        if block.type == .callout || block.isCalloutStyle { return block.calloutColorHex }
        return block.blockquoteColorHex
    }

    private func applyBlockColor(to block: JournalBlock, hex: String) {
        if block.type == .divider { block.dividerColorHex = hex }
        else if block.type == .callout || block.isCalloutStyle { block.calloutColorHex = hex }
        else { block.blockquoteColorHex = hex }
    }

    private func loadBlockColors(from hex: String) {
        let parts = hex.components(separatedBy: ":")
        if parts.count == 2,
           let r = UInt8(parts[0].prefix(2), radix: 16),
           let g = UInt8(parts[0].dropFirst(2).prefix(2), radix: 16),
           let b = UInt8(parts[0].dropFirst(4).prefix(2), radix: 16),
           let r2 = UInt8(parts[1].prefix(2), radix: 16),
           let g2 = UInt8(parts[1].dropFirst(2).prefix(2), radix: 16),
           let b2 = UInt8(parts[1].dropFirst(4).prefix(2), radix: 16) {
            blockColor1Selection = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
            blockColor2Selection = Color(red: Double(r2)/255, green: Double(g2)/255, blue: Double(b2)/255)
        } else {
            blockColor1Selection = Color(LColors.accent)
            blockColor2Selection = Color(LColors.accent)
        }
    }

    private func hexStringFromColor(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func isEntryEffectivelyEmpty(_ entry: JournalEntry) -> Bool {
        let hasTitle = !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTags = !entry.tags.isEmpty
        let meaningfulBlocks = (entry.blocks ?? []).filter { block in
            switch block.type {
            case .divider, .table:
                return false
            case .image:
                return block.imageData != nil
            default:
                return !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        return !hasTitle && !hasTags && meaningfulBlocks.isEmpty
    }
}
