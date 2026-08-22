//
//  NotesView.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import Foundation
import UIKit

private enum NoteRenderedContentKind: Equatable {
    case text(String)
    case bullets(Int)
    case checklist(Int)
    case numbers(Int)
}

private struct NoteRenderedContentElement: Identifiable, Equatable {
    let id: String
    let kind: NoteRenderedContentKind
}

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: LunixiaStoreManager

    @Query(sort: \Note.updatedAt, order: .reverse)
    private var notes: [Note]

    @Query(sort: \NotesTab.createdAt, order: .forward)
    private var tabs: [NotesTab]

    @State private var selectedFilter: NotesFilter = .all
    @State private var selectedNote: Note?
    @State private var viewingNote: Note?
    @State private var draftContent: String = ""
    @State private var draftChecklistItems: [NoteChecklistItem] = []
    @State private var draftListItems: [NoteListItem] = []
    @State private var draftSelectedListType: NoteListPlacementType = .bullets
    @State private var draftSlashCommandOffset: Int?
    @State private var showListCommandMenu: Bool = false
    @State private var showListTypeHelpSheet: Bool = false
#if canImport(UIKit)
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
#else
    private var isIPad: Bool { false }
#endif

    @State private var editingListType: NoteListPlacementType?
    @State private var draftRichContent: AttributedString = AttributedString()
    @State private var draftFontID: String = NoteFontOption.system.rawValue
    @State private var draftFontSize: Double = 15
    @State private var draftLabel1: String = ""
    @State private var draftLabel2: String = ""
    @State private var draftColorHex: String = "#6B4CDE"
    @State private var draftSecondaryColorHex: String = "#22D3EE"
    @State private var draftColor: Color = Color(red: 107 / 255, green: 76 / 255, blue: 222 / 255)
    @State private var draftSecondaryColor: Color = Color(red: 34 / 255, green: 211 / 255, blue: 238 / 255)
    @State private var draftUsesGradient: Bool = false
    @State private var draftDate: Date = Date()
    @State private var isCreatingNote: Bool = false
    @State private var showDeleteConfirmation = false
    @State private var visibleCount: Int = 6
    @AppStorage("notes.collapsedPinnedIDs") private var collapsedPinnedIDsStorage: String = ""
    @Query private var userSettings: [UserSettings]
    @State private var collapsedPinnedIDs: Set<String> = []

    @State private var selectedTab: String = ""
    @State private var newTabName: String = ""
    @State private var renamingTabName: String = ""
    @State private var renamedTabName: String = ""
    @State private var showDeleteTabConfirmation: Bool = false
    @State private var tabPendingDeletion: String = ""
    @State private var showingTabPopup: Bool = false
    @State private var tabPopupMode: TabPopupMode = .create
    @FocusState private var isEditorFocused: Bool
    @FocusState private var isTabFieldFocused: Bool

    @StateObject private var voiceManager = VoiceTranscriptionManager()
    @State private var didInsertTranscript: Bool = false

    @State private var showPremiumBanner = false
    @State private var premiumBannerMessage = ""
    @State private var showCopiedBanner = false
    @State private var copiedBannerHideTask: Task<Void, Never>?

    private var isPremium: Bool {
        storeManager.isPremium
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var settings: UserSettings? { userSettings.first }
    private var notesDefaultTab: String { settings?.notesDefaultTab ?? "" }
    private var draftFontOption: NoteFontOption {
        NoteFontOption.option(for: draftFontID)
    }
    private var draftFontSizeValue: CGFloat {
        CGFloat(draftFontSize)
    }

    private var nonRootTabs: [String] {
        notesTabs.filter { $0 != rootTabName }
    }

    private var canCreateTab: Bool {
        LunixiaLimitsManager.canCreateStickyNoteTab(
            currentCount: nonRootTabs.count,
            isPremium: isPremium
        )
    }

    private var currentTabNotes: [Note] {
        let root = rootTabName
        let activeTab = selectedTab.isEmpty ? root : selectedTab

        return notes.filter { note in
            let noteTab = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = noteTab.isEmpty ? root : noteTab
            return resolved == activeTab
        }
    }

    private var canCreateNoteInCurrentTab: Bool {
        LunixiaLimitsManager.canCreateNoteInStickyNoteTab(
            currentCountInTab: currentTabNotes.count,
            isPremium: isPremium
        )
    }


    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LunixiaBackground()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        topPageBar
                        headerSection
                        filterSection
                        tabsSection
                        notesSection
                    }
                    .padding(.top, 0)
                    .padding(.bottom, 110)
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
            .overlay {
                overlayContent
            }
            // Tab popup — sheet on iPhone, fullScreenCover on iPad
            .sheet(isPresented: Binding(
                get: { !isIPad && showingTabPopup },
                set: { if !$0 { showingTabPopup = false } }
            )) {
                tabNameSheet
            }
            .fullScreenCover(isPresented: Binding(
                get: { isIPad && showingTabPopup },
                set: { if !$0 { showingTabPopup = false } }
            )) {
                tabNameSheet
            }
            // List types help — sheet on iPhone, fullScreenCover on iPad
            .sheet(isPresented: Binding(
                get: { !isIPad && showListTypeHelpSheet },
                set: { if !$0 { showListTypeHelpSheet = false } }
            )) {
                listTypesHelpSheet
            }
            .fullScreenCover(isPresented: Binding(
                get: { isIPad && showListTypeHelpSheet },
                set: { if !$0 { showListTypeHelpSheet = false } }
            )) {
                listTypesHelpSheet
            }
            // Editor — sheet on iPhone, fullScreenCover on iPad
            .sheet(item: Binding<Note?>(
                get: { isIPad ? nil : selectedNote },
                set: { selectedNote = $0 }
            )) { note in
                editorOverlay(for: note)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: Binding<Note?>(
                get: { isIPad ? selectedNote : nil },
                set: { selectedNote = $0 }
            )) { note in
                editorOverlay(for: note)
            }
            // Viewer — sheet on iPhone, fullScreenCover on iPad
            .sheet(item: Binding<Note?>(
                get: { isIPad ? nil : viewingNote },
                set: { viewingNote = $0 }
            )) { note in
                viewerOverlay(for: note)
                    .presentationDetents(viewerSheetDetents(for: note))
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: Binding<Note?>(
                get: { isIPad ? viewingNote : nil },
                set: { viewingNote = $0 }
            )) { note in
                viewerOverlay(for: note)
            }
            .onAppear {
                ensureRootTabExists()
                if selectedTab.isEmpty {
                    let resolved = (!notesDefaultTab.isEmpty && notesTabs.contains(notesDefaultTab)) ? notesDefaultTab : rootTabName
                    selectedTab = resolved
                }
                loadCollapsedPinnedIDs()
                LunixiaStickyNoteWidgetWriter.write(notes: notes, tabs: tabs)
            }
            .onChange(of: notes) { _, newNotes in
                LunixiaStickyNoteWidgetWriter.write(notes: newNotes, tabs: tabs)
            }
            .onChange(of: tabs) { _, _ in
                if !notesTabs.contains(selectedTab) {
                    selectedTab = rootTabName
                }
                LunixiaStickyNoteWidgetWriter.write(notes: notes, tabs: tabs)
            }
            .onChange(of: collapsedPinnedIDs) { _, newValue in
                collapsedPinnedIDsStorage = newValue.sorted().joined(separator: "\n")
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        isEditorFocused = false
                        isTabFieldFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Text("Done")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(LGradients.header, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Overlay Content

    @ViewBuilder
    private var overlayContent: some View {
        if showDeleteTabConfirmation {
            deleteTabOverlay
        }
    }

    private var tabNameSheet: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground()
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Image("addtab")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(LGradients.header)

                        Text(tabPopupMode == .create ? "New Tab" : "Rename Tab")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)

                        Spacer()

                        Button {
                            closeTabPopup()
                        } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(LGradients.header)
                        }
                        .buttonStyle(.plain)
                    }

                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tab Name")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)

                            NotesGradientDoneTextField(
                                placeholder: "Enter name",
                                text: tabPopupMode == .create ? $newTabName : $renamedTabName,
                                fontOption: .system,
                                fontSize: 15
                            )
                            .focused($isTabFieldFocused)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.035))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }

                    HStack(spacing: 10) {
                        LButton(title: "Cancel", style: .secondary) {
                            closeTabPopup()
                        }

                        LButton(title: "Save", style: .gradient) {
                            if tabPopupMode == .create {
                                createTab()
                            } else {
                                renameTab()
                            }
                            showingTabPopup = false
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isTabFieldFocused = true
            }
        }
    }

    private var listTypesHelpSheet: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Image("linedpages")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(LGradients.header)

                            Text("List Types")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(LGradients.header)

                            Spacer()

                            Button {
                                showListTypeHelpSheet = false
                            } label: {
                                Image("xmarkwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.10))
                                            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        GlassCardNote {
                            VStack(alignment: .leading, spacing: 12) {
                                helpRow(
                                    title: "Choose first",
                                    body: "Use the Bullets, Checklist, and Numbers chips to choose what the plus button creates."
                                )

                                helpRow(
                                    title: "Place it in text",
                                    body: "Type / in the note text, then choose the list type. The editor inserts a placement token like \(Note.bulletsPlacementToken)."
                                )

                                helpRow(
                                    title: "Render later",
                                    body: "The editor keeps the token visible. The note view and widget replace the token with the real list from the boxes below."
                                )
                            }
                        }

                        GlassCardNote {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Tokens")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)

                                ForEach(NoteListPlacementType.allCases) { type in
                                    HStack(spacing: 10) {
                                        Text(type.title)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.78))
                                            .frame(width: 74, alignment: .leading)

                                        Text(type.token)
                                            .font(.system(size: 12, weight: .black, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(Color.white.opacity(0.10))
                                                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.20), lineWidth: 1))
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(22)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(520), .large])
        .presentationDragIndicator(.visible)
    }

    private func helpRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(body)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deleteTabOverlay: some View {
        ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()
                .onTapGesture {
                    showDeleteTabConfirmation = false
                    tabPendingDeletion = ""
                }

            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image("trash")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(LGradients.header)

                    Text("Delete Tab")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)

                    Text(deleteTabConfirmationMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        showDeleteTabConfirmation = false
                        tabPendingDeletion = ""
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LColors.glassSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        deleteTab()
                        showDeleteTabConfirmation = false
                    } label: {
                        Text("Delete")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LColors.accentGradient)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(width: 310)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LColors.bg.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 12)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(50)
    }

    private func editorOverlay(for note: Note) -> some View {
        NavigationStack {
            ZStack {
                noteBackground(
                    primary: draftColor,
                    secondary: draftSecondaryColor,
                    usesGradient: draftUsesGradient
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    popupHeader(for: note)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 14)

		                    ScrollView(showsIndicators: false) {
		                        popupContent(for: note)
		                            .padding(.horizontal, 22)
		                            .padding(.bottom, 18)
		                    }

                    popupFooter(for: note)
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            // The sheet closure captures the NotesView value from before startEditing's
            // @State writes land, so anything passed by value (font: draftFontOption)
            // renders with the defaults. Values passed as Bindings read live storage and
            // were always correct, which is why only these fields were wrong. Re-asserting
            // here forces one invalidation with the note's real font.
            if draftFontID != note.fontID {
                draftFontID = note.fontID
            }
            if draftFontSize != note.resolvedFontSize {
                draftFontSize = note.resolvedFontSize
            }
        }
        // Per-type list editor — sheet on iPhone, fullScreenCover on iPad
        .sheet(item: Binding<NoteListPlacementType?>(
            get: { isIPad ? nil : editingListType },
            set: { editingListType = $0 }
        )) { type in
            listTypeEditorSheet(for: type)
        }
        .fullScreenCover(item: Binding<NoteListPlacementType?>(
            get: { isIPad ? editingListType : nil },
            set: { editingListType = $0 }
        )) { type in
            listTypeEditorSheet(for: type)
        }
        .presentationBackground(draftColor)
        .modifier(
            LunixiaAlertConfirm(
                isPresented: $showDeleteConfirmation,
                title: "Delete Note?",
                message: "This note will be permanently removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                delete(note)
            }
        )
    }

    private func listTypeEditorSheet(for type: NoteListPlacementType) -> some View {
        NoteListTypeEditorSheet(
            type: type,
            listItems: $draftListItems,
            checklistItems: $draftChecklistItems,
            fontID: $draftFontID,
            fontSize: $draftFontSize,
            onAddGroup: { addedType, group in
                appendPlacementToken(addedType, group: group)
            },
            onClose: {
                editingListType = nil
            }
        )
    }

    private func viewerOverlay(for note: Note) -> some View {
        let noteColor = color(from: note.colorHex)
        let noteSecondaryColor = color(from: note.secondaryColorHex)

        return NavigationStack {
            ZStack {
                noteBackground(
                    primary: noteColor,
                    secondary: noteSecondaryColor,
                    usesGradient: note.usesGradient
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    viewerHeader(for: note)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 14)

                    ScrollView(showsIndicators: false) {
                        viewerContent(for: note)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 12)
                    }

                    viewerFooter(for: note)
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                }

                copiedBanner(noteColor: noteColor)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationBackground(noteColor)
        .onDisappear {
            resetCopiedBanner()
        }
        .modifier(
            LunixiaAlertConfirm(
                isPresented: $showDeleteConfirmation,
                title: "Delete Note?",
                message: "This note will be permanently removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                delete(note)
            }
        )
    }

    @ViewBuilder
    private func copiedBanner(noteColor: Color) -> some View {
        if showCopiedBanner {
            VStack {
                Text("Copied")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(noteColor)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.46), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
                    .padding(.top, 18)

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(100)
        }
    }

    @ViewBuilder
    private func noteBackground(primary: Color, secondary: Color, usesGradient: Bool) -> some View {
        if usesGradient {
            LinearGradient(
                colors: [
                    primary,
                    secondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            primary
        }
    }

    private func noteColorPickerRow(title: String, color: Binding<Color>, hex: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 58, alignment: .leading)

            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: color.wrappedValue) { _, newColor in
                    hex.wrappedValue = hexString(from: newColor)
                }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.wrappedValue)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )

            Text(hex.wrappedValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)

            Spacer(minLength: 0)
        }
    }

    private var listCommandMenu: some View {
        HStack(spacing: 8) {
            ForEach(NoteListPlacementType.allCases) { type in
                Button {
                    insertPlacementToken(type)
                } label: {
                    Text(listCommandTitle(for: type))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(draftSelectedListType == type ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.12)))
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.22), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        )
    }

    private func listCommandTitle(for type: NoteListPlacementType) -> String {
        switch type {
        case .bullets: return "Bullets"
        case .checklist: return "Checklists"
        case .numbers: return "Numbers"
        }
    }

    /// Builds the styled content for the rich editor: the note's font across the whole
    /// run, plus a tint behind each list placement token.
    private func styledDraftContent(_ plain: String) -> AttributedString {
        styledContent(plain, fontOption: draftFontOption, fontSize: draftFontSizeValue)
    }

    private func styledContent(
        _ plain: String,
        fontOption: NoteFontOption,
        fontSize: CGFloat
    ) -> AttributedString {
        var attributed = AttributedString(plain)
        attributed.font = fontOption.font(size: fontSize)
        attributed.foregroundColor = Color.white

        // Token chips. SwiftUI's AttributedString TextEditor supports background and
        // foreground colour, font and tracking, but not text attachments or a corner
        // radius — so the chip is a filled rectangle, not a true capsule. The rounded
        // black weight, purple fill and extra tracking are what sell it as tappable.
        // Every distinct token in the text, including numbered ones like [[ CHECKLIST 2 ]].
        let tokens = Set(Note.placements(in: plain).map { $0.type.token(group: $0.group) })

        for token in tokens {
            var cursor = attributed.startIndex
            while cursor < attributed.endIndex,
                  let found = attributed[cursor...].range(of: token) {
                attributed[found].backgroundColor = LColors.gradientPurple
                attributed[found].foregroundColor = Color.white
                attributed[found].font = .system(
                    size: max(11, fontSize - 2),
                    weight: .black,
                    design: .rounded
                )
                attributed[found].tracking = 0.6
                cursor = found.upperBound
            }
        }

        return attributed
    }

    private func handleDraftContentChange(oldValue: String, newValue: String) {
        guard newValue.count == oldValue.count + 1,
              let insertedSlashOffset = insertedSlashOffset(from: oldValue, to: newValue)
        else {
            if !newValue.contains("/") {
                showListCommandMenu = false
                draftSlashCommandOffset = nil
            }
            return
        }

        draftSlashCommandOffset = insertedSlashOffset
        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
            showListCommandMenu = true
        }
    }

    private func insertedSlashOffset(from oldValue: String, to newValue: String) -> Int? {
        var oldIndex = oldValue.startIndex
        var newIndex = newValue.startIndex

        while oldIndex < oldValue.endIndex, newIndex < newValue.endIndex {
            if oldValue[oldIndex] != newValue[newIndex] {
                return newValue[newIndex] == "/"
                    ? newValue.utf16.distance(from: newValue.utf16.startIndex, to: newIndex.samePosition(in: newValue.utf16) ?? newValue.utf16.startIndex)
                    : nil
            }
            oldValue.formIndex(after: &oldIndex)
            newValue.formIndex(after: &newIndex)
        }

        guard newIndex < newValue.endIndex, newValue[newIndex] == "/" else { return nil }
        return newValue.utf16.distance(from: newValue.utf16.startIndex, to: newIndex.samePosition(in: newValue.utf16) ?? newValue.utf16.startIndex)
    }

    private func insertPlacementToken(_ type: NoteListPlacementType) {
        draftSelectedListType = type
        let token = type.token(group: slashInsertGroup(for: type))
        let replacement = " \(token) "
        let nsContent = draftContent as NSString

        if let offset = draftSlashCommandOffset,
           offset >= 0,
           offset < nsContent.length,
           nsContent.substring(with: NSRange(location: offset, length: 1)) == "/" {
            draftContent = nsContent.replacingCharacters(in: NSRange(location: offset, length: 1), with: replacement)
        } else if let slashRange = draftContent.range(of: "/", options: .backwards) {
            draftContent.replaceSubrange(slashRange, with: replacement)
        } else if draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftContent = token
        } else {
            draftContent += "\n\(token)"
        }

        draftSlashCommandOffset = nil
        withAnimation(.easeOut(duration: 0.18)) {
            showListCommandMenu = false
        }
    }

    /// Which group the slash menu should place. It prefers a group that already holds
    /// items but has lost its token, then group 1, so picking a type twice can never
    /// leave two identical tokens in the text.
    private func slashInsertGroup(for type: NoteListPlacementType) -> Int {
        let placed = Set(
            Note.placements(in: draftContent)
                .filter { $0.type == type }
                .map(\.group)
        )

        let withItems: [Int]
        switch type {
        case .bullets:
            withItems = draftListItems.filter { $0.kind == .bullet }.map(\.group).sorted()
        case .numbers:
            withItems = draftListItems.filter { $0.kind == .numbered }.map(\.group).sorted()
        case .checklist:
            withItems = draftChecklistItems.map(\.group).sorted()
        }

        if let orphaned = withItems.first(where: { !placed.contains($0) }) {
            return orphaned
        }
        return placed.contains(1) ? ((placed.max() ?? 1) + 1) : 1
    }

    /// Appends a new group's token to the end of the note text. The user moves it by
    /// editing the content, the same as any other token.
    private func appendPlacementToken(_ type: NoteListPlacementType, group: Int) {
        let token = type.token(group: group)
        guard !draftContent.contains(token) else { return }

        if draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftContent = token
        } else {
            draftContent += "\n\n\(token)"
        }
    }

    private func renderedContentElements(for note: Note) -> [NoteRenderedContentElement] {
        let content = note.content
        var elements: [NoteRenderedContentElement] = []
        var placedKeys = Set<String>()
        var cursor = content.startIndex
        var counter = 0

        func appendText(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            counter += 1
            elements.append(NoteRenderedContentElement(id: "text-\(counter)", kind: .text(trimmed)))
        }

        func appendList(_ type: NoteListPlacementType, group: Int, suffix: String = "") {
            counter += 1
            elements.append(
                NoteRenderedContentElement(
                    id: "\(type.rawValue)-\(group)\(suffix)-\(counter)",
                    kind: renderedKind(for: type, group: group)
                )
            )
        }

        for placement in Note.placements(in: content) {
            appendText(String(content[cursor..<placement.range.lowerBound]))

            // A repeated identical token used to render the same list twice, mirrored.
            // Each group is now drawn once, at its first token.
            let key = groupKey(placement.type, placement.group)
            if hasItems(note, type: placement.type, group: placement.group), !placedKeys.contains(key) {
                placedKeys.insert(key)
                appendList(placement.type, group: placement.group)
            }

            cursor = placement.range.upperBound
        }

        appendText(String(content[cursor..<content.endIndex]))

        // Groups that hold items but whose token is missing from the text still render,
        // so items can never become invisible and unreachable.
        for (type, group) in populatedGroups(in: note) where !placedKeys.contains(groupKey(type, group)) {
            appendList(type, group: group, suffix: "-fallback")
        }

        return elements
    }

    private func groupKey(_ type: NoteListPlacementType, _ group: Int) -> String {
        "\(type.rawValue)-\(group)"
    }

    private func hasItems(_ note: Note, type: NoteListPlacementType, group: Int) -> Bool {
        switch type {
        case .bullets:
            return note.listItems.contains { $0.kind == .bullet && $0.group == group }
        case .numbers:
            return note.listItems.contains { $0.kind == .numbered && $0.group == group }
        case .checklist:
            return note.checklistItems.contains { $0.group == group }
        }
    }

    /// Every (type, group) pair that actually has items, in a stable order.
    private func populatedGroups(in note: Note) -> [(NoteListPlacementType, Int)] {
        var pairs: [(NoteListPlacementType, Int)] = []

        for type in NoteListPlacementType.allCases {
            let groups: Set<Int>
            switch type {
            case .bullets:
                groups = Set(note.listItems.filter { $0.kind == .bullet }.map(\.group))
            case .numbers:
                groups = Set(note.listItems.filter { $0.kind == .numbered }.map(\.group))
            case .checklist:
                groups = Set(note.checklistItems.map(\.group))
            }
            pairs.append(contentsOf: groups.sorted().map { (type, $0) })
        }

        return pairs
    }

    private func renderedKind(for type: NoteListPlacementType, group: Int) -> NoteRenderedContentKind {
        switch type {
        case .bullets: return .bullets(group)
        case .checklist: return .checklist(group)
        case .numbers: return .numbers(group)
        }
    }

    private func closeTabPopup() {
        showingTabPopup = false
        newTabName = ""
        renamedTabName = ""
        renamingTabName = ""
    }

    // MARK: - Header

    private var topPageBar: some View {
        HStack(alignment: .center) {
            Text("Notes")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)

            Spacer()

            HStack(spacing: 14) {
                Button {
                    if canCreateTab {
                        newTabName = ""
                        tabPopupMode = .create
                        showingTabPopup = true
                    } else {
                        showPremiumRequiredMessage("Premium unlocks more note tabs.")
                    }
                } label: {
                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)

                Button {
                    if canCreateNoteInCurrentTab {
                        createNote()
                    } else {
                        showPremiumRequiredMessage("Premium unlocks more notes per tab.")
                    }
                } label: {
                    Image("editing")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick thoughts, fragments, and things you want to keep nearby.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(selectedTab.isEmpty ? rootTabName : selectedTab) currently has \(currentTabNoteCount) notes")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    // MARK: - Filters

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(NotesFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if selectedFilter == filter {
                                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                            .fill(AnyShapeStyle(LGradients.header))
                                    } else {
                                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                            .fill(LColors.glassSurface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                                    .stroke(LColors.glassBorder, lineWidth: 1)
                                            )
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        }
    }

    // MARK: - Tabs Section

    private var tabsSection: some View {
        FlowLayout(spacing: 10) {
            ForEach(notesTabs, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    visibleCount = 6
                } label: {
                    HStack(spacing: 6) {
                        Text(tab)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                            .fill(Color.white.opacity(selectedTab == tab ? 0.22 : 0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: LSpacing.buttonRadius)
                                    .stroke(Color.white.opacity(selectedTab == tab ? 0.24 : 0.16), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        moveTabLeft(tab)
                    } label: {
                        Label("Move Left", image: "chevleft")
                    }
                    .disabled(tab == notesTabs.first)

                    Button {
                        moveTabRight(tab)
                    } label: {
                        Label("Move Right", image: "chevright")
                    }
                    .disabled(tab == notesTabs.last)

                    Divider()

                    Button {
                        if let s = settings {
                            s.notesDefaultTab = tab
                            s.updatedAt = Date()
                            try? modelContext.save()
                        }
                    } label: {
                        Label(notesDefaultTab == tab ? "Default Tab ✓" : "Set as Default", image: "starfill")
                    }

                    Button {
                        renamingTabName = tab
                        renamedTabName = tab
                        tabPopupMode = .rename
                        showingTabPopup = true
                    } label: {
                        Label("Rename", image: "linespencil")
                    }

                    if tab != rootTabName || notesTabs.count > 1 {
                        Button(role: .destructive) {
                            tabPendingDeletion = tab
                            showDeleteTabConfirmation = true
                        } label: {
                            Label("Delete", image: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        if filteredNotes.isEmpty {
            GlassCard(padding: 22) {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 58, height: 58)

                        Image("pencilfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.white)
                    }

                    Text(emptyMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LColors.textPrimary)
                        .multilineTextAlignment(.center)

                    LButton(title: "Create Note", style: .gradient) {
                        if canCreateNoteInCurrentTab {
                            createNote()
                        } else {
                            showPremiumRequiredMessage("Premium unlocks more notes per tab.")
                        }
                    }
                }
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14, alignment: .top),
                        GridItem(.flexible(), spacing: 14, alignment: .top)
                    ],
                    spacing: 14
                ) {
                    ForEach(visibleNotes) { note in
	                        NoteStickyCard(
	                            note: note,
	                            stickyColor: color(from: note.colorHex),
	                            secondaryStickyColor: color(from: note.secondaryColorHex),
	                            usesGradient: note.usesGradient,
	                            availableTabs: notesTabs,
                            isCollapsed: note.isPinned
                                ? Binding(
                                    get: { collapsedPinnedIDs.contains(collapseID(for: note)) },
                                    set: { collapsed in
                                        let id = collapseID(for: note)
                                        if collapsed {
                                            collapsedPinnedIDs.insert(id)
                                        } else {
                                            collapsedPinnedIDs.remove(id)
                                        }
                                    }
                                )
                                : .constant(false),
                            action: {
                                open(note)
                            },
                            onToggleChecklistItem: { item in
                                toggleChecklistItem(item, in: note)
                            },
                            onMoveToTab: { tab in
                                move(note, to: tab)
                            },
                            onDelete: {
                                delete(note)
                            }
                        )
                    }
                }

                if filteredNotes.count > visibleCount {
                    HStack {
                        Spacer()
                        LoadMoreButton {
                            visibleCount += 6
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        }
    }

    // MARK: - Note Sheets

    private func popupHeader(for note: Note) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Note")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    togglePinned(note)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Image("pin")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(note.isPinned ? .white : Color.black.opacity(0.38))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func viewerHeader(for note: Note) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Note")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    togglePinned(note)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
                            )
                            .frame(width: 44, height: 44)

                        Image("pin")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(note.isPinned ? .white : Color.black.opacity(0.38))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func viewerContent(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text("Content")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)

                    Spacer()

                    Button {
                        copyNoteContent(note)
                    } label: {
                        Image("copy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(note.contentWithoutListPlacementTokens.isEmpty && note.listItems.isEmpty && note.checklistItems.isEmpty)
                    .opacity((note.contentWithoutListPlacementTokens.isEmpty && note.listItems.isEmpty && note.checklistItems.isEmpty) ? 0.45 : 1)
                    .accessibilityLabel("Copy content")
                }

                VStack(alignment: .leading, spacing: 12) {
                    if note.contentWithoutListPlacementTokens.isEmpty && note.listItems.isEmpty && note.checklistItems.isEmpty {
                        Text("Empty note")
                            .font(NoteFontOption.option(for: note.fontID).font(size: CGFloat(note.resolvedFontSize)))
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        renderedNoteContent(note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 170, alignment: .topLeading)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)

            if !note.activeLabels.isEmpty {
                HStack(spacing: 8) {
                    ForEach(note.activeLabels, id: \.self) { label in
                        Text(label.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.18))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                    )
                            )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
        }
    }

    private func renderedNoteContent(_ note: Note) -> some View {
        let font = NoteFontOption.option(for: note.fontID)
        let textSize = CGFloat(note.resolvedFontSize)
        let elements = renderedContentElements(for: note)

        return VStack(alignment: .leading, spacing: 12) {
            ForEach(elements) { element in
                switch element.kind {
                case .text(let text):
                    Text(text)
                        .font(font.font(size: textSize))
                        .foregroundStyle(.white)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .bullets(let group):
                    NoteListDisplay(
                        items: note.listItems.filter { $0.kind == .bullet && $0.group == group },
                        font: font,
                        textColor: .white,
                        markerSize: 22,
                        textSize: textSize,
                        rowSpacing: 9
                    )
                case .checklist(let group):
                    NoteChecklistInteractiveDisplay(
                        items: note.checklistItems.filter { $0.group == group },
                        font: font,
                        textColor: .white,
                        circleSize: 22,
                        textSize: textSize,
                        rowSpacing: 9,
                        onToggle: { item in
                            toggleChecklistItem(item, in: note)
                        }
                    )
                case .numbers(let group):
                    NoteListDisplay(
                        items: note.listItems.filter { $0.kind == .numbered && $0.group == group },
                        font: font,
                        textColor: .white,
                        markerSize: 22,
                        textSize: textSize,
                        rowSpacing: 9
                    )
                }
            }
        }
    }

    private func viewerFooter(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Text("Delete")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                .fill(Color.black.opacity(0.30))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.26), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    closeViewer()
                } label: {
                    Text("Close")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                .fill(Color.black.opacity(0.30))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.26), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    startEditing(note)
                } label: {
                    Text("Edit")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                .fill(Color.black.opacity(0.30))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.26), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func popupContentEditor(for note: Note) -> some View {
        GlassCardNote {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text("Content")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        if voiceManager.isRecording {
                            let transcript = voiceManager.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                            voiceManager.stopRecording()
                            if !transcript.isEmpty {
                                if draftContent.isEmpty {
                                    draftContent = transcript
                                } else {
                                    draftContent += " " + transcript
                                }
                            }
                        } else {
                            Task { await voiceManager.startRecording() }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(voiceManager.isRecording
                                      ? Color.white.opacity(0.18)
                                      : Color.white.opacity(0.08))
                                .overlay(
                                    Circle()
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image(voiceManager.isRecording ? "stopwavy" : "micfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(
                                    (voiceManager.isRecording || !didInsertTranscript)
                                        ? .white
                                        : LColors.textSecondary
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!voiceManager.isRecording && didInsertTranscript)
                }

                if voiceManager.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)

                        Text(voiceManager.liveTranscript.isEmpty
                             ? "Listening..."
                             : voiceManager.liveTranscript)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    )
                }

                if let error = voiceManager.permissionError {
                    Text(error.errorDescription ?? "An error occurred.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassRichTextEditor(
                    placeholder: "Write anything...",
                    text: $draftRichContent,
                    minHeight: 210,
                    placeholderFontID: $draftFontID,
                    placeholderFontSize: $draftFontSize
                )
                .focused($isEditorFocused)
                .onChange(of: draftRichContent) { _, newValue in
                    // Typing flows rich -> plain. draftContent stays the source of truth
                    // for saving and for the token parsing everything else relies on.
                    let plain = String(newValue.characters)
                    if plain != draftContent {
                        draftContent = plain
                    }
                }
                .onChange(of: draftContent) { oldValue, newValue in
                    handleDraftContentChange(oldValue: oldValue, newValue: newValue)

                    // Only rebuild when the change came from outside the editor (token
                    // insertion, dictation). Rebuilding on every keystroke would reset
                    // the caret.
                    if String(draftRichContent.characters) != newValue {
                        draftRichContent = styledDraftContent(newValue)
                    }
                }
                .onChange(of: draftFontID) { _, _ in
                    draftRichContent = styledDraftContent(draftContent)
                }
                .onChange(of: draftFontSize) { _, _ in
                    draftRichContent = styledDraftContent(draftContent)
                }

                if showListCommandMenu {
                    listCommandMenu
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func popupContent(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            popupContentEditor(for: note)

            GlassCardNote {
                VStack(alignment: .leading, spacing: 12) {
                    NoteListTypesEditor(
                        listItems: $draftListItems,
                        checklistItems: $draftChecklistItems,
                        onShowHelp: {
                            saveDraftInPlace(for: note)
                            DispatchQueue.main.async {
                                showListTypeHelpSheet = true
                            }
                        },
                        onOpenType: { type in
                            editingListType = type
                        }
                    )

	                    VStack(alignment: .leading, spacing: 10) {
	                        Text("Sticky Note Color")
	                            .font(.system(size: 13, weight: .bold))
	                            .foregroundStyle(.white)

	                        VStack(alignment: .leading, spacing: 12) {
	                            noteColorPickerRow(
	                                title: "Primary",
	                                color: $draftColor,
	                                hex: $draftColorHex
	                            )

	                            Button {
	                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
	                                    draftUsesGradient.toggle()
	                                }
	                            } label: {
	                                HStack(spacing: 12) {
	                                    Text("Gradient")
	                                        .font(.system(size: 13, weight: .bold, design: .rounded))
	                                        .foregroundStyle(.white)

	                                    Spacer()

	                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
	                                        .fill(draftUsesGradient ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.12)))
	                                        .frame(width: 50, height: 28)
	                                        .overlay(
	                                            Circle()
	                                                .fill(.white)
	                                                .frame(width: 22, height: 22)
	                                                .offset(x: draftUsesGradient ? 11 : -11)
	                                                .shadow(color: .black.opacity(0.20), radius: 4, y: 2)
	                                        )
	                                        .overlay(
	                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
	                                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
	                                        )
	                                }
	                            }
	                            .buttonStyle(.plain)

	                            if draftUsesGradient {
	                                noteColorPickerRow(
	                                    title: "Second",
	                                    color: $draftSecondaryColor,
	                                    hex: $draftSecondaryColorHex
	                                )
	                                .transition(.opacity.combined(with: .move(edge: .top)))
	                            }
	                        }
	                    }
	                }
	            }

            GlassCardNote {
                NoteFontPicker(selectedFontID: $draftFontID)
            }

            GlassCardNote {
                NoteFontSizeControl(
                    fontSize: $draftFontSize,
                    fontID: $draftFontID
                )
            }

            GlassCardNote {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Label 1")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)

                        NotesGradientDoneTextField(
                            placeholder: "Add a label",
                            text: $draftLabel1,
                            fontOption: .system,
                            fontSize: 15
                        )
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.46), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous))
                    }

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Label 2")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)

                        NotesGradientDoneTextField(
                            placeholder: "Add a label",
                            text: $draftLabel2,
                            fontOption: .system,
                            fontSize: 15
                        )
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.46), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous))
                    }
                }
            }

            GlassCardNote {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text("DATE")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)

                        DatePicker("", selection: $draftDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.32), lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Text("TIME")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)

                        DatePicker("", selection: $draftDate, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.32), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func popupFooter(for note: Note) -> some View {
        HStack(spacing: 10) {
            Button {
                showDeleteConfirmation = true
            } label: {
                Text("Delete")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                closeEditor()
            } label: {
                Text("Close")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button {
                saveChanges(for: note)
            } label: {
                Text("Save")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }


    // MARK: - Data

    private var deleteTabConfirmationMessage: String {
        if tabPendingDeletion == rootTabName && notesTabs.count > 1 {
            return "Notes in this tab will be moved to the next available tab, which will become the new default tab."
        }
        return "Notes in this tab will be moved to \(rootTabName)."
    }

    private var currentTabNoteCount: Int {
        let root = rootTabName
        let activeTab = selectedTab.isEmpty ? root : selectedTab
        return notes.filter { note in
            let noteTab = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = noteTab.isEmpty ? root : noteTab
            return resolved == activeTab
        }.count
    }

    private var visibleNotes: [Note] {
        let collapsedPinnedCount = filteredNotes.filter {
            $0.isPinned && collapsedPinnedIDs.contains(collapseID(for: $0))
        }.count

        let effectiveCount = visibleCount + (collapsedPinnedCount * 2)
        return Array(filteredNotes.prefix(effectiveCount))
    }

    private var filteredNotes: [Note] {
        let root = rootTabName
        let tabbedNotes = notes.filter { note in
            let noteTab = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = noteTab.isEmpty ? root : noteTab
            return resolved == (selectedTab.isEmpty ? root : selectedTab)
        }

        switch selectedFilter {
        case .all:
            return tabbedNotes.sorted { $0.isPinned && !$1.isPinned }
        case .pinned:
            return tabbedNotes.filter(\.isPinned)
        case .recent:
            return tabbedNotes.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .all: return "Your notes will appear here."
        case .pinned: return "Pinned notes will appear here."
        case .recent: return "Recent notes will appear here."
        }
    }

    private var rootTabName: String {
        tabs.first(where: { $0.isRootTab })?.trimmedName
            ?? tabs.first?.trimmedName
            ?? "All Notes"
    }

    private var notesTabs: [String] {
        var merged: [String] = []
        let root = rootTabName
        merged.append(root)

        for tab in tabs {
            let name = tab.trimmedName
            guard !name.isEmpty, !merged.contains(name) else { continue }
            merged.append(name)
        }

        for note in notes {
            let name = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = name.isEmpty ? root : name
            if !merged.contains(resolved) { merged.append(resolved) }
        }

        return merged
    }

    private func tabModel(named name: String) -> NotesTab? {
        tabs.first { $0.trimmedName == name }
    }

    private func ensureRootTabExists() {
        guard tabs.first(where: { $0.isRootTab }) == nil else { return }
        let existingFirst = tabs.first
        if let existingFirst {
            existingFirst.isRootTab = true
        } else {
            let root = NotesTab(name: "All Notes", isRootTab: true)
            modelContext.insert(root)
        }
        try? modelContext.save()
    }

    private func collapseID(for note: Note) -> String {
        String(describing: note.id)
    }

    private func loadCollapsedPinnedIDs() {
        let values = collapsedPinnedIDsStorage
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
        collapsedPinnedIDs = Set(values)
    }

    private func createTab() {
        guard canCreateTab else {
            showPremiumRequiredMessage("Premium unlocks more note tabs.")
            return
        }
        ensureRootTabExists()
        let trimmed = newTabName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !notesTabs.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newTabName = ""
            return
        }

        let tab = NotesTab(name: trimmed, isRootTab: false)
        modelContext.insert(tab)
        do { try modelContext.save() } catch { print("Failed to create tab: \(error)") }

        selectedTab = trimmed
        visibleCount = 6
        newTabName = ""
    }

    private func renameTab() {
        ensureRootTabExists()
        let trimmed = renamedTabName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !renamingTabName.isEmpty, !trimmed.isEmpty else { return }
        guard !notesTabs.contains(where: {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame &&
            $0.caseInsensitiveCompare(renamingTabName) != .orderedSame
        }) else {
            renamedTabName = ""; renamingTabName = ""
            return
        }

        let isRenamingRoot = renamingTabName == rootTabName

        if let tab = tabModel(named: renamingTabName) {
            tab.name = trimmed
            tab.touch()
        } else if isRenamingRoot {
            let tab = NotesTab(name: trimmed, isRootTab: true)
            modelContext.insert(tab)
        }

        for note in notes {
            let noteTab = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesOld = noteTab == renamingTabName
            let matchesEmpty = isRenamingRoot && noteTab.isEmpty
            if matchesOld || matchesEmpty { note.tabName = trimmed }
        }

        do { try modelContext.save() } catch { print("Failed to rename tab: \(error)") }

        if selectedTab == renamingTabName { selectedTab = trimmed }
        renamedTabName = ""; renamingTabName = ""
    }

    private func moveTabLeft(_ tabName: String) {
        moveTab(tabName, direction: -1)
    }

    private func moveTabRight(_ tabName: String) {
        moveTab(tabName, direction: 1)
    }

    private func moveTab(_ tabName: String, direction: Int) {
        let orderedTabs = notesTabs
        guard let currentIndex = orderedTabs.firstIndex(of: tabName) else { return }

        let targetIndex = currentIndex + direction
        guard orderedTabs.indices.contains(targetIndex) else { return }

        let targetName = orderedTabs[targetIndex]

        guard
            let currentTab = tabModel(named: tabName),
            let targetTab = tabModel(named: targetName)
        else { return }

        let currentDate = currentTab.createdAt
        currentTab.createdAt = targetTab.createdAt
        targetTab.createdAt = currentDate

        currentTab.touch()
        targetTab.touch()

        do {
            try modelContext.save()
        } catch {
            print("Failed to reorder tabs: \(error)")
        }
    }

    private func deleteTab() {
        let currentRootTabName = self.rootTabName
        let tabToDelete = tabPendingDeletion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tabToDelete.isEmpty else { return }

        let isDeletingRoot = tabToDelete == currentRootTabName
        let hasMultipleTabs = notesTabs.count > 1
        if isDeletingRoot && !hasMultipleTabs { return }

        let replacementRootName: String = {
            if isDeletingRoot {
                return notesTabs.first(where: { $0 != tabToDelete }) ?? currentRootTabName
            }
            return currentRootTabName
        }()

        if isDeletingRoot, let replacementTab = tabModel(named: replacementRootName) {
            replacementTab.isRootTab = true
            replacementTab.touch()
        }

        if let tab = tabModel(named: tabToDelete) { modelContext.delete(tab) }

        for note in notes {
            let noteTab = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesDeletedTab = noteTab == tabToDelete
            let matchesEmptyRoot = isDeletingRoot && noteTab.isEmpty
            if matchesDeletedTab || matchesEmptyRoot {
                note.tabName = replacementRootName
                note.touch()
            }
        }

        do { try modelContext.save() } catch { print("Failed to delete tab: \(error)") }

        if selectedTab == tabToDelete || (isDeletingRoot && selectedTab.isEmpty) {
            selectedTab = replacementRootName
        }
        tabPendingDeletion = ""
        visibleCount = 6
    }

    private func move(_ note: Note, to tab: String) {
        note.tabName = tab
        note.touch()
        do { try modelContext.save() } catch { print("Failed to move note: \(error)") }
    }

    private func createNote() {
        guard canCreateNoteInCurrentTab else {
            showPremiumRequiredMessage("Premium unlocks more notes per tab.")
            return
        }
        let note = Note(
            content: "",
            colorHex: "#6B4CDE",
            secondaryColorHex: "#22D3EE",
            usesGradient: false,
            checklistItemsJSON: "",
            listItemsJSON: "",
            fontID: NoteFontOption.system.rawValue,
            fontSize: 15,
            label: "",
            label2: "",
            tabName: selectedTab.isEmpty ? (notesTabs.first ?? "All Notes") : selectedTab,
            isPinned: false,
            isFavorite: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        modelContext.insert(note)
        draftContent = ""
        draftRichContent = AttributedString()
        draftChecklistItems = []
        draftListItems = []
        draftSelectedListType = .bullets
        draftSlashCommandOffset = nil
        showListCommandMenu = false
        draftFontID = note.fontID
        draftFontSize = note.resolvedFontSize
        draftLabel1 = note.label
        draftLabel2 = note.label2
        draftColorHex = note.colorHex
        draftSecondaryColorHex = note.secondaryColorHex
        draftColor = color(from: note.colorHex)
        draftSecondaryColor = color(from: note.secondaryColorHex)
        draftUsesGradient = note.usesGradient
        draftDate = note.createdAt
        isCreatingNote = true

        // Same reason as startEditing: let the draft state commit before the sheet builds.
        DispatchQueue.main.async {
            selectedNote = note
        }
    }

    private func open(_ note: Note) {
        resetCopiedBanner()
        viewingNote = note
    }

    private func startEditing(_ note: Note) {
        // TEMP DIAGNOSTIC — remove once the font issue is resolved.
        print("[FONTDBG] startEditing note.fontID=\(note.fontID) note.fontSize=\(note.resolvedFontSize)")
        resetCopiedBanner()
        viewingNote = nil
        draftContent = note.content
        // Built from the note directly rather than from draft state, which has not been
        // assigned yet at this point.
        draftRichContent = styledContent(
            note.content,
            fontOption: NoteFontOption.option(for: note.fontID),
            fontSize: CGFloat(note.resolvedFontSize)
        )
        draftChecklistItems = note.checklistItems
        draftListItems = note.listItems
        draftSelectedListType = .bullets
        draftSlashCommandOffset = nil
        showListCommandMenu = false
        draftFontID = note.fontID
        draftFontSize = note.resolvedFontSize
        draftLabel1 = note.label
        draftLabel2 = note.label2
        draftColorHex = note.colorHex
        draftSecondaryColorHex = note.secondaryColorHex
        draftColor = color(from: note.colorHex)
        draftSecondaryColor = color(from: note.secondaryColorHex)
        draftUsesGradient = note.usesGradient
        draftDate = note.updatedAt
        isCreatingNote = false
        showDeleteConfirmation = false

        // Present on the next runloop so every draft value above is committed first.
        // Presenting in the same update pass let the sheet build its body while
        // draftFontID still held the previous value, which is why the list rows and the
        // font size preview rendered in the system font on the first open after launch.
        DispatchQueue.main.async {
            selectedNote = note
        }
    }

    private func closeViewer() {
        voiceManager.stopRecording()
        resetCopiedBanner()
        viewingNote = nil
        showDeleteConfirmation = false
    }

    private func closeEditor() {
        voiceManager.stopRecording()
        didInsertTranscript = false
        editingListType = nil
        selectedNote = nil
        viewingNote = nil
        draftContent = ""
        draftRichContent = AttributedString()
        draftChecklistItems = []
        draftListItems = []
        draftSelectedListType = .bullets
        draftSlashCommandOffset = nil
        showListCommandMenu = false
        draftFontID = NoteFontOption.system.rawValue
        draftFontSize = 15
        draftLabel1 = ""
        draftLabel2 = ""
        draftColorHex = "#6B4CDE"
        draftSecondaryColorHex = "#22D3EE"
        draftColor = Color(red: 107 / 255, green: 76 / 255, blue: 222 / 255)
        draftSecondaryColor = Color(red: 34 / 255, green: 211 / 255, blue: 238 / 255)
        draftUsesGradient = false
        draftDate = Date()
        isCreatingNote = false
        showDeleteConfirmation = false
    }

    private func saveChanges(for note: Note) {
        applyDraft(to: note, preservingEmptyItems: false)
        note.touch()

        do {
            try modelContext.save()
            // TEMP DIAGNOSTIC — remove once the font issue is resolved.
            print("[FONTDBG] saved. note.fontID=\(note.fontID) note.fontSize=\(note.fontSize) contextHasChanges=\(modelContext.hasChanges)")
            LunixiaStickyNoteWidgetWriter.write(notes: notes, tabs: tabs)
        } catch {
            print("[FONTDBG] SAVE FAILED: \(error)")
        }
        closeEditor()
    }

    private func saveDraftInPlace(for note: Note) {
        applyDraft(to: note, preservingEmptyItems: true)
        note.touch()

        do {
            try modelContext.save()
            LunixiaStickyNoteWidgetWriter.write(notes: notes, tabs: tabs)
        } catch {
            print("Failed to save note before showing list help: \(error)")
        }
    }

    private func applyDraft(to note: Note, preservingEmptyItems: Bool) {
        // TEMP DIAGNOSTIC — remove once the font issue is resolved.
        print("[FONTDBG] applyDraft writing fontID=\(draftFontID) size=\(draftFontSize) (was \(note.fontID)/\(note.fontSize))")
        note.content = draftContent
        var preparedListItems = draftListItems
            .map { item in
                NoteListItem(
                    id: item.id,
                    title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: item.kind,
                    createdAt: item.createdAt,
                    group: item.group
                )
            }
        if !preservingEmptyItems {
            preparedListItems = preparedListItems.filter { !$0.title.isEmpty }
        }
        note.listItems = preparedListItems

        var preparedChecklistItems = draftChecklistItems
            .map { item in
                NoteChecklistItem(
                    id: item.id,
                    title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    isCompleted: item.isCompleted,
                    createdAt: item.createdAt,
                    group: item.group
                )
            }
        if !preservingEmptyItems {
            preparedChecklistItems = preparedChecklistItems.filter { !$0.title.isEmpty }
        }
        note.checklistItems = preparedChecklistItems

        note.fontID = draftFontID
        note.fontSize = min(Note.maximumFontSize, max(Note.minimumFontSize, draftFontSize))
        note.label = draftLabel1.trimmingCharacters(in: .whitespacesAndNewlines)
        note.label2 = draftLabel2.trimmingCharacters(in: .whitespacesAndNewlines)
        note.colorHex = draftColorHex
        note.secondaryColorHex = draftSecondaryColorHex
        note.usesGradient = draftUsesGradient

        if isCreatingNote {
            note.createdAt = draftDate
            note.updatedAt = draftDate
        } else {
            note.updatedAt = draftDate
        }
    }

    private func color(from hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return Color(red: 107 / 255, green: 76 / 255, blue: 222 / 255)
        }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }

    private func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "#6B4CDE" }
        return String(format: "#%02X%02X%02X", Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
    }

    private func togglePinned(_ note: Note) {
        note.isPinned.toggle()
        note.touch()
        do { try modelContext.save() } catch { print("Failed to toggle pin: \(error)") }
    }

    private func toggleChecklistItem(_ item: NoteChecklistItem, in note: Note) {
        var items = note.checklistItems
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isCompleted.toggle()
        note.checklistItems = items
        note.touch()
        do {
            try modelContext.save()
            LunixiaStickyNoteWidgetWriter.write(notes: notes, tabs: tabs)
        } catch {
            print("Failed to toggle checklist item: \(error)")
        }
    }

    private func delete(_ note: Note) {
        selectedNote = nil
        viewingNote = nil
        visibleCount = max(6, visibleCount - 1)
        modelContext.delete(note)
        do { try modelContext.save() } catch { print("Failed to delete note: \(error)") }
        closeEditor()
    }

    private func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func longDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func showPremiumRequiredMessage(_ message: String) {
        premiumBannerMessage = message

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showPremiumBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                showPremiumBanner = false
            }
        }
    }

    private func copyNoteContent(_ note: Note) {
        let elements = renderedContentElements(for: note)
        let exportText = elements.map { element -> String in
            switch element.kind {
            case .text(let text):
                return text
            case .bullets(let group):
                return note.listItems
                    .filter { $0.kind == .bullet && $0.group == group }
                    .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { "- \($0)" }
                    .joined(separator: "\n")
            case .checklist(let group):
                return note.checklistItems
                    .filter { $0.group == group }
                    .compactMap { item in
                        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return nil }
                        return "\(item.isCompleted ? "[x]" : "[ ]") \(title)"
                    }
                    .joined(separator: "\n")
            case .numbers(let group):
                return note.listItems
                    .filter { $0.kind == .numbered && $0.group == group }
                    .enumerated()
                    .map { index, item in
                        "\(index + 1). \(item.title.trimmingCharacters(in: .whitespacesAndNewlines))"
                    }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")
            }
        }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !exportText.isEmpty else { return }

        UIPasteboard.general.string = exportText
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        copiedBannerHideTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            showCopiedBanner = true
        }

        copiedBannerHideTask = Task {
            try? await Task.sleep(for: .seconds(1.7))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    showCopiedBanner = false
                }
                copiedBannerHideTask = nil
            }
        }
    }

    private func resetCopiedBanner() {
        copiedBannerHideTask?.cancel()
        copiedBannerHideTask = nil
        showCopiedBanner = false
    }
}

