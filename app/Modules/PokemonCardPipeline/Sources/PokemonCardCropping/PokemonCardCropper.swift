//
//  PokemonCardCropper.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/19/26.
//

import CoreGraphics
import PokemonCardImageProcessing
import UIKit

public enum PokemonCardCropError: LocalizedError, Equatable {
    case invalidImage
    case cardRegionNotFound
    case emptyCrop

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The card image could not be analyzed."
        case .cardRegionNotFound:
            "A likely Pokemon card region could not be found."
        case .emptyCrop:
            "The card crop was empty."
        }
    }
}

public struct PokemonCardCropResult {
    public let originalImage: UIImage
    public let cropImage: UIImage
    public let cropRect: CGRect
    public let normalizedCropRect: CGRect
    public let isClippedToImageBounds: Bool
}

public struct PokemonCardCropper {
    struct Configuration: Sendable {
        let bufferFraction: CGFloat
        let maxAnalysisDimension: CGFloat

        static let `default` = Configuration(bufferFraction: 0.08, maxAnalysisDimension: 240)
    }

    static let targetAspectRatio: CGFloat = 63 / 88

    private init() {}

    public static func cropCard(
        from image: UIImage,
        detectedNormalizedCardRect: CGRect? = nil
    ) -> Result<PokemonCardCropResult, PokemonCardCropError> {
        cropCard(from: image, detectedNormalizedCardRect: detectedNormalizedCardRect, configuration: .default)
    }

    static func cropCard(
        from image: UIImage,
        detectedNormalizedCardRect: CGRect? = nil,
        configuration: Configuration
    ) -> Result<PokemonCardCropResult, PokemonCardCropError> {
        let normalizedImage = PokemonCardImageNormalizer.normalizedForPokemonOcr(image)
        guard normalizedImage.size.width > 0, normalizedImage.size.height > 0 else { return .failure(.invalidImage) }
        guard normalizedImage.cgImage != nil else { return .failure(.invalidImage) }

        let candidate =
            detectedNormalizedCardRect.map {
                imageRect(fromVisionNormalizedRect: $0, imageSize: normalizedImage.size)
            } ?? likelyCardRegion(in: normalizedImage, configuration: configuration)
        guard let candidate else { return .failure(.cardRegionNotFound) }

        let cropProjection = cropProjection(
            forCandidate: candidate,
            imageSize: normalizedImage.size,
            bufferFraction: configuration.bufferFraction
        )
        let crop = crop(rect: cropProjection.rect, fromNormalizedImage: normalizedImage)

        guard crop.size.width > 0, crop.size.height > 0 else { return .failure(.emptyCrop) }

        return .success(
            PokemonCardCropResult(
                originalImage: normalizedImage,
                cropImage: crop,
                cropRect: cropProjection.rect,
                normalizedCropRect: normalizedRect(for: cropProjection.rect, imageSize: normalizedImage.size),
                isClippedToImageBounds: cropProjection.isClippedToImageBounds
            ))
    }

