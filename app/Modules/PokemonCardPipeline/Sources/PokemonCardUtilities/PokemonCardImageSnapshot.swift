//
//  PokemonCardImageSnapshot.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 6/6/26.
//

import Foundation
import UIKit

public struct PokemonCardImageSnapshot: Sendable {
    private let pngData: Data
    private let scale: CGFloat

    public init(image: UIImage) {
        guard let pngData = image.pngData() else { preconditionFailure("Pokemon card image must be PNG encodable.") }

        self.pngData = pngData
        self.scale = image.scale
    }

    public var image: UIImage {
        guard let image = UIImage(data: pngData, scale: scale) else {
            preconditionFailure("Pokemon card image snapshot must decode.")
        }

        return image
    }
}
