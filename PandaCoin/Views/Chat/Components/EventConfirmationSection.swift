//
//  EventConfirmationSection.swift
//  PandaCoin
//
//  事件确认区域组件
//

import SwiftUI

// MARK: - 事件确认区域
struct EventConfirmationSection: View {
    @Binding var editableEvents: [ParsedFinancialEvent]
    let onConfirm: ([ParsedFinancialEvent]) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 熊猫提示
            HStack(alignment: .top, spacing: 8) {
                Text("🐼")
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(eventSectionTitle)
                        .font(AppFont.body(size: 15))
                        .foregroundColor(Theme.text)
                    
                    if hasSaveableEvents {
                        Text("请确认信息是否正确")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            // 使用 EventConfirmCard（完整功能，包含账户选择）
            ForEach(editableEvents) { event in
                if let index = editableEvents.firstIndex(where: { $0.id == event.id }) {
                    EventConfirmCard(event: Binding(
                        get: {
                            guard index < editableEvents.count else { return event }
                            return editableEvents[index]
                        },
                        set: { newValue in
                            guard index < editableEvents.count else { return }
                            editableEvents[index] = newValue
                        }
                    ))
                }
            }
            
            // 按钮区域
            if hasSaveableEvents {
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(AppFont.body(size: 14, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.separator)
                            .cornerRadius(22)
                    }
                    
                    Button(action: { onConfirm(editableEvents) }) {
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
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Theme.cfoShadow, radius: 10, x: 0, y: 5)
    }
    
    // MARK: - 计算属性
    
    /// 是否有可保存的事件
    private var hasSaveableEvents: Bool {
        editableEvents.contains { event in
            switch event.eventType {
            case .transaction, .assetUpdate, .creditCardUpdate, .holdingUpdate, .budget, .autoPayment:
                return true
            case .queryResponse, .nullStatement, .needMoreInfo:
                return false
            }
        }
    }
    
    /// 事件区域标题
    private var eventSectionTitle: String {
        if hasSaveableEvents {
            return "好的，帮你记录\(editableEvents.count > 1 ? "\(editableEvents.count)笔" : "")："
        } else if editableEvents.first?.eventType == .queryResponse {
            return "为您查询到以下信息："
        } else {
            return "识别结果："
        }
    }
}