    static func cropProjection(
        forCandidate candidate: CGRect,
        imageSize: CGSize,
        bufferFraction: CGFloat = Configuration.default.bufferFraction
    ) -> (rect: CGRect, isClippedToImageBounds: Bool) {
        guard imageSize.width > 0, imageSize.height > 0 else { return (.zero, false) }
        guard candidate.width > 0, candidate.height > 0 else { return (.zero, false) }

        let candidateAspectRatio = candidate.width / candidate.height
        let fittedSize =
            if candidateAspectRatio > targetAspectRatio {
                CGSize(width: candidate.width, height: candidate.width / targetAspectRatio)
            } else {
                CGSize(width: candidate.height * targetAspectRatio, height: candidate.height)
            }

        let bufferedSize = CGSize(
            width: fittedSize.width * (1 + (bufferFraction * 2)),
            height: fittedSize.height * (1 + (bufferFraction * 2))
        )
        let unclippedRect = CGRect(
            x: candidate.midX - (bufferedSize.width / 2),
            y: candidate.midY - (bufferedSize.height / 2),
            width: bufferedSize.width,
            height: bufferedSize.height
        )
        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let clippedRect = imageBounds.intersection(unclippedRect)
        let isClippedToImageBounds =
            unclippedRect.minX < imageBounds.minX
            || unclippedRect.minY < imageBounds.minY
            || unclippedRect.maxX > imageBounds.maxX
            || unclippedRect.maxY > imageBounds.maxY

        return (clippedRect, isClippedToImageBounds)
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

    static func imageRect(
        fromVisionNormalizedRect rect: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        guard imageSize.width > 0 else { return .zero }
        guard imageSize.height > 0 else { return .zero }

        let standardizedRect = rect.standardized

        return CGRect(
            x: standardizedRect.minX * imageSize.width,
            y: (1 - standardizedRect.maxY) * imageSize.height,
            width: standardizedRect.width * imageSize.width,
            height: standardizedRect.height * imageSize.height
        )
    }

    static func likelyCardRegion(
        in image: UIImage,
        configuration: Configuration = .default
    ) -> CGRect? {
        guard let analysisImage = AnalysisImage(image: image, maxDimension: configuration.maxAnalysisDimension) else {
            return nil
        }

        let mask = analysisImage.foregroundMask()
        let dilatedMask = analysisImage.dilated(mask: mask, radius: 3)
        let components = analysisImage.components(in: dilatedMask)
        let imageArea = CGFloat(analysisImage.width * analysisImage.height)

        let rankedComponents =
            components
            .filter { component in
                let rect = component.rect
                let area = CGFloat(component.pixelCount)
                return rect.width >= 8
                    && rect.height >= 8
                    && area / imageArea >= 0.004
                    && area / imageArea <= 0.85
            }
            .sorted { lhs, rhs in
                analysisImage.score(component: lhs) > analysisImage.score(component: rhs)
            }

        guard let bestComponent = rankedComponents.first else {
            return nil
        }

        return analysisImage.imageRect(fromAnalysisRect: bestComponent.rect)
    }

    private static func crop(
        rect: CGRect,
        fromNormalizedImage normalizedImage: UIImage
    ) -> UIImage {
        guard let cgImage = normalizedImage.cgImage else { return UIImage() }

        let pixelRect = CGRect(
            x: rect.origin.x * normalizedImage.scale,
            y: rect.origin.y * normalizedImage.scale,
            width: rect.width * normalizedImage.scale,
            height: rect.height * normalizedImage.scale
        ).integral

        guard pixelRect.width > 0, pixelRect.height > 0 else {
            return UIImage()
        }
        guard let croppedImage = cgImage.cropping(to: pixelRect) else {
            return UIImage()
        }

        return UIImage(cgImage: croppedImage, scale: normalizedImage.scale, orientation: .up)
    }
}

private struct PokemonCardCropAnalysisComponent {
    let rect: CGRect
    let pixelCount: Int
}

private struct AnalysisImage {
    struct Pixel {
        let luminance: CGFloat
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let saturation: CGFloat

        static let zero = Pixel(luminance: 0, red: 0, green: 0, blue: 0, saturation: 0)
    }

    let width: Int
    let height: Int
    let imageSize: CGSize
    let pixels: [Pixel]
    let borderPixel: Pixel

    init?(image: UIImage, maxDimension: CGFloat) {
        guard let sourceImage = image.cgImage else { return nil }

        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        width = max(1, Int((image.size.width * scale).rounded()))
        height = max(1, Int((image.size.height * scale).rounded()))
        imageSize = image.size

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context else { return nil }

        context.interpolationQuality = .medium
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        pixels = stride(from: 0, to: bytes.count, by: bytesPerPixel).map { index in
            let red = CGFloat(bytes[index]) / 255
            let green = CGFloat(bytes[index + 1]) / 255
            let blue = CGFloat(bytes[index + 2]) / 255
            let maximumChannel = max(red, green, blue)
            let minimumChannel = min(red, green, blue)
            let saturation = maximumChannel == 0 ? 0 : (maximumChannel - minimumChannel) / maximumChannel

            return Pixel(
                luminance: (0.2126 * red) + (0.7152 * green) + (0.0722 * blue),
                red: red,
                green: green,
                blue: blue,
                saturation: saturation
            )
        }
        borderPixel = Self.averageBorderPixel(pixels: pixels, width: width, height: height)
    }

    func foregroundMask() -> [Bool] {
        pixels.map { pixel in
            let brighterThanBackground = pixel.luminance > borderPixel.luminance + 0.16
            let darkerThanBrightBackground =
                borderPixel.luminance > 0.55 && pixel.luminance < borderPixel.luminance - 0.12
            let colorDifference =
                (abs(pixel.red - borderPixel.red)
                    + abs(pixel.green - borderPixel.green)
                    + abs(pixel.blue - borderPixel.blue)) / 3
            let differentColorOnBrightBackground = borderPixel.luminance > 0.55 && colorDifference > 0.14
            let colorfulForeground =
                pixel.saturation > max(0.18, borderPixel.saturation + 0.14)
                && (brighterThanBackground || darkerThanBrightBackground || colorDifference > 0.08)

            return brighterThanBackground
                || darkerThanBrightBackground
                || differentColorOnBrightBackground
                || colorfulForeground
        }
    }

