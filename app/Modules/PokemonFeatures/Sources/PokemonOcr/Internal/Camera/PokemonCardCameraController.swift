//
//  PokemonCardCameraController.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

@preconcurrency import AVFoundation
import UIKit

final class PokemonCardCameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "io.kamaal.Pokemon.card-camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()

    private var captureGate = PokemonCardAutoCaptureGate()
    private var frameThrottler = PokemonCardDetectionFrameThrottler()
    private var camera: AVCaptureDevice?
    private var isConfigured = false
    private var isDetecting = false
    private var isCapturing = false

    private var onStateChange: ((PokemonCardDetectionState) -> Void)?
    private var onCandidateRectanglesChange: (([CGRect]) -> Void)?
    private var onPhotoCaptured: ((UIImage) -> Void)?

    func startDetection(
        onStateChange: @escaping (PokemonCardDetectionState) -> Void,
        onCandidateRectanglesChange: @escaping ([CGRect]) -> Void,
        onPhotoCaptured: @escaping (UIImage) -> Void
    ) {
        self.onStateChange = onStateChange
        self.onCandidateRectanglesChange = onCandidateRectanglesChange
        self.onPhotoCaptured = onPhotoCaptured
        emitCandidateRectangles([])
        emit(.requestingPermission)

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startConfiguredSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
                guard let self else {
                    return
                }

                if isGranted {
                    self.startConfiguredSession()
                } else {
                    self.emit(.failed("Camera access is required to scan a card."))
                }
            }
        case .denied, .restricted:
            emit(.failed("Camera access is required to scan a card."))
        @unknown default:
            emit(.failed("Camera access is unavailable."))
        }
    }

    func stopDetection() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.isDetecting = false
            self.isCapturing = false
            self.captureGate.reset()
            self.frameThrottler.reset()
            self.emitCandidateRectangles([])
            guard self.session.isRunning else {
                return
            }

            self.session.stopRunning()
        }
    }

    private func startConfiguredSession() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard self.configureSessionIfNeeded() else {
                self.emit(.failed("The camera could not be configured."))
                return
            }

            self.captureGate.reset()
            self.frameThrottler.reset()
            self.isCapturing = false
            self.isDetecting = true
            if !self.session.isRunning {
                self.session.startRunning()
            }

            self.emit(.detecting)
        }
    }

    private func configureSessionIfNeeded() -> Bool {
        guard !isConfigured else {
            return true
        }

        guard
            let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            )
        else {
            return false
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            return false
        }

        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            session.sessionPreset = .medium
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }

        session.addInput(input)
        configureFocus(for: camera)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            return false
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        session.addOutput(videoOutput)
        session.commitConfiguration()
        self.camera = camera
        isConfigured = true

        return true
    }

    private func configureFocus(for camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
        } catch {
            return
        }

        if camera.isFocusPointOfInterestSupported {
            camera.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }

        if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }

        if camera.isAutoFocusRangeRestrictionSupported {
            camera.autoFocusRangeRestriction = .near
        }

        if camera.isSmoothAutoFocusSupported {
            camera.isSmoothAutoFocusEnabled = true
        }

        if camera.isExposurePointOfInterestSupported {
            camera.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }

        if camera.isExposureModeSupported(.continuousAutoExposure) {
            camera.exposureMode = .continuousAutoExposure
        }

        camera.isSubjectAreaChangeMonitoringEnabled = true
        camera.unlockForConfiguration()
    }

    private func focus(on detection: PokemonCardShapeDetection) {
        guard let camera else {
            return
        }

        guard camera.isFocusPointOfInterestSupported || camera.isExposurePointOfInterestSupported else {
            return
        }

        let focusPoint = PokemonCardCameraFocusPointMapper.devicePoint(for: detection)
        do {
            try camera.lockForConfiguration()
        } catch {
            return
        }

        if camera.isFocusPointOfInterestSupported {
            camera.focusPointOfInterest = focusPoint
        }

        if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }

        if camera.isExposurePointOfInterestSupported {
            camera.exposurePointOfInterest = focusPoint
        }

        if camera.isExposureModeSupported(.continuousAutoExposure) {
            camera.exposureMode = .continuousAutoExposure
        }

        camera.unlockForConfiguration()
    }

    private func captureCardSnapshot(from sampleBuffer: CMSampleBuffer, detection: PokemonCardShapeDetection) {
        isCapturing = true
        isDetecting = false
        emit(.capturing)

        guard
            let image = PokemonCardVideoFrameSnapshotter.cardSnapshot(
                from: sampleBuffer,
                detection: detection
            )
        else {
            emit(.failed("The card snapshot could not be prepared for OCR."))
            isCapturing = false
            return
        }

        if session.isRunning {
            session.stopRunning()
        }

        emitCandidateRectangles([])
        isCapturing = false

        DispatchQueue.main.async { [onPhotoCaptured] in
            onPhotoCaptured?(image)
        }
    }

    private func emit(_ state: PokemonCardDetectionState) {
        DispatchQueue.main.async { [onStateChange] in
            onStateChange?(state)
        }
    }

    private func emitCandidateRectangles(_ rectangles: [CGRect]) {
        DispatchQueue.main.async { [onCandidateRectanglesChange] in
            onCandidateRectanglesChange?(rectangles)
        }
    }
}

extension PokemonCardCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isDetecting else {
            return
        }

        guard !isCapturing else {
            return
        }

        guard frameThrottler.shouldRunDetection(at: ProcessInfo.processInfo.systemUptime) else {
            return
        }

        let detectionResult = detectCard(in: sampleBuffer)
        emitCandidateRectangles(detectionResult.candidateRectangles)

        guard let detection = detectionResult.detection else {
            _ = captureGate.shouldCapture(after: nil)
            return
        }

        focus(on: detection)
        guard captureGate.shouldCapture(after: detection) else {
            return
        }

        captureCardSnapshot(from: sampleBuffer, detection: detection)
    }

    private func detectCard(
        in sampleBuffer: CMSampleBuffer
    ) -> (candidateRectangles: [CGRect], detection: PokemonCardShapeDetection?) {
        let shapeResult = PokemonCardShapeDetector.detectCards(in: sampleBuffer)
        let textObservations = PokemonCardTextClusterDetector.detectText(in: sampleBuffer)
        let textBoxes = textObservations.map(\.boundingBox)

        if let shapeDetection = PokemonCardShapeDetector.bestDetection(
            from: shapeResult.candidates,
            overlapping: textBoxes
        ) {
            return (
                candidateRectangles: shapeResult.candidates.map(\.boundingBox),
                detection: shapeDetection
            )
        }

        return (
            candidateRectangles: shapeResult.candidates.map(\.boundingBox),
            detection: PokemonCardTextClusterDetector.bestDetection(from: textObservations)
        )
    }
}
