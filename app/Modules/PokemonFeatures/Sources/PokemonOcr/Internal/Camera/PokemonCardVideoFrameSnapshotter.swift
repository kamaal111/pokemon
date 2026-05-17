//
//  PokemonCardVideoFrameSnapshotter.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import CoreImage
import CoreMedia
import UIKit

enum PokemonCardVideoFrameSnapshotter {
    static func cardSnapshot(
        from sampleBuffer: CMSampleBuffer,
        detection: PokemonCardShapeDetection
    ) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let context = CIContext()
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }

        let frameImage = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        return PokemonCardSnapshotCropper.cropCard(from: frameImage, detection: detection)
    }
}
