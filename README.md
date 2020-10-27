#  Text Recognition using Vision

- Use Vision Framework to recognize text.

### How?
- Create a session: AVCaptureSession
- Get the video input from videoDeviceInput:AVCaptureDeviceInput
- Attach video input to session
- Attach session to previewView: a custom view backed by AVCaptureVideoPreviewLayer
    - Displays whats being captured in real time. 

### To process individual frames
- Create a videoOutput: AVCaptureVideoDataOutput 
- Set buffer delegate as 'sessionQueue' or same as the AVCaptureSession object.
- Attach videoOutput to session output.

- Get the buffer at captureOutput
- Use the following to process the buffer

```swift
    guard let uiImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
```
- In 'imageFromSampleBuffer', do the following

```swift
    let requestHandler = VNImageRequestHandler(cgImage: newImg)
    let request = VNRecognizeTextRequest(completionHandler: self.recognizeTextHandler)
```

- Implement recognizeTextHandler(request: VNRequest, error: Error?) 
- Get the recognized strings as:

```swift
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            return
        }
        let recognizedStrings = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance.
            return observation.topCandidates(1).first?.string
        }
        
        // Process the recognized strings.
        print(recognizedStrings)
```


- And you're done.
