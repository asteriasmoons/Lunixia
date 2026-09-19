//
//  AddJournalEntryShortcutIntent.swift
//  Lunixia
//

import AppIntents
import Foundation
import SwiftData

struct AddJournalEntryShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Journal Entry"
    static var description = IntentDescription("Add a journal entry to a selected Lunixia journal book.")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Journal Book",
        requestValueDialog: IntentDialog("Which journal book should this entry go in?"),
        requestDisambiguationDialog: IntentDialog("Choose a journal book."),
        query: JournalBookShortcutQuery()
    )
    var book: JournalBookShortcutEntity

    @Parameter(
        title: "Entry Title",
        inputOptions: String.IntentInputOptions(
            capitalizationType: .words,
            autocorrect: true,
            smartQuotes: true,
            smartDashes: true
        ),
        requestValueDialog: IntentDialog("What should this journal entry be named?")
    )
    var title: String

    @Parameter(
        title: "Entry",
        inputOptions: String.IntentInputOptions(
            capitalizationType: .sentences,
            multiline: true,
            autocorrect: true,
            smartQuotes: true,
            smartDashes: true
        ),
        requestValueDialog: IntentDialog("What do you want to write?")
    )
    var entryText: String

    @Parameter(
        title: "Tags",
        default: ""
    )
    var tags: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) to \(\.$book)") {
            \.$entryText
            \.$tags
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEntryText = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedTags = Self.parseTags(tags)

        guard !cleanedTitle.isEmpty else {
            return .result(dialog: IntentDialog("Please enter a journal entry title."))
        }

        guard !cleanedEntryText.isEmpty else {
            return .result(dialog: IntentDialog("Please enter journal entry text."))
        }

        let result = try await MainActor.run {
            let context = ModelContext(LunixiaApp.sharedModelContainer)
            guard let journalBook = try JournalBookShortcutQuery.fetchBook(
                id: book.id,
                in: context
            ) else {
                return AddJournalEntryResult.missingBook
            }

            let createdEntry = try JournalEntryWriter.saveEntry(
                title: cleanedTitle,
                content: cleanedEntryText,
                tags: parsedTags,
                book: journalBook,
                modelContext: context
            )

            let entryID = String(createdEntry.persistentModelID.hashValue)
            _ = try? LunixiaPointsManager.awardJournalEntry(
                in: context,
                id: entryID,
                title: cleanedTitle,
                at: createdEntry.createdAt
            )
            _ = try? LunixiaPointsManager.awardMindfulMinutes(
                in: context,
                entryId: entryID,
                minutes: 1,
                at: createdEntry.createdAt
            )

            let session = MindfulSession(
                entryPersistentID: entryID,
                bookPersistentID: journalBook.persistentModelID.hashValue.description,
                minutes: 1,
                tags: parsedTags,
                date: createdEntry.createdAt
            )
            context.insert(session)
            try context.save()

            return AddJournalEntryResult.created(bookTitle: journalBook.title, createdAt: createdEntry.createdAt)
        }

        switch result {
        case .created(let bookTitle, let createdAt):
            await HealthKitManager.shared.addMindfulMinutesForJournalEntry(minutes: 1, at: createdAt)
            return .result(dialog: IntentDialog("Added \(cleanedTitle) to \(bookTitle)."))
        case .missingBook:
            return .result(dialog: IntentDialog("That journal book could not be found."))
        }
    }

    private static func parseTags(_ rawTags: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n")
        let pieces = rawTags.components(separatedBy: separators)
        var seen = Set<String>()

        return pieces.compactMap { piece in
            let cleaned = String(
                piece
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .drop(while: { $0 == "#" })
            )
            guard !cleaned.isEmpty else { return nil }

            let key = cleaned.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
    }
}

private enum AddJournalEntryResult {
    case created(bookTitle: String, createdAt: Date)
    case missingBook
}

struct JournalBookShortcutEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Journal Book")
    static var defaultQuery = JournalBookShortcutQuery()

    let id: UUID
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct JournalBookShortcutQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [JournalBookShortcutEntity] {
        try await MainActor.run {
            try Self.fetchActiveBooks(in: ModelContext(LunixiaApp.sharedModelContainer))
                .filter { identifiers.contains($0.uuid) }
                .map(JournalBookShortcutEntity.init(book:))
        }
    }

    func suggestedEntities() async throws -> [JournalBookShortcutEntity] {
        try await MainActor.run {
            try Self.fetchActiveBooks(in: ModelContext(LunixiaApp.sharedModelContainer))
                .map(JournalBookShortcutEntity.init(book:))
        }
    }

    func entities(matching string: String) async throws -> [JournalBookShortcutEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await MainActor.run {
            let books = try Self.fetchActiveBooks(in: ModelContext(LunixiaApp.sharedModelContainer))
            guard !query.isEmpty else {
                return books.map(JournalBookShortcutEntity.init(book:))
            }

            return books
                .filter { $0.title.localizedCaseInsensitiveContains(query) }
                .map(JournalBookShortcutEntity.init(book:))
        }
    }

    func defaultResult() async -> JournalBookShortcutEntity? {
        await MainActor.run {
            try? Self.fetchActiveBooks(in: ModelContext(LunixiaApp.sharedModelContainer))
                .first
                .map(JournalBookShortcutEntity.init(book:))
        }
    }

    @MainActor
    static func fetchBook(id: UUID, in context: ModelContext) throws -> JournalBook? {
        try fetchActiveBooks(in: context)
            .first { $0.uuid == id }
    }

    @MainActor
    private static func fetchActiveBooks(in context: ModelContext) throws -> [JournalBook] {
        let descriptor = FetchDescriptor<JournalBook>(
            predicate: #Predicate<JournalBook> { $0.deletedAt == nil },
            sortBy: [
                SortDescriptor(\.pinOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        let books = try context.fetch(descriptor)

        var seen = Set<UUID>()
        var repairedDuplicateUUIDs = false
        for book in books {
            if seen.contains(book.uuid) {
                book.uuid = UUID()
                book.updatedAt = Date()
                repairedDuplicateUUIDs = true
            }
            seen.insert(book.uuid)
        }

        if repairedDuplicateUUIDs {
            try context.save()
        }

        return books.sorted {
            let lhsPinned = $0.pinOrder > 0
            let rhsPinned = $1.pinOrder > 0

            if lhsPinned != rhsPinned {
                return lhsPinned
            }
            if lhsPinned && rhsPinned, $0.pinOrder != $1.pinOrder {
                return $0.pinOrder < $1.pinOrder
            }
            return $0.createdAt > $1.createdAt
        }
    }
}

private extension JournalBookShortcutEntity {
    init(book: JournalBook) {
        self.id = book.uuid
        self.title = book.title.isEmpty ? "Untitled Journal" : book.title
    }
}
