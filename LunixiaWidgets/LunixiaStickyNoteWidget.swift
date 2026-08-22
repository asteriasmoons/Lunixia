//
//  LunixiaStickyNoteWidget.swift
//  LunixiaWidgets
//

import AppIntents
import CoreText
import Foundation
import SwiftUI
import WidgetKit

// MARK: - Snapshot

struct LunixiaStickyNoteWidgetChecklistItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    /// Group 1 is the original single list. Snapshots written before groups existed have
    /// no value here, so it is decoded leniently rather than failing the whole snapshot.
    var group: Int = 1

    private enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, group
    }

    init(id: UUID, title: String, isCompleted: Bool, group: Int = 1) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.group = group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        group = try container.decodeIfPresent(Int.self, forKey: .group) ?? 1
    }
}

enum LunixiaStickyNoteWidgetListItemKind: String, Codable, Equatable {
    case bullet
    case numbered
}

struct LunixiaStickyNoteWidgetListItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var kind: LunixiaStickyNoteWidgetListItemKind
    /// See LunixiaStickyNoteWidgetChecklistItem.group.
    var group: Int = 1

    private enum CodingKeys: String, CodingKey {
        case id, title, kind, group
    }

    init(id: UUID, title: String, kind: LunixiaStickyNoteWidgetListItemKind, group: Int = 1) {
        self.id = id
        self.title = title
        self.kind = kind
        self.group = group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decode(LunixiaStickyNoteWidgetListItemKind.self, forKey: .kind)
        group = try container.decodeIfPresent(Int.self, forKey: .group) ?? 1
    }
}

private enum StickyNoteWidgetPlacementType: String, CaseIterable, Hashable {
    case bullets
    case checklist
    case numbers

    var tokenKeyword: String {
        switch self {
        case .bullets: return "BULLETS"
        case .checklist: return "CHECKLIST"
        case .numbers: return "NUMBERS"
        }
    }

    var token: String { token(group: 1) }

    /// Group 1 keeps the original unnumbered token, matching Note.token(group:).
    func token(group: Int) -> String {
        group <= 1 ? "[[ \(tokenKeyword) ]]" : "[[ \(tokenKeyword) \(group) ]]"
    }
}

private struct StickyNoteWidgetPlacement: Equatable {
    let type: StickyNoteWidgetPlacementType
    let group: Int
    let range: Range<String.Index>
}

/// Mirrors Note.placements(in:) / Note.strippingPlacementTokens(from:) in the app target.
private enum StickyNoteWidgetTokenParser {
    private static let regex = try? NSRegularExpression(
        pattern: "\\[\\[ (BULLETS|CHECKLIST|NUMBERS)(?: (\\d+))? \\]\\]"
    )

    static func placements(in content: String) -> [StickyNoteWidgetPlacement] {
        guard let regex else { return [] }
        let ns = content as NSString

        return regex
            .matches(in: content, range: NSRange(location: 0, length: ns.length))
            .compactMap { match in
                guard let range = Range(match.range, in: content) else { return nil }

                let keyword = ns.substring(with: match.range(at: 1))
                guard let type = StickyNoteWidgetPlacementType.allCases
                    .first(where: { $0.tokenKeyword == keyword })
                else { return nil }

                var group = 1
                if match.range(at: 2).location != NSNotFound,
                   let parsed = Int(ns.substring(with: match.range(at: 2))) {
                    group = max(1, parsed)
                }

                return StickyNoteWidgetPlacement(type: type, group: group, range: range)
            }
    }

    static func stripping(_ content: String) -> String {
        guard let regex else { return content }
        let ns = content as NSString
        return regex
            .stringByReplacingMatches(
                in: content,
                range: NSRange(location: 0, length: ns.length),
                withTemplate: ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum StickyNoteWidgetRenderedKind: Equatable {
    case text(String)
    case bullets(Int)
    case checklist(Int)
    case numbers(Int)
}

private struct StickyNoteWidgetRenderedElement: Identifiable, Equatable {
    let id: String
    let kind: StickyNoteWidgetRenderedKind
}

/// Hard-bounds content to the space the widget actually has and cuts the overflow.
/// `.frame(maxHeight: .infinity)` only expands to fill — a child that insists on being
/// taller still spills past it, which is why over-long notes were overflowing the widget.
/// GeometryReader gives a concrete height to clamp to.
private struct StickyNoteWidgetOverflowClip: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
        }
    }
}

