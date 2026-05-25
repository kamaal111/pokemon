//
//  PokemonCardCameraController.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

@preconcurrency import AVFoundation
import CoreImage
import OSLog
import PokemonCardDetection
import PokemonCardPipeline
import QuartzCore
import UIKit

final class PokemonCardCameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "io.kamaal.Pokemon.card-camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let imageContext = CIContext()
    private var detectionThrottler = PokemonCardDetectionFrameThrottler()
    private var framePipeline = PokemonCardFramePipeline()

    private var latestFrame: UIImage?
    private var isConfigured = false
    private var onStateChange: ((PokemonCardCameraState) -> Void)?
    private var onFrameCaptured: ((UIImage) -> Void)?
    private var onDetectionReportChange: ((PokemonCardShapeDetectionReport?) -> Void)?
    private var onDetectedFrameCaptured: ((PokemonCardPipelineCapture) -> Void)?
    private let logger = Logger(subsystem: "io.kamaal.Pokemon", category: "CardScanner")

    func start(
        onStateChange: @escaping (PokemonCardCameraState) -> Void,
        onDetectionReportChange: @escaping (PokemonCardShapeDetectionReport?) -> Void,
        onFrameCaptured: @escaping (UIImage) -> Void,
        onDetectedFrameCaptured: @escaping (PokemonCardPipelineCapture) -> Void
    ) {
        self.onStateChange = onStateChange
        self.onDetectionReportChange = onDetectionReportChange
        self.onFrameCaptured = onFrameCaptured
        self.onDetectedFrameCaptured = onDetectedFrameCaptured
        logger.notice("Card scanner start requested")
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
            self.emitDetectionReport(nil)
            guard self.session.isRunning else {
                return
            }

            self.logger.notice("Card scanner session stopping")
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
                self.logger.error("Manual crop requested before a throttled frame was ready")
                self.emit(.failed("No camera frame is ready yet."))
                return
            }

            self.logger.notice("Manual crop using latest throttled frame")
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
            self.detectionThrottler.reset()
            self.framePipeline = PokemonCardFramePipeline()
            self.emitDetectionReport(nil)
            if !self.session.isRunning {
                self.logger.notice("Card scanner session starting")
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

    private func emitDetectionReport(_ report: PokemonCardShapeDetectionReport?) {
        DispatchQueue.main.async { [onDetectionReportChange] in
            onDetectionReportChange?(report)
        }
    }
}

extension PokemonCardCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard detectionThrottler.shouldRunDetection(at: CACurrentMediaTime()) else {
            return
        }

        guard let frame = PokemonCardVideoFrameSnapshotter.image(from: sampleBuffer, context: imageContext) else {
            logger.error("Could not convert throttled camera frame for card detection")
            return
        }

        latestFrame = frame
        let pipelineResult = framePipeline.process(frame)
        guard let frameResult = logPipelineResult(pipelineResult, frame: frame) else {
            return
        }
        emitDetectionReport(frameResult.detectionReport)

        guard let capture = frameResult.capture else {
            return
        }

        emit(.capturing)
        session.stopRunning()
        latestFrame = nil
        DispatchQueue.main.async { [onDetectedFrameCaptured] in
            onDetectedFrameCaptured?(capture)
        }
    }

    private func logPipelineResult(
        _ result: Result<PokemonCardPipelineFrameResult, PokemonCardPipelineError>,
        frame: UIImage
    ) -> PokemonCardPipelineFrameResult? {
        switch result {
        case .success(let frameResult):
            logDetectionReport(frameResult.detectionReport, frame: frame)
            return frameResult
        case .failure(let error):
            logger.error("Card pipeline failed: \(error.localizedDescription, privacy: .public)")
            emit(.failed(error.localizedDescription))
            return nil
        }
    }

    private func logDetectionReport(_ report: PokemonCardShapeDetectionReport, frame: UIImage) {
        if let detection = report.selectedDetection {
            let rect = detection.normalizedBoundingBox.standardized
            logger.info(
                "Card detection selected confidence=\(detection.confidence) rect=\(rect.debugDescription, privacy: .public) candidates=\(report.candidates.count) valid=\(report.validCandidateCount)"
            )
        } else {
            logger.info(
                "Card detection found no valid shape candidates=\(report.candidates.count) valid=\(report.validCandidateCount) frame=\(Int(report.frameSize.width))x\(Int(report.frameSize.height))"
            )
        }

        for candidate in report.candidates {
            let rect = candidate.detection.normalizedBoundingBox.standardized
            let metrics = candidate.metrics
            let reasons = candidate.rejectionReasons.map(\.rawValue).joined(separator: ",")
            logger.info(
                "Card candidate source=\(candidate.source.rawValue, privacy: .public) confidence=\(metrics.confidence) score=\(candidate.score) rect=\(rect.debugDescription, privacy: .public) aspect=\(metrics.boundingAspectRatio) area=\(metrics.areaFraction) content=\(metrics.contentScore) shape=\(metrics.shapeScore) rejected=\(reasons, privacy: .public)"
            )
        }
    }
}
