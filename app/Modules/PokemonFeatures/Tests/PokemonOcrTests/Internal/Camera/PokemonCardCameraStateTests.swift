//
//  PokemonCardCameraStateTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

import Testing

@testable import PokemonOcr

@Suite("PokemonCardCameraState Tests")
struct PokemonCardCameraStateTests {
    @Test
    func `Should only allow starting camera from idle or failed states`() {
        #expect(PokemonCardCameraState.idle.canStartCamera)
        #expect(PokemonCardCameraState.failed("Camera unavailable").canStartCamera)
        #expect(!PokemonCardCameraState.requestingPermission.canStartCamera)
        #expect(!PokemonCardCameraState.running.canStartCamera)
        #expect(!PokemonCardCameraState.capturing.canStartCamera)
        #expect(PokemonCardCameraState.completed.canStartCamera)
    }

    @Test
    func `Should only allow manual crop fallback while scanning`() {
        #expect(PokemonCardCameraState.running.canUseManualCropFallback)
        #expect(!PokemonCardCameraState.idle.canUseManualCropFallback)
        #expect(!PokemonCardCameraState.requestingPermission.canUseManualCropFallback)
        #expect(!PokemonCardCameraState.capturing.canUseManualCropFallback)
        #expect(!PokemonCardCameraState.completed.canUseManualCropFallback)
        #expect(!PokemonCardCameraState.failed("Camera unavailable").canUseManualCropFallback)
    }

    @Test
    func `Should expose scanning status while camera runs`() {
        #expect(PokemonCardCameraState.running.statusText == "Scanning for a steady card shape...")
    }

    @Test
    func `Should expose completed crop status`() {
        #expect(PokemonCardCameraState.completed.statusText == "Card crop captured. Scan again to restart the camera.")
    }

    @Test
    func `Should expose failed camera message as status text`() {
        let state = PokemonCardCameraState.failed("Camera unavailable")

        #expect(state.statusText == "Camera unavailable")
    }
}
