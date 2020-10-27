//
//  PreviewView.swift
//  CameraDemo
//
//  Created by Harry Sandhu on 2020-10-25.
//

import Foundation
import UIKit
import AVFoundation

/*
 This class facilitates session management.
 It provides a videoPreviewLayer and a session.
 videoPreviewLayer: AVCaptureVideoPreviewLayer to preview the capture.
 session: AVCaptureSession: to manage the session.
 */
class PreviewView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    
    /*
     AVCaptureSession accepts input data from capture device like - camera, microphone. After
     receiving the input, it sends that data to appropriate outputs for processing, resulting in a photo or
     a movie file.
     
    */
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
