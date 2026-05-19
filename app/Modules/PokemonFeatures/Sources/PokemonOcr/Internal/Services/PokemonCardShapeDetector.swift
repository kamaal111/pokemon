//
//  PokemonCardShapeDetector.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

import CoreGraphics
import UIKit
import Vision

struct PokemonCardShapeDetection: Equatable {
    let normalizedBoundingBox: CGRect
    let confidence: Float
    let normalizedCorners: PokemonCardShapeQuadrilateral?

    init(
        normalizedBoundingBox: CGRect,
        confidence: Float,
        normalizedCorners: PokemonCardShapeQuadrilateral? = nil
    ) {
        self.normalizedBoundingBox = normalizedBoundingBox
        self.confidence = confidence
        self.normalizedCorners = normalizedCorners
    }
}

enum PokemonCardShapeDetectionSource: String, Equatable {
    case vision = "Vision"
    case fallback = "Fallback"
}

struct PokemonCardShapeQuadrilateral: Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint

    var boundingBox: CGRect {
        let minimumX = min(topLeft.x, topRight.x, bottomRight.x, bottomLeft.x)
        let maximumX = max(topLeft.x, topRight.x, bottomRight.x, bottomLeft.x)
        let minimumY = min(topLeft.y, topRight.y, bottomRight.y, bottomLeft.y)
        let maximumY = max(topLeft.y, topRight.y, bottomRight.y, bottomLeft.y)

        return CGRect(x: minimumX, y: minimumY, width: maximumX - minimumX, height: maximumY - minimumY)
    }

    var averageSideAspectRatio: CGFloat {
        averageSideAspectRatio(imageAspectRatio: 1)
    }

    func averageSideAspectRatio(imageAspectRatio: CGFloat) -> CGFloat {
        let topWidth = distance(topLeft, topRight)
        let bottomWidth = distance(bottomLeft, bottomRight)
        let leftHeight = distance(topLeft, bottomLeft)
        let rightHeight = distance(topRight, bottomRight)
        let averageWidth = ((topWidth + bottomWidth) / 2) * imageAspectRatio
        let averageHeight = (leftHeight + rightHeight) / 2

        guard averageHeight > 0 else { return 0 }

        return averageWidth / averageHeight
    }

    var isConvex: Bool {
        let points = [topLeft, topRight, bottomRight, bottomLeft]
        var previousSign: CGFloat = 0

        for index in points.indices {
            let first = points[index]
            let second = points[(index + 1) % points.count]
            let third = points[(index + 2) % points.count]
            let crossProduct =
                ((second.x - first.x) * (third.y - second.y))
                - ((second.y - first.y) * (third.x - second.x))
            guard abs(crossProduct) > 0.0001 else {
                continue
            }

            let sign = crossProduct > 0 ? CGFloat(1) : CGFloat(-1)
            guard previousSign != 0 else {
                previousSign = sign
                continue
            }
            guard sign == previousSign else {
                return false
            }
        }

        return true
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}

struct PokemonCardShapeCandidateMetrics: Equatable {
    let confidence: Float
    let areaFraction: CGFloat
    let boundingAspectRatio: CGFloat
    let sideAspectRatio: CGFloat?
    let contentScore: CGFloat
    let shapeScore: CGFloat
}

enum PokemonCardShapeCandidateRejectionReason: String, Equatable {
    case lowConfidence
    case invalidBounds
    case tooSmall
    case tooLarge
    case unlikelyOrientation
    case poorScore
}

struct PokemonCardShapeCandidateEvaluation: Equatable {
    let score: CGFloat
    let metrics: PokemonCardShapeCandidateMetrics
    let rejectionReasons: [PokemonCardShapeCandidateRejectionReason]

    var isAccepted: Bool {
        rejectionReasons.isEmpty
    }
}

struct PokemonCardShapeDetectionCandidate: Equatable, Identifiable {
    let id: Int
    let detection: PokemonCardShapeDetection
    let source: PokemonCardShapeDetectionSource
    let evaluation: PokemonCardShapeCandidateEvaluation

