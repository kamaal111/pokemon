//
//  PokemonCardCameraController.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

@preconcurrency import AVFoundation
import CoreImage
import UIKit

final class PokemonCardCameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "io.kamaal.Pokemon.card-camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let imageContext = CIContext()

    private var latestFrame: UIImage?
    private var isConfigured = false
    private var onStateChange: ((PokemonCardCameraState) -> Void)?
    private var onFrameCaptured: ((UIImage) -> Void)?

    func start(
        onStateChange: @escaping (PokemonCardCameraState) -> Void,
        onFrameCaptured: @escaping (UIImage) -> Void
    ) {
        self.onStateChange = onStateChange
        self.onFrameCaptured = onFrameCaptured
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
                    self.emit(.failed("Camera access is required to crop a card."))
                }
            }
        case .denied, .restricted:
            emit(.failed("Camera access is required to crop a card."))
        @unknown default:
            emit(.failed("Camera access is unavailable."))
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.latestFrame = nil
            guard self.session.isRunning else {
                return
            }

            self.session.stopRunning()
        }
    }

    func captureCurrentFrame() {
        emit(.capturing)
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard let latestFrame = self.latestFrame else {
                self.emit(.failed("No camera frame is ready yet."))
                return
            }

            DispatchQueue.main.async { [onFrameCaptured] in
                onFrameCaptured?(latestFrame)
            }
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

            self.latestFrame = nil
            if !self.session.isRunning {
                self.session.startRunning()
            }

            self.emit(.running)
        }
    }

    private func configureSessionIfNeeded() -> Bool {
        guard !isConfigured else {
            return true
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        session.addOutput(videoOutput)
        session.commitConfiguration()
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

        camera.unlockForConfiguration()
    }

    private func emit(_ state: PokemonCardCameraState) {
        DispatchQueue.main.async { [onStateChange] in
            onStateChange?(state)
        }
    }
}

extension PokemonCardCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        latestFrame = PokemonCardVideoFrameSnapshotter.image(from: sampleBuffer, context: imageContext)
    }
}
