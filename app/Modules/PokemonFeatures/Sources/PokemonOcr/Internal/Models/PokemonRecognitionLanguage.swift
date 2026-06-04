//
//  PokemonRecognitionLanguage.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

enum PokemonRecognitionLanguage: String, Hashable {
    case englishUnitedStates = "en-US"
    case frenchFrance = "fr-FR"
    case germanGermany = "de-DE"
    case italianItaly = "it-IT"
    case japaneseJapan = "ja-JP"
    case koreanKorea = "ko-KR"
    case spanishSpain = "es-ES"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    var lexiconLanguages: [String] {
        switch self {
        case .englishUnitedStates:
            ["en", "ja-roma"]
        case .frenchFrance:
            ["fr"]
        case .germanGermany:
            ["de"]
        case .italianItaly:
            ["it"]
        case .japaneseJapan:
            ["ja", "ja-hrkt"]
        case .koreanKorea:
            ["ko"]
        case .spanishSpain:
            ["es"]
        case .chineseSimplified:
            ["zh-hans"]
        case .chineseTraditional:
            ["zh-hant"]
        }
    }
}
