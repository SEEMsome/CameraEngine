//
//  CameraEngine+Extensions.swift
//  CameraEngine
//
//  Created by Stan Baranouski on 9/4/18.
//  Copyright © 2018 Remi Robert. All rights reserved.
//

import UIKit
import AVFoundation

extension CameraEngine {
    
    public enum DevicePermissionRequest {
        case camera, microphone
        static let `default`: [DevicePermissionRequest] = [.camera, .microphone]
    }
    
    public enum DeviceAccessState {
        public enum UnableToAdd {
            case camera, microphone
        }
        
        case authorized // can proceed safely
        case denied // settings changes required
        case restricted // probably restricted at parental control
        case notDetermined // choice by the user wasn't made
        case unableToAdd(UnableToAdd)
        case runningOnSimulator
        case other(String)
        
        init(status: AVAuthorizationStatus) {
            switch status {
            case .authorized: self = .authorized
            case .denied: self = .denied
            case .restricted: self = .restricted
            case .notDetermined: self = .notDetermined
            }
        }
    }
    
    public enum DeviceAccessAction {
        case settingsChangeRequired // access was denied  or restricted at parental control
        case canPerformFirstTimeDeviceAccess // access not determined, can present in-app device access description (optional) before requesting on system level
        case canProceedAccessGranted // access granted, can proceed safely
        case unexpectedError(String)
        case runningOnSimulator
    }

    public enum Focus {
        case locked
        case autoFocus
        case continuousAutoFocus
        
        func foundationFocus() -> AVCaptureDevice.FocusMode {
            switch self {
            case .locked: return AVCaptureDevice.FocusMode.locked
            case .autoFocus: return AVCaptureDevice.FocusMode.autoFocus
            case .continuousAutoFocus: return AVCaptureDevice.FocusMode.continuousAutoFocus
            }
        }
        
        public func description() -> String {
            switch self {
            case .locked: return "Locked"
            case .autoFocus: return "AutoFocus"
            case .continuousAutoFocus: return "ContinuousAutoFocus"
            }
        }
        
        public static func availableFocus() -> [CameraEngine.Focus] {
            return [
                .locked,
                .autoFocus,
                .continuousAutoFocus
            ]
        }
    }
    
}
