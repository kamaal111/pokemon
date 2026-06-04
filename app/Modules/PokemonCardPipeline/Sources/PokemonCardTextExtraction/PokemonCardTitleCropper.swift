//
//  PokemonCardTitleCropper.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/4/26.
//

import CoreImage
import PokemonCardImageProcessing
import UIKit

enum PokemonCardTitleCropError: LocalizedError, Equatable {
    case emptyTitleCrop

    var errorDescription: String? {
        switch self {
        case .emptyTitleCrop:
            "The card title area could not be cropped."
        }
    }
}

struct PokemonCardTitleCrop {
    let rect: CGRect
    let image: UIImage
}

struct PokemonCardTitleCropper {
    struct Configuration {
        let xMin: CGFloat
        let xMax: CGFloat
        let yMin: CGFloat
        let yMax: CGFloat

        static let `default` = Configuration(
            xMin: 0.20,
            xMax: 0.75,
            yMin: 0.02,
            yMax: 0.13
        )
    }

    private init() {}

    static func titleRect(
        for imageSize: CGSize,
        configuration: Configuration = .default
    ) -> CGRect {
        let x = imageSize.width * configuration.xMin
        let y = imageSize.height * configuration.yMin
        let width = imageSize.width * (configuration.xMax - configuration.xMin)
        let height = imageSize.height * (configuration.yMax - configuration.yMin)

        return CGRect(x: x, y: y, width: width, height: height)
            .intersection(CGRect(origin: .zero, size: imageSize))
    }

    static func titleObservationRegion(
        for imageSize: CGSize,
        configuration: Configuration = .default
    ) -> CGRect {
        let titleRect = titleRect(for: imageSize, configuration: configuration)

        return observationRegion(for: titleRect, imageSize: imageSize)
    }

    static func observationRegion(for rect: CGRect, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0 else { return .zero }
        guard imageSize.height > 0 else { return .zero }

        return CGRect(
            x: rect.minX / imageSize.width,
            y: 1 - ((rect.minY + rect.height) / imageSize.height),
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
    }

    static func titleSearchRegion(
        for imageSize: CGSize,
        configuration: Configuration = .default
    ) -> CGRect {
        let titleRegion = titleObservationRegion(for: imageSize, configuration: configuration)
        let expandedRegion = titleRegion.insetBy(dx: -0.10, dy: -0.07)

        return CGRect(x: 0, y: 0, width: 1, height: 1).intersection(expandedRegion)
    }

    static func cropTitle(
        from image: UIImage,
        configuration: Configuration = .default
    ) -> Result<PokemonCardTitleCrop, PokemonCardTitleCropError> {
        let normalizedImage = PokemonCardImageNormalizer.normalizedForPokemonOcr(image)
        let titleRect = titleRect(for: normalizedImage.size, configuration: configuration)
        let crop = crop(rect: titleRect, fromNormalizedImage: normalizedImage)

        guard crop.image.size.width > 0 else { return .failure(.emptyTitleCrop) }
        guard crop.image.size.height > 0 else { return .failure(.emptyTitleCrop) }

        return .success(crop)
    }

    static func cropObservationRegion(_ region: CGRect, from image: UIImage) -> PokemonCardTitleCrop {
        let normalizedImage = PokemonCardImageNormalizer.normalizedForPokemonOcr(image)
        let rect = CGRect(
            x: region.minX * normalizedImage.size.width,
            y: (1 - region.maxY) * normalizedImage.size.height,
            width: region.width * normalizedImage.size.width,
            height: region.height * normalizedImage.size.height
        ).intersection(CGRect(origin: .zero, size: normalizedImage.size))

        return crop(rect: rect, fromNormalizedImage: normalizedImage)
    }

    private static func crop(
        rect: CGRect,
        fromNormalizedImage normalizedImage: UIImage
    ) -> PokemonCardTitleCrop {
        let pixelRect = CGRect(
            x: rect.origin.x * normalizedImage.scale,
            y: rect.origin.y * normalizedImage.scale,
            width: rect.width * normalizedImage.scale,
            height: rect.height * normalizedImage.scale
        ).integral

        guard let cgImage = normalizedImage.cgImage else { return PokemonCardTitleCrop(rect: rect, image: UIImage()) }
        guard let croppedImage = cgImage.cropping(to: pixelRect) else {
            return PokemonCardTitleCrop(rect: rect, image: UIImage())
        }

        return PokemonCardTitleCrop(
            rect: rect,
            image: UIImage(cgImage: croppedImage, scale: normalizedImage.scale, orientation: .up)
        )
    }
}

extension UIImage {
    func enhancedTitleCropForPokemonCardNameExtraction() -> UIImage {
        enhancedForPokemonCardNameExtraction(contrast: 2.2, scaleFactor: 3)
    }

    func enhancedFocusedTextImageForPokemonCardNameExtraction() -> UIImage {
        enhancedForPokemonCardNameExtraction(contrast: 3.0, scaleFactor: 5)
    }

    private func enhancedForPokemonCardNameExtraction(
        contrast: CGFloat,
        scaleFactor: CGFloat
    ) -> UIImage {
        let normalizedImage = PokemonCardImageNormalizer.normalizedForPokemonOcr(self)
        guard let inputCgImage = normalizedImage.cgImage else { return normalizedImage }

        let inputImage = CIImage(cgImage: inputCgImage)
        guard let colorControlsFilter = CIFilter(name: "CIColorControls") else { return normalizedImage }

        colorControlsFilter.setValue(inputImage, forKey: kCIInputImageKey)
        colorControlsFilter.setValue(0, forKey: kCIInputSaturationKey)
        colorControlsFilter.setValue(contrast, forKey: kCIInputContrastKey)

        guard let contrastImage = colorControlsFilter.outputImage else { return normalizedImage }
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else { return normalizedImage }

        sharpenFilter.setValue(contrastImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.2, forKey: kCIInputRadiusKey)
        sharpenFilter.setValue(1.5, forKey: kCIInputIntensityKey)

        let context = CIContext()
        guard let filteredImage = sharpenFilter.outputImage else { return normalizedImage }
        guard let filteredCgImage = context.createCGImage(filteredImage, from: filteredImage.extent) else {
            return normalizedImage
        }

        let scaledSize = CGSize(
            width: normalizedImage.size.width * scaleFactor,
            height: normalizedImage.size.height * scaleFactor
        )
        let renderer = UIGraphicsImageRenderer(size: scaledSize)

        return renderer.image { _ in
            UIImage(cgImage: filteredCgImage, scale: normalizedImage.scale, orientation: .up)
                .draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
}
