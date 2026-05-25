//
//  PokemonOcrScreen.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Foundation
import PokemonCardCropping
import PokemonCardDetection
import PokemonCardPipeline
import SwiftUI

public struct PokemonOcrScreen: View {
    @State private var cameraController = PokemonCardCameraController()
    @State private var cameraState = PokemonCardCameraState.idle
    @State private var capturedImage: UIImage?
    @State private var result: PokemonCardCropResult?
    @State private var detectionReport: PokemonCardShapeDetectionReport?
    @State private var errorMessage: String?
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    cameraSection

                    if let capturedImage {
                        imageSection(title: "Original", image: capturedImage)
                    }

                    if let cropImage = result?.cropImage {
                        imageSection(title: "Card Crop", image: cropImage)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }

                }
                .padding()
            }
            .navigationTitle("Pokemon OCR")
            .onDisappear {
                cameraController.stop()
            }
        }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                PokemonCardCameraPreview(session: cameraController.session)
                PokemonCardShapeOverlay(report: detectionReport)
            }
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button {
                    startCamera()
                } label: {
                    Label(
                        startCameraButtonTitle,
                        systemImage: "camera"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!cameraState.canStartCamera || isLoading)

                Button {
                    captureFrame()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                        }

                        Label(isLoading ? "Cropping" : "Crop Frame", systemImage: "crop")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!cameraState.canUseManualCropFallback || isLoading)
            }

            detectionFeedback

            Text(cameraState.statusText)
                .foregroundColor(statusTextColor)
        }
    }

    private var startCameraButtonTitle: String {
        switch cameraState {
        case .completed:
            "Scan Again"
        case .idle, .failed:
            "Start Camera"
        case .requestingPermission, .running, .capturing:
            "Camera Running"
        }
    }

    private var detectionFeedback: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Shape detection")
                .font(.subheadline.weight(.semibold))

            if let detectionReport, let currentDetection = detectionReport.selectedDetection {
                Text(
                    "Candidate confidence \(confidenceText(for: currentDetection.confidence)) "
                        + "rect \(rectText(for: currentDetection.normalizedBoundingBox))"
                )
                .foregroundColor(.secondary)
                .font(.footnote.monospacedDigit())
            } else if let detectionReport {
                Text(
                    "No valid card yet. Candidates \(detectionReport.candidates.count), "
                        + "valid \(detectionReport.validCandidateCount), "
                        + "frame \(frameText(for: detectionReport.frameSize)). "
                        + bestRejectedText(for: detectionReport)
                )
                .foregroundColor(.secondary)
                .font(.footnote.monospacedDigit())
            } else if cameraState == .running {
                Text("No card-shaped rectangle yet.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            } else {
                Text("Start scanning to see candidate rectangle feedback.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
        }
    }

    private var statusTextColor: Color {
        switch cameraState {
        case .failed:
            .red
        case .idle, .requestingPermission, .running, .capturing, .completed:
            .secondary
        }
    }

    private func imageSection(title: String, image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func startCamera() {
        result = nil
        errorMessage = nil
        capturedImage = nil
        detectionReport = nil
        cameraController.start { state in
            cameraState = state
            if case .failed(let message) = state {
                errorMessage = message
            }
        } onDetectionReportChange: { report in
            detectionReport = report
        } onFrameCaptured: { image in
            cropCard(from: image)
        } onDetectedFrameCaptured: { capture in
            finishDetectedCardCapture(capture)
        }
    }

    private func captureFrame() {
        result = nil
        errorMessage = nil
        capturedImage = nil
        detectionReport = nil
        cameraController.captureCurrentFrame()
    }

    private func cropCard(from image: UIImage) {
        isLoading = true
        errorMessage = nil
        capturedImage = image

        Task.detached(priority: .userInitiated) {
            let cropResult = PokemonCardCropper.cropCard(from: image)

            await MainActor.run {
                switch cropResult {
                case .success(let value):
                    result = value
                    cameraState = .running
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    cameraState = .failed(error.localizedDescription)
                }

                isLoading = false
            }
        }
    }

    private func finishDetectedCardCapture(_ capture: PokemonCardPipelineCapture) {
        isLoading = false
        errorMessage = nil
        capturedImage = capture.originalImage
        result = capture.cropResult
        cameraState = .completed
    }

    private func confidenceText(for confidence: Float) -> String {
        confidence.formatted(.number.precision(.fractionLength(2)))
    }

    private func rectText(for rect: CGRect) -> String {
        let standardizedRect = rect.standardized
        return [
            standardizedRect.minX,
            standardizedRect.minY,
            standardizedRect.width,
            standardizedRect.height,
        ]
        .map { value in Double(value).formatted(.number.precision(.fractionLength(2))) }
        .joined(separator: ", ")
    }

    private func frameText(for frameSize: CGSize) -> String {
        "\(Int(frameSize.width))x\(Int(frameSize.height))"
    }

    private func bestRejectedText(for report: PokemonCardShapeDetectionReport) -> String {
        guard let candidate = report.bestRejectedCandidate else {
            return ""
        }

        let score = Double(candidate.score).formatted(.number.precision(.fractionLength(2)))
        let reasons = candidate.rejectionReasons.map(\.rawValue).joined(separator: ",")

        return "Best rejected: score \(score), \(reasons)."
    }
}

#Preview {
    PokemonOcrScreen()
}
