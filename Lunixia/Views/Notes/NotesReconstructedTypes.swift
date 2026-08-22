//
//  NotesReconstructedTypes.swift
//  Lunixia
//
//  Reconstructed types after the accidental revert wiped Codex's originals.
//  The struct definitions for NoteListTypeEditorSheet and GlassRichTextEditor
//  were never committed to git and could not be recovered from the object DB.
//  These implementations match the API surface NotesView expects so the
//  build succeeds and the surrounding editor flow behaves correctly.
//
//  They intentionally use the original LColors / LGradients theme.
//

import SwiftUI
import UIKit

// MARK: - NoteListTypeEditorSheet
//
// Full-screen sheet that edits a single list type (bullets, checklist, or
// numbered). Ported the row-editing UI from the original in-line editor
// (previously part of `NoteListTypesEditor`) so item editing is fully
// functional. Adds `onAddGroup(type, group)` support for grouped lists.

struct NoteListTypeEditorSheet: View {
    let type: NoteListPlacementType
    @Binding var listItems: [NoteListItem]
    @Binding var checklistItems: [NoteChecklistItem]
    @Binding var fontID: String
    @Binding var fontSize: Double
    var onAddGroup: (NoteListPlacementType, Int) -> Void
    var onClose: () -> Void

    @FocusState private var focusedListItemID: UUID?
    @FocusState private var focusedChecklistItemID: UUID?

    private var font: NoteFontOption {
        NoteFontOption.option(for: fontID)
    }

    private var fontSizeCG: CGFloat { CGFloat(fontSize) }

