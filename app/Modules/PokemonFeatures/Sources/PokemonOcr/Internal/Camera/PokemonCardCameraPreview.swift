//
//  PokemonCardCameraPreview.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct PokemonCardCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PokemonCardCameraPreviewView {
        let view = PokemonCardCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        return view
    }

    func updateUIView(_ view: PokemonCardCameraPreviewView, context: Context) {
        view.previewLayer.session = session
    }
}

final class PokemonCardCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("Pokemon card camera preview must use AVCaptureVideoPreviewLayer.")
        }

        return layer
    }
}
