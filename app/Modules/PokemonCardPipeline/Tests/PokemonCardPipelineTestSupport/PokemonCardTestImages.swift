//
//  PokemonCardTestImages.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/31/26.
//

import CoreGraphics
import UIKit

public enum PokemonCardTestImages {
    public static func compactPipelineCard(lineWidth: CGFloat) -> UIImage {
        syntheticCard(
            size: CGSize(width: 240, height: 336),
            textLineCount: 5,
            textX: 16,
            firstTextY: 14,
            textRowSpacing: 12,
            primaryLineWidth: lineWidth,
            secondaryLineWidth: lineWidth * 0.62,
            lineHeight: 3,
            artRect: CGRect(x: 16, y: 96, width: 208, height: 160)
        )
    }

    public static func focusQualityCard(
        background: UIColor = .white,
        text: UIColor = .black
    ) -> UIImage {
        syntheticCard(
            size: CGSize(width: 360, height: 500),
            background: background,
            text: text,
            textLineCount: 6,
            textX: 34,
            firstTextY: 26,
            textRowSpacing: 16,
            primaryLineWidth: 235,
            secondaryLineWidth: 170,
            lineHeight: 4,
            artRect: CGRect(x: 28, y: 150, width: 304, height: 210)
        )
    }

    private static func syntheticCard(
        size: CGSize,
        background: UIColor = .white,
        text: UIColor = .black,
        textLineCount: Int,
        textX: CGFloat,
        firstTextY: Int,
        textRowSpacing: Int,
        primaryLineWidth: CGFloat,
        secondaryLineWidth: CGFloat,
        lineHeight: CGFloat,
        artRect: CGRect
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            text.setFill()
            for row in 0..<textLineCount {
                let y = firstTextY + (row * textRowSpacing)
                context.fill(CGRect(x: textX, y: CGFloat(y), width: primaryLineWidth, height: lineHeight))
                context.fill(CGRect(x: textX, y: CGFloat(y + 6), width: secondaryLineWidth, height: lineHeight))
            }

            UIColor.systemYellow.setFill()
            context.fill(artRect)
        }
    }
}
