//
//  CameraEngineDevice.swift
//  CameraEngine2
//
//  Created by Remi Robert on 24/12/15.
//  Copyright © 2015 Remi Robert. All rights reserved.
//

import UIKit
import AVFoundation

class CameraEngineDevice {
    
    private var backCameraDevice: AVCaptureDevice!
    private var frontCameraDevice: AVCaptureDevice!
    var micCameraDevice: AVCaptureDevice!
    var currentDevice: AVCaptureDevice?
    var currentPosition: AVCaptureDevice.Position = .unspecified
    
    func changeCameraFocusMode(_ focusMode: CameraEngine.Focus) {
        if let currentDevice = self.currentDevice {
            do {
                try currentDevice.lockForConfiguration()
                if currentDevice.isFocusModeSupported(focusMode.foundationFocus()) {
                    currentDevice.focusMode = focusMode.foundationFocus()
                }
                currentDevice.unlockForConfiguration()
            }
            catch {
                fatalError("[CameraEngine] error, impossible to lock configuration device")
            }
        }
    }
    
    func changeCurrentZoomFactor(_ newFactor: CGFloat) -> CGFloat {
        var zoom: CGFloat = 1.0
        if let currentDevice = self.currentDevice {
            do {
                try currentDevice.lockForConfiguration()
                zoom = max(1.0, min(newFactor, currentDevice.activeFormat.videoMaxZoomFactor))
                currentDevice.videoZoomFactor = zoom
                currentDevice.unlockForConfiguration()
            }
            catch {
                zoom = -1.0
                fatalError("[CameraEngine] error, impossible to lock configuration device")
            }
        }
        
        return zoom
    }
    
    func changeCurrentDevice(_ position: AVCaptureDevice.Position) {
        self.currentPosition = position
        switch position {
        case .back: self.currentDevice = self.backCameraDevice
        case .front: self.currentDevice = self.frontCameraDevice
        case .unspecified: self.currentDevice = nil
        }
    }
    
    private func configureDeviceCamera() {
        self.backCameraDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInDuoCamera, AVCaptureDevice.DeviceType.builtInTelephotoCamera, AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.back).devices.first
        
        self.frontCameraDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInDuoCamera, AVCaptureDevice.DeviceType.builtInTelephotoCamera, AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.front).devices.first
    }
    
    private func configureDeviceMic() {
        self.micCameraDevice = AVCaptureDevice.default(for: .audio)
    }
    
    init() {
        self.configureDeviceCamera()
        self.configureDeviceMic()
        self.changeCurrentDevice(.back)
    }
}
