//
//  VoiceRecordConfirmationView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI

struct VoiceRecordConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    
    let records: [AIRecordParsed]
    let onConfirm: ([AIRecordParsed]) -> Void
    
    @State private var editedRecords: [AIRecordParsed]
    
    init(records: [AIRecordParsed], onConfirm: @escaping ([AIRecordParsed]) -> Void) {
        self.records = records
        self.onConfirm = onConfirm
        _editedRecords = State(initialValue: records)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        // 熊猫提示
                        VStack(spacing: Spacing.small) {
                            Text("🐼")
                                .font(.system(size: 50))
                            
                            Text("熊猫帮你识别了\(records.count)笔记账")
                                .font(AppFont.body(size: 16, weight: .medium))
                                .foregroundColor(Theme.text)
                            
                            Text("请确认是否正确")
                                .font(AppFont.body(size: 14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, Spacing.large)
                        
                        // 记录列表
                        VStack(spacing: Spacing.medium) {
                            ForEach(editedRecords.indices, id: \.self) { index in
                                RecordConfirmCard(record: editedRecords[index])
                            }
                        }
                        .padding(.horizontal, Spacing.medium)
                        
                        // 按钮
                        HStack(spacing: Spacing.medium) {
                            Button(action: {
                                dismiss()
                            }) {
                                Text("取消")
                                    .font(AppFont.body(size: 16, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .cornerRadius(CornerRadius.medium)
                            }
                            
                            Button(action: {
                                onConfirm(editedRecords)
                                dismiss()
                            }) {
                                Text("确认记账")
                                    .font(AppFont.body(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Theme.bambooGreen)
                                    .cornerRadius(CornerRadius.medium)
                            }
                        }
                        .padding(.horizontal, Spacing.medium)
                        .padding(.bottom, Spacing.large)
                    }
                }
            }
            .navigationTitle("确认记账")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 记录确认卡片
struct RecordConfirmCard: View {
    let record: AIRecordParsed
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // 顶部: 金额和类型
            HStack {
                Text(formatAmount())
                    .font(AppFont.monoNumber(size: 24, weight: .bold))
                    .foregroundColor(record.type == .expense ? Theme.expense : Theme.income)
                
                Spacer()
                
                // 置信度指示器
                if let confidence = record.confidence {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("\(Int(confidence * 100))%")
                            .font(AppFont.body(size: 12))
                    }
                    .foregroundColor(confidenceColor(confidence))
                    .padding(.horizontal, Spacing.small)
                    .padding(.vertical, 4)
                    .background(confidenceColor(confidence).opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // 分类和账户
            HStack(spacing: Spacing.large) {
                Label(record.category, systemImage: categoryIcon())
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.text)
                
                Label(record.accountName, systemImage: "creditcard")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            
            // 描述
            if !record.description.isEmpty {
                Text(record.description)
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            
            // 日期
            Text(formatDate())
                .font(AppFont.body(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(Spacing.medium)
        .background(Color.white)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(record.type == .expense ? Theme.expense.opacity(0.2) : Theme.income.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    private func formatAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let amountStr = formatter.string(from: NSDecimalNumber(decimal: record.amount)) ?? "0.00"
        let prefix = record.type == .expense ? "-" : "+"
        return "\(prefix)¥\(amountStr)"
    }
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: record.date)
    }
    
    private func categoryIcon() -> String {
        switch record.category {
        case "餐饮": return "fork.knife"
        case "交通": return "car.fill"
        case "购物": return "cart.fill"
        case "娱乐": return "gamecontroller.fill"
        default: return "tag.fill"
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence > 0.8 {
            return Theme.income
        } else if confidence > 0.5 {
            return .orange
        } else {
            return Theme.expense
        }
    }
}

#Preview {
    VoiceRecordConfirmationView(
        records: [
            AIRecordParsed(
                type: .expense,
                amount: 15,
                category: "餐饮",
                accountName: "支付宝",
                description: "早餐",
                date: Date(),
                confidence: 0.95
            ),
            AIRecordParsed(
                type: .expense,
                amount: 35,
                category: "交通",
                accountName: "支付宝",
                description: "打车",
                date: Date(),
                confidence: 0.88
            )
        ],
        onConfirm: { _ in }
    )
}
