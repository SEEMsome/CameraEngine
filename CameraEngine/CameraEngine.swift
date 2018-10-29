//
//  CameraEngine.swift
//  CameraEngine2
//
//  Created by Remi Robert on 24/12/15.
//  Copyright © 2015 Remi Robert. All rights reserved.
//

import UIKit
import AVFoundation

public enum CameraEngineDeviceAccessResult {
    case camera(CameraEngine.DeviceAccessState)
    case microphone(CameraEngine.DeviceAccessState)
}

public typealias CameraEngineDeviceAccessStateHandler = ((CameraEngine.DeviceAccessAction) -> Void)
public typealias CameraEngineDeviceAccessCompletion = ((CameraEngineDeviceAccessResult, CameraEngineDeviceAccessStateHandler?) -> Void)

public enum CameraEngineSessionPreset {
    case photo
    case high
    case medium
    case low
    case cif352x288
    case vga640x480
    case hd1280x720
    case hd1920x1080
    case hd4k3840x2160
    case iFrame960x540
    case iFrame1280x720
    case inputPriority
    
    public func foundationPreset() -> AVCaptureSession.Preset {
        switch self {
        case .photo: return AVCaptureSession.Preset.photo
        case .high: return AVCaptureSession.Preset.high
        case .medium: return AVCaptureSession.Preset.medium
        case .low: return AVCaptureSession.Preset.low
        case .cif352x288: return AVCaptureSession.Preset.cif352x288
        case .vga640x480: return AVCaptureSession.Preset.vga640x480
        case .hd1280x720: return AVCaptureSession.Preset.hd1280x720
        case .hd1920x1080: return AVCaptureSession.Preset.hd1920x1080
        case .hd4k3840x2160:
            if #available(iOS 9.0, *) {
                return AVCaptureSession.Preset.hd4K3840x2160
            }
            else {
                return AVCaptureSession.Preset.photo
            }
        case .iFrame960x540: return AVCaptureSession.Preset.iFrame960x540
        case .iFrame1280x720: return AVCaptureSession.Preset.iFrame1280x720
        default: return AVCaptureSession.Preset.photo
        }
    }
    
    public static func availablePresset() -> [CameraEngineSessionPreset] {
        return [
            .photo,
            .high,
            .medium,
            .low,
            .cif352x288,
            .vga640x480,
            .hd1280x720,
            .hd1920x1080,
            .hd4k3840x2160,
            .iFrame960x540,
            .iFrame1280x720,
            .inputPriority
        ]
    }
}

let cameraEngineSessionQueueIdentifier = "com.cameraEngine.capturesession"

public class CameraEngine: NSObject {
    
    let session = AVCaptureSession()
    let cameraDevice = CameraEngineDevice()
    let cameraOutput = CameraEngineCaptureOutput()
    let cameraInput = CameraEngineDeviceInput()
    let cameraMetadata = CameraEngineMetadataOutput()
    let cameraGifEncoder = CameraEngineGifEncoder()
    let capturePhotoSettings = AVCapturePhotoSettings()
    var captureDeviceIntput: AVCaptureDeviceInput?
    private(set) var devicePermissionRequests: [DevicePermissionRequest] = DevicePermissionRequest.default
    
    var sessionQueue: DispatchQueue = DispatchQueue(label: cameraEngineSessionQueueIdentifier)
    
    private var _torchMode: AVCaptureDevice.TorchMode = .off
    public var torchMode: AVCaptureDevice.TorchMode! {
        get {
            return _torchMode
        }
        set {
            _torchMode = newValue
            configureTorch(newValue)
        }
    }
    
    private var _flashMode: AVCaptureDevice.FlashMode = .off
    public var flashMode: AVCaptureDevice.FlashMode! {
        get {
            return _flashMode
        }
        set {
            _flashMode = newValue
            configureFlash(newValue)
        }
    }
    
    public lazy var previewLayer: AVCaptureVideoPreviewLayer! = {
        let layer =  AVCaptureVideoPreviewLayer(session: self.session)
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        return layer
    }()
    
    private var _sessionPresset: CameraEngineSessionPreset = .inputPriority
    public var sessionPresset: CameraEngineSessionPreset! {
        get {
            return self._sessionPresset
        }
        set {
            if self.session.canSetSessionPreset(newValue.foundationPreset()) {
                self._sessionPresset = newValue
                self.session.sessionPreset = self._sessionPresset.foundationPreset()
            }
            else {
                fatalError("[CameraEngine] session presset : [\(newValue.foundationPreset())] uncompatible with the current device")
            }
        }
    }
    
