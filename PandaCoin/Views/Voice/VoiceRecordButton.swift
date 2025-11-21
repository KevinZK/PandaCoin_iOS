//
//  VoiceRecordButton.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Speech

// MARK: - 语音记账按钮
struct VoiceRecordButton: View {
    @ObservedObject var speechService: SpeechRecognitionService
    @State private var waveScale: CGFloat = 1.0
    @State private var showingVoiceSheet = false
    
    let onRecognizedText: (String) -> Void
    
    var body: some View {
        Button(action: {
            showingVoiceSheet = true
        }) {
            ZStack {
                // 录音时的波纹动画
                if speechService.isRecording {
                    Circle()
                        .stroke(Theme.bambooGreen.opacity(0.5), lineWidth: 4)
                        .scaleEffect(waveScale)
                        .opacity(2 - waveScale)
                        .animation(
                            Animation.easeOut(duration: 1)
                                .repeatForever(autoreverses: false),
                            value: waveScale
                        )
                        .onAppear {
                            waveScale = 2.0
                        }
                        .onDisappear {
                            waveScale = 1.0
                        }
                }
                
                // 主按钮
                Circle()
                    .fill(Theme.bambooGreen)
                    .frame(width: 80, height: 80)
                    .shadow(
                        color: Theme.bambooGreen.opacity(0.4),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
                
                // 麦克风图标
                Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showingVoiceSheet) {
            VoiceRecordSheet(
                speechService: speechService,
                onComplete: { text in
                    onRecognizedText(text)
                    showingVoiceSheet = false
                }
            )
        }
    }
}

// MARK: - 语音录音弹窗
struct VoiceRecordSheet: View {
    @ObservedObject var speechService: SpeechRecognitionService
    @Environment(\.dismiss) var dismiss
    
    let onComplete: (String) -> Void
    
    @State private var waveScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.large) {
                Spacer()
                
                // 熊猫动画区域
                ZStack {
                    if speechService.isRecording {
                        // 外圈波纹
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(Theme.bambooGreen.opacity(0.3), lineWidth: 2)
                                .scaleEffect(waveScale)
                                .opacity(2 - waveScale)
                                .animation(
                                    Animation.easeOut(duration: 1.5)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(index) * 0.3),
                                    value: waveScale
                                )
                        }
                    }
                    
                    // 麦克风图标
                    ZStack {
                        Circle()
                            .fill(speechService.isRecording ? Theme.bambooGreen : Theme.textSecondary)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 200)
                .onAppear {
                    if speechService.isRecording {
                        waveScale = 2.0
                    }
                }
                
                // 提示文字
                Text(speechService.isRecording ? "熊猫正在听..." : "按住开始说话")
                    .font(AppFont.body(size: 18, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                
                // 识别文本显示
                ScrollView {
                    Text(speechService.recognizedText.isEmpty ? "试试说: 早餐花了15块" : speechService.recognizedText)
                        .font(AppFont.body(size: 20))
                        .foregroundColor(speechService.recognizedText.isEmpty ? Theme.textSecondary : Theme.text)
                        .padding(Spacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.background)
                        .cornerRadius(CornerRadius.medium)
                        .padding(.horizontal)
                }
                .frame(height: 150)
                
                Spacer()
                
                // 按钮区域
                HStack(spacing: Spacing.large) {
                    // 取消按钮
                    Button(action: {
                        speechService.stopRecording()
                        dismiss()
                    }) {
                        Text("取消")
                            .font(AppFont.body(size: 18, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(CornerRadius.medium)
                    }
                    
                    // 录音/完成按钮
                    Button(action: {
                        if speechService.isRecording {
                            speechService.stopRecording()
                            if !speechService.recognizedText.isEmpty {
                                onComplete(speechService.recognizedText)
                            }
                        } else {
                            do {
                                try speechService.startRecording()
                                waveScale = 2.0
                            } catch {
                                print("录音失败: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        Text(speechService.isRecording ? "完成" : "开始录音")
                            .font(AppFont.body(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(speechService.isRecording ? Theme.bambooGreen : Theme.textSecondary)
                            .cornerRadius(CornerRadius.medium)
                    }
                    .disabled(speechService.authorizationStatus != .authorized)
                }
                .padding(.horizontal)
                .padding(.bottom, Spacing.large)
            }
            .navigationTitle("语音记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        speechService.stopRecording()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if speechService.authorizationStatus == .notDetermined {
                speechService.requestAuthorization()
            }
        }
        .onDisappear {
            speechService.stopRecording()
        }
    }
}
