//
//  ChatInputBar.swift
//  PandaCoin
//
//  对话输入栏 - 支持文本输入
//

import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputBar(
            text: .constant(""),
            onSend: {}
        )
    }
    .background(Theme.background)
}
