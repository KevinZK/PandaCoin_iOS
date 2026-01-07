//
//  ChatBubbles.swift
//  PandaCoin
//
//  对话气泡组件
//

import SwiftUI

// MARK: - 简化对话气泡视图
struct SimpleChatBubble: View {
    let message: ChatMessage
    var onConfirmAutoIncome: ((FixedIncomeInfo, UUID) -> Void)?
    var onCancelAutoIncome: ((UUID) -> Void)?
    var onPickerSelection: ((SelectedAccountInfo, NeedMoreInfoParsed) -> Void)?
    var onPickerCancel: (() -> Void)?

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

        case .userImage(let image):
            imageBubble(image: image)

        case .assistantText(let text):
            assistantTextBubble(text: text)

        case .assistantParsing:
            parsingBubble

        case .assistantResult:
            // 事件卡片现在在 ChatRecordView 中单独处理
            EmptyView()

        case .assistantError(let error):
            errorBubble(error: error)

        case .savedConfirmation(let summary):
            confirmationBubble(summary: summary)

        case .autoIncomePrompt(let info):
            autoIncomePromptBubble(info: info)
            
        case .selectionFollowUp(let needMoreInfo):
            selectionFollowUpBubble(needMoreInfo: needMoreInfo)
        }
    }
    
    // MARK: - 选择器追问气泡
    @ViewBuilder
    private func selectionFollowUpBubble(needMoreInfo: NeedMoreInfoParsed) -> some View {
        SelectionFollowUpCard(
            needMoreInfo: needMoreInfo,
            onSelection: { selectedAccount in
                onPickerSelection?(selectedAccount, needMoreInfo)
            },
            onCancel: {
                onPickerCancel?()
            }
        )
    }
    
    // MARK: - 用户消息气泡
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
    }
    
    // MARK: - 图片消息气泡
    private func imageBubble(image: UIImage) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .cornerRadius(12)
                .clipped()
            
            HStack(spacing: 4) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 10))
                Text("票据识别")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.bambooGreen.opacity(0.8))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 熊猫文字消息气泡
    private func assistantTextBubble(text: String) -> some View {
        Text(text)
            .font(AppFont.body(size: 15))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cardBackground)
            .cornerRadius(18)
            .shadow(color: Theme.cfoShadow, radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 解析中气泡
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
    
    // MARK: - 错误气泡
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
    
    // MARK: - 保存成功确认气泡
    private func confirmationBubble(summary: SavedEventsSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.income)
                .font(.system(size: 16))
            Text(summary.confirmationMessage)
                .font(AppFont.body(size: 15))
                .foregroundColor(Theme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.income.opacity(0.1))
        .cornerRadius(18)
    }

    // MARK: - 自动入账提示气泡
    private func autoIncomePromptBubble(info: FixedIncomeInfo) -> some View {
        let record = info.record
        let incomeName = record.description.isEmpty ? record.category : record.description

        return VStack(alignment: .leading, spacing: 12) {
            // 提示文字
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                Text("检测到「\(incomeName)」是固定收入")
                    .font(AppFont.body(size: 15))
                    .foregroundColor(Theme.text)
            }

            Text("要设置为每月自动入账吗？这样以后就不用手动记录啦~")
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)

            // 确认/取消按钮
            HStack(spacing: 12) {
                Button(action: {
                    onCancelAutoIncome?(message.id)
                }) {
                    Text("不用了")
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.separator)
                        .cornerRadius(16)
                }

                Button(action: {
                    onConfirmAutoIncome?(info, message.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("设置自动入账")
                            .font(AppFont.body(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.bambooGreen)
                    .cornerRadius(16)
                }
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .shadow(color: Theme.cfoShadow, radius: 5, x: 0, y: 2)
    }
}