private extension View {
    func stickyNoteOverflowClip() -> some View {
        modifier(StickyNoteWidgetOverflowClip())
    }
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

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case colorHex
        case secondaryColorHex
        case usesGradient
        case checklistItems
        case listItems
        case fontID
        case tabName
        case label
        case label2
        case isPinned
        case updatedAt
    }

    init(
        id: UUID,
        content: String,
        colorHex: String,
        secondaryColorHex: String,
        usesGradient: Bool,
        checklistItems: [LunixiaStickyNoteWidgetChecklistItem],
        listItems: [LunixiaStickyNoteWidgetListItem],
        fontID: String,
        tabName: String,
        label: String,
        label2: String,
        isPinned: Bool,
        updatedAt: Date
    ) {
        self.id = id
        self.content = content
        self.colorHex = colorHex
        self.secondaryColorHex = secondaryColorHex
        self.usesGradient = usesGradient
        self.checklistItems = checklistItems
        self.listItems = listItems
        self.fontID = fontID
        self.tabName = tabName
        self.label = label
        self.label2 = label2
        self.isPinned = isPinned
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        secondaryColorHex = try container.decodeIfPresent(String.self, forKey: .secondaryColorHex) ?? "#22D3EE"
        usesGradient = try container.decodeIfPresent(Bool.self, forKey: .usesGradient) ?? false
        checklistItems = try container.decodeIfPresent([LunixiaStickyNoteWidgetChecklistItem].self, forKey: .checklistItems) ?? []
        listItems = try container.decodeIfPresent([LunixiaStickyNoteWidgetListItem].self, forKey: .listItems) ?? []
        fontID = try container.decodeIfPresent(String.self, forKey: .fontID) ?? "system"
        tabName = try container.decodeIfPresent(String.self, forKey: .tabName) ?? "All Notes"
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        label2 = try container.decodeIfPresent(String.self, forKey: .label2) ?? ""
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

struct LunixiaStickyNoteWidgetSnapshot: Codable, Equatable {
    var tabs: [String]
    var notes: [LunixiaStickyNoteWidgetNote]
    var lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case tabs
        case notes
        case lastUpdated
    }

    init(tabs: [String], notes: [LunixiaStickyNoteWidgetNote], lastUpdated: Date) {
        self.tabs = tabs
        self.notes = notes
        self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notes = try container.decode([LunixiaStickyNoteWidgetNote].self, forKey: .notes)
        let decodedTabs = try container.decodeIfPresent([String].self, forKey: .tabs) ?? []
        let noteTabs = notes.map(\.tabName)
        var mergedTabs: [String] = decodedTabs.isEmpty ? ["All Notes"] : decodedTabs
        for tab in noteTabs where !mergedTabs.contains(tab) {
            mergedTabs.append(tab)
        }
        tabs = mergedTabs
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
    }
}

enum LunixiaStickyNoteWidgetStore {
    static let appGroupID = "group.com.asteriasmoons.Lunixia"
    static let snapshotKey = "lunixiaStickyNoteWidgetSnapshot"
    private static let checklistToggleRequestsKey = "lunixiaStickyNoteChecklistToggleRequests"

    struct ChecklistToggleRequest: Codable, Equatable {
        var noteID: UUID
        var itemID: UUID
        var isCompleted: Bool
        var createdAt: Date
    }

    static func read() -> LunixiaStickyNoteWidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: snapshotKey),
            let decoded = try? JSONDecoder().decode(LunixiaStickyNoteWidgetSnapshot.self, from: data)
        else { return placeholder }

        return decoded
    }

    static var placeholder: LunixiaStickyNoteWidgetSnapshot {
        LunixiaStickyNoteWidgetSnapshot(
            tabs: ["All Notes"],
            notes: [
	                LunixiaStickyNoteWidgetNote(
	                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
	                    content: "Choose a sticky note to keep nearby.",
	                    colorHex: "#6B4CDE",
	                    secondaryColorHex: "#22D3EE",
	                    usesGradient: false,
	                    checklistItems: [
	                        LunixiaStickyNoteWidgetChecklistItem(
	                            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
	                            title: "Tap and hold to edit widget",
	                            isCompleted: false
	                        )
	                    ],
	                    listItems: [],
	                    fontID: "rounded",
                    tabName: "All Notes",
                    label: "",
                    label2: "",
                    isPinned: false,
                    updatedAt: Date()
                )
            ],
            lastUpdated: Date()
        )
    }

    static func notes(in tabName: String?) -> [LunixiaStickyNoteWidgetNote] {
        let notes = read().notes
        guard let tabName, !tabName.isEmpty else { return notes }
        return notes.filter { $0.tabName == tabName }
    }

    static func note(id: UUID?, in tabName: String?) -> LunixiaStickyNoteWidgetNote? {
        let filteredNotes = notes(in: tabName)
        let notes = filteredNotes.isEmpty ? read().notes : filteredNotes
        guard let id else { return notes.first }
        return notes.first { $0.id == id } ?? notes.first
    }

    static func toggleChecklistItem(noteID: UUID, itemID: UUID) {
        var snapshot = read()
        guard let noteIndex = snapshot.notes.firstIndex(where: { $0.id == noteID }),
              let itemIndex = snapshot.notes[noteIndex].checklistItems.firstIndex(where: { $0.id == itemID })
        else { return }

        snapshot.notes[noteIndex].checklistItems[itemIndex].isCompleted.toggle()
        snapshot.notes[noteIndex].updatedAt = Date()
        snapshot.lastUpdated = Date()

        let isCompleted = snapshot.notes[noteIndex].checklistItems[itemIndex].isCompleted
        write(snapshot)
        enqueueToggle(
            ChecklistToggleRequest(
                noteID: noteID,
                itemID: itemID,
                isCompleted: isCompleted,
                createdAt: Date()
            )
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "LunixiaStickyNoteWidget")
    }

    private static func write(_ snapshot: LunixiaStickyNoteWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: snapshotKey)
    }

    private static func enqueueToggle(_ request: ChecklistToggleRequest) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var requests = readToggleRequests(from: defaults)
        requests.removeAll { $0.noteID == request.noteID && $0.itemID == request.itemID }
        requests.append(request)

        guard let data = try? JSONEncoder().encode(requests) else { return }
        defaults.set(data, forKey: checklistToggleRequestsKey)
    }

    private static func readToggleRequests(from defaults: UserDefaults) -> [ChecklistToggleRequest] {
        guard let data = defaults.data(forKey: checklistToggleRequestsKey),
              let decoded = try? JSONDecoder().decode([ChecklistToggleRequest].self, from: data)
        else { return [] }
        return decoded
    }
}

