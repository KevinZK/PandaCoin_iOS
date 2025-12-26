//
//  ReceiptPreviewView.swift
//  PandaCoin
//
//  票据识别预览视图 - 显示 OCR 结果并确认
//

import SwiftUI
import Combine

struct ReceiptPreviewView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onConfirm: (OCRResult) -> Void
    let onCancel: () -> Void
    
    @StateObject private var ocrService = LocalOCRService.shared
    @State private var ocrResult: OCRResult?
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 图片预览区域
                    imagePreviewSection
                    
                    // 识别结果区域
                    resultSection
                }
            }
            .navigationTitle("识别票据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
            .onAppear {
                startOCR()
            }
        }
    }
    
    // MARK: - 图片预览区域
    private var imagePreviewSection: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height)
                .background(Color.black.opacity(0.05))
        }
        .frame(height: 280)
    }
    
    // MARK: - 结果区域
    private var resultSection: some View {
        VStack(spacing: 0) {
            if ocrService.isProcessing {
                // 识别中
                processingView
            } else if let error = errorMessage {
                // 识别失败
                errorView(message: error)
            } else if let result = ocrResult {
                if result.isValidReceipt {
                    // 识别成功
                    successView(result: result)
                } else {
                    // 不是有效票据
                    invalidReceiptView
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Theme.cardBackground)
    }
    
    // MARK: - 处理中视图
    private var processingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 熊猫图标
            Text("🐼")
                .font(.system(size: 48))
            
            Text("正在识别文字...")
                .font(AppFont.body(size: 16, weight: .medium))
                .foregroundColor(Theme.text)
            
            // 进度条
            ProgressView(value: ocrService.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: Theme.bambooGreen))
                .frame(width: 200)
            
            Text("\(Int(ocrService.progress * 100))%")
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - 错误视图
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.expense)
            
            Text("识别失败")
                .font(AppFont.body(size: 18, weight: .semibold))
                .foregroundColor(Theme.text)
            
            Text(message)
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 16) {
                Button(action: onRetake) {
                    Text("重新拍摄")
                        .font(AppFont.body(size: 16, weight: .medium))
                        .foregroundColor(Theme.bambooGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.bambooGreen.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { startOCR() }) {
                    Text("重试")
                        .font(AppFont.body(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.bambooGreen)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - 不是有效票据视图
    private var invalidReceiptView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("🐼")
                .font(.system(size: 48))
            
            Text("这张图片不像是票据")
                .font(AppFont.body(size: 18, weight: .semibold))
                .foregroundColor(Theme.text)
            
            Text("请拍摄清晰的购物小票、支付截图\n或外卖订单等票据")
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            // 支持的票据类型提示
            VStack(alignment: .leading, spacing: 8) {
                Text("支持识别：")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 12) {
                    receiptTypeChip(icon: "cart.fill", text: "购物小票")
                    receiptTypeChip(icon: "takeoutbag.and.cup.and.straw.fill", text: "外卖订单")
                    receiptTypeChip(icon: "creditcard.fill", text: "支付截图")
                }
            }
            .padding(.top, 8)
            
            Spacer()
            
            // 操作按钮
            Button(action: onRetake) {
                Text("重新选择图片")
                    .font(AppFont.body(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.bambooGreen)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func receiptTypeChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(AppFont.body(size: 12))
        }
        .foregroundColor(Theme.bambooGreen)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.bambooGreen.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - 识别成功视图
    private func successView(result: OCRResult) -> some View {
        VStack(spacing: 0) {
            // 识别结果摘要
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 票据类型标签
                    HStack {
                        Image(systemName: result.receiptType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(Theme.bambooGreen)
                        
                        Text("检测到：\(result.receiptType.rawValue)")
                            .font(AppFont.body(size: 14, weight: .medium))
                            .foregroundColor(Theme.text)
                        
                        Spacer()
                        
                        // 置信度
                        Text("置信度 \(Int(result.confidence * 100))%")
                            .font(AppFont.body(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.bambooGreen.opacity(0.1))
                    .cornerRadius(10)
                    
                    // 提取的信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("识别到的信息")
                            .font(AppFont.body(size: 14, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        
                        if let amount = result.extractedInfo.amount {
                            infoRow(label: "金额", value: "¥\(amount)")
                        }
                        
                        if let merchant = result.extractedInfo.merchant {
                            infoRow(label: "商家", value: merchant)
                        }
                        
                        if let date = result.extractedInfo.date {
                            infoRow(label: "日期", value: formatDate(date))
                        }
                        
                        if let paymentMethod = result.extractedInfo.paymentMethod {
                            infoRow(label: "支付方式", value: paymentMethod)
                        }
                    }
                    
                    // 原始文字（可折叠）
                    DisclosureGroup {
                        Text(result.rawText)
                            .font(AppFont.body(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 8)
                    } label: {
                        Text("查看识别原文")
                            .font(AppFont.body(size: 13))
                            .foregroundColor(Theme.bambooGreen)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            
            Divider()
                .background(Theme.separator)
            
            // 操作按钮
            HStack(spacing: 16) {
                Button(action: onRetake) {
                    Text("重新拍摄")
                        .font(AppFont.body(size: 16, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.separator.opacity(0.5))
                        .cornerRadius(12)
                }
                
                Button(action: {
                    onConfirm(result)
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("AI 解析")
                    }
                    .font(AppFont.body(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.bambooGreen)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(AppFont.body(size: 15, weight: .medium))
                .foregroundColor(Theme.text)
            
            Spacer()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - 开始 OCR
    private func startOCR() {
        errorMessage = nil
        ocrResult = nil
        
        ocrService.recognizeText(from: image)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { result in
                    self.ocrResult = result
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    ReceiptPreviewView(
        image: UIImage(systemName: "doc.text.fill")!,
        onRetake: {},
        onConfirm: { _ in },
        onCancel: {}
    )
}

