//
//  JournalEntryWriter.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/13/26.
//

import SwiftData
import Foundation

enum JournalEntryWriter {

    static func saveEntry(
        title: String,
        content: String,
        tags: [String],
        book: JournalBook,
        modelContext: ModelContext
    ) throws -> JournalEntry {

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { String($0.drop(while: { $0 == "#" })) }
            .filter { !$0.isEmpty }

        let attributed = NSAttributedString(string: cleanedContent)

        let entry = JournalEntry(
            title: cleanedTitle,
            bodyAttributedText: attributed,
            tags: cleanedTags,
            book: book
        )

        let bodyBlock = JournalBlock(
            type: .paragraph,
            text: cleanedContent,
            sortOrder: 0
        )
        bodyBlock.entry = entry
        entry.blocks = [bodyBlock]
        entry.updatedAt = Date()

        modelContext.insert(entry)
        modelContext.insert(bodyBlock)

        try modelContext.save()

        return entry
    }
}
