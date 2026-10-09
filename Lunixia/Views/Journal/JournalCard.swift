//
//  JournalCard.swift
//  Lunixia
//

import SwiftUI
import SwiftData

struct JournalCard: View {
    @Environment(\.appTheme) private var theme

    let entry: JournalEntry
    let onView: (JournalEntry) -> Void
    let onTagSelect: (String) -> Void
    var onMove: ((JournalEntry, JournalBook) -> Void)? = nil
    var moveableBooks: [JournalBook] = []

    @State private var showMoveSheet = false

    private var snippet: String {
        entry.preferredCardPreviewText
    }

    private var dateLabel: String {
        entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }

    var body: some View {
        Button { onView(entry) } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        Spacer()
                        Text(dateLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }

                    if !snippet.isEmpty {
                        Text(snippet)
                            .font(.system(size: 14))
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(3)
                    }

                    if !entry.tags.isEmpty {
                        TagFlowLayout(spacing: 8) {
                            ForEach(entry.tags.indices, id: \.self) { index in
                                let tag = entry.tags[index]
                                let tint = theme.palette.rotation[index % theme.palette.rotation.count]

                                Button { onTagSelect(tag) } label: {
                                    Text("#\(tag)")
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                        .foregroundStyle(.white)
                                        .shadow(color: .black, radius: 2, y: 1)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background {
                                            BubblyIconMaterial(tint: tint)
                                                .clipShape(Capsule())
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onMove != nil {
                Menu("Move to Book") {
                    ForEach(moveableBooks, id: \.persistentModelID) { book in
                        Button(book.title) {
                            onMove?(entry, book)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let e = JournalEntry(
        title: "A day in the mountains",
        bodyAttributedText: NSAttributedString(string: "It was peaceful and calm..."),
        tags: ["dev", "family", "health"]
    )
    ZStack {
        LunixiaBackground()
        JournalCard(entry: e, onView: { _ in }, onTagSelect: { _ in })
            .padding()
    }
}
