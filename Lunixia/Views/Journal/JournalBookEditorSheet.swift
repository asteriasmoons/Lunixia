//
//  JournalBookEditorSheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/3/26.
//

import SwiftUI
import SwiftData

struct JournalBookEditorSheet: View {
    @Environment(\.modelContext) private var modelContext

    let book: JournalBook?
    var onClose: (() -> Void)? = nil

    @State private var title: String = ""
    @State private var coverColor: Color = Color(lunixiaHex: "#6A5CFF")

    private var closeAction: () -> Void {
        onClose ?? {}
    }

    var body: some View {
        LunixiaPopup(
            onClose: {
                closeAction()
            },
            width: 640,
            heightRatio: 0.78,
            header: {
                HStack {
                    Text(book != nil ? "Edit Book" : "New Book")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Button { closeAction() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TITLE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    TextField("Book title", text: $title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .tint(LColors.gradientBlue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                                .fill(LColors.glassSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: LSpacing.inputRadius, style: .continuous)
                                        .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                )
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("COVER COLOR")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    GlassCard {
                        HStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(coverColor)
                                .frame(width: 48, height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))

                            ColorPicker("Choose color", selection: $coverColor, supportsOpacity: false)
                                .foregroundStyle(LColors.textPrimary)

                            Spacer()
                        }
                    }
                }
            },
            footer: {
                Button { saveBook() } label: {
                    Text(book != nil ? "Save Changes" : "Create Book")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(title.trimmed.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LGradients.blue))
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        .shadow(color: title.trimmed.isEmpty ? .clear : LColors.accent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(title.trimmed.isEmpty)
            }
        )
        .onAppear {
            if let book {
                title = book.title
                coverColor = Color(lunixiaHex: book.coverHex)
            }
        }
    }

    private func saveBook() {
        let t = title.trimmed
        guard !t.isEmpty else { return }

        let hex = coverColor.toHex() ?? "#6A5CFF"

        if let book {
            book.title = t
            book.coverHex = hex
            book.updatedAt = Date()
        } else {
            let newBook = JournalBook(title: t, coverHex: hex)
            newBook.updatedAt = Date()
            modelContext.insert(newBook)
        }

        closeAction()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    // In-memory SwiftData container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: JournalBook.self, configurations: config)

    // Seed a sample book
    let ctx = container.mainContext
    let sampleBook = JournalBook(title: "General Journal", coverHex: "#6A5CFF")
    ctx.insert(sampleBook)

    return JournalBookEditorSheet(book: sampleBook)
        .modelContainer(container)
}