// MARK: - Sticky Note Card

private struct NoteStickyCard: View {
    let note: Note
    let stickyColor: Color
    let secondaryStickyColor: Color
    let usesGradient: Bool
    let availableTabs: [String]
    @Binding var isCollapsed: Bool
    let action: () -> Void
    let onToggleChecklistItem: (NoteChecklistItem) -> Void
    let onMoveToTab: (String) -> Void
    let onDelete: () -> Void

    private var cardHeight: CGFloat { note.isPinned && isCollapsed ? 96 : 190 }
    private var previewLineLimit: Int { note.isPinned && isCollapsed ? 3 : 8 }
    private var cardFontSize: CGFloat {
        min(max(CGFloat(note.resolvedFontSize) * 0.82, 11), 15)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(stickyFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        HStack(spacing: 8) {
                            if note.isPinned {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                        isCollapsed.toggle()
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.08))
                                            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                                            .frame(width: 28, height: 28)
                                        Image(isCollapsed ? "chevdown" : "chevup")
                                            .renderingMode(.template).resizable().scaledToFit()
                                            .frame(width: 12, height: 12).foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                Image("pin")
                                    .renderingMode(.template).resizable().scaledToFit()
                                    .foregroundStyle(.white).frame(width: 18, height: 18)
                            }
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 5) {
                            if note.isPinned && !isCollapsed { stickyBadge(text: "PINNED") }
                            ForEach(displayedBadges, id: \.self) { badge in stickyBadge(text: badge) }
                        }
                        .frame(maxWidth: 92, alignment: .trailing)
                        .layoutPriority(0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if previewText == "Empty note" && displayedListItems.isEmpty && displayedChecklistItems.isEmpty {
                            Text(previewText)
                                .font(NoteFontOption.option(for: note.fontID).font(size: cardFontSize, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.60))
                                .lineLimit(2)
                        } else {
	                            if !cardContent.isEmpty {
	                                Text(cardContent)
	                                    .font(NoteFontOption.option(for: note.fontID).font(size: cardFontSize, weight: .medium))
	                                    .foregroundStyle(Color.black.opacity(0.82))
	                                    .lineSpacing(2)
	                                    .lineLimit(cardTextLineLimit)
	                            }

	                            if !displayedListItems.isEmpty {
	                                NoteListDisplay(
	                                    items: displayedListItems,
	                                    font: NoteFontOption.option(for: note.fontID),
	                                    textColor: Color.black.opacity(0.82),
	                                    markerSize: 16,
	                                    textSize: max(10, cardFontSize - 1),
	                                    lineLimit: 1,
	                                    rowSpacing: 5
	                                )
	                            }

	                            if !displayedChecklistItems.isEmpty {
                                NoteChecklistInteractiveDisplay(
                                    items: displayedChecklistItems,
                                    font: NoteFontOption.option(for: note.fontID),
                                    textColor: Color.black.opacity(0.82),
                                    circleSize: 16,
                                    textSize: max(10, cardFontSize - 1),
                                    lineLimit: 1,
                                    rowSpacing: 5,
                                    onToggle: { item in
                                        onToggleChecklistItem(item)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: cardPreviewMaxHeight, alignment: .topLeading)
                    .clipped()
                    .layoutPriority(1)

                }
                .padding(.top, 14)
                .padding(.horizontal, 14)
                .padding(.bottom, note.isPinned && isCollapsed ? 14 : 46)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if !(note.isPinned && isCollapsed) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created: \(shortDateTime(note.createdAt))")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.black.opacity(0.55))
                        Text("Updated: \(shortDateTime(note.updatedAt))")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.black.opacity(0.55))
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: cardHeight, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .gesture(
            TapGesture().onEnded {
                action()
            },
            including: .gesture
        )
        .contextMenu {
            Menu("Move to Tab") {
                ForEach(availableTabs, id: \.self) { tab in
                    Button(tab) {
                        onMoveToTab(tab)
                    }
                }
            }

            Divider()

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }


    private var previewText: String {
        let cleaned = note.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Empty note" : cleaned
    }

    private var stickyFill: AnyShapeStyle {
        if usesGradient {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [stickyColor, secondaryStickyColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(stickyColor)
    }

    private var cardContent: String {
        note.contentWithoutListPlacementTokens
    }

    private var displayedListItems: [NoteListItem] {
        Array(note.listItems.prefix(listPreviewLimit))
    }

    private var listPreviewLimit: Int {
        if note.isPinned && isCollapsed { return 1 }
        if cardContent.isEmpty { return 3 }
        return 2
    }

    private var displayedChecklistItems: [NoteChecklistItem] {
        Array(note.checklistItems.prefix(checklistPreviewLimit))
    }

    private var checklistPreviewLimit: Int {
        if note.isPinned && isCollapsed { return 1 }
        if cardContent.isEmpty { return 3 }
        return 2
    }

    private var cardTextLineLimit: Int {
        if !displayedListItems.isEmpty || !displayedChecklistItems.isEmpty {
            return note.isPinned && isCollapsed ? 1 : 3
        }
        return previewLineLimit
    }

    private var cardPreviewMaxHeight: CGFloat {
        note.isPinned && isCollapsed ? 34 : 68
    }

    private var displayedBadges: [String] {
        let labelBadges = note.activeLabels.map { $0.uppercased() }
        if note.isPinned && isCollapsed { return Array(labelBadges.prefix(2)) }
        return labelBadges
    }

    private func stickyBadge(text: String) -> some View {
        let isCollapsedPinned = note.isPinned && isCollapsed
        let fontSize: CGFloat = isCollapsedPinned ? 8 : 9
        let horizontalPadding: CGFloat = isCollapsedPinned ? 6 : 7
        let verticalPadding: CGFloat = isCollapsedPinned ? 2 : 3
        return Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .allowsTightening(true)
            .frame(maxWidth: 78, alignment: .center)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.14))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
            )
    }

    private func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Filter Enum

private enum NotesFilter: String, CaseIterable, Identifiable {
    case all, pinned, recent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .pinned: return "Pinned"
        case .recent: return "Recent"
        }
    }
}