    var isValid: Bool {
        evaluation.isAccepted
    }

    var score: CGFloat {
        evaluation.score
    }

    var metrics: PokemonCardShapeCandidateMetrics {
        evaluation.metrics
    }

    var rejectionReasons: [PokemonCardShapeCandidateRejectionReason] {
        evaluation.rejectionReasons
    }
}

struct PokemonCardShapeDetectionReport: Equatable {
    let frameSize: CGSize
    let candidates: [PokemonCardShapeDetectionCandidate]
    let selectedDetection: PokemonCardShapeDetection?

    var validCandidateCount: Int {
        candidates.filter(\.isValid).count
    }

    var bestRejectedCandidate: PokemonCardShapeDetectionCandidate? {
        candidates
            .filter { !$0.isValid }
            .sorted { $0.score > $1.score }
            .first
    }
}

enum PokemonCardShapeDetectionError: LocalizedError, Equatable {
    case invalidImage
    case visionRequestFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The camera frame could not be analyzed."
        case .visionRequestFailed:
            "The card shape could not be detected."
        }
    }
}

struct PokemonCardShapeDetector {
    struct Configuration {
        let minimumConfidence: Float
        let minimumAreaFraction: CGFloat
        let maximumAreaFraction: CGFloat
        let minimumToleratedAspectRatio: CGFloat
        let maximumToleratedAspectRatio: CGFloat
        let minimumAcceptedScore: CGFloat
        let maximumObservations: Int

        static let `default` = Configuration(
            minimumConfidence: 0.55,
            minimumAreaFraction: 0.035,
            maximumAreaFraction: 0.86,
            minimumToleratedAspectRatio: 0.45,
            maximumToleratedAspectRatio: 1.05,
            minimumAcceptedScore: 0.55,
            maximumObservations: 8
        )
    }

    private init() {}

    static func detectCardShape(
        in image: UIImage,
        configuration: Configuration = .default
    ) -> Result<PokemonCardShapeDetection?, PokemonCardShapeDetectionError> {
        detectCardShapeReport(in: image, configuration: configuration)
            .map(\.selectedDetection)
    }

    static func detectCardShapeReport(
        in image: UIImage,
        configuration: Configuration = .default
    ) -> Result<PokemonCardShapeDetectionReport, PokemonCardShapeDetectionError> {
        let normalizedImage = image.normalizedForPokemonOcr()
        guard let cgImage = normalizedImage.cgImage else {
            return .failure(.invalidImage)
        }

        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = configuration.minimumConfidence
        request.maximumObservations = configuration.maximumObservations
        request.minimumAspectRatio = Float(configuration.minimumToleratedAspectRatio)
        request.maximumAspectRatio = Float(configuration.maximumToleratedAspectRatio)
        request.minimumSize = Float(configuration.minimumAreaFraction.squareRoot())
        request.quadratureTolerance = 45

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return .success(
                fallbackReport(
                    in: normalizedImage,
                    visionCandidates: [],
                    configuration: configuration
                ))
        }

        let detections =
            (request.results ?? [])
            .map { observation in
                let quadrilateral = PokemonCardShapeQuadrilateral(
                    topLeft: observation.topLeft,
                    topRight: observation.topRight,
                    bottomRight: observation.bottomRight,
                    bottomLeft: observation.bottomLeft
                )

                return PokemonCardShapeDetection(
                    normalizedBoundingBox: observation.boundingBox,
                    confidence: observation.confidence,
                    normalizedCorners: quadrilateral
                )
            }
        let visionCandidates = candidates(
            from: detections,
            source: .vision,
            startingAt: 0,
            imageSize: normalizedImage.size,
            configuration: configuration
        )

        if let detection = bestDetection(in: visionCandidates) {
            return .success(
                PokemonCardShapeDetectionReport(
                    frameSize: normalizedImage.size,
                    candidates: visionCandidates,
                    selectedDetection: detection
                ))
        }

