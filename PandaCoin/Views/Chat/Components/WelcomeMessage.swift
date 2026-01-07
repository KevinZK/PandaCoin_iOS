//
//  WelcomeMessage.swift
//  PandaCoin
//
//  欢迎消息组件
//

import SwiftUI

// MARK: - 欢迎消息视图
struct WelcomeMessageView: View {
    var body: some View {
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
                    QuickTipChip(text: "我的汇丰银行储蓄卡有156300")
                    QuickTipChip(text: "我这个月预算2600")
                }
                QuickTipChip(text: "我有一张尾号2345的花旗银行信用卡，额度25000，每个月15号还款")
                HStack(spacing: 8) {
                    QuickTipChip(text: "午餐花了35元，打车15块")
                    QuickTipChip(text: "发了8000工资")
                }
                
                HStack(spacing: 8) {
                    QuickTipChip(text: "买衣服消费200")
                    QuickTipChip(text: "我持有英伟达股票1万股")
                }
                HStack(spacing: 8) {
                    QuickTipChip(text: "我的车贷目前还有12000")
                    QuickTipChip(text: "今天车贷还款3065")
                }
                
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
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

#Preview {
    WelcomeMessageView()
}
