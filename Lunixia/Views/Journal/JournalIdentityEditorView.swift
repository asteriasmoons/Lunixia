//
//  JournalIdentityEditorView.swift
//  Lunixia
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Preview
// Read-only journal identity header. No glass card background — designed to be embedded
// inside the journal paged content/card structure.

struct JournalIdentityEditorPreviewView: View {
    let entry: JournalEntry
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var coverMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : .infinity
    }

    private var coverHeight: CGFloat {
        horizontalSizeClass == .regular ? 240 : 200
    }

    private var coverImageScale: CGFloat {
        horizontalSizeClass == .regular ? 0.92 : 1.0
    }

    private var resolvedTitleColor: Color {
        let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hex.isEmpty,
              let r = UInt8(hex.prefix(2), radix: 16),
              let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16)
        else { return .white }
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image — only rendered when data exists, sits inside the card
            if let data = entry.coverImageData, let uiImage = UIImage(data: data) {
                coverImageView(uiImage)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 14)
            }

            // Title
            if !entry.title.isEmpty {
                Text(entry.title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(resolvedTitleColor)
                    .lineSpacing(2)
                    .padding(.horizontal, 20)
                    .padding(.top, entry.coverImageData == nil ? 20 : 0)
                    .padding(.bottom, 10)
            }

            // Tags
            if !entry.tags.isEmpty {
                TagFlowLayout(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }

            // Separator before content
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func coverImageView(_ uiImage: UIImage) -> some View {
        let offset = entry.coverImageVerticalOffset
        GeometryReader { geo in
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(coverImageScale)
                .offset(y: offset * 30)
                .clipped()
        }
        .frame(maxWidth: coverMaxWidth)
        .frame(height: coverHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 6) {
            Image("tagsparkle")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.white)
            Text(tag)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(LColors.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
    }
}

// MARK: - Editor (editable title + tags + cover picker)
// No glass card — embedded inside JournalBlockEditorView's first page card.

struct JournalIdentityEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let entry: JournalEntry

    @Binding var pageTitleDraft: String
    @Binding var pageTagsDraft: String

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showRemoveCoverConfirm = false

    private var coverMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : .infinity
    }

    private var coverHeight: CGFloat {
        horizontalSizeClass == .regular ? 240 : 200
    }

    private var coverImageScale: CGFloat {
        horizontalSizeClass == .regular ? 0.92 : 1.0
    }

    private var resolvedTitleColor: Color {
        let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hex.isEmpty,
              let r = UInt8(hex.prefix(2), radix: 16),
              let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16)
        else { return .white }
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Entry date + time — custom picker, matches the entry's text tint
            JournalEntryDateTimePicker(
                date: Binding(
                    get: { entry.createdAt },
                    set: { newValue in
                        entry.createdAt = newValue
                        entry.touch()
                        try? modelContext.save()
                    }
                ),
                tint: resolvedTitleColor
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Body font picker — custom dropdown, matches the entry's text tint
            JournalBodyFontPicker(
                selectedPostScriptName: Binding(
                    get: { entry.bodyFontName },
                    set: { newValue in
                        entry.bodyFontName = newValue
                        entry.touch()
                        try? modelContext.save()
                    }
                ),
                tint: resolvedTitleColor
            )
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 4)

            // Body font size stepper — minuswavy | current pt | addwavy
            JournalBodyFontSizePicker(
                sizeOffset: Binding(
                    get: { entry.bodyFontSizeOffset },
                    set: { newValue in
                        entry.bodyFontSizeOffset = newValue
                        entry.touch()
                        try? modelContext.save()
                    }
                ),
                tint: resolvedTitleColor
            )
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 4)

            // Cover image editor zone
            if let data = entry.coverImageData, let uiImage = UIImage(data: data) {
                coverEditorView(uiImage)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
            } else {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 12, weight: .medium))
                        Text("Add cover")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }

            // Title field — bare, no card
            TextField("Untitled", text: $pageTitleDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(resolvedTitleColor)
                .lineSpacing(2)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .onChange(of: pageTitleDraft) {
                    entry.title = pageTitleDraft
                    entry.touch()
                    try? modelContext.save()
                }

            // Tags — show chips for existing tags, then editable field below
            if !entry.tags.isEmpty {
                TagFlowLayout(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Image("tagsparkle")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(resolvedTitleColor)

                            Text(tag)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(resolvedTitleColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(resolvedTitleColor.opacity(0.55), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            // Tags edit field
            HStack(spacing: 4) {
                Text("#")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(resolvedTitleColor)
                TextField(entry.tags.isEmpty ? "tags, comma separated" : "edit tags...", text: $pageTagsDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(resolvedTitleColor.opacity(0.75))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: pageTagsDraft) {
                        let parsed = pageTagsDraft
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        entry.tags = parsed
                        entry.touch()
                        try? modelContext.save()
                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
        }
        .onChange(of: selectedPhoto) {
            Task {
                guard let item = selectedPhoto else { return }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    entry.coverImageData = data
                    entry.coverImageVerticalOffset = 0.0
                    entry.touch()
                    try? modelContext.save()
                }
                selectedPhoto = nil
            }
        }
        .confirmationDialog("Remove cover image?", isPresented: $showRemoveCoverConfirm, titleVisibility: .visible) {
            Button("Remove Cover", role: .destructive) {
                entry.coverImageData = nil
                entry.coverImageVerticalOffset = 0.0
                entry.touch()
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func coverEditorView(_ uiImage: UIImage) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Menu {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Change Cover", systemImage: "photo")
                }
                Button {
                    entry.coverImageVerticalOffset = -1.0
                    entry.touch()
                    try? modelContext.save()
                } label: {
                    Label("Show Top", systemImage: "arrow.up.to.line")
                }
                Button {
                    entry.coverImageVerticalOffset = 0.0
                    entry.touch()
                    try? modelContext.save()
                } label: {
                    Label("Show Center", systemImage: "square.split.1x2")
                }
                Button {
                    entry.coverImageVerticalOffset = 1.0
                    entry.touch()
                    try? modelContext.save()
                } label: {
                    Label("Show Bottom", systemImage: "arrow.down.to.line")
                }
                Divider()
                Button(role: .destructive) {
                    showRemoveCoverConfirm = true
                } label: {
                    Label("Remove Cover", systemImage: "trash")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Edit")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .padding(10)
        }
    }
}
