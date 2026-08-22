//
//  LunixiaStickyNoteWidgetWriter.swift
//  Lunixia
//

import Foundation
import SwiftData
import WidgetKit

struct LunixiaStickyNoteWidgetChecklistItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    /// Which placement group this item belongs to. Group 1 is the original single list.
    var group: Int = 1
}

struct LunixiaStickyNoteWidgetListItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var kind: String
    /// Which placement group this item belongs to. Group 1 is the original single list.
    var group: Int = 1
}

struct LunixiaStickyNoteWidgetNote: Codable, Identifiable, Equatable {
    var id: UUID
    var content: String
    var colorHex: String
    var secondaryColorHex: String
    var usesGradient: Bool
    var checklistItems: [LunixiaStickyNoteWidgetChecklistItem]
    var listItems: [LunixiaStickyNoteWidgetListItem]
    var fontID: String
    var tabName: String
    var label: String
    var label2: String
    var isPinned: Bool
    var updatedAt: Date
}

struct LunixiaStickyNoteWidgetSnapshot: Codable, Equatable {
    var tabs: [String]
    var notes: [LunixiaStickyNoteWidgetNote]
    var lastUpdated: Date
}

enum LunixiaStickyNoteWidgetWriter {
    private static let widgetDefaults = UserDefaults(suiteName: "group.com.asteriasmoons.Lunixia")
    private static let snapshotKey = "lunixiaStickyNoteWidgetSnapshot"
    private static let checklistToggleRequestsKey = "lunixiaStickyNoteChecklistToggleRequests"
    private static let widgetKind = "LunixiaStickyNoteWidget"

    private struct ChecklistToggleRequest: Codable, Equatable {
        var noteID: UUID
        var itemID: UUID
        var isCompleted: Bool
        var createdAt: Date
    }

    static func write(notes: [Note], tabs: [NotesTab] = []) {
        let rootTabName = tabs.first(where: { $0.isRootTab })?.trimmedName
            ?? tabs.first?.trimmedName
            ?? "All Notes"
        let orderedTabs = mergedTabNames(notes: notes, tabs: tabs, rootTabName: rootTabName)
        let pendingChecklistStates = latestPendingChecklistToggleStates()

        let snapshot = LunixiaStickyNoteWidgetSnapshot(
            tabs: orderedTabs,
            notes: notes
                .sorted { lhs, rhs in
                    if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                    return lhs.updatedAt > rhs.updatedAt
                }
                .map { note in
                    LunixiaStickyNoteWidgetNote(
	                        id: note.id,
	                        content: note.content,
	                        colorHex: note.colorHex,
	                        secondaryColorHex: note.secondaryColorHex,
	                        usesGradient: note.usesGradient,
	                        checklistItems: note.checklistItems.map {
	                            LunixiaStickyNoteWidgetChecklistItem(
	                                id: $0.id,
                                title: $0.title,
	                                isCompleted: pendingChecklistStates[toggleKey(noteID: note.id, itemID: $0.id)] ?? $0.isCompleted,
	                                group: $0.group
	                            )
	                        },
	                        listItems: note.listItems.map {
	                            LunixiaStickyNoteWidgetListItem(
	                                id: $0.id,
	                                title: $0.title,
	                                kind: $0.kind.rawValue,
	                                group: $0.group
	                            )
	                        },
	                        fontID: note.fontID,
                        tabName: resolvedTabName(for: note, rootTabName: rootTabName),
                        label: note.label,
                        label2: note.label2,
                        isPinned: note.isPinned,
                        updatedAt: note.updatedAt
                    )
                },
            lastUpdated: Date()
        )

        do {
            let data = try JSONEncoder().encode(snapshot)
            widgetDefaults?.set(data, forKey: snapshotKey)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        } catch {
            print("[LunixiaStickyNoteWidgetWriter] encode error: \(error)")
        }
    }

    @MainActor
    static func write(in modelContext: ModelContext) {
        applyPendingChecklistToggles(in: modelContext)

        let noteDescriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let tabDescriptor = FetchDescriptor<NotesTab>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let notes = try modelContext.fetch(noteDescriptor)
            let tabs = try modelContext.fetch(tabDescriptor)
            write(notes: notes, tabs: tabs)
        } catch {
            print("[LunixiaStickyNoteWidgetWriter] fetch error: \(error)")
        }
    }

    @MainActor
    private static func applyPendingChecklistToggles(in modelContext: ModelContext) {
        guard let requests = pendingChecklistToggleRequests(), !requests.isEmpty else { return }

        let noteDescriptor = FetchDescriptor<Note>()

        do {
            let notes = try modelContext.fetch(noteDescriptor)
            var didChange = false

            for request in requests.sorted(by: { $0.createdAt < $1.createdAt }) {
                guard let note = notes.first(where: { $0.id == request.noteID }) else { continue }
                var items = note.checklistItems
                guard let index = items.firstIndex(where: { $0.id == request.itemID }) else { continue }

                if items[index].isCompleted != request.isCompleted {
                    items[index].isCompleted = request.isCompleted
                    note.checklistItems = items
                    note.touch()
                    didChange = true
                }
            }

            if didChange {
                try modelContext.save()
            }
            widgetDefaults?.removeObject(forKey: checklistToggleRequestsKey)
        } catch {
            print("[LunixiaStickyNoteWidgetWriter] pending checklist toggle error: \(error)")
        }
    }

    private static func pendingChecklistToggleRequests() -> [ChecklistToggleRequest]? {
        guard let data = widgetDefaults?.data(forKey: checklistToggleRequestsKey) else { return nil }
        return try? JSONDecoder().decode([ChecklistToggleRequest].self, from: data)
    }

    private static func latestPendingChecklistToggleStates() -> [String: Bool] {
        var states: [String: Bool] = [:]
        for request in (pendingChecklistToggleRequests() ?? []).sorted(by: { $0.createdAt < $1.createdAt }) {
            states[toggleKey(noteID: request.noteID, itemID: request.itemID)] = request.isCompleted
        }
        return states
    }

    private static func toggleKey(noteID: UUID, itemID: UUID) -> String {
        "\(noteID.uuidString)|\(itemID.uuidString)"
    }

    private static func mergedTabNames(notes: [Note], tabs: [NotesTab], rootTabName: String) -> [String] {
        var names: [String] = [rootTabName]

        for tab in tabs {
            let name = tab.trimmedName
            guard !name.isEmpty, !names.contains(name) else { continue }
            names.append(name)
        }

        for note in notes {
            let name = resolvedTabName(for: note, rootTabName: rootTabName)
            guard !names.contains(name) else { continue }
            names.append(name)
        }

        return names
    }

    private static func resolvedTabName(for note: Note, rootTabName: String) -> String {
        let trimmed = note.tabName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? rootTabName : trimmed
    }
}