// MARK: - Checklist Toggle Intent

struct ToggleStickyNoteChecklistItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Checklist Item"
    static var description = IntentDescription("Marks a sticky note checklist item complete or incomplete.")
    static var openAppWhenRun = false

    @Parameter(title: "Note ID")
    var noteID: String

    @Parameter(title: "Checklist Item ID")
    var itemID: String

    init() {
        noteID = ""
        itemID = ""
    }

    init(noteID: UUID, itemID: UUID) {
        self.noteID = noteID.uuidString
        self.itemID = itemID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let noteUUID = UUID(uuidString: noteID),
              let itemUUID = UUID(uuidString: itemID)
        else { return .result() }

        LunixiaStickyNoteWidgetStore.toggleChecklistItem(noteID: noteUUID, itemID: itemUUID)
        return .result()
    }
}

// MARK: - App Intent Configuration

struct StickyNoteTabEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note Tab")
    static var defaultQuery = StickyNoteTabEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct StickyNoteTabEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StickyNoteTabEntity] {
        LunixiaStickyNoteWidgetStore.read().tabs
            .filter { identifiers.contains($0) }
            .map { StickyNoteTabEntity(id: $0, name: $0) }
    }

    func suggestedEntities() async throws -> [StickyNoteTabEntity] {
        LunixiaStickyNoteWidgetStore.read().tabs
            .map { StickyNoteTabEntity(id: $0, name: $0) }
    }

    func defaultResult() async -> StickyNoteTabEntity? {
        LunixiaStickyNoteWidgetStore.read().tabs.first
            .map { StickyNoteTabEntity(id: $0, name: $0) }
    }
}

struct StickyNoteEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sticky Note")
    static var defaultQuery = StickyNoteEntityQuery()

    let id: UUID
    let title: String
    let tabName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct StickyNoteEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [StickyNoteEntity] {
        let notes = LunixiaStickyNoteWidgetStore.read().notes
        return notes
            .filter { identifiers.contains($0.id) }
            .map(StickyNoteEntity.init(note:))
    }

    func suggestedEntities() async throws -> [StickyNoteEntity] {
        LunixiaStickyNoteWidgetStore.read().notes.map(StickyNoteEntity.init(note:))
    }

    func defaultResult() async -> StickyNoteEntity? {
        LunixiaStickyNoteWidgetStore.read().notes.first.map(StickyNoteEntity.init(note:))
    }
}

struct StickyNoteOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<StickyNoteConfigurationIntent>(\.$tab)
    var intent

    func results() async throws -> [StickyNoteEntity] {
        LunixiaStickyNoteWidgetStore.notes(in: intent?.tab.name)
            .map(StickyNoteEntity.init(note:))
    }

    func defaultResult() async -> StickyNoteEntity? {
        LunixiaStickyNoteWidgetStore.notes(in: intent?.tab.name)
            .first
            .map(StickyNoteEntity.init(note:))
    }
}

extension StickyNoteEntity {
	init(note: LunixiaStickyNoteWidgetNote) {
	    let trimmed = StickyNoteWidgetTokenParser.stripping(note.content)
	    let listTitle = note.listItems
	        .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
	        .first { !$0.isEmpty }
	    let checklistTitle = note.checklistItems
	        .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
	        .first { !$0.isEmpty }
	    self.id = note.id
	    self.title = trimmed.isEmpty ? (listTitle ?? checklistTitle ?? "Empty Note") : trimmed
	    self.tabName = note.tabName
	}
}

struct StickyNoteConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Sticky Note"
    static var description = IntentDescription("Choose a note for this widget.")

    @Parameter(title: "Tab")
    var tab: StickyNoteTabEntity?

    @Parameter(title: "Note", optionsProvider: StickyNoteOptionsProvider())
    var note: StickyNoteEntity?

    init() {
        self.tab = nil
        self.note = nil
    }

    init(tab: StickyNoteTabEntity? = nil, note: StickyNoteEntity? = nil) {
        self.tab = tab
        self.note = note
    }
}