    func dilated(mask: [Bool], radius: Int) -> [Bool] {
        guard radius > 0 else { return mask }

        var result = mask
        for y in 0..<height {
            for x in 0..<width where mask[index(x: x, y: y)] {
                for yOffset in -radius...radius {
                    for xOffset in -radius...radius {
                        let projectedX = x + xOffset
                        let projectedY = y + yOffset
                        guard projectedX >= 0, projectedX < width else { continue }
                        guard projectedY >= 0, projectedY < height else { continue }

                        result[index(x: projectedX, y: projectedY)] = true
                    }
                }
            }
        }

        return result
    }

    func components(in mask: [Bool]) -> [PokemonCardCropAnalysisComponent] {
        var visited = [Bool](repeating: false, count: mask.count)
        var components: [PokemonCardCropAnalysisComponent] = []

        for y in 0..<height {
            for x in 0..<width {
                let startingIndex = index(x: x, y: y)
                guard mask[startingIndex], !visited[startingIndex] else { continue }

                var queue = [(x: x, y: y)]
                var queueIndex = 0
                visited[startingIndex] = true
                var minimumX = x
                var maximumX = x
                var minimumY = y
                var maximumY = y
                var pixelCount = 0

                while queueIndex < queue.count {
                    let point = queue[queueIndex]
                    queueIndex += 1
                    pixelCount += 1
                    minimumX = min(minimumX, point.x)
                    maximumX = max(maximumX, point.x)
                    minimumY = min(minimumY, point.y)
                    maximumY = max(maximumY, point.y)

                    for neighbor in neighbors(x: point.x, y: point.y) {
                        let neighborIndex = index(x: neighbor.x, y: neighbor.y)
                        guard mask[neighborIndex], !visited[neighborIndex] else { continue }

                        visited[neighborIndex] = true
                        queue.append(neighbor)
                    }
                }

                components.append(
                    PokemonCardCropAnalysisComponent(
                        rect: CGRect(
                            x: minimumX,
                            y: minimumY,
                            width: (maximumX - minimumX) + 1,
                            height: (maximumY - minimumY) + 1
                        ),
                        pixelCount: pixelCount
                    ))
            }
        }

        return components
    }

    func score(component: PokemonCardCropAnalysisComponent) -> CGFloat {
        let rect = component.rect
        let imageArea = CGFloat(width * height)
        let rectArea = max(rect.width * rect.height, 1)
        let componentArea = CGFloat(component.pixelCount)
        let areaFraction = componentArea / imageArea
        let fillFraction = componentArea / rectArea
        let aspectRatio = rect.width / rect.height
        let aspectScore = max(0, 1 - min(abs(aspectRatio - PokemonCardCropper.targetAspectRatio), 1))
        let centerY = rect.midY / CGFloat(height)
        let verticalScore = centerY > 0.18 ? 1 : 0.6

        return (areaFraction * 3) + fillFraction + aspectScore + verticalScore
    }

    func imageRect(fromAnalysisRect rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX / CGFloat(width) * imageSize.width,
            y: rect.minY / CGFloat(height) * imageSize.height,
            width: rect.width / CGFloat(width) * imageSize.width,
            height: rect.height / CGFloat(height) * imageSize.height
        )
    }

    private func index(x: Int, y: Int) -> Int {
        (y * width) + x
    }

    private func neighbors(x: Int, y: Int) -> [(x: Int, y: Int)] {
        [
            (x: x - 1, y: y),
            (x: x + 1, y: y),
            (x: x, y: y - 1),
            (x: x, y: y + 1),
        ].filter { point in
            point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
        }
    }

    private static func averageBorderPixel(pixels: [Pixel], width: Int, height: Int) -> Pixel {
        let borderThickness = max(2, min(width, height) / 20)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var luminance: CGFloat = 0
        var saturation: CGFloat = 0
        var count: CGFloat = 0

        for y in 0..<height {
            for x in 0..<width {
                let isMatching =
                    x < borderThickness
                    || y < borderThickness
                    || x >= width - borderThickness
                    || y >= height - borderThickness
                guard isMatching else { continue }

                let pixel = pixels[(y * width) + x]
                red += pixel.red
                green += pixel.green
                blue += pixel.blue
                luminance += pixel.luminance
                saturation += pixel.saturation
                count += 1
            }
        }

        guard count > 0 else { return .zero }

        return Pixel(
            luminance: luminance / count,
            red: red / count,
            green: green / count,
            blue: blue / count,
            saturation: saturation / count
        )
    }
}
