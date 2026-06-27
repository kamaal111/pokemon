//
//  PokemonCardFoundationModelMetadataModels.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/27/26.
//

import Foundation

public struct PokemonCardMetadataExtractionResult: Equatable, Sendable {
    public let pokemonName: String?
    public let setID: String?
    public let setIDDebugInfo: PokemonCardSetIDDebugInfo?
    public let setIDDebugImages: [PokemonCardSetIDDebugImage]

    public init(
        pokemonName: String?,
        setID: String?,
        setIDDebugInfo: PokemonCardSetIDDebugInfo? = nil,
        setIDDebugImages: [PokemonCardSetIDDebugImage] = []
    ) {
        self.pokemonName = pokemonName
        self.setID = setID
        self.setIDDebugInfo = setIDDebugInfo
        self.setIDDebugImages = setIDDebugImages
    }

    public static func == (
        lhs: PokemonCardMetadataExtractionResult,
        rhs: PokemonCardMetadataExtractionResult
    ) -> Bool {
        lhs.pokemonName == rhs.pokemonName
            && lhs.setID == rhs.setID
            && lhs.setIDDebugInfo == rhs.setIDDebugInfo
    }
}

public enum PokemonCardFoundationModelUnavailableReason: Equatable, Sendable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknown
}

public enum PokemonCardMetadataExtractionError: LocalizedError, Equatable, Sendable {
    case unsupportedToolchain
    case unsupportedOS
    case modelUnavailable(PokemonCardFoundationModelUnavailableReason)
    case generationFailed(String)
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .unsupportedToolchain:
            "Foundation Models card text extraction requires the Xcode 27 toolchain or newer."
        case .unsupportedOS:
            "Foundation Models card text extraction requires iOS 27 or later."
        case .modelUnavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                "This device is not eligible for Apple Intelligence card text extraction."
            case .appleIntelligenceNotEnabled:
                "Apple Intelligence must be enabled to extract card text with Foundation Models."
            case .modelNotReady:
                "The Foundation Models assets are not ready yet. Try again after Apple Intelligence finishes setup."
            case .unknown:
                "Foundation Models card text extraction is unavailable on this device."
            }
        case .generationFailed(let message):
            "Foundation Models could not extract card text: \(message)"
        case .emptyResult:
            "Foundation Models did not return a Pokemon name or set ID."
        }
    }
}

enum PokemonCardFoundationModelMetadataNormalizer {
    static func normalizedPokemonName(_ value: String?) -> String? {
        guard let value else { return nil }

        let normalized = value.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        return normalized
    }

    static func normalizedSetID(_ value: String?) -> String? {
        guard let value else { return nil }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard !normalized.contains(where: { $0.isWhitespace }) else { return nil }
        guard normalized.range(of: #"^[A-Za-z]{1,6}[0-9]{1,3}[A-Za-z]?$"#, options: .regularExpression) != nil else {
            return nil
        }
        guard normalized.range(of: #"^hp[0-9]+$"#, options: [.caseInsensitive, .regularExpression]) == nil else {
            return nil
        }
        guard normalized.range(of: #"^no[0-9]+$"#, options: [.caseInsensitive, .regularExpression]) == nil else {
            return nil
        }

        return normalized.lowercased()
    }

    static func normalizedSetID(fromEvidence evidence: String) -> String? {
        let prioritizedLines = evidence.components(separatedBy: .newlines)
            .filter { line in
                let lowercasedLine = line.lowercased()
                return lowercasedLine.contains("set")
                    || lowercasedLine.contains("code")
                    || lowercasedLine.contains("bottom")
                    || lowercasedLine.contains("left")
                    || lowercasedLine.contains("black")
                    || lowercasedLine.contains("rectangle")
            }
        if let setID = normalizedSetID(fromCandidateText: prioritizedLines.joined(separator: " ")) {
            return setID
        }

        return normalizedSetID(fromCandidateText: evidence)
    }

    static func normalizedResult(
        pokemonName: String?,
        setID: String?,
        setIDDebugInfo: PokemonCardSetIDDebugInfo? = nil,
        setIDDebugImages: [PokemonCardSetIDDebugImage] = []
    ) -> PokemonCardMetadataExtractionResult? {
        let normalizedPokemonName = normalizedPokemonName(pokemonName)
        let normalizedSetID = normalizedSetID(setID)
        guard normalizedPokemonName != nil || normalizedSetID != nil else { return nil }

        return PokemonCardMetadataExtractionResult(
            pokemonName: normalizedPokemonName,
            setID: normalizedSetID,
            setIDDebugInfo: setIDDebugInfo,
            setIDDebugImages: setIDDebugImages
        )
    }

    static func resolvedSetID(
        setIDOCRResult: PokemonCardSetIDExtractionResult?,
        structuredSetID: String?,
        evidence: String
    ) -> String? {
        normalizedSetID(setIDOCRResult?.setID)
            ?? normalizedSetID(structuredSetID)
            ?? normalizedSetID(fromEvidence: evidence)
    }

    private static func normalizedSetID(fromCandidateText text: String) -> String? {
        let pattern = #"[A-Za-z]{1,6}[0-9]{1,3}[A-Za-z]?"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            assertionFailure("Set ID regular expression must compile.")
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = expression.matches(in: text, range: range)
        for match in matches {
            guard let matchRange = Range(match.range, in: text) else {
                continue
            }

            if let setID = normalizedSetID(String(text[matchRange])) {
                return setID
            }
        }

        return nil
    }
}

enum PokemonCardFoundationModelMetadataStrategy: Equatable {
    case ocrTool
    case directImagePrompt

    static var current: Self {
        #if os(iOS) && !targetEnvironment(simulator)
            .ocrTool
        #else
            .directImagePrompt
        #endif
    }
}
