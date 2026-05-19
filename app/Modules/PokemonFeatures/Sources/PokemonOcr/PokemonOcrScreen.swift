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
    @State private var cameraState = PokemonCardCameraState.idle
    @State private var capturedImage: UIImage?
    @State private var result: PokemonCardCropResult?
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
            PokemonCardCameraPreview(session: cameraController.session)
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button {
                    startCamera()
                } label: {
                    Label(
                        cameraState.canStartCamera ? "Start Camera" : "Camera Running",
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
                .disabled(!cameraState.canCaptureFrame || isLoading)
            }

            Text(cameraState.statusText)
                .foregroundColor(statusTextColor)
        }
    }

    private var statusTextColor: Color {
        switch cameraState {
        case .failed:
            .red
        case .idle, .requestingPermission, .running, .capturing:
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
        cameraController.start { state in
            cameraState = state
            if case .failed(let message) = state {
                errorMessage = message
            }
        } onFrameCaptured: { image in
            cropCard(from: image)
        }
    }

    private func captureFrame() {
        result = nil
        errorMessage = nil
        capturedImage = nil
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
}

#Preview {
    PokemonOcrScreen()
}