// MARK: - Timeline

struct LunixiaStickyNoteWidgetEntry: TimelineEntry {
    let date: Date
    let selectedNoteID: UUID?
    let note: LunixiaStickyNoteWidgetNote?
    let lastUpdated: Date
}

struct LunixiaStickyNoteWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LunixiaStickyNoteWidgetEntry {
        let snapshot = LunixiaStickyNoteWidgetStore.read()
        return LunixiaStickyNoteWidgetEntry(
            date: Date(),
            selectedNoteID: snapshot.notes.first?.id,
            note: snapshot.notes.first,
            lastUpdated: snapshot.lastUpdated
        )
    }

    func snapshot(for configuration: StickyNoteConfigurationIntent, in context: Context) async -> LunixiaStickyNoteWidgetEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: StickyNoteConfigurationIntent, in context: Context) async -> Timeline<LunixiaStickyNoteWidgetEntry> {
        let entry = entry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func entry(for configuration: StickyNoteConfigurationIntent) -> LunixiaStickyNoteWidgetEntry {
        let snapshot = LunixiaStickyNoteWidgetStore.read()
        let selectedID = configuration.note?.id
        let selectedTab = configuration.tab?.name
        return LunixiaStickyNoteWidgetEntry(
            date: Date(),
            selectedNoteID: selectedID,
            note: LunixiaStickyNoteWidgetStore.note(id: selectedID, in: selectedTab),
            lastUpdated: snapshot.lastUpdated
        )
    }
}

// MARK: - Fonts

private enum StickyNoteWidgetFontOption: String {
    case system
    case rounded
    case serif
    case beautifulRainbow
    case balistia
    case cenila
    case cheekySmileAlt
    case chibiDinosaur
    case childowEveryday
    case chunkyBear
    case chubbyLines
    case foxLollipop
    case handDrawn
    case hachiMaruPop
    case inLove
    case liveOnTheMoon
    case loveMonday
    case lumilkys
    case mightyFineDemibold
    case rainbowClub
    case santaJolly
    case soulDreams
    case sugarDonutHeart

    var postScriptName: String? {
        switch self {
        case .system, .rounded, .serif:
            return nil
        case .beautifulRainbow:
            return "BeautifulRainbow"
        case .balistia:
            return "Balistia-Regular"
        case .cenila:
            return "Cenila"
        case .cheekySmileAlt:
            return "CheekySmileAltRegular"
        case .chibiDinosaur:
            return "ChibiDinosaurRegular"
        case .childowEveryday:
            return "ChildowEveryday"
        case .chunkyBear:
            return "ChunkyBear"
        case .chubbyLines:
            return "ChubbyLines-Regular"
        case .foxLollipop:
            return "FoxLollipopRegular"
        case .handDrawn:
            return "HandDrawnRegular"
        case .hachiMaruPop:
            return "HachiMaruPop-Regular"
        case .inLove:
            return "InLoveRegular"
        case .liveOnTheMoon:
            return "LiveonTheMoon"
        case .loveMonday:
            return "LoveMonday"
        case .lumilkys:
            return "Lumilkys"
        case .mightyFineDemibold:
            return "ZPMightyFineDemibold"
        case .rainbowClub:
            return "RainbowClubRegular"
        case .santaJolly:
            return "SantaJollyRegular"
        case .soulDreams:
            return "SoulDreams"
        case .sugarDonutHeart:
            return "SugarDonutHeart"
        }
    }

    var fileName: String? {
        switch self {
        case .system, .rounded, .serif:
            return nil
        case .beautifulRainbow:
            return "Beautiful Rainbow Font by Dani 7NTypes.otf"
        case .balistia:
            return "Balistia.otf"
        case .cenila:
            return "Cenila.otf"
        case .cheekySmileAlt:
            return "Cheeky Smilealt.otf"
        case .chibiDinosaur:
            return "Chibi Dinosaur.otf"
        case .childowEveryday:
            return "Childow Everyday.otf"
        case .chunkyBear:
            return "Chunky Bear.otf"
        case .chubbyLines:
            return "Chubby Lines.otf"
        case .foxLollipop:
            return "Fox Lollipop.otf"
        case .handDrawn:
            return "Hand Drawn.otf"
        case .hachiMaruPop:
            return "HachiMaruPop-Regular.ttf"
        case .inLove:
            return "Inlove.otf"
        case .liveOnTheMoon:
            return "Live On The Moon.otf"
        case .loveMonday:
            return "Love Monday.otf"
        case .lumilkys:
            return "Lumilkys Regular.ttf"
        case .mightyFineDemibold:
            return "Mighty Fine Demibold.otf"
        case .rainbowClub:
            return "RainbowClub.otf"
        case .santaJolly:
            return "Santa Jolly.otf"
        case .soulDreams:
            return "Soul Dreams.otf"
        case .sugarDonutHeart:
            return "Sugar Donut Heart.otf"
        }
    }