        return .success(
            fallbackReport(
                in: normalizedImage,
                visionCandidates: visionCandidates,
                configuration: configuration
            ))
    }

    static func bestDetection(
        in detections: [PokemonCardShapeDetection],
        configuration: Configuration = .default
    ) -> PokemonCardShapeDetection? {
        let candidates = candidates(
            from: detections,
            source: .vision,
            startingAt: 0,
            imageSize: nil,
            configuration: configuration
        )

        return bestDetection(in: candidates)
    }

    static func isValid(
        _ detection: PokemonCardShapeDetection,
        configuration: Configuration = .default
    ) -> Bool {
        scoreCandidate(detection, configuration: configuration).isAccepted
    }

    static func scoreCandidate(
        _ detection: PokemonCardShapeDetection,
        configuration: Configuration = .default,
        imageSize: CGSize? = nil,
        contentScore: CGFloat = 0.5
    ) -> PokemonCardShapeCandidateEvaluation {
        let rect = detection.normalizedBoundingBox.standardized
        let area = rect.width * rect.height
        let imageAspectRatio = normalizedImageAspectRatio(for: imageSize)
        let boundingAspectRatio = rect.height > 0 ? (rect.width * imageAspectRatio) / rect.height : 0
        let sideAspectRatio = detection.normalizedCorners.map {
            $0.averageSideAspectRatio(imageAspectRatio: imageAspectRatio)
        }
        let scoringAspectRatio = sideAspectRatio ?? boundingAspectRatio
        let confidenceScore = clamped(CGFloat(detection.confidence))
        let areaScore = scoreArea(area)
        let aspectScore = scoreAspectRatio(scoringAspectRatio, configuration: configuration)
        let shapeScore = scoreShape(detection.normalizedCorners)
        let normalizedContentScore = clamped(contentScore)
        let score =
            (confidenceScore * 0.30)
            + (areaScore * 0.20)
            + (aspectScore * 0.20)
            + (normalizedContentScore * 0.20)
            + (shapeScore * 0.10)

        let metrics = PokemonCardShapeCandidateMetrics(
            confidence: detection.confidence,
            areaFraction: area,
            boundingAspectRatio: boundingAspectRatio,
            sideAspectRatio: sideAspectRatio,
            contentScore: normalizedContentScore,
            shapeScore: shapeScore
        )
        var rejectionReasons: [PokemonCardShapeCandidateRejectionReason] = []

        if detection.confidence < configuration.minimumConfidence {
            rejectionReasons.append(.lowConfidence)
        }
        if rect.width <= 0 || rect.height <= 0 || rect.minX < 0 || rect.minY < 0 || rect.maxX > 1 || rect.maxY > 1 {
            rejectionReasons.append(.invalidBounds)
        }
        if area < configuration.minimumAreaFraction {
            rejectionReasons.append(.tooSmall)
        }
        if area > configuration.maximumAreaFraction {
            rejectionReasons.append(.tooLarge)
        }
        if boundingAspectRatio > 1.25 || scoringAspectRatio < 0.32 || scoringAspectRatio > 1.18 {
            rejectionReasons.append(.unlikelyOrientation)
        }
        if score < configuration.minimumAcceptedScore {
            rejectionReasons.append(.poorScore)
        }

        return PokemonCardShapeCandidateEvaluation(
            score: score,
            metrics: metrics,
            rejectionReasons: rejectionReasons
        )
    }

    static func fallbackDetection(
        in image: UIImage,
        configuration: Configuration
    ) -> PokemonCardShapeDetection? {
        guard let detection = fallbackCandidateDetection(in: image, configuration: configuration) else {
            return nil
        }
        guard isValid(detection, configuration: configuration) else {
            return nil
        }

        return detection
    }

    private static func shapeFallbackCandidate(
        in image: UIImage,
        configuration: Configuration
    ) -> CGRect? {
        guard let analysisImage = ShapeFallbackAnalysisImage(image: image, maxDimension: 260) else {
            return nil
        }

        let mask = analysisImage.cardShapeMask()
        let dilatedMask = analysisImage.dilated(mask: mask, radius: 4)
        let imageArea = CGFloat(analysisImage.width * analysisImage.height)
        let rankedComponents =
            analysisImage.components(in: dilatedMask)
            .filter { component in
                let rect = component.rect
                let areaFraction = CGFloat(component.pixelCount) / imageArea
                return rect.width >= 10
                    && rect.height >= 10
                    && areaFraction >= configuration.minimumAreaFraction * 0.45
                    && areaFraction <= configuration.maximumAreaFraction
                    && rect.width / rect.height <= 1.25
            }
            .sorted { lhs, rhs in
                analysisImage.score(component: lhs) > analysisImage.score(component: rhs)
            }

        guard let component = rankedComponents.first else {
            return nil
        }

        return analysisImage.imageRect(fromAnalysisRect: component.rect)
    }

    private static func fallbackReport(
        in image: UIImage,
        visionCandidates: [PokemonCardShapeDetectionCandidate],
        configuration: Configuration
    ) -> PokemonCardShapeDetectionReport {
        guard let fallbackDetection = fallbackCandidateDetection(in: image, configuration: configuration) else {
            return PokemonCardShapeDetectionReport(
                frameSize: image.size,
                candidates: visionCandidates,
                selectedDetection: nil
            )
        }

        let fallbackCandidates = candidates(
            from: [fallbackDetection],
            source: .fallback,
            startingAt: visionCandidates.count,
            imageSize: image.size,
            configuration: configuration
        )
        let allCandidates = visionCandidates + fallbackCandidates
        let selectedDetection = bestDetection(in: allCandidates)

        return PokemonCardShapeDetectionReport(
            frameSize: image.size,
            candidates: allCandidates,
            selectedDetection: selectedDetection
        )
    }

    private static func fallbackCandidateDetection(
        in image: UIImage,
        configuration: Configuration
    ) -> PokemonCardShapeDetection? {
        let candidate =
            shapeFallbackCandidate(in: image, configuration: configuration)
            ?? PokemonCardCropper.likelyCardRegion(in: image)
        guard let candidate else { return nil }

        return PokemonCardShapeDetection(
            normalizedBoundingBox: visionNormalizedRect(for: candidate, imageSize: image.size),
            confidence: 0.62
        )
    }

    private static func candidates(
        from detections: [PokemonCardShapeDetection],
        source: PokemonCardShapeDetectionSource,
        startingAt startingID: Int,
        imageSize: CGSize?,
        configuration: Configuration
    ) -> [PokemonCardShapeDetectionCandidate] {
        detections.enumerated().map { offset, detection in
            PokemonCardShapeDetectionCandidate(
                id: startingID + offset,
                detection: detection,
                source: source,
                evaluation: scoreCandidate(
                    detection,
                    configuration: configuration,
                    imageSize: imageSize,
                    contentScore: source == .fallback ? 0.75 : 0.5
                )
            )
        }
    }

    private static func bestDetection(in candidates: [PokemonCardShapeDetectionCandidate]) -> PokemonCardShapeDetection?
    {
        candidates
            .filter(\.isValid)
            .sorted { $0.score > $1.score }
            .first?
            .detection
    }

    private static func scoreArea(_ area: CGFloat) -> CGFloat {
        guard area > 0 else { return 0 }

        if area < 0.10 {
            return clamped(area / 0.10)
        }
        if area <= 0.45 {
            return 1
        }

        return clamped(1 - ((area - 0.45) / 0.41))
    }

    private static func scoreAspectRatio(
        _ aspectRatio: CGFloat,
        configuration: Configuration
    ) -> CGFloat {
        guard aspectRatio > 0 else { return 0 }
        guard aspectRatio >= configuration.minimumToleratedAspectRatio else {
            return clamped(aspectRatio / configuration.minimumToleratedAspectRatio)
        }
        guard aspectRatio <= configuration.maximumToleratedAspectRatio else {
            return clamped(1 - ((aspectRatio - configuration.maximumToleratedAspectRatio) / 0.20))
        }

        let target = PokemonCardCropper.targetAspectRatio
        let maximumDeviation = max(
            target - configuration.minimumToleratedAspectRatio,
            configuration.maximumToleratedAspectRatio - target
        )
        let deviation = abs(aspectRatio - target)

        return clamped(1 - (deviation / maximumDeviation) * 0.45)
    }

    private static func normalizedImageAspectRatio(for imageSize: CGSize?) -> CGFloat {
        guard let imageSize else { return 1 }
        guard imageSize.width > 0 else { return 1 }
        guard imageSize.height > 0 else { return 1 }

        return imageSize.width / imageSize.height
    }

    private static func scoreShape(_ quadrilateral: PokemonCardShapeQuadrilateral?) -> CGFloat {
        guard let quadrilateral else { return 0.6 }
        guard quadrilateral.isConvex else { return 0.1 }

        let boundingBox = quadrilateral.boundingBox.standardized
        guard boundingBox.width > 0, boundingBox.height > 0 else { return 0.1 }

        let sideAspectRatio = quadrilateral.averageSideAspectRatio
        guard sideAspectRatio > 0.28, sideAspectRatio < 1.22 else {
            return 0.35
        }

        return 1
    }

    private static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    private static func visionNormalizedRect(for imageRect: CGRect, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let clippedRect = imageBounds.intersection(imageRect.standardized)
        guard !clippedRect.isNull else {
            return .zero
        }

        return CGRect(
            x: clippedRect.minX / imageSize.width,
            y: 1 - (clippedRect.maxY / imageSize.height),
            width: clippedRect.width / imageSize.width,
            height: clippedRect.height / imageSize.height
        )
    }
}

