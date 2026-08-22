//
//  Note.swift
//  Lunixia
//

import Foundation
import SwiftData

struct NoteChecklistItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    /// Which placement group this item belongs to. Group 1 is the original single list.
    var group: Int

    init(
        id: UUID = UUID(),
        title: String = "",
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        group: Int = 1
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.group = group
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, createdAt, group
    }

    /// Existing notes were encoded before `group` existed. The synthesised decoder would
    /// throw on that older JSON, and the `try?` in Note.checklistItems would swallow it
    /// and return an empty array — silently wiping every checklist item. decodeIfPresent
    /// keeps old data readable and files it under group 1.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        group = try container.decodeIfPresent(Int.self, forKey: .group) ?? 1
    }
}

enum NoteListItemKind: String, Codable, Equatable {
    case bullet
    case numbered
}

enum NoteListPlacementType: String, CaseIterable, Identifiable, Hashable {
    case bullets
    case checklist
    case numbers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bullets: return "Bullets"
        case .checklist: return "Checklist"
        case .numbers: return "Numbers"
        }
    }

    var token: String {
        switch self {
        case .bullets: return Note.bulletsPlacementToken
        case .checklist: return Note.checklistPlacementToken
        case .numbers: return Note.numbersPlacementToken
        }
    }

    /// The bare word used inside a token, e.g. "CHECKLIST".
    var tokenKeyword: String {
        switch self {
        case .bullets: return "BULLETS"
        case .checklist: return "CHECKLIST"
        case .numbers: return "NUMBERS"
        }
    }

    /// Group 1 keeps the original unnumbered token so existing notes are untouched.
    func token(group: Int) -> String {
        group <= 1 ? "[[ \(tokenKeyword) ]]" : "[[ \(tokenKeyword) \(group) ]]"
    }

    /// "Checklist" for group 1, "Checklist 2" for later groups.
    func sectionTitle(group: Int) -> String {
        group <= 1 ? title : "\(title) \(group)"
    }
}

/// One placement token found in a note's content.
struct NoteListPlacement: Equatable {
    let type: NoteListPlacementType
    let group: Int
    let range: Range<String.Index>
}

struct NoteListItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var kind: NoteListItemKind
    var createdAt: Date
    /// Which placement group this item belongs to. Group 1 is the original single list.
    var group: Int

    init(
        id: UUID = UUID(),
        title: String = "",
        kind: NoteListItemKind = .bullet,
        createdAt: Date = Date(),
        group: Int = 1
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.createdAt = createdAt
        self.group = group
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, kind, createdAt, group
    }

    /// See NoteChecklistItem.init(from:) — decodeIfPresent keeps pre-group JSON readable
    /// instead of throwing and silently emptying the list.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decode(NoteListItemKind.self, forKey: .kind)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        group = try container.decodeIfPresent(Int.self, forKey: .group) ?? 1
    }
}

@Model
final class Note {
    static let minimumFontSize: Double = 12
    static let maximumFontSize: Double = 28
    static let bulletsPlacementToken = "[[ BULLETS ]]"
    static let checklistPlacementToken = "[[ CHECKLIST ]]"
    static let numbersPlacementToken = "[[ NUMBERS ]]"
    static let listPlacementTokens = [
        bulletsPlacementToken,
        checklistPlacementToken,
        numbersPlacementToken
    ]

    var id: UUID = UUID()

    // Main content
    var content: String = ""
    var colorHex: String = "#6B4CDE"
    var secondaryColorHex: String = "#22D3EE"
    var usesGradient: Bool = false
    var checklistItemsJSON: String = ""
    var listItemsJSON: String = ""
    var fontID: String = "system"
    var fontSize: Double = 15

    // Original stored label — kept intact so existing data is not lost
    var label: String = ""
    // Second label stored as a plain string (empty = not set)
    var label2: String = ""

    var tabName: String = "All Notes"

    // Markers
    var isPinned: Bool = false
    var isFavorite: Bool = false

    // Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        content: String = "",
        colorHex: String = "#6B4CDE",
        secondaryColorHex: String = "#22D3EE",
        usesGradient: Bool = false,
        checklistItemsJSON: String = "",
        listItemsJSON: String = "",
        fontID: String = "system",
        fontSize: Double = 15,
        label: String = "",
        label2: String = "",
        tabName: String = "All Notes",
        isPinned: Bool = false,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.colorHex = colorHex
        self.secondaryColorHex = secondaryColorHex
        self.usesGradient = usesGradient
        self.checklistItemsJSON = checklistItemsJSON
        self.listItemsJSON = listItemsJSON
        self.fontID = fontID
        self.fontSize = fontSize
        self.label = label
        self.label2 = label2
        self.tabName = tabName
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Call this whenever content changes
    func touch() {
        updatedAt = Date()
    }

    // Cleaned content (for safety checks)
    var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedFontSize: Double {
        min(Self.maximumFontSize, max(Self.minimumFontSize, fontSize))
    }

    // Prevent saving empty notes if you want
    var isEmpty: Bool {
        trimmedContent.isEmpty && listItems.isEmpty && checklistItems.isEmpty
    }

    // Used for sticky note preview cards
    var previewText: String {
        let textPreview = contentWithoutListPlacementTokens.replacingOccurrences(of: "\n", with: " ")
        let listPreview = listItems
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let checklistPreview = checklistItems
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return [textPreview, listPreview, checklistPreview]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var contentWithoutListPlacementTokens: String {
        Self.strippingPlacementTokens(from: content)
    }

    /// Matches "[[ CHECKLIST ]]" and "[[ CHECKLIST 2 ]]".
    private static let placementTokenPattern = "\\[\\[ (BULLETS|CHECKLIST|NUMBERS)(?: (\\d+))? \\]\\]"

    private static let placementTokenRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: placementTokenPattern)
    }()

    /// Every placement token in `content`, in the order it appears.
    static func placements(in content: String) -> [NoteListPlacement] {
        guard let regex = placementTokenRegex else { return [] }
        let ns = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: ns.length))

        return matches.compactMap { match in
            guard let range = Range(match.range, in: content) else { return nil }

            let keyword = ns.substring(with: match.range(at: 1))
            guard let type = NoteListPlacementType.allCases.first(where: { $0.tokenKeyword == keyword })
            else { return nil }

            var group = 1
            if match.range(at: 2).location != NSNotFound,
               let parsed = Int(ns.substring(with: match.range(at: 2))) {
                group = max(1, parsed)
            }

            return NoteListPlacement(type: type, group: group, range: range)
        }
    }

    static func strippingPlacementTokens(from content: String) -> String {
        guard let regex = placementTokenRegex else { return content }
        let ns = content as NSString
        return regex
            .stringByReplacingMatches(
                in: content,
                range: NSRange(location: 0, length: ns.length),
                withTemplate: ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Both labels as an array, omitting empty entries.
    var activeLabels: [String] {
        [label, label2]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var checklistItems: [NoteChecklistItem] {
        get {
            guard !checklistItemsJSON.isEmpty,
                  let data = checklistItemsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([NoteChecklistItem].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let encoded = String(data: data, encoding: .utf8)
            else {
                checklistItemsJSON = ""
                return
            }
            checklistItemsJSON = encoded
        }
    }

    var listItems: [NoteListItem] {
        get {
            guard !listItemsJSON.isEmpty,
                  let data = listItemsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([NoteListItem].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let encoded = String(data: data, encoding: .utf8)
            else {
                listItemsJSON = ""
                return
            }
            listItemsJSON = encoded
        }
    }
}
