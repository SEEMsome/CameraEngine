//
//  CameraEngineDeviceInput.swift
//  CameraEngine2
//
//  Created by Remi Robert on 01/02/16.
//  Copyright © 2016 Remi Robert. All rights reserved.
//

import UIKit
import AVFoundation

public enum CameraEngineDeviceInputErrorType: Error {
    case unableToAddCamera
    case unableToAddMic
}

class CameraEngineDeviceInput {

    private var cameraDeviceInput: AVCaptureDeviceInput?
    private var micDeviceInput: AVCaptureDeviceInput?
    
    func configureInputCamera(_ session: AVCaptureSession,
                              device: AVCaptureDevice,
                              deviceAccessPermissionHandler: CameraEngineDeviceAccessCompletion?) {
        
        let onAccessGranted = {
            session.beginConfiguration()
            let possibleCameraInput: AnyObject?
            do {
                possibleCameraInput = try AVCaptureDeviceInput(device: device)
            } catch {
                deviceAccessPermissionHandler?(.camera(.other(error.localizedDescription)), nil)
                return
            }
            
            if let cameraInput = possibleCameraInput as? AVCaptureDeviceInput {
                if let currentDeviceInput = self.cameraDeviceInput {
                    session.removeInput(currentDeviceInput)
                }
                self.cameraDeviceInput = cameraInput
                if let cameraInput = self.cameraDeviceInput, session.canAddInput(cameraInput) {
                    session.addInput(cameraInput)
                }
                else {
                    deviceAccessPermissionHandler?(.camera(.unableToAdd(.camera)), nil)
                    return
                }
            }
            session.commitConfiguration()
        }
        
        let onProcceed: CameraEngineDeviceAccessStateHandler = { action in
            switch action {
            case .canPerformFirstTimeDeviceAccess, .canProceedAccessGranted:
                onAccessGranted()
            case .settingsChangeRequired, .unexpectedError, .runningOnSimulator:
                print("nothing to do")
                // TODO: probably remove inputs & kill session.
            }
        }
        
        let accessState = CameraEngine.DeviceAccessState.init(status: CameraEngine.cameraAuthorizationStatus())
        deviceAccessPermissionHandler?(.camera(accessState), onProcceed)
    }
    
    func configureInputMic(_ session: AVCaptureSession, device: AVCaptureDevice, deviceAccessPermissionHandler: CameraEngineDeviceAccessCompletion?) {
        
        let onAccessGranted = {
            if self.micDeviceInput != nil {
                deviceAccessPermissionHandler?(.microphone(.unableToAdd(.microphone)), nil)
                return
            }
            
            let micDeviceInput: AVCaptureDeviceInput
            do {
                micDeviceInput = try AVCaptureDeviceInput(device: device)
            } catch {
                deviceAccessPermissionHandler?(.microphone(.other(error.localizedDescription)), nil)
                return
            }
            
            self.micDeviceInput = micDeviceInput
            
            if let micInput = self.micDeviceInput, session.canAddInput(micInput) {
                session.addInput(micInput)
            }
            else {
                deviceAccessPermissionHandler?(.microphone(.unableToAdd(.microphone)), nil)
                return
            }
        }
        
        let onProcceed: CameraEngineDeviceAccessStateHandler = { action in
            switch action {
            case .canPerformFirstTimeDeviceAccess, .canProceedAccessGranted:
                onAccessGranted()
            case .settingsChangeRequired, .unexpectedError, .runningOnSimulator:
                print("nothing to do")
                // TODO: probably remove inputs & kill session.
            }
        }
        
        let accessState = CameraEngine.DeviceAccessState.init(status: CameraEngine.microphoneAuthorizationStatus())
        deviceAccessPermissionHandler?(.microphone(accessState), onProcceed)
    }
    
    static func defaultDeviceAccessHandler() -> CameraEngineDeviceAccessCompletion {
        let handler: CameraEngineDeviceAccessCompletion = { result, onFinishHandlingDeviceAccessState in
            switch result {
            // TODO: refactor this
            case .camera(.denied),
                 .camera(.restricted),
                 .camera(.unableToAdd(.camera)),
                 .camera(.unableToAdd(.microphone)),
                 .microphone(.denied),
                 .microphone(.restricted),
                 .microphone(.unableToAdd(.microphone)),
                 .microphone(.unableToAdd(.camera)):
                onFinishHandlingDeviceAccessState?(.settingsChangeRequired)
            case .camera(.notDetermined), .microphone(.notDetermined):
                onFinishHandlingDeviceAccessState?(.canPerformFirstTimeDeviceAccess)
            case .camera(.authorized), .microphone(.authorized):
                onFinishHandlingDeviceAccessState?(.canProceedAccessGranted)
            case let .camera(.other(errorMessage)):
                onFinishHandlingDeviceAccessState?(.unexpectedError(errorMessage))
            case let .microphone(.other(errorMessage)):
                onFinishHandlingDeviceAccessState?(.unexpectedError(errorMessage))
            case .camera(.runningOnSimulator),
                 .microphone(.runningOnSimulator):
                onFinishHandlingDeviceAccessState?(.runningOnSimulator)
            }
        }
        return handler
    }
}