private struct ShapeFallbackComponent {
    let rect: CGRect
    let pixelCount: Int
}

private struct ShapeFallbackAnalysisImage {
    struct Pixel {
        let luminance: CGFloat
        let saturation: CGFloat
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
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        guard
            let context = CGContext(
                data: &bytes,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

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
                saturation: saturation
            )
        }
        borderPixel = Self.averageBorderPixel(pixels: pixels, width: width, height: height)
    }

    func cardShapeMask() -> [Bool] {
        pixels.map { pixel in
            let darkerThanLightTable =
                borderPixel.luminance > 0.55
                && pixel.luminance < borderPixel.luminance - 0.10
                && (pixel.saturation > 0.08 || pixel.luminance < borderPixel.luminance - 0.20)
            let colorfulCard =
                pixel.saturation > borderPixel.saturation + 0.12
                && abs(pixel.luminance - borderPixel.luminance) > 0.04

            return darkerThanLightTable || colorfulCard
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

    func components(in mask: [Bool]) -> [ShapeFallbackComponent] {
        var visited = [Bool](repeating: false, count: mask.count)
        var components: [ShapeFallbackComponent] = []

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
                    ShapeFallbackComponent(
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

    func score(component: ShapeFallbackComponent) -> CGFloat {
        let rect = component.rect
        let imageArea = CGFloat(width * height)
        let areaFraction = CGFloat(component.pixelCount) / imageArea
        let aspectRatio = rect.width / rect.height
        let aspectDeviation = abs(aspectRatio - PokemonCardCropper.targetAspectRatio)
        let aspectScore = max(0, 1 - min(aspectDeviation / PokemonCardCropper.targetAspectRatio, 1))

        return (areaFraction * 3) + (aspectScore * 2)
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
        var luminance: CGFloat = 0
        var saturation: CGFloat = 0
        var count: CGFloat = 0

        for y in 0..<height {
            for x in 0..<width {
                guard
                    x < borderThickness
                        || y < borderThickness
                        || x >= width - borderThickness
                        || y >= height - borderThickness
                else { continue }

                let pixel = pixels[(y * width) + x]
                luminance += pixel.luminance
                saturation += pixel.saturation
                count += 1
            }
        }

        guard count > 0 else {
            return Pixel(luminance: 0, saturation: 0)
        }

        return Pixel(luminance: luminance / count, saturation: saturation / count)
    }
}