    private var _cameraFocus: CameraEngine.Focus = .continuousAutoFocus
    public var cameraFocus: CameraEngine.Focus! {
        get {
            return self._cameraFocus
        }
        set {
            self.cameraDevice.changeCameraFocusMode(newValue)
            self._cameraFocus = newValue
        }
    }
    
    private var _metadataDetection: CameraEngineCaptureOutputDetection = .none
    public var metadataDetection: CameraEngineCaptureOutputDetection! {
        get {
            return self._metadataDetection
        }
        set {
            self._metadataDetection = newValue
            self.cameraMetadata.configureMetadataOutput(self.session, sessionQueue: self.sessionQueue, metadataType: self._metadataDetection)
        }
    }
    
    private var _videoEncoderPresset: CameraEngineVideoEncoderEncoderSettings!
    public var videoEncoderPresset: CameraEngineVideoEncoderEncoderSettings! {
        set {
            self._videoEncoderPresset = newValue
            self.cameraOutput.setPressetVideoEncoder(self._videoEncoderPresset)
        }
        get {
            return self._videoEncoderPresset
        }
    }
    
    private var _cameraZoomFactor: CGFloat = 1.0
    public var cameraZoomFactor: CGFloat! {
        get {
            if let `captureDevice` = captureDevice {
                _cameraZoomFactor = captureDevice.videoZoomFactor
            }
            
            return self._cameraZoomFactor
        }
        set {
            let newZoomFactor = self.cameraDevice.changeCurrentZoomFactor(newValue)
            if newZoomFactor > 0 {
                self._cameraZoomFactor = newZoomFactor
            }
        }
    }
    
    public var blockCompletionBuffer: blockCompletionOutputBuffer? {
        didSet {
            self.cameraOutput.blockCompletionBuffer = self.blockCompletionBuffer
        }
    }
    
    public var blockCompletionProgress: blockCompletionProgressRecording? {
        didSet {
            self.cameraOutput.blockCompletionProgress = self.blockCompletionProgress
        }
    }
    
    public var blockCompletionFaceDetection: blockCompletionDetectionFace? {
        didSet {
            self.cameraMetadata.blockCompletionFaceDetection = self.blockCompletionFaceDetection
        }
    }
    
    public var blockCompletionCodeDetection: blockCompletionDetectionCode? {
        didSet {
            self.cameraMetadata.blockCompletionCodeDetection = self.blockCompletionCodeDetection
        }
    }
    
    private var _rotationCamera = false
    public var rotationCamera: Bool {
        get {
            return _rotationCamera
        }
        set {
            _rotationCamera = newValue
            self.handleDeviceOrientation()
        }
    }
    
    public var captureDevice: AVCaptureDevice? {
        get {
            return cameraDevice.currentDevice
        }
    }
    
    public var isRecording: Bool {
        get {
            return self.cameraOutput.isRecording
        }
    }
    
    public var isAdjustingFocus: Bool {
        get {
            if let `captureDevice` = captureDevice {
                return captureDevice.isAdjustingFocus
            }
            
            return false
        }
    }
    
    public var isAdjustingExposure: Bool {
        get {
            if let `captureDevice` = captureDevice {
                return captureDevice.isAdjustingExposure
            }
            
            return false
        }
    }
    
    public var isAdjustingWhiteBalance: Bool {
        get {
            if let `captureDevice` = captureDevice {
                return captureDevice.isAdjustingWhiteBalance
            }
            
            return false
        }
    }
    
    public static let shared = CameraEngine()
    private override init() {
        super.init()
    }
    
    /*
    public func testStart() {
        startSession(devicePermissionRequests: [.camera, .microphone], deviceAccessPermissionHandler: { result, onFinishHandlingDeviceAccessState in
            switch result {
            case .camera(.denied),
                 .camera(.restricted),
                 .camera(.unableToAdd(.camera)),
                 .camera(.unableToAdd(.microphone)),
                 .microphone(.denied),
                 .microphone(.restricted),
                 .microphone(.unableToAdd(.microphone)),
                 .microphone(.unableToAdd(.camera)):
                // TODO:
                //
                // fix redundant cases like:
                // .camera(.unableToAdd(.microphone)),
                // .microphone(.unableToAdd(.camera)):
                //
                // print("sad :(")
                // present in-app alert, settings change required here
                //
                onFinishHandlingDeviceAccessState?(.settingsChangeRequired)
            case .camera(.notDetermined), .microphone(.notDetermined):
                //
                //print("ok, preparing ui for the first permission request")
                //
                // notify caller to show in-app ui for upcoming system permission, then continue on notify completion
                onFinishHandlingDeviceAccessState?(.canPerformFirstTimeDeviceAccess)
            case .camera(.authorized), .microphone(.authorized):
                onFinishHandlingDeviceAccessState?(.canProceedAccessGranted)
            case let .camera(.other(errorMessage)):
                onFinishHandlingDeviceAccessState?(.unexpectedError(errorMessage))
            case let .microphone(.other(errorMessage)):
                onFinishHandlingDeviceAccessState?(.unexpectedError(errorMessage))
            }
        })
    }
    */
    
