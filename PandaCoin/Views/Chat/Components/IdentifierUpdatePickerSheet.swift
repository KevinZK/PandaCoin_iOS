//
//  IdentifierUpdatePickerSheet.swift
//  PandaCoin
//
//  账户尾号更新选择器
//

import SwiftUI

struct IdentifierUpdatePickerSheet: View {
    let cardIdentifier: String
    let accounts: [Asset]
    let onSelect: (Asset) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("请选择要添加尾号「\(cardIdentifier)」的账户")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                        .listRowBackground(Color.clear)
                }
                
                Section {
                    ForEach(accounts, id: \.id) { account in
                        Button {
                            onSelect(account)
                        } label: {
                            HStack(spacing: 12) {
                                // 账户图标
                                Image(systemName: account.type.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.bambooGreen)
                                    .frame(width: 36, height: 36)
                                    .background(Theme.bambooGreen.opacity(0.1))
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                        .font(AppFont.body(size: 16, weight: .medium))
                                        .foregroundColor(Theme.text)
                                    
                                    if let institution = account.institutionName {
                                        Text(institution)
                                            .font(AppFont.body(size: 12))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // 余额
                                Text(formatBalance(account))
                                    .font(AppFont.monoNumber(size: 14, weight: .medium))
                                    .foregroundColor(Theme.text)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("选择账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func formatBalance(_ account: Asset) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let symbol = currencySymbol(account.currency)
        return "\(symbol)\(formatter.string(from: NSDecimalNumber(decimal: account.balance)) ?? "0.00")"
    }
    
    private func currencySymbol(_ currency: String) -> String {
        switch currency.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "HKD": return "HK$"
        default: return "¥"
        }
    }
}
