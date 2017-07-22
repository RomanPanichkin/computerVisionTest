//
//  ViewController.swift
//  computerVision
//
//  Created by Roman Panichkin on 7/22/17.
//  Copyright © 2017 Roman Panichkin. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    @IBOutlet var visualEffectView: UIVisualEffectView!
    @IBOutlet var outputLabel: UILabel!
    @IBOutlet var containerView: UIView!
    
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    let captureQueue = DispatchQueue(label: "captureQueue")
    var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let camera = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        containerView.layer.addSublayer(previewLayer)
        
        let cameraInput = try! AVCaptureDeviceInput(device: camera)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        session.sessionPreset = .high
        session.addInput(cameraInput)
        session.addOutput(videoOutput)
        
        let connection = videoOutput.connection(with: .video)
        connection?.videoOrientation = .portrait
        session.startRunning()
        
        initVision()
    }
    
    func initVision() {
        guard let visionModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
            fatalError("Could not load model")
        }
        
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
        classificationRequest.imageCropAndScaleOption = .centerCrop
        visionRequests = [classificationRequest]
    }
    
    private func handleClassifications(request: VNRequest, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        guard let results = request.results as? [VNClassificationObservation] else {
            print("No results")
            return
        }
        
        var resultString = "Это не кот!"
        results[0...3].forEach {
            let identifer = $0.identifier.lowercased()
            if identifer.range(of: "cat") != nil {
                resultString = "Это кот!"
            }
        }
        DispatchQueue.main.async {
            self.outputLabel.text = resultString
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions: [VNImageOption: Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                        orientation: CGImagePropertyOrientation.init(rawValue: 1)!,
                                                        options: requestOptions)
        do {
            try imageRequestHandler.perform(visionRequests)
        } catch {
            print(error)
        }
    }
}

