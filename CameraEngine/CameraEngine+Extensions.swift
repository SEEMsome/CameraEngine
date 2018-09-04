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
