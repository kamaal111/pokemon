//
//  PokemonCardTextPassPlanner.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import UIKit

struct PokemonCardTextRecognitionPass {
    let label: String
    let image: UIImage
    let regionOfInterest: CGRect?
    let minimumTextHeight: Float
}

enum PokemonCardTextPassPlanner {
    static func passes(for image: UIImage) -> [PokemonCardTextRecognitionPass] {
        let normalizedImage = PokemonCardTextImageProcessing.normalized(image)
        let enhancedImage = PokemonCardTextImageProcessing.enhanced(normalizedImage)

        return [
            PokemonCardTextRecognitionPass(
                label: "normalized-full-card",
                image: normalizedImage,
                regionOfInterest: nil,
                minimumTextHeight: 0.008
            ),
            PokemonCardTextRecognitionPass(
                label: "enhanced-full-card",
                image: enhancedImage,
                regionOfInterest: nil,
                minimumTextHeight: 0.008
            ),
            PokemonCardTextRecognitionPass(
                label: "enhanced-top-band",
                image: enhancedImage,
                regionOfInterest: CGRect(x: 0, y: 0.66, width: 1, height: 0.34),
                minimumTextHeight: 0.006
            ),
            PokemonCardTextRecognitionPass(
                label: "enhanced-middle-band",
                image: enhancedImage,
                regionOfInterest: CGRect(x: 0, y: 0.32, width: 1, height: 0.36),
                minimumTextHeight: 0.006
            ),
            PokemonCardTextRecognitionPass(
                label: "enhanced-bottom-band",
                image: enhancedImage,
                regionOfInterest: CGRect(x: 0, y: 0, width: 1, height: 0.35),
                minimumTextHeight: 0.006
            ),
        ]
    }

    static func debugImages(for passes: [PokemonCardTextRecognitionPass]) -> [PokemonCardTextDebugImage] {
        passes.map { pass in
            let image: UIImage
            if let regionOfInterest = pass.regionOfInterest {
                image = PokemonCardTextImageProcessing.croppedDebugImage(
                    from: pass.image,
                    regionOfInterest: regionOfInterest
                )
            } else {
                image = pass.image
            }

            return PokemonCardTextDebugImage(
                label: pass.label,
                image: image,
                regionOfInterest: pass.regionOfInterest
            )
        }
    }
}
