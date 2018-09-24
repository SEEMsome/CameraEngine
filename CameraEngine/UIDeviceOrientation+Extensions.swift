//
//  UIDeviceOrientation+Extensions.swift
//  CameraEngine
//
//  Created by Stan Baranouski on 9/4/18.
//  Copyright © 2018 Remi Robert. All rights reserved.
//

import UIKit

extension UIDeviceOrientation {
    
    // source: https://stackoverflow.com/a/46896096/1994889
    func getUIImageOrientationFromDevice() -> UIImage.Orientation {
        // return CGImagePropertyOrientation based on Device Orientation
        // This extented function has been determined based on experimentation with how an UIImage gets displayed.
        switch self {
        case UIDeviceOrientation.portrait, .faceUp: return UIImage.Orientation.right
        case UIDeviceOrientation.portraitUpsideDown, .faceDown: return UIImage.Orientation.left
        case UIDeviceOrientation.landscapeLeft: return UIImage.Orientation.up // this is the base orientation
        case UIDeviceOrientation.landscapeRight: return UIImage.Orientation.down
        case UIDeviceOrientation.unknown: return UIImage.Orientation.up
        }
    }
    
}
