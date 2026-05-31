//
//  PokemonCardCameraDeviceSelection.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/31/26.
//

import AVFoundation

enum PokemonCardCameraDeviceSelection {
    private static let preferredBackCameraTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera,
    ]

    private static func preferredDeviceType(
        from availableDeviceTypes: [AVCaptureDevice.DeviceType]
    ) -> AVCaptureDevice.DeviceType? {
        preferredBackCameraTypes.first { deviceType in
            availableDeviceTypes.contains(deviceType)
        }
    }

    static func preferredBackCamera() -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: preferredBackCameraTypes,
            mediaType: .video,
            position: .back
        )
        let deviceType = preferredDeviceType(from: discoverySession.devices.map(\.deviceType))
        guard let deviceType else { return nil }

        return discoverySession.devices.first { $0.deviceType == deviceType }
    }
}
