//
// JournalEntry.swift
// Lunixia
//

import Foundation
import UIKit
import SwiftData

@Model
final class JournalEntry {
    var deletedAt: Date?

    // MARK: - Relationship
    var book: JournalBook?
    var blocks: [JournalBlock]? = nil

    // MARK: - Fields
    var title: String = ""
    var body: String = ""
    var bodyData: Data?
    var tagsStorage: String = "[]"

    // MARK: - Background Appearance
    var backgroundModeRaw: String = JournalEntryBackgroundMode.defaultLystaria.rawValue
    var backgroundColorHex: String = ""
    var backgroundGradientStartHex: String = ""
    var backgroundGradientEndHex: String = ""
    @Attribute(.externalStorage) var backgroundImageData: Data? = nil
    var backgroundImageOpacity: Double = 0.85
    var backgroundImageBlur: Double = 0.0
    var backgroundOverlayOpacity: Double = 0.35
    var textColorHex: String = ""

    // MARK: - Inner Page Appearance
    var innerPageBackgroundModeRaw: String = JournalInnerPageBackgroundMode.defaultGlass.rawValue
    var innerPageBackgroundColorHex: String = ""
    var innerPageGradientStartHex: String = ""
    var innerPageGradientEndHex: String = ""
    var innerPageOpacity: Double = 0.34

    // MARK: - Cover Image
    @Attribute(.externalStorage) var coverImageData: Data? = nil
    var coverImageVerticalOffset: Double = 0.0

    // MARK: - Body Font
    /// PostScript name of the custom body font selected for this entry.
    /// Empty string means "use the default system font".
    var bodyFontName: String = ""

    /// Points added to every body/heading font size in this entry.
    /// 0 = the block type's normal size; positive values grow, negative shrink.
    var bodyFontSizeOffset: Double = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var backgroundMode: JournalEntryBackgroundMode {
        get { JournalEntryBackgroundMode(rawValue: backgroundModeRaw) ?? .defaultLystaria }
        set {
            backgroundModeRaw = newValue.rawValue
            touch()
        }
    }

    var innerPageBackgroundMode: JournalInnerPageBackgroundMode {
        get { JournalInnerPageBackgroundMode(rawValue: innerPageBackgroundModeRaw) ?? .defaultGlass }
        set {
            innerPageBackgroundModeRaw = newValue.rawValue
            touch()
        }
    }

    var tags: [String] {
        get {
            guard let data = tagsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let encoded = String(data: data, encoding: .utf8) {
                tagsStorage = encoded
            } else {
                tagsStorage = "[]"
            }
        }
    }

    var bodyAttributedText: NSAttributedString {
        get {
            if let bodyData, !bodyData.isEmpty {
                let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: bodyData)
                unarchiver?.requiresSecureCoding = false
                let attributed = unarchiver?.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
                unarchiver?.finishDecoding()
                if let attributed {
                    return attributed
                }
            }
            return NSAttributedString(string: body)
        }
        set {
            self.bodyData = try? NSKeyedArchiver.archivedData(
                withRootObject: newValue,
                requiringSecureCoding: false
            )
            self.body = newValue.string
            self.updatedAt = Date()
        }
    }

    init(
        title: String = "",
        bodyAttributedText: NSAttributedString = NSAttributedString(string: ""),
        tags: [String] = [],
        book: JournalBook? = nil,
        deletedAt: Date? = nil
    ) {
        self.title = title
        self.body = bodyAttributedText.string
        self.bodyData = try? NSKeyedArchiver.archivedData(
            withRootObject: bodyAttributedText,
            requiringSecureCoding: false
        )
        self.tagsStorage = "[]"
        self.book = book
        self.deletedAt = deletedAt
        self.backgroundModeRaw = JournalEntryBackgroundMode.defaultLystaria.rawValue
        self.backgroundColorHex = ""
        self.backgroundGradientStartHex = ""
        self.backgroundGradientEndHex = ""
        self.backgroundImageData = nil
        self.backgroundImageOpacity = 0.85
        self.backgroundImageBlur = 0.0
        self.backgroundOverlayOpacity = 0.35
        self.innerPageBackgroundModeRaw = JournalInnerPageBackgroundMode.defaultGlass.rawValue
        self.innerPageBackgroundColorHex = ""
        self.innerPageGradientStartHex = ""
        self.innerPageGradientEndHex = ""
        self.innerPageOpacity = 0.34
        self.coverImageData = nil
        self.coverImageVerticalOffset = 0.0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }

    var sortedBlocks: [JournalBlock] {
        (blocks ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    // Plain-text preview for journal cards
    var blockPreviewText: String {
        let pieces = sortedBlocks.compactMap { block -> String? in
            switch block.type {
            case .divider, .table:
                return nil
            case .blockquote:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .callout:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .code:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .toggle:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : "▸ \(t)"
            case .bulletedList:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : "• \(t)"
            case .numberedList:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .checklist:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                let state = block.languageHint.trimmingCharacters(in: .whitespacesAndNewlines)
                switch state {
                case "checked": return "☑ \(t)"
                case "xmark":   return "☒ \(t)"
                default:        return "☐ \(t)"
                }
            case .paragraph,
                 .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            case .toggleHeading1, .toggleHeading2, .toggleHeading3,
                 .toggleHeading4, .toggleHeading5, .toggleHeading6:
                let t = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : "▸ \(t)"
            case .image:
                return block.imageData != nil ? "🖼️" : nil
            case .drawing:
                return block.drawingData != nil ? "Drawing" : nil
            }
        }
        let joined = pieces.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(joined.prefix(300))
    }

    func ensureStarterBlock() {
        if blocks == nil {
            blocks = []
        }
        if blocks?.isEmpty != false {
            let block = JournalBlock(type: .paragraph, text: "", sortOrder: 0)
            block.entry = self
            blocks?.append(block)
        }
    }

    func normalizeBlockSortOrders() {
        let all = (blocks ?? []).sorted { $0.sortOrder < $1.sortOrder }
        var ordered: [JournalBlock] = []
        var visited = Set<UUID>()

        func append(_ block: JournalBlock) {
            guard !visited.contains(block.id) else { return }
            visited.insert(block.id)
            ordered.append(block)
            let children = all.filter { $0.parentBlockID == block.id }
            for child in children {
                append(child)
            }
        }

        for block in all where block.parentBlockID == nil {
            append(block)
        }
        for block in all where !visited.contains(block.id) {
            block.parentBlockID = nil
            append(block)
        }

        for (index, block) in ordered.enumerated() {
            if block.sortOrder != index {
                block.sortOrder = index
            }
        }
    }

    func touch() {
        updatedAt = Date()
    }
}

enum JournalEntryBackgroundMode: String, Codable, CaseIterable, Identifiable {
    case defaultLystaria
    case solidColor
    case gradient
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultLystaria: return "Default"
        case .solidColor:      return "Color"
        case .gradient:        return "Gradient"
        case .image:           return "Image"
        }
    }
}

enum JournalInnerPageBackgroundMode: String, Codable, CaseIterable, Identifiable {
    case defaultGlass
    case solidColor
    case gradient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultGlass: return "Default"
        case .solidColor:   return "Color"
        case .gradient:     return "Gradient"
        }
    }
}
