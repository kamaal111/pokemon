//
//  PokemonRecognitionLanguage.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

enum PokemonRecognitionLanguage: String, Hashable {
    case englishUnitedStates = "en-US"
    case japaneseJapan = "ja-JP"
    case koreanKorea = "ko-KR"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    var lexiconLanguages: [String] {
        switch self {
        case .englishUnitedStates:
            ["en"]
        case .japaneseJapan:
            ["ja", "ja-hrkt"]
        case .koreanKorea:
            ["ko"]
        case .chineseSimplified:
            ["zh-hans"]
        case .chineseTraditional:
            ["zh-hant"]
        }
    }
}
