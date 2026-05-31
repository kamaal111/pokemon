//
//  PokemonCardFocusQuality.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/31/26.
//

import CoreGraphics
import PokemonCardUtilities
import UIKit

public enum PokemonCardFocusQualityReason: Equatable, Sendable {
    case focused
    case tooBlurry
    case tooDark
    case tooLowContrast
    case tooCloseLikely
    case waitingForAutofocus
}

public struct PokemonCardFocusQualityReport: Equatable, Sendable {
    public let isSharpEnough: Bool
    public let sharpnessScore: Double
    public let gradientScore: Double
    public let brightness: Double
    public let contrast: Double
    public let reason: PokemonCardFocusQualityReason
    public let normalizedRegion: CGRect

    public var score: Double {
        sharpnessScore + (gradientScore * 8)
    }

    static func focused() -> PokemonCardFocusQualityReport {
        let sharpnessScore = 1_000.0
        let gradientScore = 40.0
        let contrast = 40.0

        return PokemonCardFocusQualityReport(
            isSharpEnough: true,
            sharpnessScore: sharpnessScore,
            gradientScore: gradientScore,
            brightness: brightness,
            contrast: contrast,
            reason: .focused,
            normalizedRegion: PokemonCardFocusQualityAnalyzer.fullRegion
        )
    }

    static func rejected(
        reason: PokemonCardFocusQualityReason,
        normalizedRegion: CGRect
    ) -> PokemonCardFocusQualityReport {
        let sharpnessScore = 0.0
        let gradientScore = 0.0
        let contrast = 0.0

        return PokemonCardFocusQualityReport(
            isSharpEnough: false,
            sharpnessScore: sharpnessScore,
            gradientScore: gradientScore,
            brightness: brightness,
            contrast: contrast,
            reason: reason,
            normalizedRegion: normalizedRegion
        )
    }

    private static let brightness = 128.0
}

public enum PokemonCardFocusQualityAnalyzer {
    public static func evaluate(
        image: UIImage,
        cardAreaFraction: CGFloat,
        isFocusAdjusting: Bool,
        isFocusSettling: Bool
    ) -> PokemonCardFocusQualityReport {
        let standardizedRegion = titleTextBand.standardized.intersection(fullRegion)
        guard !standardizedRegion.isNull else { return .rejected(reason: .tooBlurry, normalizedRegion: fullRegion) }

        let sample = LuminanceSample.sample(image: image, normalizedRegion: standardizedRegion)
        guard let sample else { return .rejected(reason: .tooBlurry, normalizedRegion: standardizedRegion) }

        let brightness = sample.mean
        let contrast = sample.standardDeviation
        guard
            let sharpnessScore = ImageFocusMetrics.laplacianVariance(
                values: sample.values,
                width: sample.width,
                height: sample.height
            )
        else {
            return .rejected(reason: .tooBlurry, normalizedRegion: standardizedRegion)
        }

        guard
            let gradientScore = ImageFocusMetrics.tenengradMean(
                values: sample.values,
                width: sample.width,
                height: sample.height
            )
        else {
            return .rejected(reason: .tooBlurry, normalizedRegion: standardizedRegion)
        }
        let reason = reason(
            sharpnessScore: sharpnessScore,
            gradientScore: gradientScore,
            brightness: brightness,
            contrast: contrast,
            cardAreaFraction: cardAreaFraction,
            isFocusAdjusting: isFocusAdjusting,
            isFocusSettling: isFocusSettling
        )

        return PokemonCardFocusQualityReport(
            isSharpEnough: reason == .focused,
            sharpnessScore: sharpnessScore,
            gradientScore: gradientScore,
            brightness: brightness,
            contrast: contrast,
            reason: reason,
            normalizedRegion: standardizedRegion
        )
    }

