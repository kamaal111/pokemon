//
//  PokemonCardVideoFrameSnapshotter.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

import CoreImage
import CoreMedia
import UIKit

enum PokemonCardVideoFrameSnapshotter {
    static func image(from sampleBuffer: CMSampleBuffer, context: CIContext = CIContext()) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
