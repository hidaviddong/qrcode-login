//
//  ContentView.swift
//  QRScanApp
//
//  Created by daviddong on 15/7/2025.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var isShowingCamera = false
    @State private var scannedCode: String? = nil
    
    var body: some View {
        VStack {
            if let code = scannedCode {
                Text("Scan Result: \(code)")
                    .padding()
                    .foregroundColor(.green)
            }
            
            Button(action: {
                self.isShowingCamera = true
            }) {
                Text("Scan Login")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .sheet(isPresented: $isShowingCamera) {
            CameraView { code in
                scannedCode = code
                isShowingCamera = false
            }
        }
    }
}

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onScan: (String) -> Void
    
    init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("No available cameras!")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Input settings error: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("Can't add video input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]  //
        } else {
            print("Can't add metadata output")
            return
        }
        

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
        
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            onScan(stringValue)
        }
        
        dismiss(animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerController {
        return QRScannerController(onScan: onScan)
    }
    
    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

#Preview {
    ContentView()
}

