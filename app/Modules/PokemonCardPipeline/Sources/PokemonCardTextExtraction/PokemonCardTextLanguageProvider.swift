//
//  PokemonCardTextLanguageProvider.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import Vision

protocol PokemonCardTextRecognitionLanguageProviding: Sendable {
    func supportedRecognitionLanguages(
        recognitionLevel: VNRequestTextRecognitionLevel
    ) -> Result<[String], PokemonCardTextExtractionError>
}

struct PokemonCardTextRecognitionLanguageProvider: PokemonCardTextRecognitionLanguageProviding {
    func supportedRecognitionLanguages(
        recognitionLevel: VNRequestTextRecognitionLevel
    ) -> Result<[String], PokemonCardTextExtractionError> {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel

        let languages: [String]
        do {
            languages = try request.supportedRecognitionLanguages()
        } catch {
            return .failure(.requestFailed(error.localizedDescription))
        }

        return .success(languages)
    }
}
