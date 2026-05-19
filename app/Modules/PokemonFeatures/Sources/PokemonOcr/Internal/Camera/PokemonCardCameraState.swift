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
    case completed
    case failed(String)

    var statusText: String {
        switch self {
        case .idle:
            "Start the camera, then capture a frame to crop the card."
        case .requestingPermission:
            "Requesting camera access..."
        case .running:
            "Scanning for a steady card shape..."
        case .capturing:
            "Cropping captured frame..."
        case .completed:
            "Card crop captured. Scan again to restart the camera."
        case .failed(let message):
            message
        }
    }

    var canStartCamera: Bool {
        switch self {
        case .idle, .completed, .failed:
            true
        case .requestingPermission, .running, .capturing:
            false
        }
    }

    var canUseManualCropFallback: Bool {
        switch self {
        case .running:
            true
        case .idle, .requestingPermission, .capturing, .completed, .failed:
            false
        }
    }
}
