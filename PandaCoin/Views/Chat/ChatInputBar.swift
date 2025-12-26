//
//  ChatInputBar.swift
//  PandaCoin
//
//  对话输入栏 - 支持文本、语音、拍照输入
//

import SwiftUI
import AVFoundation
import Photos

struct ChatInputBar: View {
    @Binding var text: String
    @Binding var isRecording: Bool
    
    let onSend: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onCameraPressed: () -> Void
    let onPhotoLibraryPressed: () -> Void  // 新增：相册回调
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.separator)
            
            HStack(spacing: 8) {
                // 拍照按钮
                Button(action: checkCameraPermission) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.bambooGreen)
                        .frame(width: 36, height: 36)
                        .background(Theme.bambooGreen.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // 相册按钮
                Button(action: checkPhotoLibraryPermission) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.income)
                        .frame(width: 36, height: 36)
                        .background(Theme.income.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // 文本输入框
                HStack(spacing: 8) {
                    TextField("输入记账内容...", text: $text)
                        .font(AppFont.body(size: 15))
                        .foregroundColor(Theme.text)
                        .focused($isTextFieldFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            if !text.isEmpty {
                                onSend()
                            }
                        }
                    
                    // 发送按钮（有文本时显示）
                    if !text.isEmpty {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.bambooGreen)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.cardBackground)
                .cornerRadius(20)
                .shadow(color: Theme.cfoShadow, radius: 3, x: 0, y: 1)
                
                // 语音按钮
                ChatVoiceButton(
                    isRecording: $isRecording,
                    onStart: onStartRecording,
                    onStop: onStopRecording
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.clear
                    .background(.ultraThinMaterial)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
        .alert("需要权限", isPresented: $showingPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(permissionAlertMessage)
        }
    }
    
    // MARK: - 检查相机权限
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onCameraPressed()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        onCameraPressed()
                    }
                }
            }
        case .denied, .restricted:
            permissionAlertMessage = "请在设置中允许访问相机，以便拍摄票据进行识别。"
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
    
    // MARK: - 检查相册权限
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            onPhotoLibraryPressed()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        onPhotoLibraryPressed()
                    }
                }
            }
        case .denied, .restricted:
            permissionAlertMessage = "请在设置中允许访问相册，以便选择票据图片进行识别。"
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
}

// MARK: - 对话语音录制按钮
struct ChatVoiceButton: View {
    @Binding var isRecording: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    
    @State private var waveScales: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 多层波浪效果（录音时）
            if isRecording {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            Theme.bambooGreen.opacity(0.4 - Double(index) * 0.1),
                            lineWidth: 2
                        )
                        .frame(width: 44, height: 44)
                        .scaleEffect(waveScales[index])
                        .opacity(Double(2.0 - waveScales[index]))
                }
            }
            
            // 主按钮
            Circle()
                .fill(isRecording ? Theme.expense : Theme.bambooGreen)
                .frame(width: 44, height: 44)
                .shadow(color: (isRecording ? Theme.expense : Theme.bambooGreen).opacity(0.3), radius: 5, x: 0, y: 2)
                .overlay(
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                )
                .scaleEffect(isRecording ? 1.05 : 1.0)
        }
        .onTapGesture {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
        .onChange(of: isRecording) { newValue in
            if newValue {
                startWaveAnimation()
            } else {
                stopWaveAnimation()
            }
        }
    }
    
    private func startRecording() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        onStart()
    }
    
    private func stopRecording() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        onStop()
    }
    
    private func startWaveAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        waveScales = [1.0, 1.0, 1.0]
        
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                guard self.isAnimating else { return }
                withAnimation(
                    .easeOut(duration: 1.0)
                    .repeatForever(autoreverses: false)
                ) {
                    self.waveScales[i] = 1.8
                }
            }
        }
    }
    
    private func stopWaveAnimation() {
        isAnimating = false
        withAnimation(.easeOut(duration: 0.2)) {
            waveScales = [1.0, 1.0, 1.0]
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputBar(
            text: .constant(""),
            isRecording: .constant(false),
            onSend: {},
            onStartRecording: {},
            onStopRecording: {},
            onCameraPressed: {},
            onPhotoLibraryPressed: {}
        )
    }
    .background(Theme.background)
}
