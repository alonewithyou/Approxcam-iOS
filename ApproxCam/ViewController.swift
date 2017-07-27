//
//  ViewController.swift
//  ApproxCam
//
//  Created by Shining on 2017/7/17.
//  Copyright © 2017年 Shining. All rights reserved.
//

import UIKit
import Photos
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    var outputObject : AVCapturePhotoOutput!
    var session: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var rawPhotoOutputBuffer: CMSampleBuffer!
    var capturedImage: UIImageView!
    
    @IBOutlet weak var preViewImage: UIImageView!
    @IBOutlet weak var captureImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSession()
    }
    
    func setupSession(){
        
        session = AVCaptureSession()
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input){
                session.addInput(input)
            }
        } catch {
            print("Error handling the camera Input: \(error)")
            return
        }
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session:session)
        videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        videoPreviewLayer.frame = preViewImage.bounds
        preViewImage.layer.addSublayer(videoPreviewLayer)
        
        outputObject = AVCapturePhotoOutput()
        session.addOutput(outputObject)
        
        session.sessionPreset = AVCaptureSessionPresetPhoto
        
        session.startRunning()
    }
    
    @IBAction func capturePicture() {
        print(outputObject.availablePhotoPixelFormatTypes)  //ip7:[875704422, 875704438, 1111970369]
        print(outputObject.availableRawPhotoPixelFormatTypes)

        let rawFormatType = outputObject.availableRawPhotoPixelFormatTypes.first as! OSType
        let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormatType,
                                                   processedFormat: [AVVideoCodecKey : AVVideoCodecJPEG])
        outputObject.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func getCurrentTimeWithString() -> String{
        let now = Date()
        let timeInterval:TimeInterval = now.timeIntervalSince1970
        return "/" + String(timeInterval) + ".dng"
    }
    
    func saveRAWPlusJPEGPhotoLibrary(_ rawSampleBuffer: CMSampleBuffer,
                                     rawPreviewSampleBuffer: CMSampleBuffer?,
                                     photoSampleBuffer: CMSampleBuffer,
                                     previewSampleBuffer: CMSampleBuffer?,
                                     completionHandler: ((_ success: Bool, _ error: Error?) -> Void)?) {
        guard let jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(
            forJPEGSampleBuffer: photoSampleBuffer,
            previewPhotoSampleBuffer: previewSampleBuffer)
            else {
                print("Unable to create JPEG data.")
                completionHandler?(false, nil)
                return
        }
            
        guard let dngData = AVCapturePhotoOutput.dngPhotoDataRepresentation(
            forRawSampleBuffer: rawSampleBuffer,
            previewPhotoSampleBuffer: rawPreviewSampleBuffer)
            else {
                print("Unable to create DNG data.")
                completionHandler?(false, nil)
                return
        }
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fileName = getCurrentTimeWithString()
        let dngFileURL = URL(string: "file://\(documentsPath + fileName)")
        print(dngFileURL!)
        do {
            try dngData.write(to: dngFileURL!, options: [])
        } catch let error as NSError {
            print("Unable to write DNG file.")
            completionHandler?(false, error)
            return
        }
            
        PHPhotoLibrary.shared().performChanges( {
            let creationRequest = PHAssetCreationRequest.forAsset()
            let creationOptions = PHAssetResourceCreationOptions()
            //creationOptions.shouldMoveFile = true
            creationRequest.addResource(with: .photo, data: jpegData, options: nil)
            creationRequest.addResource(with: .alternatePhoto, fileURL: dngFileURL!, options: creationOptions)
            },
            completionHandler: completionHandler)
    }
    
    var photoSampleBuffer: CMSampleBuffer?
    var previewPhotoSampleBuffer: CMSampleBuffer?
    var rawSampleBuffer: CMSampleBuffer?
    var rawPreviewPhotoSampleBuffer: CMSampleBuffer?
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        guard error == nil, let photoSampleBuffer = photoSampleBuffer else {
            print("Error capturing photo:\(String(describing: error))")
            return
        }
        
        self.photoSampleBuffer = photoSampleBuffer
        self.previewPhotoSampleBuffer = previewPhotoSampleBuffer
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingRawPhotoSampleBuffer rawSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        guard error == nil, let rawSampleBuffer = rawSampleBuffer else {
            print("Error capturing RAW photo:\(String(describing: error))")
            return
        }
        
        self.rawSampleBuffer = rawSampleBuffer
        self.rawPreviewPhotoSampleBuffer = previewPhotoSampleBuffer
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings,
                 error: Error?){
        guard error == nil else {
            print("Error in capture process: \(String(describing: error))")
            return
        }
    
        if let rawSampleBuffer = self.rawSampleBuffer, let photoSampleBuffer = self.photoSampleBuffer {
            saveRAWPlusJPEGPhotoLibrary(rawSampleBuffer,
                                    rawPreviewSampleBuffer: self.rawPreviewPhotoSampleBuffer,
            photoSampleBuffer: photoSampleBuffer,
            previewSampleBuffer: self.previewPhotoSampleBuffer,
            completionHandler: { success, error in
                if success {
                    print("Successfully added.")
                } else {
                    print("Error while adding \(String(describing: error))")
                }
            }
            )
        }
    }
}

