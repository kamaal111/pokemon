//
//  PokemonCardSetIDCropper.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/27/26.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import PokemonCardImageProcessing
import UIKit

enum PokemonCardSetIDCropError: LocalizedError, Equatable {
    case emptyCrop

    var errorDescription: String? {
        switch self {
        case .emptyCrop:
            "The card set ID area could not be cropped."
        }
    }
}

struct PokemonCardSetIDCrop {
    let label: String
    let rect: CGRect
    let normalizedRect: CGRect
    let image: UIImage
    let enhancedImage: UIImage
}

enum PokemonCardSetIDCropper {
    struct Region: Equatable {
        let label: String
        let normalizedRect: CGRect
    }

    static let primaryRegion = Region(
        label: "set-id-primary-bottom-left",
        normalizedRect: CGRect(x: 0.03, y: 0.82, width: 0.34, height: 0.16)
    )
    static let fallbackRegion = Region(
        label: "set-id-fallback-lower-left",
        normalizedRect: CGRect(x: 0, y: 0.76, width: 0.45, height: 0.23)
    )

    private static let context = CIContext()

    static func crops(from image: UIImage) -> Result<[PokemonCardSetIDCrop], PokemonCardSetIDCropError> {
        let crops = [primaryRegion, fallbackRegion].compactMap { crop(region: $0, from: image) }
        guard !crops.isEmpty else { return .failure(.emptyCrop) }

        return .success(crops)
    }

    static func crop(
        region: Region,
        from image: UIImage
    ) -> PokemonCardSetIDCrop? {
        let normalizedImage = PokemonCardImageNormalizer.normalizedForPokemonOcr(image)
        guard normalizedImage.size.width > 0 else { return nil }
        guard normalizedImage.size.height > 0 else { return nil }
        guard let cgImage = normalizedImage.cgImage else { return nil }

        let rect = imageRect(for: region.normalizedRect, imageSize: normalizedImage.size)
        guard rect.width > 0 else { return nil }
        guard rect.height > 0 else { return nil }

        let pixelRect = CGRect(
            x: rect.minX * normalizedImage.scale,
            y: rect.minY * normalizedImage.scale,
            width: rect.width * normalizedImage.scale,
            height: rect.height * normalizedImage.scale
        ).integral
        guard let croppedCgImage = cgImage.cropping(to: pixelRect) else { return nil }

        let cropImage = UIImage(cgImage: croppedCgImage, scale: normalizedImage.scale, orientation: .up)

        return PokemonCardSetIDCrop(
            label: region.label,
            rect: rect,
            normalizedRect: normalizedRect(for: rect, imageSize: normalizedImage.size),
            image: cropImage,
            enhancedImage: enhanced(cropImage)
        )
    }

    private static func imageRect(for normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let rect = CGRect(
            x: normalizedRect.minX * imageSize.width,
            y: normalizedRect.minY * imageSize.height,
            width: normalizedRect.width * imageSize.width,
            height: normalizedRect.height * imageSize.height
        )

        return rect.intersection(imageBounds)
    }

    private static func normalizedRect(for rect: CGRect, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0 else { return .zero }
        guard imageSize.height > 0 else { return .zero }

        return CGRect(
            x: rect.minX / imageSize.width,
            y: rect.minY / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
    }

    private static func enhanced(_ image: UIImage) -> UIImage {
        let normalizedImage = PokemonCardImageNormalizer.normalizedForPokemonOcr(image)
        guard let cgImage = normalizedImage.cgImage else { return normalizedImage }

        let inputImage = CIImage(cgImage: cgImage)
        let colorControlsFilter = CIFilter.colorControls()
        colorControlsFilter.inputImage = inputImage
        colorControlsFilter.saturation = 0
        colorControlsFilter.contrast = 3.2
        colorControlsFilter.brightness = 0.08
        guard let contrastImage = colorControlsFilter.outputImage else { return normalizedImage }

        let sharpenFilter = CIFilter.unsharpMask()
        sharpenFilter.inputImage = contrastImage
        sharpenFilter.radius = 1.4
        sharpenFilter.intensity = 1.8
        guard let filteredImage = sharpenFilter.outputImage else { return normalizedImage }

        guard let filteredCgImage = context.createCGImage(filteredImage, from: filteredImage.extent) else {
            return normalizedImage
        }

        let scaledSize = CGSize(
            width: normalizedImage.size.width * 5,
            height: normalizedImage.size.height * 5
        )
        let renderer = UIGraphicsImageRenderer(size: scaledSize)

        return renderer.image { _ in
            UIImage(cgImage: filteredCgImage, scale: normalizedImage.scale, orientation: .up)
                .draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
}
