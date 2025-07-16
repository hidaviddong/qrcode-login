//
//  ContentView.swift
//  QRScanApp
//
//  Created by daviddong on 15/7/2025.
//

import SwiftUI
import AVFoundation

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoggedIn = false
    @State private var userEmail = ""
    
    var body: some View {
        if isLoggedIn {
            ContentView(userEmail: userEmail)
        } else {
            VStack {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Login") {
                    login()
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red)
                }
            }.padding()
        }
    }
    
    private func login() {
        guard let url = URL(string: "http://192.168.5.14:3001/login") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { errorMessage = error.localizedDescription }
                return
            }
            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let jwt = json["token"] as? String else {
                DispatchQueue.main.async { errorMessage = "登录失败" }
                return
            }
            print(data)
            // 存储 JWT
            UserDefaults.standard.set(jwt, forKey: "jwtToken")
            DispatchQueue.main.async {
                userEmail = email  // 显示 email（从输入获取，或从响应解析）
                isLoggedIn = true
            }
        }.resume()
    }
}

// 主视图（登录后）
struct ContentView: View {
    let userEmail: String  // 从登录视图传入
    @State private var isShowingCamera = false
    @State private var scannedCode: String? = nil
    
    var body: some View {
        VStack {
            Text("欢迎, \(userEmail)")  // 显示用户 email
                .padding()
            
            if let code = scannedCode {
                Text("扫描结果: \(code)")
                    .padding()
                    .foregroundColor(.green)
            }
            
            Button(action: {
                self.isShowingCamera = true
            }) {
                Text("Scan QR Code")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .sheet(isPresented: $isShowingCamera) {
            CameraView { code in
                scannedCode = code
                isShowingCamera = false
                confirmLogin(scannedToken: code)  // 扫描后调用确认
            }
        }
    }
    
    // 发送确认请求（带 JWT）
    private func confirmLogin(scannedToken: String) {
        guard let jwt = UserDefaults.standard.string(forKey: "jwtToken"),
              let url = URL(string: "http://localhost:3001/confirm-login") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")  // 带 JWT
        let body: [String: String] = ["scannedToken": scannedToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("确认失败: \(error)")
                return
            }
            // 处理成功响应（可选更新 UI，例如打印或警报）
            print("确认成功")
        }.resume()
    }
}

// 自定义摄像头视图控制器（基于 AVFoundation）
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
        
        // 获取后置摄像头
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("无可用摄像头")
            return
        }
        
        // 设置输入
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("输入设置错误: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("无法添加输入")
            return
        }
        
        // 设置元数据输出（QR 检测）
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]  // 只检测 QR 码
        } else {
            print("无法添加输出")
            return
        }
        
        // 添加预览层
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // 开始会话（后台线程）
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    // 代理方法：检测到 QR 码
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()  // 停止扫描
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // 调用回调，返回解码数据
            onScan(stringValue)
        }
        
        // 关闭视图
        dismiss(animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
}

// SwiftUI 包装器
struct CameraView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerController {
        return QRScannerController(onScan: onScan)
    }
    
    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

#Preview {
    LoginView()  // 预览从登录开始
}

