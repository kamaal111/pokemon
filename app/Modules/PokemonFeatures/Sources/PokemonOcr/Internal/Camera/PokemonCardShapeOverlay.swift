//
//  PokemonCardShapeOverlay.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/24/26.
//

import CoreGraphics
import SwiftUI

enum PokemonCardShapeOverlayGeometry {
    static func overlayRect(
        for normalizedRect: CGRect,
        frameSize: CGSize,
        viewSize: CGSize
    ) -> CGRect {
        guard frameSize.width > 0 else { return .zero }
        guard frameSize.height > 0 else { return .zero }
        guard viewSize.width > 0 else { return .zero }
        guard viewSize.height > 0 else { return .zero }

        let frameAspectRatio = frameSize.width / frameSize.height
        let viewAspectRatio = viewSize.width / viewSize.height
        let displaySize: CGSize
        if frameAspectRatio > viewAspectRatio {
            displaySize = CGSize(
                width: viewSize.height * frameAspectRatio,
                height: viewSize.height
            )
        } else {
            displaySize = CGSize(
                width: viewSize.width,
                height: viewSize.width / frameAspectRatio
            )
        }

        let displayOrigin = CGPoint(
            x: (viewSize.width - displaySize.width) / 2,
            y: (viewSize.height - displaySize.height) / 2
        )
        let standardizedRect = normalizedRect.standardized

        return CGRect(
            x: displayOrigin.x + standardizedRect.minX * displaySize.width,
            y: displayOrigin.y + (1 - standardizedRect.maxY) * displaySize.height,
            width: standardizedRect.width * displaySize.width,
            height: standardizedRect.height * displaySize.height
        )
    }
}

struct PokemonCardShapeOverlay: View {
    let report: PokemonCardShapeDetectionReport?

    var body: some View {
        GeometryReader { geometry in
            if let report {
                ForEach(report.candidates) { candidate in
                    let rect = PokemonCardShapeOverlayGeometry.overlayRect(
                        for: candidate.detection.normalizedBoundingBox,
                        frameSize: report.frameSize,
                        viewSize: geometry.size
                    )
                    candidateOverlay(candidate, rect: rect)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func candidateOverlay(
        _ candidate: PokemonCardShapeDetectionCandidate,
        rect: CGRect
    ) -> some View {
        let color = color(for: candidate)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .path(in: rect)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: candidate.isValid ? 3 : 2,
                        dash: candidate.isValid ? [] : [6, 4]
                    )
                )

            Text(label(for: candidate))
                .font(.caption2.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .foregroundStyle(.black)
                .background(color.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .position(x: rect.minX + 34, y: max(rect.minY + 12, 12))
        }
    }

    private func color(for candidate: PokemonCardShapeDetectionCandidate) -> Color {
        guard candidate.isValid else {
            return .orange
        }

        switch candidate.source {
        case .vision:
            return .green
        case .fallback:
            return .cyan
        }
    }

    private func label(for candidate: PokemonCardShapeDetectionCandidate) -> String {
        let prefix =
            switch candidate.source {
            case .vision:
                "V"
            case .fallback:
                "F"
            }
        let confidence = candidate.detection.confidence.formatted(
            .number.precision(.fractionLength(2))
        )
        let score = Double(candidate.score).formatted(.number.precision(.fractionLength(2)))

        return "\(prefix) \(confidence) \(score)"
    }
}
