//
//  ContentView.swift
//  QRScanApp
//
//  Created by daviddong on 15/7/2025.
//

import SwiftUI
import AVFoundation  // 用于摄像头和 QR 检测

// 登录视图
struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoggedIn = false
    @State private var userEmail = ""  // 存储登录后 email
    
    var body: some View {
        if isLoggedIn {
            ContentView(userEmail: userEmail)  // 登录成功，跳转主视图
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
            
            // 弹出确认弹窗（在主线程）
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(title: "确认登录", message: "确认使用此 QR 码登录吗？", preferredStyle: .alert)
                
                // “确认” 按钮：发送请求
                alert.addAction(UIAlertAction(title: "确认", style: .default, handler: { _ in
                    self.confirmLogin(scannedToken: stringValue) { success in
                        DispatchQueue.main.async {  // [修复] 所有 UI/回调在主线程
                            if success {
                                self.onScan(stringValue)  // 成功后调用回调
                                self.dismiss(animated: true)  // 关闭视图
                            } else {
                                // 失败警报
                                let errorAlert = UIAlertController(title: "错误", message: "确认失败，请重试", preferredStyle: .alert)
                                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                                self.present(errorAlert, animated: true)
                            }
                        }
                    }
                }))
                
                // “取消” 按钮：不发送，关闭弹窗
                alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
                    self.dismiss(animated: true)  // 关闭视图
                }))
                
                // 显示弹窗
                self.present(alert, animated: true)
            }
        }
    }
    
    // 发送确认请求（私有函数）
    private func confirmLogin(scannedToken: String, completion: @escaping (Bool) -> Void) {
        guard let jwt = UserDefaults.standard.string(forKey: "jwtToken"),
              let url = URL(string: "http://192.168.5.14:3001/confirm-login") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let body: [String: String] = ["scannedToken": scannedToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("确认失败: \(error)")
                completion(false)
                return
            }
            // 检查响应状态（假设 200 表示成功）
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
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

