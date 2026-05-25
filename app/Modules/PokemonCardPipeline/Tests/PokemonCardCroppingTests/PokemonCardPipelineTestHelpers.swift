//
//  PokemonOcrTestHelpers.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Foundation
import UIKit

enum PokemonOcrTestError: Error {
    case missingSample(String)
}

func sampleImage(_ name: String) throws -> UIImage {
    let url =
        Bundle.module.url(forResource: name, withExtension: "jpg")
        ?? Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "SampleCards")

    guard let url else {
        throw PokemonOcrTestError.missingSample(name)
    }

    guard let image = UIImage(contentsOfFile: url.path) else {
        throw PokemonOcrTestError.missingSample(name)
    }

    return image
}
