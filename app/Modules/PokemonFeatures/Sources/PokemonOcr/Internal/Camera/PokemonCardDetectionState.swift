//
//  PokemonCardDetectionState.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

enum PokemonCardDetectionState: Equatable {
    case idle
    case requestingPermission
    case detecting
    case capturing
    case reading
    case finished
    case failed(String)

    var statusText: String {
        switch self {
        case .idle:
            "Tap the camera button to scan a card."
        case .requestingPermission:
            "Requesting camera access..."
        case .detecting:
            "Detecting card shape..."
        case .capturing:
            "Capturing card..."
        case .reading:
            "Reading card name..."
        case .finished:
            "Scan complete. Tap the camera button to scan another card."
        case .failed(let message):
            message
        }
    }

    var canStartDetection: Bool {
        switch self {
        case .idle, .finished, .failed:
            true
        case .requestingPermission, .detecting, .capturing, .reading:
            false
        }
    }
}
