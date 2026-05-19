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
    }

    @Test
    func `Should only allow frame capture while camera is running`() {
        #expect(PokemonCardCameraState.running.canCaptureFrame)
        #expect(!PokemonCardCameraState.idle.canCaptureFrame)
        #expect(!PokemonCardCameraState.requestingPermission.canCaptureFrame)
        #expect(!PokemonCardCameraState.capturing.canCaptureFrame)
        #expect(!PokemonCardCameraState.failed("Camera unavailable").canCaptureFrame)
    }

    @Test
    func `Should expose failed camera message as status text`() {
        let state = PokemonCardCameraState.failed("Camera unavailable")

        #expect(state.statusText == "Camera unavailable")
    }
}
