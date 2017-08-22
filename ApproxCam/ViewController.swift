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
import AWSCore
import AWSCognito
import AWSS3

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    var outputObject : AVCapturePhotoOutput!
    var session: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var rawPhotoOutputBuffer: CMSampleBuffer!
    var capturedImage: UIImageView!
    
    var fileName = ""
    var URLToUpload = URL(string: "")
    var FilenameToUpload = ""
    var BucketToUploadS3 = "approxcam-rawphoto"
    var BucketToUploadMinio = "rawphoto"
    
    @IBOutlet weak var preViewImage: UIImageView!
    
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
        //AVCaptureSessionPresetHigh, AVCaptureSessionPresetMedium, AVCaptureSessionPresetLow
        //AVCaptureSessionPreset640x480, AVCaptureSessionPreset1280x720
        
        session.startRunning()
    }
    
    @IBAction func capturePicture() {
        //print(outputObject.availablePhotoPixelFormatTypes)  //ip7:[875704422, 875704438, 1111970369]
        //print(outputObject.availableRawPhotoPixelFormatTypes)
        
        let rawFormatType = outputObject.availableRawPhotoPixelFormatTypes.first as! OSType
        let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormatType,
                                                   processedFormat: [AVVideoCodecKey : AVVideoCodecJPEG])
        outputObject.capturePhoto(with: photoSettings, delegate: self)
        
    }
    
    func getFilenameForLocal() -> String{
        let now = Date()
        let timeInterval:TimeInterval = now.timeIntervalSince1970
        return "/" + String(timeInterval) + ".dng"
    }
    
    func getFilenameForRemoteS3() -> String{
        let now = Date()
        let timeInterval:TimeInterval = now.timeIntervalSince1970
        return "default/" + String(timeInterval) + ".dng"
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
        fileName = getFilenameForLocal()
        FilenameToUpload = getFilenameForRemoteS3()
        let dngFileURL = URL(string: "file://\(documentsPath + fileName)")
        URLToUpload = dngFileURL!
        do {
            try dngData.write(to: dngFileURL!)
        } catch let error as NSError {
            print("Unable to write DNG file.")
            completionHandler?(false, error)
            return
        }
        
        PHPhotoLibrary.shared().performChanges( {
            let creationRequest = PHAssetCreationRequest.forAsset()
            let creationOptions = PHAssetResourceCreationOptions()
            creationRequest.addResource(with: .photo, data: jpegData, options: nil)
            creationRequest.addResource(with: .alternatePhoto, fileURL: dngFileURL!, options: creationOptions)
        },
                                                completionHandler: completionHandler)
        
        //uploadFile(bucketName: BucketToUpload, remoteName: FilenameToUpload, fileURL: URLToUpload!)
    }
    
    @IBOutlet weak var candidateLabels: UILabel!
    
    @IBAction func getCandidateLabels(_ sender: UIButton) {
        candidateLabels.text = String("Dog")!
    }
    
    
    @IBAction func UploadPicture() {
        //uploadFileToS3(bucketName: BucketToUploadS3, remoteName: FilenameToUpload, fileURL: URLToUpload!)
        uploadFileToMinio(bucketName: BucketToUploadMinio, remoteName: fileName, fileURL: URLToUpload!)
    }
    
    func uploadFileToMinio(bucketName: String,
                        remoteName: String,
                        fileURL: URL){
        
        let accessKey = "shining"
        let secretKey = "abdefghi"
        
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let configuration = AWSServiceConfiguration(region: .USEast1, endpoint: AWSEndpoint(region: .USEast1, service: .S3, url: URL(string:"http://169.254.143.227:9000")),credentialsProvider: credentialsProvider)
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        let uploadRequest = AWSS3TransferManagerUploadRequest()!
        uploadRequest.body = fileURL
        uploadRequest.key = remoteName
        uploadRequest.bucket = bucketName
        
        let transferManager = AWSS3TransferManager.default()
        transferManager.upload(uploadRequest)
        transferManager.upload(uploadRequest).continueWith { (task: AWSTask<AnyObject>) -> Any? in
            
            if let error = task.error {
                print("Upload failed with error: (\(error.localizedDescription))")
            }
            
            if task.result != nil {
                let url = AWSS3.default().configuration.endpoint.url
                let publicURL = url?.appendingPathComponent(uploadRequest.bucket!).appendingPathComponent(uploadRequest.key!)
                print("Uploaded to:\(String(describing: publicURL!))")
            }
            
            return nil
        }
    }
    
    func uploadFileToS3(bucketName: String,
                    remoteName: String,
                    fileURL: URL){
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: .APNortheast1, identityPoolId: "ap-northeast-1:b631a38e-d447-456a-89d0-bba44586c1f0")
        let configuration = AWSServiceConfiguration(region: .APNortheast1, credentialsProvider: credentialsProvider)
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        let transferManager = AWSS3TransferManager.default()
        
        let uploadRequest = AWSS3TransferManagerUploadRequest()!
        uploadRequest.bucket = bucketName
        uploadRequest.body = fileURL
        uploadRequest.key = remoteName
        print(remoteName)
        
        transferManager.upload(uploadRequest)
        transferManager.upload(uploadRequest).continueWith { (task: AWSTask<AnyObject>) -> Any? in
            
            if let error = task.error {
                print("Upload failed with error: (\(error.localizedDescription))")
            }
            
            if task.result != nil {
                let url = AWSS3.default().configuration.endpoint.url
                let publicURL = url?.appendingPathComponent(uploadRequest.bucket!).appendingPathComponent(uploadRequest.key!)
                print("Uploaded to:\(String(describing: publicURL!))")
            }
            
            return nil
        }
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