    static func option(for id: String) -> StickyNoteWidgetFontOption {
        StickyNoteWidgetFontOption(rawValue: id) ?? .system
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        StickyNoteWidgetFontRegistrar.registerFontsIfNeeded()

        switch self {
        case .system:
            return .system(size: size, weight: weight)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        default:
            if let postScriptName {
                return .custom(postScriptName, size: size)
            }
            return .system(size: size, weight: weight)
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        StickyNoteWidgetFontRegistrar.registerFontsIfNeeded()

        switch self {
        case .system:
            return .systemFont(ofSize: size)
        case .rounded:
            if let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
                .withDesign(.rounded) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return .systemFont(ofSize: size)
        case .serif:
            if let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
                .withDesign(.serif) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return .systemFont(ofSize: size)
        default:
            if let postScriptName, let font = UIFont(name: postScriptName, size: size) {
                return font
            }
            return .systemFont(ofSize: size)
        }
    }
}

private enum StickyNoteWidgetFontRegistrar {
    private static var didRegister = false

    static func registerFontsIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        for option in [
            StickyNoteWidgetFontOption.beautifulRainbow,
            .balistia,
            .cenila,
            .cheekySmileAlt,
            .chibiDinosaur,
            StickyNoteWidgetFontOption.childowEveryday,
            .chunkyBear,
            .chubbyLines,
            .foxLollipop,
            .handDrawn,
            .hachiMaruPop,
            .inLove,
            .liveOnTheMoon,
            .loveMonday,
            .lumilkys,
            .mightyFineDemibold,
            .rainbowClub,
            .santaJolly,
            .soulDreams,
            .sugarDonutHeart
        ] {
            guard let fileName = option.fileName else { continue }
            let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: fileName, withExtension: nil)
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Widget View

struct LunixiaStickyNoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LunixiaStickyNoteWidgetEntry

    private var note: LunixiaStickyNoteWidgetNote? { entry.note }
    private var noteColor: Color { Color(lunixiaHex: note?.colorHex ?? "#6B4CDE") }
    private var noteSecondaryColor: Color { Color(lunixiaHex: note?.secondaryColorHex ?? "#22D3EE") }
    private var fontOption: StickyNoteWidgetFontOption {
        StickyNoteWidgetFontOption.option(for: note?.fontID ?? "system")
    }

    var body: some View {
        ZStack {
            noteBackground

            LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.05),
                    Color.black.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let note {
                switch family {
                case .systemSmall:
                    smallNoteContent(note)
                        .padding(widgetPadding)
                        .unredacted()
                case .systemMedium:
                    mediumNoteContent(note)
                        .padding(widgetPadding)
                        .unredacted()
                default:
                    noteContent(note)
                        .padding(widgetPadding)
                }
            } else {
                emptyContent
                    .padding(widgetPadding)
            }
        }
        .containerBackground(for: .widget) {
            noteBackground
        }
    }

