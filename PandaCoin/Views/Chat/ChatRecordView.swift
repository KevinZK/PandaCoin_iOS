//
//  ChatRecordView.swift
//  PandaCoin
//
//  对话式记账视图 - 与熊猫财务官对话记账
//

import SwiftUI
import Combine

// MARK: - 对话消息类型
enum ChatMessageType {
    case userText(String)                      // 用户文字输入
    case userVoice(String)                     // 用户语音输入
    case assistantText(String)                 // 熊猫文字回复
    case assistantParsing                      // 正在解析中
    case assistantResult([ParsedFinancialEvent]) // AI解析结果卡片
    case assistantError(String)                // 错误提示
    case savedConfirmation(Int)                // 保存成功确认（保存了几条）
}

// MARK: - 对话消息模型
struct ChatMessage: Identifiable {
    let id = UUID()
    let type: ChatMessageType
    let timestamp = Date()
    
    // 是否是用户消息
    var isUser: Bool {
        switch type {
        case .userText, .userVoice:
            return true
        default:
            return false
        }
    }
}

// MARK: - 对话式记账视图
struct ChatRecordView: View {
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var recordService = RecordService()
    @ObservedObject private var accountService = AssetService.shared
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isRecording = false
    @State private var editableEvents: [ParsedFinancialEvent] = []  // 可编辑的事件列表
    @State private var showingEventCards = false  // 是否显示事件确认卡片
    @State private var cancellables = Set<AnyCancellable>()
    
    // 用于自动滚动到底部
    @Namespace private var bottomID
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 欢迎消息
                        if messages.isEmpty && !showingEventCards {
                            welcomeMessage
                        }
                        
                        // 显示对话消息
                        ForEach(messages) { message in
                            SimpleChatBubble(message: message)
                        }
                        
                        // 显示可编辑的事件确认卡片（复用 UnifiedConfirmationView 的卡片）
                        if showingEventCards && !editableEvents.isEmpty {
                            eventConfirmationSection
                        }
                        
