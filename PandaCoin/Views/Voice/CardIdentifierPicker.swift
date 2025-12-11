//
//  CardIdentifierPicker.swift
//  PandaCoin
//
//  信用卡标识选择器 - 用于选择或输入卡片唯一标识
//

import SwiftUI

struct CardIdentifierPicker: View {
    @Binding var cardIdentifier: String
    let placeholder: String
    
    @ObservedObject private var creditCardService = CreditCardService.shared
    @State private var showPicker = false
    
    var body: some View {
        HStack(spacing: Spacing.small) {
            // 卡片标识输入框
            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .foregroundColor(Theme.textSecondary)
                    .font(.system(size: 14))
                
                TextField(placeholder, text: $cardIdentifier)
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.background)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // 选择已有卡片按钮
            if !creditCardService.creditCards.isEmpty {
                Button(action: {
                    showPicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12))
                        Text("选择")
                            .font(AppFont.body(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Theme.bambooGreen)
                    .cornerRadius(CornerRadius.small)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            CreditCardPickerSheet(
                cards: creditCardService.creditCards,
                onSelect: { card in
                    cardIdentifier = card.cardIdentifier
                    showPicker = false
                }
            )
        }
        .onAppear {
            // 确保加载信用卡列表
            if creditCardService.creditCards.isEmpty {
                creditCardService.fetchCreditCards()
            }
        }
    }
}

// MARK: - 信用卡选择 Sheet
struct CreditCardPickerSheet: View {
    let cards: [CreditCard]
    let onSelect: (CreditCard) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if cards.isEmpty {
                    Text("暂无信用卡")
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(cards) { card in
                        Button(action: {
                            onSelect(card)
                        }) {
                            CreditCardPickerRow(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("选择信用卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 信用卡选择行
struct CreditCardPickerRow: View {
    let card: CreditCard
    
    var body: some View {
        HStack(spacing: 12) {
            // 卡片图标
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Text("💳")
                    .font(.system(size: 20))
            }
            
            // 卡片信息
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundColor(Theme.text)
                
                HStack(spacing: 8) {
                    Text(card.institutionName)
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    
                    if !card.cardIdentifier.isEmpty {
                        Text("尾号 \(card.cardIdentifier)")
                            .font(AppFont.body(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // 选择指示
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview("CardIdentifierPicker - 有值") {
    struct PreviewWrapper: View {
        @State var identifier = "1234"
        
        var body: some View {
            VStack(spacing: 20) {
                CardIdentifierPicker(
                    cardIdentifier: $identifier,
                    placeholder: "请输入卡片标识（如尾号）"
                )
                
                Text("当前值: \(identifier)")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
        }
    }
    
    return PreviewWrapper()
}

#Preview("CardIdentifierPicker - 无值") {
    struct PreviewWrapper: View {
        @State var identifier = ""
        
        var body: some View {
            VStack(spacing: 20) {
                CardIdentifierPicker(
                    cardIdentifier: $identifier,
                    placeholder: "请输入卡片标识（如尾号）"
                )
            }
            .padding()
            .background(Color.white)
        }
    }
    
    return PreviewWrapper()
}

#Preview("CreditCardPickerSheet") {
    CreditCardPickerSheet(
        cards: [
            CreditCard(
                id: "1",
                name: "招商信用卡",
                institutionName: "招商银行",
                cardIdentifier: "1234",
                creditLimit: 50000,
                currentBalance: 5000,
                repaymentDueDate: "15",
                currency: "CNY",
                createdAt: Date(),
                updatedAt: Date()
            ),
            CreditCard(
                id: "2",
                name: "花旗信用卡",
                institutionName: "花旗银行",
                cardIdentifier: "5678",
                creditLimit: 53000,
                currentBalance: 500,
                repaymentDueDate: "04",
                currency: "USD",
                createdAt: Date(),
                updatedAt: Date()
            )
        ],
        onSelect: { _ in }
    )
}
