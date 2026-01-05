//
//  EventConfirmCard.swift
//  PandaCoin
//
//  事件确认卡片 - 从 UnifiedConfirmationView 拆分
//

import SwiftUI

// MARK: - 事件确认卡片
struct EventConfirmCard: View {
    @Binding var event: ParsedFinancialEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // 事件类型标签
            HStack {
                eventTypeLabel
                Spacer()
            }
            
            // 根据事件类型显示不同内容
            switch event.eventType {
            case .transaction:
                if let transactionData = event.transactionData {
                    TransactionCardContent(data: Binding(
                        get: { event.transactionData ?? transactionData },
                        set: { event.transactionData = $0 }
                    ))
                }
            case .assetUpdate:
                if let assetData = event.assetUpdateData {
                    AssetUpdateCardContent(data: Binding(
                        get: { event.assetUpdateData ?? assetData },
                        set: { event.assetUpdateData = $0 }
                    ))
                }
            case .creditCardUpdate:
                if let cardData = event.creditCardData {
                    CreditCardUpdateCardContent(data: Binding(
                        get: { event.creditCardData ?? cardData },
                        set: { event.creditCardData = $0 }
                    ))
                }
            case .holdingUpdate:
                if let holdingData = event.holdingUpdateData {
                    HoldingUpdateCardContent(data: Binding(
                        get: { event.holdingUpdateData ?? holdingData },
                        set: { event.holdingUpdateData = $0 }
                    ))
                }
            case .budget:
                if let budgetData = event.budgetData {
                    BudgetCardContent(data: Binding(
                        get: { event.budgetData ?? budgetData },
                        set: { event.budgetData = $0 }
                    ))
                }
            case .autoPayment:
                if let autoPaymentData = event.autoPaymentData {
                    AutoPaymentCardContent(data: Binding(
                        get: { event.autoPaymentData ?? autoPaymentData },
                        set: { event.autoPaymentData = $0 }
                    ))
                }
            case .queryResponse:
                if let queryData = event.queryResponseData {
                    QueryResponseCardContent(data: queryData)
                }
            case .nullStatement, .needMoreInfo:
                EmptyView()
            }
        }
        .padding(Spacing.medium)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(borderColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var eventTypeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: eventIcon)
                .font(.system(size: 12))
            Text(eventTypeName)
                .font(AppFont.body(size: 12, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, 4)
        .background(borderColor)
        .cornerRadius(12)
    }
    
    private var eventTypeName: String {
        switch event.eventType {
        case .transaction: return "交易记录"
        case .assetUpdate: return "资产更新"
        case .creditCardUpdate: return "信用卡"
        case .holdingUpdate: return "持仓交易"
        case .budget: return "预算"
        case .autoPayment: return "自动扣款"
        case .queryResponse: return "查询结果"
        case .nullStatement: return "无效"
        case .needMoreInfo: return "追问"
        }
    }

    private var eventIcon: String {
        switch event.eventType {
        case .transaction: return "arrow.left.arrow.right"
        case .assetUpdate: return "building.columns"
        case .creditCardUpdate: return "creditcard"
        case .holdingUpdate: return "chart.line.uptrend.xyaxis"
        case .budget: return "target"
        case .autoPayment: return "arrow.triangle.2.circlepath"
        case .queryResponse: return "chart.bar.doc.horizontal"
        case .nullStatement: return "xmark"
        case .needMoreInfo: return "questionmark.circle"
        }
    }

    private var borderColor: Color {
        switch event.eventType {
        case .transaction:
            if let data = event.transactionData {
                return data.type == .expense ? Theme.expense : Theme.income
            }
            return Theme.textSecondary
        case .assetUpdate: return .blue
        case .creditCardUpdate: return .orange
        case .holdingUpdate:
            if let data = event.holdingUpdateData {
                return data.holdingAction == "BUY" ? Theme.expense : Theme.income
            }
            return .green
        case .budget: return .purple
        case .autoPayment: return .cyan
        case .queryResponse: return .teal
        case .nullStatement: return Theme.textSecondary
        case .needMoreInfo: return .gray
        }
    }
}
