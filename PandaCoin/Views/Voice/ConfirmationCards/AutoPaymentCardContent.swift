//
//  AutoPaymentCardContent.swift
//  PandaCoin
//
//  自动扣款卡片内容 - 从 UnifiedConfirmationView 拆分
//

import SwiftUI

// MARK: - 自动扣款卡片内容
struct AutoPaymentCardContent: View {
    @Binding var data: AutoPaymentParsed
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 订阅名称
            HStack {
                Text("订阅名称")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(data.name)
                    .font(AppFont.body(size: 14, weight: .medium))
                    .foregroundColor(Theme.text)
            }
            
            Divider()
            
            // 类型
            HStack {
                Text("类型")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(data.paymentTypeDisplayName)
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.text)
            }
            
            Divider()
            
            // 金额
            HStack {
                Text("每月金额")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("¥\(data.amount.formatted())")
                    .font(AppFont.body(size: 16, weight: .bold))
                    .foregroundColor(Theme.expense)
            }
            
            Divider()
            
            // 扣款日
            HStack {
                Text("扣款日")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                if let day = data.dayOfMonth {
                    Text("每月\(day)号")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.text)
                } else {
                    Text("未设置")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}
