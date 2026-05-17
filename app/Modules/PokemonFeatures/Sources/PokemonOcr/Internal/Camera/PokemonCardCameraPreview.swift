//
//  PokemonCardCameraPreview.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct PokemonCardCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let candidateRectangles: [CGRect]

    func makeUIView(context: Context) -> PokemonCardCameraPreviewView {
        let view = PokemonCardCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.setCandidateRectangles(candidateRectangles)

        return view
    }

    func updateUIView(_ view: PokemonCardCameraPreviewView, context: Context) {
        view.previewLayer.session = session
        view.setCandidateRectangles(candidateRectangles)
    }
}

final class PokemonCardCameraPreviewView: UIView {
    private let candidateRectangleLayer = CAShapeLayer()
    private var candidateRectangles: [CGRect] = []

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCandidateRectangleLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureCandidateRectangleLayer()
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("Pokemon card camera preview must use AVCaptureVideoPreviewLayer.")
        }

        return layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        candidateRectangleLayer.frame = bounds
        updateCandidateRectanglePath()
    }

    func setCandidateRectangles(_ candidateRectangles: [CGRect]) {
        self.candidateRectangles = candidateRectangles
        updateCandidateRectanglePath()
    }

    private func configureCandidateRectangleLayer() {
        candidateRectangleLayer.fillColor = UIColor.clear.cgColor
        candidateRectangleLayer.strokeColor = UIColor.systemRed.cgColor
        candidateRectangleLayer.lineWidth = 3
        candidateRectangleLayer.shadowColor = UIColor.black.cgColor
        candidateRectangleLayer.shadowOffset = CGSize(width: 0, height: 1)
        candidateRectangleLayer.shadowOpacity = 0.7
        candidateRectangleLayer.shadowRadius = 1
        previewLayer.addSublayer(candidateRectangleLayer)
    }

    private func updateCandidateRectanglePath() {
        let path = UIBezierPath()
        for candidateRectangle in candidateRectangles {
            path.append(UIBezierPath(rect: previewRect(for: candidateRectangle)))
        }

        candidateRectangleLayer.path = path.cgPath
    }

    private func previewRect(for visionRectangle: CGRect) -> CGRect {
        let metadataRectangle = CGRect(
            x: visionRectangle.minX,
            y: 1 - visionRectangle.maxY,
            width: visionRectangle.width,
            height: visionRectangle.height
        )

        return previewLayer.layerRectConverted(fromMetadataOutputRect: metadataRectangle)
    }
}
