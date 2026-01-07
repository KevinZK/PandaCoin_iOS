//
//  ChatModels.swift
//  PandaCoin
//
//  对话式记账 - 数据模型
//

import SwiftUI

// MARK: - 固定收入信息（用于自动入账提示）
struct FixedIncomeInfo {
    let record: AIRecordParsed
    let accountId: String  // 记录收入时使用的账户 ID
}

// MARK: - 对话消息类型
enum ChatMessageType {
    case userText(String)                      // 用户文字输入
    case userVoice(String)                     // 用户语音输入
    case userImage(UIImage)                    // 用户图片输入
    case assistantText(String)                 // 熊猫文字回复
    case assistantParsing                      // 正在解析中
    case assistantResult([ParsedFinancialEvent]) // AI解析结果卡片
    case assistantError(String)                // 错误提示
    case savedConfirmation(Int)                // 保存成功确认（保存了几条）
    case autoIncomePrompt(FixedIncomeInfo)     // 自动入账提示（带确认/取消按钮）
    case selectionFollowUp(NeedMoreInfoParsed) // 选择器追问卡片
    
    var isVoice: Bool {
        if case .userVoice = self { return true }
        return false
    }
}

// MARK: - 对话消息模型
struct ChatMessage: Identifiable {
    let id = UUID()
    let type: ChatMessageType
    let timestamp = Date()
    
    // 是否是用户消息
    var isUser: Bool {
        switch type {
        case .userText, .userVoice, .userImage:
            return true
        default:
            return false
        }
    }
}
