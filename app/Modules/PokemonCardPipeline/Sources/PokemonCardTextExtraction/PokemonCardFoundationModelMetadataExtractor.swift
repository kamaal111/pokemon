//
//  PokemonCardFoundationModelMetadataExtractor.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/27/26.
//

import Foundation
import UIKit

#if compiler(>=6.4)
    import FoundationModels
    import Vision

    public struct PokemonCardFoundationModelMetadataExtractor: Sendable {
        public init() {}

        public func extractMetadata(
            from image: UIImage
        ) async -> Result<PokemonCardMetadataExtractionResult, PokemonCardMetadataExtractionError> {
            guard #available(iOS 27.0, *) else {
                return .failure(.unsupportedOS)
            }

            return await extractAvailableMetadata(from: image)
        }

        @available(iOS 27.0, *)
        private func extractAvailableMetadata(
            from image: UIImage
        ) async -> Result<PokemonCardMetadataExtractionResult, PokemonCardMetadataExtractionError> {
            let model = SystemLanguageModel(useCase: .general)
            guard case .available = model.availability else {
                return .failure(.modelUnavailable(Self.unavailableReason(for: model.availability)))
            }

            do {
                let setIDResult = try? await PokemonCardSetIDExtractor().extractSetID(from: image).get()
                let evidence = try await makeEvidence(from: image, setIDResult: setIDResult, model: model)
                let response = try await makeStructuredResponse(
                    from: image,
                    evidence: evidence,
                    setIDResult: setIDResult,
                    model: model
                )
                let setID = PokemonCardFoundationModelMetadataNormalizer.resolvedSetID(
                    setIDOCRResult: setIDResult,
                    structuredSetID: response.setID,
                    evidence: evidence
                )
                guard
                    let result = PokemonCardFoundationModelMetadataNormalizer.normalizedResult(
                        pokemonName: response.pokemonName,
                        setID: setID,
                        setIDDebugInfo: setIDResult?.debugInfo,
                        setIDDebugImages: setIDResult?.debugImages ?? []
                    )
                else {
                    return .failure(.emptyResult)
                }

                return .success(result)
            } catch {
                return .failure(.generationFailed(error.localizedDescription))
            }
        }

        @available(iOS 27.0, *)
        private func makeEvidence(
            from image: UIImage,
            setIDResult: PokemonCardSetIDExtractionResult?,
            model: SystemLanguageModel
        ) async throws -> String {
            switch PokemonCardFoundationModelMetadataStrategy.current {
            case .ocrTool:
                try await makeOCRToolEvidence(from: image, setIDResult: setIDResult, model: model)
            case .directImagePrompt:
                try await makeDirectImageEvidence(from: image, setIDResult: setIDResult, model: model)
            }
        }

        @available(iOS 27.0, *)
        private func makeDirectImageEvidence(
            from image: UIImage,
            setIDResult: PokemonCardSetIDExtractionResult?,
            model: SystemLanguageModel
        ) async throws -> String {
            let session = LanguageModelSession(
                model: model,
                instructions:
                    """
                    Inspect Pokemon card images and report only text that is visibly printed on the card.
                    """
            )
            let prompt = Self.evidencePrompt(setIDResult: setIDResult)
            let response =
                if let setIDCropImage = Self.promptSetIDCropImage(from: setIDResult) {
                    try await session.respond(options: GenerationOptions(samplingMode: .greedy)) {
                        prompt
                        Attachment(image).label(Self.imageAttachmentLabel)
                        Attachment(setIDCropImage).label(Self.setIDCropAttachmentLabel)
                    }
                } else {
                    try await session.respond(options: GenerationOptions(samplingMode: .greedy)) {
                        prompt
                        Attachment(image).label(Self.imageAttachmentLabel)
                    }
                }

            return response.content
        }

        @available(iOS 27.0, *)
        private static func promptSetIDCropImage(from result: PokemonCardSetIDExtractionResult?) -> UIImage? {
            result?.debugImages.first { $0.label.hasSuffix("-enhanced") }?.image
        }

        private static func evidencePrompt(setIDResult: PokemonCardSetIDExtractionResult?) -> String {
            """
            Analyze the attached Pokemon card image. Produce concise plain-text evidence for:
            - the top title/name area
            - the bottom-left set-code area, especially the small black rounded rectangle with white text

            Preserve exact casing for short set codes such as sv8a or m2a. Include the nearby collector \
            number separately if visible, but do not merge it into the set code. Include uncertainty if \
            text is not readable.

            Deterministic bottom-left OCR evidence:
            \(setIDOcrEvidence(from: setIDResult))
            """
        }

        private static func setIDOcrEvidence(from result: PokemonCardSetIDExtractionResult?) -> String {
            guard let result else {
                return "No deterministic set-code OCR result was available."
            }

            let selectedSetID = result.setID ?? "nil"
            let selectedCropLabel = result.selectedCropLabel ?? "nil"
            let rawCandidates = result.rawCandidates.isEmpty ? "none" : result.rawCandidates.joined(separator: ", ")

            return "setID=\(selectedSetID); selectedCrop=\(selectedCropLabel); rawCandidates=\(rawCandidates)"
        }

        @available(iOS 27.0, *)
        private func makeStructuredResponse(
            from image: UIImage,
            evidence: String,
            setIDResult: PokemonCardSetIDExtractionResult?,
            model: SystemLanguageModel
        ) async throws -> PokemonCardFoundationModelMetadataResponse {
            let session = LanguageModelSession(
                model: model,
                instructions:
                    """
                    Return structured Pokemon card metadata from the provided image and text evidence. \
                    Use nil for any field that is not visibly supported by the image or evidence.
                    """
            )
            let prompt =
                """
                Extract these fields:
                - pokemonName: the Pokemon name printed in the top title area of the card.
                - setID: the small set code in the bottom-left black rounded rectangle.

                The setID is like sv8a or m2a. Do not use the collector number, rarity, illustrator, \
                regulation mark, copyright line, HP, move damage, Pokedex number, or any text outside \
                the bottom-left black rounded rectangle as setID.

                Plain-text evidence from the first pass:
                \(evidence)
                """
            let response =
                if let setIDCropImage = Self.promptSetIDCropImage(from: setIDResult) {
                    try await session.respond(
                        generating: PokemonCardFoundationModelMetadataResponse.self,
                        options: GenerationOptions(samplingMode: .greedy)
                    ) {
                        prompt
                        Attachment(image).label(Self.imageAttachmentLabel)
                        Attachment(setIDCropImage).label(Self.setIDCropAttachmentLabel)
                    }
                } else {
                    try await session.respond(
                        generating: PokemonCardFoundationModelMetadataResponse.self,
                        options: GenerationOptions(samplingMode: .greedy)
                    ) {
                        prompt
                        Attachment(image).label(Self.imageAttachmentLabel)
                    }
                }

            return response.content
        }

        @available(iOS 27.0, *)
        private static func unavailableReason(
            for availability: SystemLanguageModel.Availability
        ) -> PokemonCardFoundationModelUnavailableReason {
            switch availability {
            case .available:
                .unknown
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    .deviceNotEligible
                case .appleIntelligenceNotEnabled:
                    .appleIntelligenceNotEnabled
                case .modelNotReady:
                    .modelNotReady
                @unknown default:
                    .unknown
                }
            }
        }

        private static let imageAttachmentLabel = "pokemon-card"
        private static let setIDCropAttachmentLabel = "bottom-left-set-code-crop"
    }

    #if os(iOS) && !targetEnvironment(simulator)
        @available(iOS 27.0, *)
        extension PokemonCardFoundationModelMetadataExtractor {
            fileprivate func makeOCRToolEvidence(
                from image: UIImage,
                setIDResult: PokemonCardSetIDExtractionResult?,
                model: SystemLanguageModel
            ) async throws -> String {
                let session = LanguageModelSession(
                    model: model,
                    tools: [OCRTool()],
                    instructions:
                        """
                        Use OCR when exact Pokemon card text matters. Return concise plain-text evidence only.
                        """
                )
                let prompt = Self.evidencePrompt(setIDResult: setIDResult)
                let response =
                    if let setIDCropImage = Self.promptSetIDCropImage(from: setIDResult) {
                        try await session.respond(options: GenerationOptions(samplingMode: .greedy)) {
                            prompt
                            Attachment(image).label(Self.imageAttachmentLabel)
                            Attachment(setIDCropImage).label(Self.setIDCropAttachmentLabel)
                        }
                    } else {
                        try await session.respond(options: GenerationOptions(samplingMode: .greedy)) {
                            prompt
                            Attachment(image).label(Self.imageAttachmentLabel)
                        }
                    }

                return response.content
            }
        }
    #else
        @available(iOS 27.0, *)
        extension PokemonCardFoundationModelMetadataExtractor {
            fileprivate func makeOCRToolEvidence(
                from image: UIImage,
                setIDResult: PokemonCardSetIDExtractionResult?,
                model: SystemLanguageModel
            ) async throws -> String {
                try await makeDirectImageEvidence(from: image, setIDResult: setIDResult, model: model)
            }
        }
    #endif

    @available(iOS 27.0, *)
    @Generable
    private struct PokemonCardFoundationModelMetadataResponse {
        @Guide(description: "The Pokemon name printed at the top of the card.")
        let pokemonName: String?

        @Guide(
            description:
                "The Pokemon card set code printed in the bottom-left black rounded rectangle, for example sv8a.")
        let setID: String?
    }
#else
    public struct PokemonCardFoundationModelMetadataExtractor: Sendable {
        public init() {}

        public func extractMetadata(
            from image: UIImage
        ) async -> Result<PokemonCardMetadataExtractionResult, PokemonCardMetadataExtractionError> {
            let _ = image
            return .failure(.unsupportedToolchain)
        }
    }
#endif
