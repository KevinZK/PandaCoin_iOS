//
//  UnifiedConfirmationView.swift
//  PandaCoin
//
//  统一确认视图 - 支持多种事件类型
//

import SwiftUI
import Combine

struct UnifiedConfirmationView: View {
    @Environment(\.dismiss) var dismiss

    @State private var editableEvents: [ParsedFinancialEvent]
    let onConfirm: ([ParsedFinancialEvent]) -> Void

    // 自动入账提示状态
    @State private var showAutoIncomePrompt = false
    @State private var showAutoIncomeSheet = false
    @State private var pendingFixedIncomeEvent: ParsedFinancialEvent?
    @State private var showAutoIncomeSuccessAlert = false

    init(events: [ParsedFinancialEvent], onConfirm: @escaping ([ParsedFinancialEvent]) -> Void) {
        self._editableEvents = State(initialValue: events)
        self.onConfirm = onConfirm
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

                            Text(headerTitle)
                                .font(AppFont.body(size: 16, weight: .medium))
                                 .foregroundColor(Theme.text)

                            if hasSaveableEvents {
                                Text("请确认是否正确")
                                    .font(AppFont.body(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.top, Spacing.large)

                        // 事件列表
                        VStack(spacing: Spacing.medium) {
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
                        }
                        .padding(.horizontal, Spacing.medium)

                        // 按钮
                        if hasSaveableEvents {
                            HStack(spacing: Spacing.medium) {
                                Button(action: {
                                    dismiss()
                                }) {
                                    Text("取消")
                                        .font(AppFont.body(size: 16, weight: .medium))
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Theme.cardBackground)
                                        .cornerRadius(CornerRadius.medium)
                                }

                                Button(action: {
                                    handleConfirm()
                                }) {
                                    Text("确认保存")
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
                        } else {
                            // 查询类结果只显示关闭按钮
                            Button(action: {
                                dismiss()
                            }) {
                                Text("关闭")
                                    .font(AppFont.body(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Theme.bambooGreen)
                                    .cornerRadius(CornerRadius.medium)
                            }
                            .padding(.horizontal, Spacing.medium)
                            .padding(.bottom, Spacing.large)
                        }
                    }
                }
            }
            .navigationTitle("确认记录")
            .navigationBarTitleDisplayMode(.inline)
        }
        // 自动入账提示对话框
        .alert("设置自动入账", isPresented: $showAutoIncomePrompt) {
            Button("稍后设置") {
                dismiss()
            }
            Button("立即设置") {
                showAutoIncomeSheet = true
            }
        } message: {
            if let event = pendingFixedIncomeEvent, let record = event.transactionData {
                Text("检测到「\(record.description)」是固定收入，是否设置为每月自动入账？")
            } else {
                Text("检测到固定收入，是否设置为每月自动入账？")
            }
        }
        // 快速设置自动入账 Sheet
        .sheet(isPresented: $showAutoIncomeSheet, onDismiss: {
            dismiss()
        }) {
            if let event = pendingFixedIncomeEvent, let record = event.transactionData {
                QuickAutoIncomeSheet(
                    prefillName: record.description.isEmpty ? record.category : record.description,
                    prefillAmount: Double(truncating: record.amount as NSNumber),
                    prefillDay: record.suggestedDay ?? Calendar.current.component(.day, from: Date()),
                    prefillIncomeType: inferIncomeType(from: record)
                ) { success in
                    if success {
                        showAutoIncomeSuccessAlert = true
                    }
                }
            }
        }
        // 设置成功提示
        .alert("自动入账已设置", isPresented: $showAutoIncomeSuccessAlert) {
            Button("知道了") {
                dismiss()
            }
            Button("前往查看") {
                // TODO: 导航到自动入账列表
                dismiss()
            }
        } message: {
            Text("您可以在 设置 → 自动入账 中管理")
        }
    }

    // MARK: - 计算属性
    
    /// 是否有可保存的事件（非查询类型）
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
    
    /// 标题文字
    private var headerTitle: String {
        if hasSaveableEvents {
            return "熊猫识别了\(editableEvents.count)条记录"
        } else if editableEvents.first?.eventType == .queryResponse {
            return "熊猫为您查询到以下信息"
        } else {
            return "熊猫识别结果"
        }
    }
    
    // MARK: - 确认逻辑

    private func handleConfirm() {
        onConfirm(editableEvents)

        // 检查是否有固定收入事件
        if let fixedIncomeEvent = findFixedIncomeEvent() {
            pendingFixedIncomeEvent = fixedIncomeEvent
            showAutoIncomePrompt = true
        } else {
            dismiss()
        }
    }

    /// 查找固定收入事件（使用 CategoryMapper 的纯枚举匹配）
    private func findFixedIncomeEvent() -> ParsedFinancialEvent? {
        for event in editableEvents {
            if let record = event.transactionData {
                // 收入类型且被标记为固定收入
                if record.type == .income && record.isFixedIncome == true {
                    return event
                }
                // 收入类型且分类是工资、公积金、养老金等
                if record.type == .income && CategoryMapper.isFixedIncomeCategory(record.category) {
                    return event
                }
            }
        }
        return nil
    }

    /// 从交易记录推断收入类型
    private func inferIncomeType(from record: AIRecordParsed) -> IncomeType {
        // 先尝试使用 incomeType 字段
        if let typeString = record.incomeType {
            switch typeString.uppercased() {
            case "SALARY": return .salary
            case "HOUSING_FUND": return .housingFund
            case "PENSION": return .pension
            case "RENTAL": return .rental
            case "INVESTMENT_RETURN": return .investmentReturn
            default: break
            }
        }

        // 使用 CategoryMapper 从 category 推断
        return CategoryMapper.inferIncomeType(from: record.category)
    }
}

#Preview("统一确认页面 - 全部类型") {
    UnifiedConfirmationView(
        events: [
            ParsedFinancialEvent(
                eventType: .transaction,
                transactionData: AIRecordParsed(
                    type: .expense,
                    amount: 35,
                    category: "FOOD",
                    accountName: "招商银行",
                    description: "午餐",
                    date: Date(),
                    confidence: 0.95
                ),
                assetUpdateData: nil,
                creditCardData: nil,
                budgetData: nil
            )
        ]
    ) { _ in }
}
