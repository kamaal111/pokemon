//
//  PokemonCardTestImageFilters.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/31/26.
//

import CoreImage
import UIKit

public enum PokemonCardTestImageFilters {
    public static func gaussianBlurred(
        _ image: UIImage,
        radius: Double = 6
    ) throws -> UIImage {
        let ciContext = CIContext()

        guard let input = CIImage(image: image) else {
            throw PokemonCardTestImageFilterError.missingInputImage
        }

        let output =
            input
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": radius])
            .cropped(to: input.extent)

        guard let cgImage = ciContext.createCGImage(output, from: input.extent) else {
            throw PokemonCardTestImageFilterError.missingOutputImage
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

private enum PokemonCardTestImageFilterError: Error {
    case missingInputImage
    case missingOutputImage
}