    public func startSession(devicePermissionRequests: [DevicePermissionRequest],
                             deviceAccessPermissionHandler: @escaping CameraEngineDeviceAccessCompletion) {
        self.devicePermissionRequests = devicePermissionRequests
        setupSession(deviceAccessPermissionHandler: deviceAccessPermissionHandler)
        startSession()
    }
    
    deinit {
        self.stopSession()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupSession(deviceAccessPermissionHandler: @escaping CameraEngineDeviceAccessCompletion) {
        self.sessionQueue.async { () -> Void in
            self.configureInputDevice(deviceAccessPermissionHandler: deviceAccessPermissionHandler)
            self.configureOutputDevice()
            self.handleDeviceOrientation()
        }
    }
    
    public class func cameraAuthorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    }
    
    public class func microphoneAuthorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)
    }
    
    //MARK: Session management
    
    public func startSession() {
        let session = self.session
        
        self.sessionQueue.async { () -> Void in
            session.startRunning()
        }
    }
    
    public func stopSession() {
        let session = self.session
        
        self.sessionQueue.async { () -> Void in
            session.stopRunning()
        }
    }
    
    //MARK: Device management
    
    private func handleDeviceOrientation() {
        if self.rotationCamera {
			if (!UIDevice.current.isGeneratingDeviceOrientationNotifications) {
				UIDevice.current.beginGeneratingDeviceOrientationNotifications()
			}
            NotificationCenter.default.addObserver(forName: NSNotification.Name.UIDeviceOrientationDidChange, object: nil, queue: OperationQueue.main) { (_) -> Void in
                self.previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.orientationFromUIDeviceOrientation(UIDevice.current.orientation)
            }
        }
        else {
			if (UIDevice.current.isGeneratingDeviceOrientationNotifications) {
				UIDevice.current.endGeneratingDeviceOrientationNotifications()
			}
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        }
    }
    
    public func changeCurrentDevicePosition(_ position: AVCaptureDevice.Position) {
        self.cameraDevice.changeCurrentDevice(position)
        self.configureInputDevice(deviceAccessPermissionHandler: nil)
    }
    
    public func compatibleCameraFocus() -> [CameraEngine.Focus] {
        if let currentDevice = self.cameraDevice.currentDevice {
            return CameraEngine.Focus.availableFocus().filter {
                return currentDevice.isFocusModeSupported($0.foundationFocus())
            }
        }
        else {
            return []
        }
    }
    
    public func compatibleSessionPresset() -> [CameraEngineSessionPreset] {
        return CameraEngineSessionPreset.availablePresset().filter {
            return self.session.canSetSessionPreset($0.foundationPreset())
        }
    }
    
    public func compatibleVideoEncoderPresset() -> [CameraEngineVideoEncoderEncoderSettings] {
        return CameraEngineVideoEncoderEncoderSettings.availableFocus()
    }
    
    public func compatibleDetectionMetadata() -> [CameraEngineCaptureOutputDetection] {
        return CameraEngineCaptureOutputDetection.availableDetection()
    }
    
    private func configureFlash(_ mode: AVCaptureDevice.FlashMode) {
        if let currentDevice = self.cameraDevice.currentDevice, currentDevice.isFlashAvailable && self.capturePhotoSettings.flashMode != mode {
            self.capturePhotoSettings.flashMode = mode
        }
//        if let currentDevice = self.cameraDevice.currentDevice, currentDevice.isFlashAvailable && currentDevice.flashMode != mode {
//            do {
//                try currentDevice.lockForConfiguration()
//                currentDevice.flashMode = mode
//                currentDevice.unlockForConfiguration()
//            }
//            catch {
//                fatalError("[CameraEngine] error lock configuration device")
//            }
//        }
    }
    
    private func configureTorch(_ mode: AVCaptureDevice.TorchMode) {
        if let currentDevice = self.cameraDevice.currentDevice, currentDevice.isTorchAvailable && currentDevice.torchMode != mode {
            do {
                try currentDevice.lockForConfiguration()
                currentDevice.torchMode = mode
                currentDevice.unlockForConfiguration()
            }
            catch {
                fatalError("[CameraEngine] error lock configuration device")
            }
        }
    }
    
    public func switchCurrentDevice() {
        if self.isRecording == false {
            let position = self.cameraDevice.currentPosition.toggle()
            self.changeCurrentDevicePosition(position)
        }
    }
    
    public var currentDevicePosition: AVCaptureDevice.Position {
        get {
            return self.cameraDevice.currentPosition
        }
        set {
            self.changeCurrentDevicePosition(newValue)
        }
    }
    
    //MARK: Device I/O configuration
    
    private func configureInputDevice(deviceAccessPermissionHandler: CameraEngineDeviceAccessCompletion?) {
        if let currentDevice = self.cameraDevice.currentDevice, devicePermissionRequests.contains(.camera) {
            self.cameraInput.configureInputCamera(self.session, device: currentDevice, deviceAccessPermissionHandler: deviceAccessPermissionHandler)
        }
        if let micDevice = self.cameraDevice.micCameraDevice, devicePermissionRequests.contains(.microphone) {
            self.cameraInput.configureInputMic(self.session, device: micDevice, deviceAccessPermissionHandler: deviceAccessPermissionHandler)
        }
    }
    
    private func configureOutputDevice() {
        self.cameraOutput.configureCaptureOutput(self.session, sessionQueue: self.sessionQueue)
        self.cameraMetadata.previewLayer = self.previewLayer
        self.cameraMetadata.configureMetadataOutput(self.session, sessionQueue: self.sessionQueue, metadataType: self.metadataDetection)
    }
}