#Preview {
    NotesView()
}

// MARK: - Tab Popup Mode

private enum TabPopupMode {
    case create
    case rename
}

// MARK: - Cursor-Aware Editor

final class NotesCursorInserter {
    static let shared = NotesCursorInserter()
    private init() {}
    weak var textView: UITextView?

    func insert(_ text: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if tv.textStorage.length == 0 {
            tv.text = text
        } else {
            tv.textStorage.replaceCharacters(in: range, with: text)
            tv.selectedRange = NSRange(location: range.location + (text as NSString).length, length: 0)
        }
        tv.delegate?.textViewDidChange?(tv)
    }
}

struct NotesCursorAwareEditor: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textColor = UIColor(LColors.textPrimary)
        tv.font = .systemFont(ofSize: 15)
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NotesCursorInserter.shared.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
        if text.isEmpty { tv.textColor = UIColor(LColors.textPrimary) }
        NotesCursorInserter.shared.textView = tv
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NotesCursorAwareEditor
        init(_ parent: NotesCursorAwareEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}

    private func viewerSheetDetents(for note: Note) -> Set<PresentationDetent> {
        let characterCount = note.trimmedContent.count
        let labelCount = note.activeLabels.count

        if characterCount <= 140 && labelCount <= 2 {
            return [.height(520), .large]
        }

        if characterCount <= 360 {
            return [.height(640), .large]
        }

        return [.large]
    }
