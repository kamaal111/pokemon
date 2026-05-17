//
//  PokemonOcrScreen.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Foundation
import SwiftUI

public struct PokemonOcrScreen: View {
    @State private var selectedSample = PokemonOcrSampleCard.allCases[0]
    @State private var result: PokemonCardNameExtractionResult?
    @State private var errorMessage: String?
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Sample", selection: $selectedSample) {
                        ForEach(PokemonOcrSampleCard.allCases) { sample in
                            Text(sample.title).tag(sample)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isLoading)
                    .onChange(of: selectedSample) { _ in
                        result = nil
                        errorMessage = nil
                    }

                    imageSection(title: "Original", image: selectedSample.image)

                    if let cropImage = result?.titleCropImage {
                        imageSection(title: "Title Crop", image: cropImage)
                    }

                    Button {
                        runOcr()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                            }

                            Text(isLoading ? "Reading" : "Run OCR")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading)

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

    private func runOcr() {
        isLoading = true
        errorMessage = nil
        let selectedImage = selectedSample.image

        Task.detached(priority: .userInitiated) {
            let extractionResult = await PokemonCardNameExtractor().extractName(from: selectedImage)

            await MainActor.run {
                switch extractionResult {
                case .success(let value):
                    result = value
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }

                isLoading = false
            }
        }
    }
}

#Preview {
    PokemonOcrScreen()
}
