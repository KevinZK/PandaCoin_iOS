//
//  ChatInputBar.swift
//  PandaCoin
//
//  对话输入栏 - 支持文本、语音、拍照输入
//

import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    @Binding var isRecording: Bool
    
    let onSend: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.separator)
            
            HStack(spacing: 12) {
                // 拍照按钮（预留）
                Button(action: {
                    // TODO: 拍照功能（第二阶段实现）
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .disabled(true) // 暂时禁用
                .opacity(0.5)
                
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                // 输入栏使用毛玻璃效果，Light Mode 下更透明
                Color.clear
                    .background(.ultraThinMaterial)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

// MARK: - 对话语音录制按钮
struct ChatVoiceButton: View {
    @Binding var isRecording: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    
    @State private var waveScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 波浪效果（录音时）
            if isRecording {
                Circle()
                    .stroke(Theme.bambooGreen.opacity(0.3), lineWidth: 2)
                    .frame(width: 50, height: 50)
                    .scaleEffect(waveScale)
                    .opacity(2.0 - waveScale)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                            waveScale = 1.8
                        }
                    }
                    .onDisappear {
                        waveScale = 1.0
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
                .scaleEffect(isRecording ? 1.1 : 1.0)
        }
        .onTapGesture {
            if isRecording {
                onStop()
            } else {
                onStart()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
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
            onStopRecording: {}
        )
    }
    .background(Theme.background)
}