    private static func reason(
        sharpnessScore: Double,
        gradientScore: Double,
        brightness: Double,
        contrast: Double,
        cardAreaFraction: CGFloat,
        isFocusAdjusting: Bool,
        isFocusSettling: Bool
    ) -> PokemonCardFocusQualityReason {
        if isFocusAdjusting || isFocusSettling {
            return .waitingForAutofocus
        }

        if brightness < minimumBrightness {
            return .tooDark
        }

        if contrast < minimumContrast {
            return .tooLowContrast
        }

        if cardAreaFraction >= closeCardAreaFraction {
            if sharpnessScore < minimumSharpness || gradientScore < minimumGradient {
                return .tooCloseLikely
            }
        }

        if sharpnessScore < minimumSharpness || gradientScore < minimumGradient {
            return .tooBlurry
        }

        return .focused
    }

    static let fullRegion = CGRect(x: 0, y: 0, width: 1, height: 1)

    private static let titleTextBand = CGRect(x: 0.06, y: 0.03, width: 0.88, height: 0.24)
    private static let minimumBrightness = 35.0
    private static let minimumContrast = 18.0
    private static let minimumSharpness = 120.0
    private static let minimumGradient = 18.0
    private static let closeCardAreaFraction: CGFloat = 0.68
}

private struct LuminanceSample {
    let width: Int
    let height: Int
    let values: [Double]
    let mean: Double
    let standardDeviation: Double

    private init(width: Int, height: Int, values: [Double], mean: Double, standardDeviation: Double) {
        self.width = width
        self.height = height
        self.values = values
        self.mean = mean
        self.standardDeviation = standardDeviation
    }

    static func sample(image: UIImage, normalizedRegion: CGRect) -> LuminanceSample? {
        guard let cgImage = image.cgImage else { return nil }

        let pixelWidth = cgImage.width
        let pixelHeight = cgImage.height
        let cropRect = Self.pixelRect(for: normalizedRegion, width: pixelWidth, height: pixelHeight)
        guard cropRect.width >= 3 else { return nil }
        guard cropRect.height >= 3 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = cropRect.width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: cropRect.height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(
            data: &data,
            width: cropRect.width,
            height: cropRect.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
        guard let context else { return nil }

        context.translateBy(x: CGFloat(-cropRect.minX), y: CGFloat(cropRect.height - pixelHeight + cropRect.minY))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        var luminanceValues: [Double] = []
        let lumninceValuesCapacity = cropRect.width * cropRect.height
        luminanceValues.reserveCapacity(lumninceValuesCapacity)
        for index in stride(from: 0, to: data.count, by: bytesPerPixel) {
            let red = Double(data[index])
            let green = Double(data[index + 1])
            let blue = Double(data[index + 2])
            luminanceValues.append((0.299 * red) + (0.587 * green) + (0.114 * blue))
        }

        let mean = luminanceValues.reduce(0, +) / Double(luminanceValues.count)
        let luminanceSum = luminanceValues.reduce(0) { sum, value in
            let difference = value - mean
            return sum + (difference * difference)
        }
        let variance = luminanceSum / Double(luminanceValues.count)

        return LuminanceSample(
            width: cropRect.width,
            height: cropRect.height,
            values: luminanceValues,
            mean: mean,
            standardDeviation: sqrt(variance)
        )
    }

    private static func pixelRect(for normalizedRegion: CGRect, width: Int, height: Int) -> PixelRect {
        let imageRect = CGRect(x: 0, y: 0, width: width, height: height)
        let region = CGRect(
            x: normalizedRegion.minX * imageRect.width,
            y: normalizedRegion.minY * imageRect.height,
            width: normalizedRegion.width * imageRect.width,
            height: normalizedRegion.height * imageRect.height
        )
        let standardized = region.integral.intersection(imageRect)

        return PixelRect(
            minX: Int(standardized.minX),
            minY: Int(standardized.minY),
            width: Int(standardized.width),
            height: Int(standardized.height)
        )
    }
}

private struct PixelRect {
    let minX: Int
    let minY: Int
    let width: Int
    let height: Int
}
