import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct LunixiaConversationComposer: View {
    @Environment(\.appTheme) private var theme
    @Binding var draft: String
    let isEnabled: Bool
    let isSending: Bool
    var disabledMessage = "Waiting for Voxiverse to send the first message…"
    let onSend: (String, [LunixiaConversationAttachment]) -> Bool

    @State private var isExpanded = false
    @State private var showingAttachmentMenu = false
    @State private var showingPhotos = false
    @State private var showingFiles = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachments: [LunixiaConversationAttachment] = []
    @State private var attachmentError: String?
    @FocusState private var isDraftFocused: Bool

    private var canSend: Bool {
        isEnabled && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if isEnabled {
                    TextEditor(text: $draft)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.text.primary)
                        .tint(LColors.accents.contrast)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                        .focused($isDraftFocused)
                        .padding(.leading, 10)
                        .padding(.trailing, 44)
                        .padding(.vertical, 7)

                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Reply to Voxiverse…")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.text.secondary.opacity(0.75))
                            .padding(.leading, 16)
                            .padding(.top, 15)
                            .allowsHitTesting(false)
                    }
                } else {
                    Text(disabledMessage)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                        .padding(.trailing, 54)
                        .padding(.top, 15)
                }

                HStack(spacing: 2) {
                    Button { isExpanded = true } label: {
                        icon("expand", tint: LColors.accents.contrast, size: 23)
                            .frame(width: 42, height: 42)
                            .contentShape(Rectangle())
                    }
                    .disabled(!isEnabled)
                    .opacity(isEnabled ? 1 : 0.45)
                    .accessibilityLabel("Expand message editor")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.trailing, 8)
                .padding(.top, 5)
            }
            .frame(height: 74)

            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            HStack(spacing: 6) {
                                Text(attachment.name).lineLimit(1)
                                Button {
                                    attachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    icon("xmarkwavy", tint: LColors.accents.primary, size: 12)
                                }
                                .disabled(!isEnabled)
                                .accessibilityLabel("Remove \(attachment.name)")
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(LColors.text.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(LColors.surface.nested, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }

            Rectangle()
                .fill(LColors.text.primary.opacity(0.17))
                .frame(height: 1)
                .padding(.horizontal, 12)

            HStack {
                Button {
                    showingAttachmentMenu = true
                } label: {
                    icon("attach", tint: LColors.accents.primary, size: 29)
                        .frame(width: 42, height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.45)
                .accessibilityLabel("Add attachment")
                .popover(isPresented: $showingAttachmentMenu, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        attachmentMenuButton("Gallery") {
                            showingAttachmentMenu = false
                            showingPhotos = true
                        }
                        attachmentMenuButton("Files") {
                            showingAttachmentMenu = false
                            showingFiles = true
                        }
                    }
                    .padding(8)
                    .background(LColors.surface.elevated)
                    .presentationCompactAdaptation(.popover)
                }

                Spacer(minLength: 0)

                Button(action: sendDraft) {
                    icon("send", tint: LColors.accents.secondary, size: 28)
                        .frame(width: 42, height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 11)
            .frame(height: 58)
        }
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LColors.surface.elevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(theme.palette.primaryAction, lineWidth: 1.2)
        }
        .sheet(isPresented: $isExpanded) { expandedEditor }
        .photosPicker(isPresented: $showingPhotos, selection: $selectedPhotos, maxSelectionCount: 3, matching: .images)
        .onChange(of: selectedPhotos) { _, items in
            Task { await loadPhotos(items) }
        }
        .fileImporter(isPresented: $showingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            loadFiles(result)
        }
        .alert("Attachment Error", isPresented: Binding(
            get: { attachmentError != nil },
            set: { if !$0 { attachmentError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(attachmentError ?? "")
        }
    }

    private func icon(_ name: String, tint: Color, size: CGFloat) -> some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
            .bubblyIconMaterial(tint: tint)
    }

    private func attachmentMenuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.text.primary)
                .frame(minWidth: 120, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expandedEditor: some View {
        VStack(spacing: 0) {
            HStack {
                Button { isExpanded = false } label: {
                    icon("xmarkwavy", tint: LColors.accents.secondary, size: 24)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close message editor")

                Spacer()

                Text("Message")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.text.primary)

                Spacer()

                Button {
                    sendDraft()
                    isExpanded = false
                } label: {
                    icon("send", tint: LColors.accents.secondary, size: 24)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            TextEditor(text: $draft)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.text.primary)
                .tint(LColors.accents.contrast)
                .scrollContentBackground(.hidden)
                .padding(16)
                .background(LColors.surface.primary)
        }
        .background(LColors.surface.primary)
        .presentationDetents([.large])
    }

    private func sendDraft() {
        guard canSend else { return }
        let message = draft
        let selectedAttachments = attachments
        if onSend(message, selectedAttachments) {
            draft = ""
            attachments = []
        }
    }

    private func addAttachment(name: String, typeIdentifier: String, data: Data) {
        guard attachments.count < 3 else {
            attachmentError = "You can attach up to three items to a message."
            return
        }
        do {
            let prepared = try ConversationImageOptimizer.prepare(data: data, name: name, typeIdentifier: typeIdentifier)
            guard prepared.data.count <= ConversationImageOptimizer.maximumAttachmentBytes else {
                attachmentError = "Files must be 10 MB or smaller."
                return
            }
            attachments.append(LunixiaConversationAttachment(
                name: prepared.name,
                typeIdentifier: prepared.typeIdentifier,
                data: prepared.data
            ))
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let type = item.supportedContentTypes.first ?? .image
                let ext = type.preferredFilenameExtension ?? "jpg"
                addAttachment(name: "Photo \(attachments.count + 1).\(ext)", typeIdentifier: type.identifier, data: data)
            } catch {
                attachmentError = error.localizedDescription
            }
        }
        selectedPhotos = []
    }

    private func loadFiles(_ result: Result<[URL], Error>) {
        do {
            for url in try result.get() {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let resourceType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
                let extensionType = UTType(filenameExtension: url.pathExtension)
                let type = resourceType?.conforms(to: .image) == true
                    ? (resourceType ?? .image)
                    : (extensionType ?? resourceType ?? .data)
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                let sourceLimit = type.conforms(to: .image)
                    ? ConversationImageOptimizer.maximumSourceImageBytes
                    : ConversationImageOptimizer.maximumAttachmentBytes
                guard size <= sourceLimit else {
                    attachmentError = type.conforms(to: .image)
                        ? "This image is too large to process."
                        : "Files must be 10 MB or smaller."
                    continue
                }
                addAttachment(name: url.lastPathComponent, typeIdentifier: type.identifier, data: try Data(contentsOf: url))
            }
        } catch {
            attachmentError = error.localizedDescription
        }
    }
}
