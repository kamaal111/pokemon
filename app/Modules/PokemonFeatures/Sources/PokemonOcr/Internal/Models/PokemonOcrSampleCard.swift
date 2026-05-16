//
//  PokemonOcrSampleCard.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import UIKit

enum PokemonOcrSampleCard: String, CaseIterable, Identifiable {
    case eevee
    case shinyCharmeleon
    case trainersSnorlax

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .eevee:
            "Eevee"
        case .shinyCharmeleon:
            "Shiny Charmeleon"
        case .trainersSnorlax:
            "Trainer's Snorlax"
        }
    }

    var expectedOcrTitle: String {
        switch self {
        case .eevee:
            "이브이ex"
        case .shinyCharmeleon:
            "リザード"
        case .trainersSnorlax:
            "ホップのカビゴン"
        }
    }

    var image: UIImage {
        let url = Bundle.module.url(forResource: fileName, withExtension: "jpg")!
        let image = UIImage(contentsOfFile: url.path)!

        return image
    }

    private var fileName: String {
        switch self {
        case .eevee:
            "eevee"
        case .shinyCharmeleon:
            "shiny-charmeleon"
        case .trainersSnorlax:
            "trainers-snorlax"
        }
    }
}
