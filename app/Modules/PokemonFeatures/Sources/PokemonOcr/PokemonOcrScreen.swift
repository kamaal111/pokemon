//
//  PokemonOcrScreen.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Foundation
import SwiftUI

public struct PokemonOcrScreen: View {
    @State private var cameraController = PokemonCardCameraController()
    @State private var detectionState = PokemonCardDetectionState.idle
    @State private var candidateRectangles: [CGRect] = []
    @State private var capturedImage: UIImage?
    @State private var selectedSample = PokemonOcrSampleCard.allCases[0]
    @State private var result: PokemonCardNameExtractionResult?
    @State private var errorMessage: String?
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        PokemonCardCameraPreview(
                            session: cameraController.session,
                            candidateRectangles: candidateRectangles
                        )
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            startCardDetection()
                        } label: {
                            HStack {
                                Image(systemName: "camera")
                                Text(detectionState.canStartDetection ? "Scan Card" : "Scanning")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(!detectionState.canStartDetection)

                        Text(detectionState.statusText)
                            .foregroundColor(statusTextColor)
                    }
                    .disabled(isLoading)

                    if let capturedImage {
                        imageSection(title: "Captured", image: capturedImage)
                    }

                    sampleSection

                    if let cropImage = result?.titleCropImage {
                        imageSection(title: "Title Crop", image: cropImage)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }

                    if let result {
                        resultSection(result)
                    }
                }
                .padding()
            }
            .navigationTitle("Pokemon OCR")
            .onDisappear {
                cameraController.stopDetection()
            }
        }
    }

    private var sampleSection: some View {
        DisclosureGroup("Sample OCR Debug") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Sample", selection: $selectedSample) {
                    ForEach(PokemonOcrSampleCard.allCases) { sample in
                        Text(sample.title).tag(sample)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isLoading || !detectionState.canStartDetection)
                .onChange(of: selectedSample) { _ in
                    result = nil
                    errorMessage = nil
                }

                imageSection(title: "Sample", image: selectedSample.image)

                Button {
                    runOcr(on: selectedSample.image, finishedState: nil)
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                        }

                        Text(isLoading ? "Reading" : "Run Sample OCR")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading)
            }
        }
    }

    private var statusTextColor: Color {
        switch detectionState {
        case .failed:
            .red
        case .finished:
            .green
        case .idle, .requestingPermission, .detecting, .capturing, .reading:
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

    private func resultSection(_ result: PokemonCardNameExtractionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedCandidate = result.selectedCandidate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Candidate")
                        .font(.headline)
                    Text(selectedCandidate.text)
                    Text(selectedCandidate.normalizedText)
                        .font(.title3.bold())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Candidates")
                    .font(.headline)

                ForEach(result.rawCandidates) { candidate in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(candidate.text)
                            Text(candidate.normalizedText)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(String(format: "%.2f", candidate.confidence))
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }

    private func startCardDetection() {
        result = nil
        errorMessage = nil
        capturedImage = nil
        candidateRectangles = []

        if let fakeCaptureImage = fakeCameraCaptureImage {
            simulateCameraCapture(with: fakeCaptureImage)
            return
        }

        cameraController.startDetection { state in
            detectionState = state
            if case .failed(let message) = state {
                errorMessage = message
            }
        } onCandidateRectanglesChange: { rectangles in
            candidateRectangles = rectangles
        } onPhotoCaptured: { image in
            capturedImage = image
            runOcr(on: image, finishedState: .finished)
        }
    }

    private var fakeCameraCaptureImage: UIImage? {
        guard
            ProcessInfo.processInfo.environment["POKEMON_UI_TEST_FAKE_CAMERA_CAPTURE"] == "eevee"
        else {
            return nil
        }

        return PokemonOcrSampleCard.eevee.image
    }

    private func simulateCameraCapture(with image: UIImage) {
        detectionState = .detecting

        Task {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            detectionState = .capturing

            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            capturedImage = image
            runOcr(on: image, finishedState: .finished)
        }
    }

    private func runOcr(on image: UIImage, finishedState: PokemonCardDetectionState?) {
        isLoading = true
        errorMessage = nil
        if finishedState != nil {
            detectionState = .reading
        }

        Task.detached(priority: .userInitiated) {
            let extractionResult = await PokemonCardNameExtractor().extractName(from: image)

            await MainActor.run {
                switch extractionResult {
                case .success(let value):
                    result = value
                    if let finishedState {
                        detectionState = finishedState
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    detectionState = .failed(error.localizedDescription)
                }

                isLoading = false
            }
        }
    }
}

#Preview {
    PokemonOcrScreen()
}
