//
//  PokemonOcrSampleCard.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import UIKit

enum PokemonOcrSampleCard: String, CaseIterable, Identifiable {
    case cameraMeowth
    case eevee
    case insectChinese
    case shinyCharmeleon
    case trainersGhost
    case trainersSnorlax
    case trainersWold

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .cameraMeowth:
            "Camera Meowth"
        case .eevee:
            "Eevee"
        case .insectChinese:
            "Chinese Insect"
        case .shinyCharmeleon:
            "Shiny Charmeleon"
        case .trainersGhost:
            "黑夜魔靈"
        case .trainersSnorlax:
            "Trainer's Snorlax"
        case .trainersWold:
            "Nのゾロアークex"
        }
    }

    var expectedOcrTitle: String {
        switch self {
        case .cameraMeowth:
            "Team Rocket's Meowth"
        case .eevee:
            "이브이ex"
        case .insectChinese:
            "音箱蟀"
        case .shinyCharmeleon:
            "リザード"
        case .trainersGhost:
            "黑夜魔靈"
        case .trainersSnorlax:
            "ホップのカビゴン"
        case .trainersWold:
            "Nのゾロアークex"
        }
    }

    var image: UIImage {
        guard let url = resourceURL else {
            preconditionFailure("Missing OCR sample image resource: \(fileName).jpg")
        }
        guard let image = UIImage(contentsOfFile: url.path) else {
            preconditionFailure("OCR sample image could not be decoded: \(fileName).jpg")
        }

        return image
    }

    private var fileName: String {
        switch self {
        case .cameraMeowth:
            "camera-meowth"
        case .eevee:
            "eevee"
        case .insectChinese:
            "insect-chinese"
        case .shinyCharmeleon:
            "shiny-charmeleon"
        case .trainersGhost:
            "trainers-ghost"
        case .trainersSnorlax:
            "trainers-snorlax"
        case .trainersWold:
            "trainers-wold"
        }
    }

    private var resourceURL: URL? {
        if let rootURL = Bundle.module.url(forResource: fileName, withExtension: "jpg") {
            return rootURL
        }

        return Bundle.module.url(
            forResource: fileName,
            withExtension: "jpg",
            subdirectory: "SampleCards"
        )
    }
}
