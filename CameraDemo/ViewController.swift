//
//  ViewController.swift
//  CameraDemo
//
//  Created by Harry Sandhu on 2020-10-25.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
         
 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        cameraButton.isEnabled = false
        resultText.isEditable = false
        
        if previewView != nil {
            previewView.session = session
        }else{
            print("WHAT TEH SHIT")
        }
           
        
        switch AVCaptureDevice.authorizationStatus(for: .video){
        case .authorized:
            break
        case .notDetermined:
        /*
         The user has not yet been presented with the option to grant
         video access. Suspend the session queue to delay session
         setup until the access request has completed.
         
         Note that audio access will be implicitly requested when we
         create an AVCaptureDeviceInput for audio during session setup.
         */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: {
                granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
            
        default:
            setupResult = .notAuthorized
        }
        
        
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        
        
        sessionQueue.async {
            self.configureSession()
            print("Session is running...")
        }
    
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session if setup succeeded.
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    
    @IBAction func cameraButtonPressed(_ sender: UIButton) {
    }
    
    
    
    
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    
    // MARK: Session Management
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    let session = AVCaptureSession()
    private var isSessionRunning = false
    
    // Communicate with the session and other session objects on this queue
    private let sessionQueue = DispatchQueue(label:"session queue")
    private var setupResult: SessionSetupResult = SessionSetupResult.success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    

    @IBOutlet weak var previewView: PreviewView!
    
    // Call this on session queue
    /// - Tag: ConfigureSession
    private func configureSession(){
        if setupResult != .success{ return }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        //add video input
        do {
            var defaultVideoDevice: AVCaptureDevice?
            // Choose the back dual camera, if available, otherwise default to a wide angle camera.
            
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back){
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for:.video, position:.back){
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for:.video, position:.front){
                defaultVideoDevice = frontCameraDevice
            }
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device in unavailable")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput){
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
//                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "session queue"))
                guard session.canAddOutput(videoOutput) else {return}
                session.addOutput(videoOutput)
                guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
                connection.videoOrientation = .portrait
                
                DispatchQueue.main.async {
                    /*
                     Dispatch video streaming to the main queue because AVCaptureVideoPreviewLayer is the backing layer for PreviewView.
                     You can manipulate UIView only on the main thread.
                     Note: As an exception to the above rule, it's not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                     
                     Use the window scene's orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    
                    let initialVideoOrientation:AVCaptureVideoOrientation = .portrait
                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                    self.previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
                }
                
                
                
                
            }else{
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
        }catch{
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
//        if session.canAddOutput(<#T##output: AVCaptureOutput##AVCaptureOutput#>)
    }
   
    private let context = CIContext()
    @IBOutlet weak var resultText: UITextView!
    
   
    private func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            return
        }
        let recognizedStrings = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance.
            return observation.topCandidates(1).first?.string
        }
        
        // Process the recognized strings.
        print(recognizedStrings.count)
        if recognizedStrings.count > 0 {
            self.resultText.text = recognizedStrings.joined(separator: " ")
        }
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage?{
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return nil}
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent) else {return nil}
        
        var ratio: Float = 0.0
               let imageWidth = Float(cgImage.width)
               let imageHeight = Float(cgImage.height)
               let maxWidth: Float = 1024.0
               let maxHeight: Float = 768.0
               
               // Get ratio (landscape or portrait)
               if (imageWidth > imageHeight) {
                   ratio = maxWidth / imageWidth
               } else {
                   ratio = maxHeight / imageHeight
               }
               
               // Calculate new size based on the ratio
               if ratio > 1 {
                ratio = 0.05
               }
        
        
               let width = imageWidth * ratio
               let height = imageHeight * ratio
               
               guard let colorSpace = cgImage.colorSpace else { return nil }
               guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: cgImage.bytesPerRow, space: colorSpace, bitmapInfo: cgImage.alphaInfo.rawValue) else { return nil }
               
               // draw image to context (resizing it)
               context.interpolationQuality = .low
               context.draw(cgImage, in: CGRect(x: 0, y: 0, width: Int(width), height: Int(height)))
        guard let newImg = context.makeImage() else {return nil}
        
        let requestHandler = VNImageRequestHandler(cgImage: newImg)
        let request = VNRecognizeTextRequest(completionHandler: self.recognizeTextHandler)
        

        
        do{
            try requestHandler.perform([request])
        }catch{
            print("Unable to perform the requests: \(error).")
        }
        
        return UIImage(cgImage: newImg)
    }
    
    
  
    
    
    func captureOutput(_ output: AVCaptureOutput,
                  didOutput sampleBuffer: CMSampleBuffer,
                         from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
                guard let uiImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
            self.imageView.image = uiImage
        
            
            }
        
    }
 
    
}

