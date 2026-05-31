//
//  PokemonCardCameraController.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

@preconcurrency import AVFoundation
import CoreImage
import KamaalLogger
import PokemonCardDetection
import PokemonCardFocusQuality
import PokemonCardPipeline
import PokemonCardStability
import QuartzCore
import UIKit

final class PokemonCardCameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "io.kamaal.Pokemon.card-camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let imageContext = CIContext()
    private var detectionThrottler = PokemonCardDetectionFrameThrottler()
    private var framePipeline = PokemonCardFramePipeline()
    private var refocusCoordinator = PokemonCardCameraRefocusCoordinator()

    private var latestFrame: UIImage?
    private var activeCamera: AVCaptureDevice?
    private var isConfigured = false
    private var onStateChange: ((PokemonCardCameraState) -> Void)?
    private var onFrameCaptured: ((UIImage) -> Void)?
    private var onDetectionReportChange: ((PokemonCardShapeDetectionReport?) -> Void)?
    private var onDetectedFrameCaptured: ((PokemonCardPipelineCapture) -> Void)?
    private let logger = KamaalLogger(from: PokemonCardCameraController.self)

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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
        logger.info("Card scanner start requested")
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

            self.logger.info("Card scanner session stopping")
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

            self.logger.info("Manual crop using latest throttled frame")
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
            self.refocusCoordinator.reset()
            self.emitDetectionReport(nil)
            if !self.session.isRunning {
                self.logger.info("Card scanner session starting")
                self.session.startRunning()
            }

            self.emit(.running)
        }
    }

    private func configureSessionIfNeeded() -> Bool {
        guard !isConfigured else {
            return true
        }

        guard let camera = PokemonCardCameraDeviceSelection.preferredBackCamera() else {
            return false
        }
        activeCamera = camera
        logCameraCapabilities(camera)

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            return false
        }

        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else if session.canSetSessionPreset(.hd1280x720) {
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
        startSubjectAreaMonitoring(for: camera)
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
        refocusCoordinator.markFocusRequested(point: CGPoint(x: 0.5, y: 0.5), at: CACurrentMediaTime())
    }

    private func startSubjectAreaMonitoring(for camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
        } catch {
            return
        }

        camera.isSubjectAreaChangeMonitoringEnabled = true
        camera.unlockForConfiguration()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subjectAreaDidChange),
            name: AVCaptureDevice.subjectAreaDidChangeNotification,
            object: camera
        )
    }

    @objc private func subjectAreaDidChange(_ notification: Notification) {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.requestFocus(at: CGPoint(x: 0.5, y: 0.5), reason: "subject-area-change")
        }
    }

    private func requestFocus(at point: CGPoint, reason: String) {
        guard let camera = activeCamera else { return }

        do {
            try camera.lockForConfiguration()
        } catch {
            logger.error(label: "Could not lock camera for focus request reason=\(reason)", error: error)
            return
        }

        if camera.isFocusPointOfInterestSupported {
            camera.focusPointOfInterest = point
        }

        if camera.isFocusModeSupported(.autoFocus) {
            camera.focusMode = .autoFocus
        } else if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }

        if camera.isExposurePointOfInterestSupported {
            camera.exposurePointOfInterest = point
        }

        if camera.isExposureModeSupported(.continuousAutoExposure) {
            camera.exposureMode = .continuousAutoExposure
        }

        camera.unlockForConfiguration()
        refocusCoordinator.markFocusRequested(point: point, at: CACurrentMediaTime())
        logger.info("Requested card focus reason=\(reason) point=\(point.debugDescription)")
    }

    private func resumeContinuousFocusIfNeeded() {
        guard let camera = activeCamera else {
            return
        }

        guard !camera.isAdjustingFocus else {
            return
        }

        guard camera.focusMode == .autoFocus else {
            return
        }

        do {
            try camera.lockForConfiguration()
        } catch {
            return
        }

        if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }

        camera.unlockForConfiguration()
    }

    private func logCameraCapabilities(_ camera: AVCaptureDevice) {
        logger.info(
            "Using camera type=\(camera.deviceType.rawValue) minimumFocusDistance=\(camera.minimumFocusDistance) switchOvers=\(camera.virtualDeviceSwitchOverVideoZoomFactors) minZoom=\(camera.minAvailableVideoZoomFactor) maxZoom=\(camera.maxAvailableVideoZoomFactor) nearRestriction=\(camera.isAutoFocusRangeRestrictionSupported)"
        )
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
        let now = CACurrentMediaTime()
        let isFocusAdjusting = activeCamera?.isAdjustingFocus ?? false
        let isFocusSettling = refocusCoordinator.isSettling(at: now)
        let pipelineResult = framePipeline.process(
            frame,
            isFocusAdjusting: isFocusAdjusting,
            isFocusSettling: isFocusSettling
        )
        guard let frameResult = logPipelineResult(pipelineResult, frame: frame) else {
            return
        }
        emitDetectionReport(frameResult.detectionReport)
        handleFocusFeedback(frameResult, at: now)

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

    private func handleFocusFeedback(_ frameResult: PokemonCardPipelineFrameResult, at time: TimeInterval) {
        guard let detection = frameResult.detectionReport.selectedDetection else {
            emit(.running)
            return
        }

        guard let focusQuality = frameResult.focusQuality else {
            emit(.running)
            return
        }

        let focusPoint = Self.deviceFocusPoint(for: detection.normalizedBoundingBox)
        if refocusCoordinator.shouldRequestFocus(point: focusPoint, focusQuality: focusQuality, at: time) {
            requestFocus(at: focusPoint, reason: "\(focusQuality.reason)")
        } else {
            resumeContinuousFocusIfNeeded()
        }

        emitScanningState(focusQuality: focusQuality, decision: frameResult.autoCaptureDecision)
    }

    private func emitScanningState(
        focusQuality: PokemonCardFocusQualityReport,
        decision: PokemonCardAutoCaptureDecision
    ) {
        switch focusQuality.reason {
        case .tooCloseLikely:
            emit(.moveFartherAway)
        case .tooDark, .tooLowContrast:
            emit(.moreLightNeeded)
        case .waitingForAutofocus:
            emit(.holdingSteady)
        case .tooBlurry:
            emit(decision.isGeometryStable ? .holdingSteady : .running)
        case .focused:
            emit(.running)
        }
    }

    static func deviceFocusPoint(for normalizedBoundingBox: CGRect) -> CGPoint {
        let rect = normalizedBoundingBox.standardized
        return CGPoint(
            x: min(max(1 - rect.midY, 0), 1),
            y: min(max(1 - rect.midX, 0), 1)
        )
    }

    private func logPipelineResult(
        _ result: Result<PokemonCardPipelineFrameResult, PokemonCardPipelineError>,
        frame: UIImage
    ) -> PokemonCardPipelineFrameResult? {
        switch result {
        case .success(let frameResult):
            logDetectionReport(frameResult.detectionReport, frame: frame)
            logFocusQuality(frameResult.focusQuality, decision: frameResult.autoCaptureDecision)
            return frameResult
        case .failure(let error):
            logger.error("Card pipeline failed: \(error.localizedDescription)")
            emit(.failed(error.localizedDescription))
            return nil
        }
    }

    private func logDetectionReport(_ report: PokemonCardShapeDetectionReport, frame: UIImage) {
        if let detection = report.selectedDetection {
            let rect = detection.normalizedBoundingBox.standardized
            logger.info(
                "Card detection selected confidence=\(detection.confidence) rect=\(rect.debugDescription) candidates=\(report.candidates.count) valid=\(report.validCandidateCount)"
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
                "Card candidate source=\(candidate.source.rawValue) confidence=\(metrics.confidence) score=\(candidate.score) rect=\(rect.debugDescription) aspect=\(metrics.boundingAspectRatio) area=\(metrics.areaFraction) content=\(metrics.contentScore) shape=\(metrics.shapeScore) rejected=\(reasons)"
            )
        }
    }

    private func logFocusQuality(
        _ focusQuality: PokemonCardFocusQualityReport?,
        decision: PokemonCardAutoCaptureDecision
    ) {
        guard let focusQuality else {
            return
        }

        logger.info(
            "Focus quality sharp=\(focusQuality.isSharpEnough) reason=\(focusQuality.reason) laplacian=\(focusQuality.sharpnessScore) gradient=\(focusQuality.gradientScore) brightness=\(focusQuality.brightness) contrast=\(focusQuality.contrast) geometryStable=\(decision.isGeometryStable) focusEligible=\(decision.isFocusEligible)"
        )
    }
}