    @ViewBuilder
    private var noteBackground: some View {
        if note?.usesGradient == true {
            LinearGradient(
                colors: [noteColor, noteSecondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            noteColor
        }
    }

    private func contentWithoutPlacementTokens(_ content: String) -> String {
        StickyNoteWidgetTokenParser.stripping(content)
    }

    private func renderedContentElements(for note: LunixiaStickyNoteWidgetNote) -> [StickyNoteWidgetRenderedElement] {
        let content = note.content
        var elements: [StickyNoteWidgetRenderedElement] = []
        var placedKeys = Set<String>()
        var cursor = content.startIndex
        var counter = 0

        func appendText(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            counter += 1
            elements.append(StickyNoteWidgetRenderedElement(id: "text-\(counter)", kind: .text(trimmed)))
        }

        func appendList(_ type: StickyNoteWidgetPlacementType, group: Int, suffix: String = "") {
            counter += 1
            elements.append(
                StickyNoteWidgetRenderedElement(
                    id: "\(type.rawValue)-\(group)\(suffix)-\(counter)",
                    kind: renderedKind(for: type, group: group)
                )
            )
        }

        for placement in StickyNoteWidgetTokenParser.placements(in: content) {
            appendText(String(content[cursor..<placement.range.lowerBound]))

            let key = "\(placement.type.rawValue)-\(placement.group)"
            if hasItems(note, type: placement.type, group: placement.group), !placedKeys.contains(key) {
                placedKeys.insert(key)
                appendList(placement.type, group: placement.group)
            }

            cursor = placement.range.upperBound
        }

        appendText(String(content[cursor..<content.endIndex]))

        for (type, group) in populatedGroups(in: note)
        where !placedKeys.contains("\(type.rawValue)-\(group)") {
            appendList(type, group: group, suffix: "-fallback")
        }

        return elements
    }

    private func hasItems(
        _ note: LunixiaStickyNoteWidgetNote,
        type: StickyNoteWidgetPlacementType,
        group: Int
    ) -> Bool {
        switch type {
        case .bullets:
            return note.listItems.contains { $0.kind == .bullet && $0.group == group }
        case .numbers:
            return note.listItems.contains { $0.kind == .numbered && $0.group == group }
        case .checklist:
            return note.checklistItems.contains { $0.group == group }
        }
    }

    private func populatedGroups(
        in note: LunixiaStickyNoteWidgetNote
    ) -> [(StickyNoteWidgetPlacementType, Int)] {
        var pairs: [(StickyNoteWidgetPlacementType, Int)] = []

        for type in StickyNoteWidgetPlacementType.allCases {
            let groups: Set<Int>
            switch type {
            case .bullets:
                groups = Set(note.listItems.filter { $0.kind == .bullet }.map(\.group))
            case .numbers:
                groups = Set(note.listItems.filter { $0.kind == .numbered }.map(\.group))
            case .checklist:
                groups = Set(note.checklistItems.map(\.group))
            }
            pairs.append(contentsOf: groups.sorted().map { (type, $0) })
        }

        return pairs
    }

    private func renderedKind(for type: StickyNoteWidgetPlacementType, group: Int) -> StickyNoteWidgetRenderedKind {
        switch type {
        case .bullets: return .bullets(group)
        case .checklist: return .checklist(group)
        case .numbers: return .numbers(group)
        }
    }

    private func placedContent(
        _ note: LunixiaStickyNoteWidgetNote,
        textFontSize: CGFloat,
        textLineLimit: Int?,
        listLimit: Int?,
        checklistLimit: Int?,
        markerSize: CGFloat,
        circleSize: CGFloat,
        listFontSize: CGFloat,
        checklistFontSize: CGFloat,
        itemLineLimit: Int?,
        rowSpacing: CGFloat,
        itemSpacing: CGFloat
    ) -> some View {
        let elements = renderedContentElements(for: note)

        return VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(elements) { element in
                switch element.kind {
                case .text(let text):
                    Text(text)
                        .font(fontOption.font(size: textFontSize))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .lineLimit(textLineLimit)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(2)
                case .bullets(let group):
                    list(
                        note.listItems.filter { $0.kind == .bullet && $0.group == group },
                        limit: listLimit,
                        markerSize: markerSize,
                        fontSize: listFontSize,
                        itemLineLimit: itemLineLimit,
                        rowSpacing: rowSpacing,
                        itemSpacing: itemSpacing
                    )
                case .checklist(let group):
                    checklist(
                        note.checklistItems.filter { $0.group == group },
                        noteID: note.id,
                        limit: checklistLimit,
                        circleSize: circleSize,
                        fontSize: checklistFontSize,
                        itemLineLimit: itemLineLimit,
                        rowSpacing: rowSpacing,
                        itemSpacing: itemSpacing
                    )
                case .numbers(let group):
                    list(
                        note.listItems.filter { $0.kind == .numbered && $0.group == group },
                        limit: listLimit,
                        markerSize: markerSize,
                        fontSize: listFontSize,
                        itemLineLimit: itemLineLimit,
                        rowSpacing: rowSpacing,
                        itemSpacing: itemSpacing
                    )
                }
            }
        }
        // Lay the whole stack out at its natural height. The caller then re-bounds it to
        // the space the widget actually has and clips, so earlier content renders in full
        // and whatever runs past the bottom edge is simply cut. Without this the stack
        // joins the normal height distribution and every block gets squeezed instead.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func smallNoteContent(_ note: LunixiaStickyNoteWidgetNote) -> some View {
        let trimmedContent = contentWithoutPlacementTokens(note.content)

        return VStack(alignment: .leading, spacing: 7) {
            header(note)

            VStack(alignment: .leading, spacing: 6) {
                if trimmedContent.isEmpty && note.listItems.isEmpty && note.checklistItems.isEmpty {
                    Text("Empty note")
                        .font(fontOption.font(size: 13))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    placedContent(
                        note,
                        textFontSize: 13,
                        textLineLimit: nil,
                        listLimit: nil,
                        checklistLimit: nil,
                        markerSize: 14,
                        circleSize: 14,
                        listFontSize: 11,
                        checklistFontSize: 11,
                        itemLineLimit: nil,
                        rowSpacing: 4,
                        itemSpacing: 6
                    )
                }
            }
            .stickyNoteOverflowClip()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediumNoteContent(_ note: LunixiaStickyNoteWidgetNote) -> some View {
        let trimmedContent = contentWithoutPlacementTokens(note.content)

        return VStack(alignment: .leading, spacing: 9) {
            header(note)

            VStack(alignment: .leading, spacing: 8) {
                if trimmedContent.isEmpty && note.listItems.isEmpty && note.checklistItems.isEmpty {
                    Text("Empty note")
                        .font(fontOption.font(size: 14))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    placedContent(
                        note,
                        textFontSize: 14,
                        textLineLimit: nil,
                        listLimit: nil,
                        checklistLimit: nil,
                        markerSize: 17,
                        circleSize: 17,
                        listFontSize: 12,
                        checklistFontSize: 12,
                        itemLineLimit: nil,
                        rowSpacing: 7,
                        itemSpacing: 8
                    )
                    .layoutPriority(2)
                }
            }
            .stickyNoteOverflowClip()

            footer(note)
                .layoutPriority(-1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func noteContent(_ note: LunixiaStickyNoteWidgetNote) -> some View {
        let trimmedContent = contentWithoutPlacementTokens(note.content)

        return VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 10) {
            header(note)

            VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 9) {
                if trimmedContent.isEmpty && note.listItems.isEmpty && note.checklistItems.isEmpty {
                    Text("Empty note")
                        .font(fontOption.font(size: contentFontSize))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                } else {
                    placedContent(
                        note,
                        textFontSize: contentFontSize,
                        textLineLimit: nil,
                        listLimit: nil,
                        checklistLimit: nil,
                        markerSize: markerSize,
                        circleSize: markerSize,
                        listFontSize: checklistFontSize,
                        checklistFontSize: checklistFontSize,
                        itemLineLimit: nil,
                        rowSpacing: contentRowSpacing,
                        itemSpacing: contentItemSpacing
                    )
                }
            }
            .stickyNoteOverflowClip()

            if family != .systemSmall {
                footer(note)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ note: LunixiaStickyNoteWidgetNote) -> some View {
        HStack(spacing: 7) {
            Image("starnote")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: headerIconSize, height: headerIconSize)
                .foregroundStyle(LGradients.header)

            Text(headerTitle(note))
                .font(.system(size: headerTitleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Spacer(minLength: 0)
        }
    }

    private func list(_ items: [LunixiaStickyNoteWidgetListItem]) -> some View {
        list(
            items,
            limit: listLimit,
            markerSize: family == .systemSmall ? 14 : 17,
            fontSize: checklistFontSize,
            itemLineLimit: checklistItemLineLimit,
            rowSpacing: family == .systemSmall ? 4 : 7,
            itemSpacing: family == .systemSmall ? 6 : 8
        )
    }

    private func list(
        _ items: [LunixiaStickyNoteWidgetListItem],
        limit: Int?,
        markerSize: CGFloat,
        fontSize: CGFloat,
        itemLineLimit: Int?,
        rowSpacing: CGFloat,
        itemSpacing: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(Array(items.prefix(limit ?? items.count).enumerated()), id: \.element.id) { _, item in
                HStack(alignment: .top, spacing: itemSpacing) {
                    StickyNoteWidgetListMarker(
                        kind: item.kind,
                        number: number(for: item, in: items),
                        size: markerSize
                    )
                    .padding(.top, 1)

                    Text(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "List item" : item.title)
                        .font(fontOption.font(size: fontSize))
                        .foregroundStyle(.white)
                        .lineLimit(itemLineLimit)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func number(for item: LunixiaStickyNoteWidgetListItem, in items: [LunixiaStickyNoteWidgetListItem]) -> Int {
        let numberedItems = items.filter { $0.kind == .numbered }
        guard let index = numberedItems.firstIndex(where: { $0.id == item.id }) else { return 1 }
        return index + 1
    }

    private func checklist(_ items: [LunixiaStickyNoteWidgetChecklistItem], noteID: UUID) -> some View {
        checklist(
            items,
            noteID: noteID,
            limit: checklistLimit,
            circleSize: family == .systemSmall ? 14 : 17,
            fontSize: checklistFontSize,
            itemLineLimit: checklistItemLineLimit,
            rowSpacing: family == .systemSmall ? 4 : 7,
            itemSpacing: family == .systemSmall ? 6 : 8
        )
    }

    private func checklist(
        _ items: [LunixiaStickyNoteWidgetChecklistItem],
        noteID: UUID,
        limit: Int?,
        circleSize: CGFloat,
        fontSize: CGFloat,
        itemLineLimit: Int?,
        rowSpacing: CGFloat,
        itemSpacing: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(Array(items.prefix(limit ?? items.count))) { item in
                HStack(alignment: .top, spacing: itemSpacing) {
                    Button(intent: ToggleStickyNoteChecklistItemIntent(noteID: noteID, itemID: item.id)) {
                        StickyNoteWidgetChecklistCircle(
                            isCompleted: item.isCompleted,
                            size: circleSize
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 1)

                    StickyNoteWidgetChecklistText(
                        title: item.title,
                        isCompleted: item.isCompleted,
                        fontOption: fontOption,
                        fontSize: fontSize,
                        lineLimit: itemLineLimit
                    )
                }
            }
        }
    }

    private func footer(_ note: LunixiaStickyNoteWidgetNote) -> some View {
        HStack(spacing: 6) {
            ForEach(activeLabels(note).prefix(family == .systemSmall ? 1 : 2), id: \.self) { label in
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.22))
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
                    )
            }

            Spacer(minLength: 0)
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("linedpages")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(LGradients.header)

            Text("No sticky note yet")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Create a note in Lunixia.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func headerTitle(_ note: LunixiaStickyNoteWidgetNote) -> String {
        if note.isPinned { return "Pinned Note" }
        if let label = activeLabels(note).first { return label }
        return "Sticky Note"
    }

    private func activeLabels(_ note: LunixiaStickyNoteWidgetNote) -> [String] {
        [note.label, note.label2]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Bullet dots, number markers and checklist circles.
    private var markerSize: CGFloat {
        switch family {
        case .systemSmall: return 14
        case .systemExtraLarge: return 21
        default: return 17
        }
    }

    private var contentRowSpacing: CGFloat {
        switch family {
        case .systemSmall: return 4
        case .systemExtraLarge: return 11
        default: return 7
        }
    }

    private var contentItemSpacing: CGFloat {
        switch family {
        case .systemSmall: return 6
        case .systemExtraLarge: return 11
        default: return 8
        }
    }

    private var headerIconSize: CGFloat {
        switch family {
        case .systemSmall: return 15
        case .systemExtraLarge: return 24
        default: return 18
        }
    }

    private var headerTitleSize: CGFloat {
        switch family {
        case .systemSmall: return 11
        case .systemExtraLarge: return 17
        default: return 13
        }
    }

    private var widgetPadding: CGFloat {
        switch family {
        case .systemSmall: return 16
        case .systemMedium: return 18
        case .systemExtraLarge: return 26
        default: return 20
        }
    }

    private var contentFontSize: CGFloat {
        switch family {
        case .systemSmall: return 13
        case .systemMedium: return 14
        case .systemExtraLarge: return 19
        default: return 16
        }
    }

    private var checklistFontSize: CGFloat {
        switch family {
        case .systemSmall: return 11
        case .systemMedium: return 12
        case .systemExtraLarge: return 17
        default: return 14
        }
    }

    private var contentLineLimit: Int {
        switch family {
        case .systemSmall: return 4
        case .systemMedium: return 4
        case .systemExtraLarge: return 16
        default: return 8
        }
    }

    private var checklistLimit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemExtraLarge: return 16
        default: return 8
        }
    }

    private var listLimit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemExtraLarge: return 16
        default: return 8
        }
    }

    private var checklistItemLineLimit: Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 2
        case .systemExtraLarge: return 4
        default: return 3
        }
    }
}

private struct StickyNoteWidgetChecklistText: View {
    let title: String
    let isCompleted: Bool
    let fontOption: StickyNoteWidgetFontOption
    let fontSize: CGFloat
    /// nil means "wrap freely and let the widget clip", rather than squeezing to fit.
    let lineLimit: Int?

    private var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Checklist item" : trimmed
    }

    var body: some View {
        Text(displayTitle)
            .font(fontOption.font(size: fontSize))
            .foregroundStyle(.white.opacity(isCompleted ? 0.5 : 1.0))
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .overlay {
                if isCompleted {
                    GeometryReader { geo in
                        let lineCount = geo.size.height < fontSize * 2.0
                            ? 1
                            : max(1, min(lineLimit ?? Int.max, Int(round(geo.size.height / (fontSize * 1.4)))))
                        let lineSpacing = geo.size.height / CGFloat(lineCount)

                        ForEach(0..<lineCount, id: \.self) { i in
                            Rectangle()
                                .fill(Color.white.opacity(0.6))
                                .frame(height: 1.5)
                                .offset(y: lineSpacing * CGFloat(i) + lineSpacing * 0.48)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StickyNoteWidgetListMarker: View {
    let kind: LunixiaStickyNoteWidgetListItemKind
    let number: Int
    let size: CGFloat

    var body: some View {
        switch kind {
        case .bullet:
            Circle()
                .fill(LGradients.header)
                .frame(width: max(5, size * 0.38), height: max(5, size * 0.38))
                .frame(width: size, height: size)
        case .numbered:
            Text("\(number).")
                .font(.system(size: max(8, size * 0.58), weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
                .frame(width: max(size + 8, 24), height: size, alignment: .trailing)
        }
    }
}

private struct StickyNoteWidgetChecklistCircle: View {
    let isCompleted: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isCompleted ? AnyShapeStyle(Color.clear) : AnyShapeStyle(LGradients.header),
                    lineWidth: max(1.4, size * 0.12)
                )
                .background(
                    Circle()
                        .fill(isCompleted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.clear))
                )

            if isCompleted {
                Image("checkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: size * 0.48, height: size * 0.48)
            }
        }
        .frame(width: size, height: size)
    }
}

struct LunixiaStickyNoteWidget: Widget {
    let kind = "LunixiaStickyNoteWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: StickyNoteConfigurationIntent.self,
            provider: LunixiaStickyNoteWidgetProvider()
        ) { entry in
            LunixiaStickyNoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Sticky Note")
        .description("Keep a selected Lunixia note on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}
