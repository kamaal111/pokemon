//
//  PokemonCardImageNormalizer.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import UIKit

public enum PokemonCardImageNormalizer {
    public static func normalizedForPokemonOcr(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up, image.cgImage != nil {
            return image
        }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
