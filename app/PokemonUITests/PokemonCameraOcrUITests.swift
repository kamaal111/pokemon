//
//  PokemonCameraOcrUITests.swift
//  PokemonUITests
//
//  Created by Kamaal M Farah on 5/18/26.
//

import XCTest

final class PokemonCameraOcrUITests: XCTestCase {
    @MainActor
    func testShowsCameraScannerAndSampleDebugFallback() {
        let app = launchApp()

        XCTAssertTrue(app.buttons["Scan Card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tap the camera button to scan a card."].exists)
        XCTAssertTrue(app.buttons["Sample OCR Debug"].exists)
    }

    @MainActor
    func testRunsBundledSampleOcrFromDebugFallback() {
        let app = launchApp()

        XCTAssertTrue(app.buttons["Sample OCR Debug"].waitForExistence(timeout: 5))
        app.buttons["Sample OCR Debug"].tap()

        XCTAssertTrue(app.buttons["Run Sample OCR"].waitForExistence(timeout: 5))
        app.buttons["Run Sample OCR"].tap()

        XCTAssertTrue(app.staticTexts["Selected Candidate"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["이브이ex"].exists)
    }

    @MainActor
    func testScanCardRunsInjectedCameraCaptureThroughOcr() {
        let app = launchApp(fakeCameraCapture: true)

        XCTAssertTrue(app.buttons["Scan Card"].waitForExistence(timeout: 5))
        app.buttons["Scan Card"].tap()

        XCTAssertTrue(app.buttons["Scanning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Captured"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Selected Candidate"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["이브이ex"].exists)
        XCTAssertTrue(app.staticTexts["Scan complete. Tap the camera button to scan another card."].exists)
        XCTAssertTrue(app.buttons["Scan Card"].exists)
    }

    @MainActor
    private func launchApp(fakeCameraCapture: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if fakeCameraCapture {
            app.launchEnvironment["POKEMON_UI_TEST_FAKE_CAMERA_CAPTURE"] = "eevee"
        }
        app.launch()

        return app
    }
}