    private var typeIconAsset: String {
        switch type {
        case .bullets:   return "linedpages"
        case .checklist: return "checkwavy"
        case .numbers:   return "linedpages"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LunixiaBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        addItemChip

                        if isEmpty {
                            GlassCardNote {
                                emptyState
                            }
                        } else {
                            grouped
                        }

                        addGroupButton
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: Header (matches listTypesHelpSheet pattern)

    private var header: some View {
        HStack(spacing: 10) {
            Image(typeIconAsset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(LGradients.header)

            Text(type.title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)

            Spacer()

            Button {
                onClose()
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
    }

    private var addItemChip: some View {
        Button {
            addItemToCurrentGroup()
        } label: {
            HStack(spacing: 8) {
                Image("addwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.white)

                Text("Add \(type.title.lowercased()) item")
                    .font(font.font(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        Text("No \(type.title.lowercased()) items yet. Tap the button above to add one.")
            .font(font.font(size: 13))
            .foregroundStyle(Color.white.opacity(0.72))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addGroupButton: some View {
        Button {
            let next = (currentGroups.max() ?? 0) + 1
            switch type {
            case .bullets:
                listItems.append(NoteListItem(kind: .bullet, group: next))
            case .checklist:
                checklistItems.append(NoteChecklistItem(group: next))
            case .numbers:
                listItems.append(NoteListItem(kind: .numbered, group: next))
            }
            onAddGroup(type, next)
        } label: {
            HStack(spacing: 8) {
                Image("addwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.white)
                Text("Add new group")
                    .font(font.font(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Grouped rows — each group is its own GlassCardNote

    @ViewBuilder
    private var grouped: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(currentGroups, id: \.self) { group in
                GlassCardNote {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Group \(group)")
                            .font(font.font(size: 11, weight: .black))
                            .foregroundStyle(Color.white.opacity(0.68))

                        switch type {
                        case .bullets:
                            listRows(kind: .bullet, group: group)
                        case .numbers:
                            listRows(kind: .numbered, group: group)
                        case .checklist:
                            checklistRows(group: group)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func listRows(kind: NoteListItemKind, group: Int) -> some View {
        let indices = listItems.indices.filter {
            listItems[$0].kind == kind && listItems[$0].group == group
        }
        ForEach(indices, id: \.self) { index in
            HStack(alignment: .top, spacing: 9) {
                NoteListMarker(
                    kind: listItems[index].kind,
                    number: number(for: listItems[index]),
                    size: 24,
                    textColor: .white
                )
                .padding(.top, 9)

                NotesGradientDoneTextView(
                    placeholder: "List item",
                    text: $listItems[index].title,
                    fontOption: font,
                    fontSize: fontSizeCG,
                    minHeight: 42,
                    verticallyCentersText: true,
                    growsWithContent: true
                )
                .padding(.horizontal, 10)
                .frame(minHeight: 42, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )

                removeButton {
                    let id = listItems[index].id
                    listItems.removeAll { $0.id == id }
                }
            }
        }
    }

    @ViewBuilder
    private func checklistRows(group: Int) -> some View {
        let visible = checklistItems.enumerated().filter { $0.element.group == group }
        ForEach(visible, id: \.element.id) { pair in
            let index = pair.offset
            HStack(alignment: .top, spacing: 9) {
                Button {
                    checklistItems[index].isCompleted.toggle()
                } label: {
                    NoteChecklistCircle(isCompleted: checklistItems[index].isCompleted, size: 24)
                }
                .buttonStyle(.plain)
                .padding(.top, 9)

                NotesGradientDoneTextView(
                    placeholder: "Checklist item",
                    text: $checklistItems[index].title,
                    fontOption: font,
                    fontSize: fontSizeCG,
                    textColor: UIColor.white.withAlphaComponent(checklistItems[index].isCompleted ? 0.70 : 1),
                    minHeight: 42,
                    verticallyCentersText: true,
                    growsWithContent: true
                )
                .opacity(checklistItems[index].isCompleted ? 0.70 : 1)
                .padding(.horizontal, 10)
                .frame(minHeight: 42, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )

                removeButton {
                    let id = checklistItems[index].id
                    checklistItems.removeAll { $0.id == id }
                }
            }
        }
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image("xmarkwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove item")
    }

    // MARK: Helpers

    private var isEmpty: Bool {
        currentGroups.isEmpty
    }

    private var currentGroups: [Int] {
        let raw: [Int]
        switch type {
        case .bullets:
            raw = listItems.filter { $0.kind == .bullet }.map { $0.group }
        case .checklist:
            raw = checklistItems.map { $0.group }
        case .numbers:
            raw = listItems.filter { $0.kind == .numbered }.map { $0.group }
        }
        return Array(Set(raw)).sorted()
    }

    private func addItemToCurrentGroup() {
        let group = currentGroups.max() ?? 1
        switch type {
        case .bullets:
            let item = NoteListItem(kind: .bullet, group: group)
            listItems.append(item)
            focusedListItemID = item.id
        case .checklist:
            let item = NoteChecklistItem(group: group)
            checklistItems.append(item)
            focusedChecklistItemID = item.id
        case .numbers:
            let item = NoteListItem(kind: .numbered, group: group)
            listItems.append(item)
            focusedListItemID = item.id
        }
    }

    private func number(for item: NoteListItem) -> Int {
        let numbered = listItems
            .filter { $0.kind == .numbered && $0.group == item.group }
        return (numbered.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
    }
}

// MARK: - GlassRichTextEditor
//
// Reconstructed rich-text editor. It keeps the AttributedString binding so
// token styling from NotesView renders inside the editable note body.

struct GlassRichTextEditor: View {
    let placeholder: String
    @Binding var text: AttributedString
    var minHeight: CGFloat = 210
    @Binding var placeholderFontID: String
    @Binding var placeholderFontSize: Double

    private var currentFont: Font {
        NoteFontOption.option(for: placeholderFontID)
            .font(size: CGFloat(placeholderFontSize))
    }

    var body: some View {
        // White translucent glass tile with a subtle white hairline —
        // matches the other note input fields. No gradient border,
        // because notes are user-defined in color.
        // Placeholder is aligned to sit exactly where TextEditor draws
        // its first character (matches TextEditor's default text
        // container inset of ~5pt on top and ~5pt on the leading edge).
        ZStack(alignment: .topLeading) {
            if String(text.characters).isEmpty {
                Text(placeholder)
                    .font(currentFont)
                    .foregroundStyle(Color.white.opacity(0.48))
                    .padding(.leading, 17)
                    .padding(.top, 13)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(currentFont)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: minHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.38), lineWidth: 1.25)
        )
    }
}
