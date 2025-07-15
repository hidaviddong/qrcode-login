//
//  ContentView.swift
//  QRScanApp
//
//  Created by daviddong on 15/7/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingCamera = false
    var body: some View {
        VStack {
            Button(action:{
                self.isShowingCamera = true
            }){
               Text("Scan Login")
            }.buttonStyle(.bordered).controlSize(.large)
        }
        .padding()
        .sheet(isPresented: $isShowingCamera) {
               // 在弹出的页面里，显示我们的相机视图
               CameraView()
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    
    // 创建 ViewController
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera // 设置源为相机
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // 空
    }
}



#Preview {
    ContentView()
}