                        // 底部锚点
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: showingEventCards) { _ in
                    scrollToBottom(proxy)
                }
            }
            
            // 输入栏（确认卡片显示时禁用输入）
            ChatInputBar(
                text: $inputText,
                isRecording: $isRecording,
                onSend: sendTextMessage,
                onStartRecording: startRecording,
                onStopRecording: stopRecording
            )
            .disabled(showingEventCards)
            .opacity(showingEventCards ? 0.5 : 1.0)
        }
        .background(Color.clear)  // 透明背景，与首页渐变融合
    }
    
    // MARK: - 事件确认区域（复用 EventConfirmCard）
    private var eventConfirmationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 熊猫提示
            HStack(alignment: .top, spacing: 8) {
                Text("🐼")
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("好的，帮你记录\(editableEvents.count > 1 ? "\(editableEvents.count)笔" : "")：")
                        .font(AppFont.body(size: 15))
                        .foregroundColor(Theme.text)
                    
                    Text("请确认信息是否正确")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // 使用 EventConfirmCard（完整功能，包含账户选择）
            ForEach(editableEvents.indices, id: \.self) { index in
                EventConfirmCard(event: $editableEvents[index])
            }
            
            // 确认按钮
            HStack(spacing: 12) {
                Button(action: cancelEvents) {
                    Text("取消")
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.separator)
                        .cornerRadius(22)
                }
                
                Button(action: { confirmEvents(editableEvents) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("确认保存")
                            .font(AppFont.body(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.bambooGreen)
                    .cornerRadius(22)
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Theme.cfoShadow, radius: 10, x: 0, y: 5)
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
    
    // MARK: - 欢迎消息
    private var welcomeMessage: some View {
        VStack(spacing: 16) {
            Text("🐼")
                .font(.system(size: 60))
            
            VStack(spacing: 8) {
                Text("你好！我是熊猫财务官")
                    .font(AppFont.body(size: 18, weight: .semibold))
                    .foregroundColor(Theme.text)
                
                Text("告诉我你今天的收支吧~")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            
            // 快捷提示
            VStack(spacing: 8) {
                Text("你可以这样说：")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 8) {
                    QuickTipChip(text: "午餐花了35元")
                    QuickTipChip(text: "发了8000工资")
                }
                
                HStack(spacing: 8) {
                    QuickTipChip(text: "买衣服消费200")
                    QuickTipChip(text: "打车15块")
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - 发送文本消息
    private func sendTextMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // 添加用户消息
        messages.append(ChatMessage(type: .userText(text)))
        inputText = ""
        
        // 显示解析中状态
        let parsingMessageId = UUID()
        messages.append(ChatMessage(type: .assistantParsing))
        
        // 调用AI解析
        parseAndRespond(text: text, parsingMessageId: parsingMessageId)
    }
    
    // MARK: - 开始录音
    private func startRecording() {
        do {
            try speechService.startRecording()
            isRecording = true
        } catch {
            messages.append(ChatMessage(type: .assistantError("语音识别启动失败，请检查麦克风权限")))
        }
    }
    
    // MARK: - 停止录音
    private func stopRecording() {
        let recognizedText = speechService.recognizedText
        speechService.stopRecording()
        isRecording = false
        
        guard !recognizedText.isEmpty else {
            messages.append(ChatMessage(type: .assistantText("没有听清楚，请再说一次吧~")))
            return
        }
        
        // 添加用户语音消息
        messages.append(ChatMessage(type: .userVoice(recognizedText)))
        
        // 显示解析中
        messages.append(ChatMessage(type: .assistantParsing))
        
        // 调用AI解析
        parseAndRespond(text: recognizedText, parsingMessageId: nil)
    }
    
    // MARK: - AI解析并响应
    private func parseAndRespond(text: String, parsingMessageId: UUID?) {
        recordService.parseVoiceInputUnified(text: text)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                // 移除"解析中"消息
                self.messages.removeAll { msg in
                    if case .assistantParsing = msg.type { return true }
                    return false
                }
                
                if case .failure(let error) = completion {
                    self.messages.append(ChatMessage(type: .assistantError("解析失败：\(error.localizedDescription)")))
                }
            } receiveValue: { events in
                // 移除"解析中"消息
                self.messages.removeAll { msg in
                    if case .assistantParsing = msg.type { return true }
                    return false
                }
                
                if events.isEmpty {
                    self.messages.append(ChatMessage(type: .assistantText("抱歉，没有识别出记账信息，请换个方式描述试试~")))
                } else {
                    // 设置可编辑事件并显示确认卡片
                    self.editableEvents = events
                    self.showingEventCards = true
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 确认保存事件
    private func confirmEvents(_ events: [ParsedFinancialEvent]) {
        // 隐藏事件卡片
        showingEventCards = false
        
        // 构建账户映射
        var accountMap: [String: String] = [:]
        for account in accountService.accounts {
            accountMap[account.name] = account.id
        }
        
        // 保存事件
        recordService.saveFinancialEvents(events, accountMap: accountMap, assetService: accountService)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    self.messages.append(ChatMessage(type: .assistantError("保存失败：\(error.localizedDescription)")))
                }
            } receiveValue: { count in
                self.messages.append(ChatMessage(type: .savedConfirmation(count)))
                self.editableEvents = []
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 取消事件
    private func cancelEvents() {
        showingEventCards = false
        editableEvents = []
        messages.append(ChatMessage(type: .assistantText("好的，已取消。有其他记账需要吗？")))
    }
}

// MARK: - 快捷提示标签
struct QuickTipChip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Theme.bambooGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.bambooGreen.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.bambooGreen.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(16)
    }
}

// MARK: - 简化对话气泡视图（不包含事件卡片）
struct SimpleChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !message.isUser {
                // 熊猫头像
                Text("🐼")
                    .font(.system(size: 28))
                    .frame(width: 36, height: 36)
            }
            
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            bubbleContent
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
            
            if message.isUser {
                // 用户头像
                Circle()
                    .fill(Theme.bambooGreen.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(Theme.bambooGreen)
                            .font(.system(size: 16))
                    )
            }
        }
    }
    
    @ViewBuilder
    private var bubbleContent: some View {
        switch message.type {
        case .userText(let text), .userVoice(let text):
            userBubble(text: text, isVoice: message.type.isVoice)
            
        case .assistantText(let text):
            assistantTextBubble(text: text)
            
        case .assistantParsing:
            parsingBubble
            
        case .assistantResult:
            // 事件卡片现在在 ChatRecordView 中单独处理
            EmptyView()
            
        case .assistantError(let error):
            errorBubble(error: error)
            
        case .savedConfirmation(let count):
            confirmationBubble(count: count)
        }
    }
    
    // 用户消息气泡
    private func userBubble(text: String, isVoice: Bool) -> some View {
        HStack(spacing: 6) {
            if isVoice {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            Text(text)
                .font(AppFont.body(size: 15))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.bambooGreen)
        .cornerRadius(18)
        .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
    }
    
    // 熊猫文字消息气泡
    private func assistantTextBubble(text: String) -> some View {
        Text(text)
            .font(AppFont.body(size: 15))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cardBackground)
            .cornerRadius(18)
            .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
            .shadow(color: Theme.cfoShadow, radius: 5, x: 0, y: 2)
    }
    
    // 解析中气泡
    private var parsingBubble: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("让我看看...")
                .font(AppFont.body(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .shadow(color: Theme.cfoShadow, radius: 5, x: 0, y: 2)
    }
    
    // 错误气泡
    private func errorBubble(error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.expense)
                .font(.system(size: 14))
            Text(error)
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.expense)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.expense.opacity(0.1))
        .cornerRadius(18)
    }
    
    // 保存成功确认气泡
    private func confirmationBubble(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.income)
                .font(.system(size: 16))
            Text("已记录\(count)笔！继续保持好习惯 💪")
                .font(AppFont.body(size: 15))
                .foregroundColor(Theme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.income.opacity(0.1))
        .cornerRadius(18)
    }
}

// MARK: - 扩展：判断是否是语音消息
extension ChatMessageType {
    var isVoice: Bool {
        if case .userVoice = self { return true }
        return false
    }
}

// MARK: - 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ChatRecordView()
}

