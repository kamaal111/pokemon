//
//  PokemonOcrTestHelpers.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Foundation
import UIKit

enum PokemonOcrTestError: Error {
    case missingSample(String)
}

func sampleImage(_ name: String) throws -> UIImage {
    guard let url = Bundle.module.url(forResource: name, withExtension: "jpg") else {
        throw PokemonOcrTestError.missingSample(name)
    }

    guard let image = UIImage(contentsOfFile: url.path) else {
        throw PokemonOcrTestError.missingSample(name)
    }

    return image
}
