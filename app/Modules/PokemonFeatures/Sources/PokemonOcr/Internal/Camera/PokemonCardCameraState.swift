//
//  PokemonCardCameraState.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

enum PokemonCardCameraState: Equatable {
    case idle
    case requestingPermission
    case running
    case capturing
    case failed(String)

    var statusText: String {
        switch self {
        case .idle:
            "Start the camera, then capture a frame to crop the card."
        case .requestingPermission:
            "Requesting camera access..."
        case .running:
            "Position the card in view, then capture a crop."
        case .capturing:
            "Cropping captured frame..."
        case .failed(let message):
            message
        }
    }

    var canStartCamera: Bool {
        switch self {
        case .idle, .failed:
            true
        case .requestingPermission, .running, .capturing:
            false
        }
    }

    var canCaptureFrame: Bool {
        switch self {
        case .running:
            true
        case .idle, .requestingPermission, .capturing, .failed:
            false
        }
    }
}
