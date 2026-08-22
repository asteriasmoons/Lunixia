//
//  NoteFontOption.swift
//  Lunixia
//

import CoreText
import SwiftUI

enum NoteFontOption: String, CaseIterable, Identifiable, Codable {
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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .beautifulRainbow: return "Beautiful Rainbow"
        case .balistia: return "Balistia"
        case .cenila: return "Cenila"
        case .cheekySmileAlt: return "Cheeky Smile Alt"
        case .chibiDinosaur: return "Chibi Dinosaur"
        case .childowEveryday: return "Childow Everyday"
        case .chunkyBear: return "Chunky Bear"
        case .chubbyLines: return "Chubby Lines"
        case .foxLollipop: return "Fox Lollipop"
        case .handDrawn: return "Hand Drawn"
        case .hachiMaruPop: return "Hachi Maru Pop"
        case .inLove: return "Inlove"
        case .liveOnTheMoon: return "Live On The Moon"
        case .loveMonday: return "Love Monday"
        case .lumilkys: return "Lumilkys"
        case .mightyFineDemibold: return "Mighty Fine Demibold"
        case .rainbowClub: return "Rainbow Club"
        case .santaJolly: return "Santa Jolly"
        case .soulDreams: return "Soul Dreams"
        case .sugarDonutHeart: return "Sugar Donut Heart"
        }
    }

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

    static func option(for id: String) -> NoteFontOption {
        NoteFontOption(rawValue: id) ?? .system
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // No manual registration here. Every file in `fileName` is listed under
        // UIAppFonts in Info.plist, so iOS registers them all at launch. Calling
        // CTFontManagerRegisterFontsForURL again re-registers fonts that are already
        // installed, and that happened on the very first font lookup of each process —
        // which is exactly when the editor was being opened for the first time.
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
}

enum NoteFontRegistrar {
    private static var didRegister = false

    static func registerFontsIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        for option in NoteFontOption.allCases {
            guard let fileName = option.fileName else { continue }
            let url = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: fileName, withExtension: nil)
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