//MARK: Extension Device

public extension CameraEngine {
    
    public func focus(_ atPoint: CGPoint) {
        if let currentDevice = self.cameraDevice.currentDevice {
			let performFocus = currentDevice.isFocusModeSupported(.autoFocus) && currentDevice.isFocusPointOfInterestSupported
			let performExposure = currentDevice.isExposureModeSupported(.autoExpose) && currentDevice.isExposurePointOfInterestSupported
            if performFocus || performExposure {
                let focusPoint = self.previewLayer.captureDevicePointConverted(fromLayerPoint: atPoint)
                do {
                    try currentDevice.lockForConfiguration()
					
					if performFocus {
						currentDevice.focusPointOfInterest = CGPoint(x: focusPoint.x, y: focusPoint.y)
						if currentDevice.focusMode == AVCaptureDevice.FocusMode.locked {
							currentDevice.focusMode = AVCaptureDevice.FocusMode.autoFocus
						} else {
							currentDevice.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
						}
					}
					
                    if performExposure {
						currentDevice.exposurePointOfInterest = CGPoint(x: focusPoint.x, y: focusPoint.y)
                        if currentDevice.exposureMode == AVCaptureDevice.ExposureMode.locked {
                            currentDevice.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
                        } else {
                            currentDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure;
                        }
                    }
                    currentDevice.unlockForConfiguration()
                }
                catch {
                    fatalError("[CameraEngine] error lock configuration device")
                }
            }
        }
    }
}

//MARK: Extension capture

public extension CameraEngine {
    
    public func capturePhoto(_ blockCompletion: @escaping blockCompletionCapturePhoto) {
        self.cameraOutput.capturePhoto(settings: self.capturePhotoSettings, blockCompletion)
    }
	
	public func capturePhotoBuffer(_ blockCompletion: @escaping blockCompletionCapturePhotoBuffer) {
        self.cameraOutput.capturePhotoBuffer(settings: self.capturePhotoSettings, blockCompletion)
	}
    
    public func startRecordingVideo(_ url: URL, blockCompletion: @escaping blockCompletionCaptureVideo) {
        if self.isRecording == false {
            self.sessionQueue.async(execute: { () -> Void in
                self.cameraOutput.startRecordVideo(blockCompletion, url: url)
            })
        }
    }
    
    public func stopRecordingVideo() {
        if self.isRecording {
            self.sessionQueue.async(execute: { () -> Void in
                self.cameraOutput.stopRecordVideo()
            })
        }
    }
    
    public func createGif(_ fileUrl: URL, frames: [UIImage], delayTime: Float, loopCount: Int = 0, completionGif: @escaping blockCompletionGifEncoder) {
        self.cameraGifEncoder.blockCompletionGif = completionGif
        self.cameraGifEncoder.createGif(fileUrl, frames: frames, delayTime: delayTime, loopCount: loopCount)
    }
}

extension AVCaptureDevice.Position {
    public func toggle() -> AVCaptureDevice.Position {
        switch self {
        case .back: return .front
        case .front, .unspecified: return .back
        }
    }
}
