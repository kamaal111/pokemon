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
import PokemonCardTextExtraction
import SwiftUI

public struct PokemonOcrScreen: View {
    @State private var cameraController = PokemonCardCameraController()
    @State private var cameraState = PokemonCardCameraState.idle
    @State private var capturedImage: UIImage?
    @State private var result: PokemonCardCropResult?
    @State private var detectionReport: PokemonCardShapeDetectionReport?
    @State private var textExtractionResult: PokemonCardTextExtractionResult?
    @State private var pokemonName: String?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isExtractingText = false

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    cameraSection

                    if let pokemonName {
                        pokemonNameSection(pokemonName)
                    }

                    if let capturedImage {
                        imageSection(title: "Original", image: capturedImage)
                    }

                    if let cropImage = result?.cropImage {
                        cardCropSection(image: cropImage)
                    }

                    if isExtractingText {
                        ProgressView("Extracting text")
                    }

                    if let textExtractionResult {
                        textExtractionSection(textExtractionResult)
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

    private func pokemonNameSection(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pokemon Name")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(name)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .disabled(!cameraState.canStartCamera || isLoading || isExtractingText)

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
                .disabled(!cameraState.canUseManualCropFallback || isLoading || isExtractingText)
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
        case .requestingPermission, .running, .holdingSteady, .moveFartherAway, .moreLightNeeded, .capturing:
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
            } else if cameraState.canUseManualCropFallback {
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
        case .moveFartherAway, .moreLightNeeded:
            .orange
        case .idle, .requestingPermission, .running, .holdingSteady, .capturing, .completed:
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

    private func cardCropSection(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card Crop")
                .font(.headline)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    if let observations = textExtractionResult?.observations {
                        ForEach(observations) { observation in
                            let rect = PokemonCardTextOverlayGeometry.displayRect(
                                for: observation.normalizedBoundingBox,
                                imageSize: image.size,
                                containerSize: geometry.size
                            )

                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.green, lineWidth: 2)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)

                            Text(shortOverlayLabel(for: observation))
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.72))
                                .position(x: rect.midX, y: max(8, rect.minY - 8))
                        }
                    }
                }
            }
            .aspectRatio(image.size, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func textExtractionSection(
        _ result: PokemonCardTextExtractionResult
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !result.combinedText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recognized Text")
                        .font(.headline)

                    Text(result.combinedText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Passes")
                    .font(.headline)

                ForEach(result.passes, id: \.label) { report in
                    Text(PokemonCardTextPassReportFormatter.summary(for: report))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(report.errorMessage == nil ? .secondary : .red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Debug Images")
                    .font(.headline)

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 140), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(result.debugImages) { debugImage in
                        VStack(alignment: .leading, spacing: 4) {
                            Image(uiImage: debugImage.image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(debugImage.label)
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    private func startCamera() {
        result = nil
        textExtractionResult = nil
        pokemonName = nil
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
        textExtractionResult = nil
        pokemonName = nil
        errorMessage = nil
        capturedImage = nil
        detectionReport = nil
        cameraController.captureCurrentFrame()
    }

    private func cropCard(from image: UIImage) {
        isLoading = true
        errorMessage = nil
        pokemonName = nil
        capturedImage = image

        Task.detached(priority: .userInitiated) {
            let cropResult = PokemonCardCropper.cropCard(from: image)

            await MainActor.run {
                switch cropResult {
                case .success(let value):
                    result = value
                    cameraState = .running
                    extractText(from: value.cropImage)
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
        pokemonName = capture.pokemonName
        cameraState = .completed
        extractText(from: capture.cropResult.cropImage)
    }

    private func extractText(from image: UIImage) {
        isExtractingText = true
        textExtractionResult = nil

        Task.detached(priority: .userInitiated) {
            let extractionResult = await PokemonCardTextExtractor().extractText(from: image)

            await MainActor.run {
                switch extractionResult {
                case .success(let value):
                    textExtractionResult = value
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }

                isExtractingText = false
            }
        }
    }

    private func shortOverlayLabel(for observation: PokemonCardTextObservation) -> String {
        let text = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 18 else { return text }

        let endIndex = text.index(text.startIndex, offsetBy: 18)
        return String(text[..<endIndex]) + "..."
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
