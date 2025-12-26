//
//  RecordService.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import Combine

class RecordService: ObservableObject {
    static let shared = RecordService()
    
    @Published var records: [Record] = []
    @Published var isLoading = false
    @Published var statistics: RecordStatistics?
    
    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - 获取所有记录
    func fetchRecords(filters: RecordFilters? = nil) {
        isLoading = true
        
        var params: [String: String] = [:]
        if let type = filters?.type {
            params["type"] = type.rawValue
        }
        if let category = filters?.category {
            params["category"] = category
        }
        if let accountId = filters?.accountId {
            params["accountId"] = accountId
        }
        
        let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let endpoint = "/records" + (queryString.isEmpty ? "" : "?\(queryString)")
        
        networkManager.request(endpoint: endpoint, method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        logError("获取记录失败", error: error)
                    }
                },
                receiveValue: { [weak self] (records: [Record]) in
                    self?.records = records
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 获取记录（返回 Publisher，支持按账户和日期筛选）
    func fetchRecords(
        accountId: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) -> AnyPublisher<[Record], APIError> {
        var params: [String: String] = [:]
        
        if let accountId = accountId {
            params["accountId"] = accountId
        }
        if let startDate = startDate {
            params["startDate"] = startDate
        }
        if let endDate = endDate {
            params["endDate"] = endDate
        }
        
        let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let endpoint = "/records" + (queryString.isEmpty ? "" : "?\(queryString)")
        
        return networkManager.request(endpoint: endpoint, method: "GET")
            .eraseToAnyPublisher()
    }
    
    // MARK: - AI语音记账（新流程：只解析不存储）
    func parseVoiceInput(text: String) -> AnyPublisher<[AIRecordParsed], APIError> {
        Logger.shared.logAIRequest(text: text)
        let request = ParseFinancialRequest(text: text)
        return networkManager.request(
            endpoint: "/financial/parse",
            method: "POST",
            body: request
        )
        .map { (response: FinancialEventsResponse) -> [AIRecordParsed] in
            // 调试日志
            logInfo("📝 解析响应: \(response.events.count)条事件")
            
            // 转换 FinancialEvent 为 AIRecordParsed
            return response.events.compactMap { event -> AIRecordParsed? in
                logInfo("📌 事件类型: \(event.event_type), data: \(event.data != nil ? "存在" : "为nil")")
                
                guard event.event_type == "TRANSACTION",
                      let data = event.data else {
                    logInfo("⚠️ 跳过事件: event_type=\(event.event_type)")
                    return nil
                }
                
                logInfo("✅ 解析数据: amount=\(data.amount ?? 0), type=\(data.transaction_type ?? "")")
                
                
                return AIRecordParsed(
                    type: self.mapTransactionType(data.transaction_type ?? ""),
                    amount: Decimal(data.amount ?? 0),
                    category: data.category ?? "其他",
                    accountName: data.source_account ?? "支付宝",
                    description: data.note ?? "",
                    date: self.parseDate(data.date) ?? Date(),
                    confidence: 0.95
                )
            }
        }
        .handleEvents(
            receiveOutput: { records in
                Logger.shared.logAIResponse(
                    records: records.count,
                    confidence: records.first?.confidence
                )
                logInfo("成功解析\(records.count)条AI记账")
            },
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    Logger.shared.logAIError(error: error)
                }
            }
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 统一解析方法（支持所有事件类型）
    func parseVoiceInputUnified(text: String) -> AnyPublisher<[ParsedFinancialEvent], APIError> {
        Logger.shared.logAIRequest(text: text)
        let request = ParseFinancialRequest(text: text)
        return networkManager.request(
            endpoint: "/financial/parse",
            method: "POST",
            body: request
        )
        .map { [weak self] (response: FinancialEventsResponse) -> [ParsedFinancialEvent] in
            guard let self = self else { return [] }
            
            logInfo("📝 统一解析响应: \(response.events.count)条事件")
            
            return response.events.compactMap { event -> ParsedFinancialEvent? in
                guard let data = event.data else { return nil }
                
                let eventType = FinancialEventType(rawValue: event.event_type) ?? .nullStatement
                logInfo("📌 处理事件: \(eventType.rawValue)")
                
                switch eventType {
                case .transaction:
                    var transactionData = AIRecordParsed(
                        type: self.mapTransactionType(data.transaction_type ?? ""),
                        amount: Decimal(data.amount ?? 0),
                        category: data.category ?? "OTHER",
                        accountName: data.source_account ?? "",
                        description: data.note ?? "",
                        date: self.parseDate(data.date) ?? Date(),
                        confidence: 0.95
                    )
                    transactionData.cardIdentifier = data.card_identifier
                    return ParsedFinancialEvent(
                        eventType: .transaction,
                        transactionData: transactionData,
                        assetUpdateData: nil,
                        creditCardData: nil,
                        budgetData: nil
                    )
                    
                case .assetUpdate:
                    // 使用通用字段 name 和 amount
                    let assetType = data.asset_type ?? "BANK"
                    let defaultName = self.generateDefaultAssetName(
                        type: assetType,
                        institution: data.institution_name
                    )
                    var assetData = AssetUpdateParsed(
                        assetType: assetType,
                        assetName: data.name ?? data.source_account ?? defaultName,
                        totalValue: Decimal(data.amount ?? 0),
                        currency: data.currency ?? "CNY",
                        date: self.parseDate(data.date) ?? Date(),
                        institutionName: data.institution_name ?? data.target_account,
                        quantity: data.quantity,
                        interestRateAPY: data.interest_rate_apy,
                        maturityDate: data.maturity_date,
                        isInitialRecord: data.is_initial_record ?? false,
                        costBasis: data.cost_basis,
                        costBasisCurrency: data.cost_basis_currency,
                        projectedValue: data.projected_value,
                        location: data.location,
                        repaymentAmount: data.repayment_amount,
                        repaymentSchedule: data.repayment_schedule,
                        cardIdentifier: data.card_identifier,
                        loanTermMonths: data.loan_term_months,
                        interestRate: data.interest_rate,
                        monthlyPayment: data.monthly_payment,
                        repaymentDay: data.repayment_day,
                        autoRepayment: data.auto_repayment,
                        sourceAccount: data.source_account
                    )
                    return ParsedFinancialEvent(
                        eventType: .assetUpdate,
                        transactionData: nil,
                        assetUpdateData: assetData,
                        creditCardData: nil,
                        budgetData: nil
                    )
                    
                case .creditCardUpdate:
                    // CREDIT_CARD_UPDATE 中，amount 代表信用额度，outstanding_balance 代表待还金额
                    let creditLimit = data.credit_limit ?? data.amount ?? 0
                    let outstandingBalance = data.outstanding_balance ?? 0
                    var creditCardData = CreditCardParsed(
                        name: data.name ?? "",
                        outstandingBalance: Decimal(outstandingBalance),
                        currency: data.currency ?? "CNY",
                        date: self.parseDate(data.date) ?? Date(),
                        institutionName: data.institution_name,
                        creditLimit: creditLimit,
                        repaymentDueDate: data.repayment_due_date,
                        cardIdentifier: data.card_identifier,
                        autoRepayment: data.auto_repayment,
                        repaymentType: data.repayment_type,
                        sourceAccount: data.source_account
                    )
                    return ParsedFinancialEvent(
                        eventType: .creditCardUpdate,
                        transactionData: nil,
                        assetUpdateData: nil,
                        creditCardData: creditCardData,
                        budgetData: nil
                    )
                    
                case .budget:
                    // 使用通用字段 name, amount, date
                    let budgetData = BudgetParsed(
                        action: data.budget_action ?? "CREATE_BUDGET",
                        name: data.name ?? "",
                        targetAmount: Decimal(data.amount ?? 0),
                        currency: data.currency,
                        targetDate: data.date,
                        priority: data.priority,
                        isRecurring: data.is_recurring ?? false
                    )
                    return ParsedFinancialEvent(
                        eventType: .budget,
                        transactionData: nil,
                        assetUpdateData: nil,
                        creditCardData: nil,
                        budgetData: budgetData
                    )
                    
                case .nullStatement:
                    logInfo("⚠️ 无效语句，跳过")
                    return nil
                }
            }
        }
        .handleEvents(
            receiveOutput: { events in
                logInfo("✅ 统一解析完成: \(events.count)条事件")
                for event in events {
                    logInfo("   - \(event.eventType.rawValue)")
                }
            },
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    Logger.shared.logAIError(error: error)
                }
            }
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 统一保存事件（支持多类型）
    // 重要：先保存资产更新，再保存交易，确保账户映射正确
    func saveFinancialEvents(
        _ events: [ParsedFinancialEvent],
        accountMap: [String: String],
        assetService: AssetService? = nil,
        authService: AuthService? = nil  // 新增：用于获取默认支出账户
    ) -> AnyPublisher<Int, APIError> {
        
        // 分离事件类型
        let assetEvents = events.filter { $0.eventType == .assetUpdate }
        let creditCardEvents = events.filter { $0.eventType == .creditCardUpdate }
        let transactionEvents = events.filter { $0.eventType == .transaction }
        let budgetEvents = events.filter { $0.eventType == .budget }
        
        // 第一阶段：先保存资产和信用卡更新（创建新账户）
        var phase1Publishers: [AnyPublisher<Void, APIError>] = []
        
        for event in assetEvents {
                if let data = event.assetUpdateData {
                    let pub = saveAssetUpdate(data)
                    .map { _ in () }
                    .eraseToAnyPublisher()
                phase1Publishers.append(pub)
            }
        }
        
        for event in creditCardEvents {
            if let data = event.creditCardData {
                let pub = saveCreditCardUpdate(data)
                    .map { _ in () }
                        .eraseToAnyPublisher()
                phase1Publishers.append(pub)
            }
                }
        
        // 同时保存预算（不依赖账户）
        for event in budgetEvents {
                if let data = event.budgetData {
                    let pub = saveBudget(data)
                    .map { _ in () }
                    .eraseToAnyPublisher()
                phase1Publishers.append(pub)
            }
        }
        
        // 如果没有资产/信用卡更新，直接保存交易
        if phase1Publishers.isEmpty {
            return saveTransactionEvents(transactionEvents, accountMap: accountMap, authService: authService)
                .map { events.count }
                        .eraseToAnyPublisher()
        }
        
        // 第一阶段完成后，刷新账户列表，再保存交易
        return Publishers.MergeMany(phase1Publishers)
            .collect()
            .flatMap { [weak self] _ -> AnyPublisher<Int, APIError> in
                guard let self = self else {
                    return Just(0).setFailureType(to: APIError.self).eraseToAnyPublisher()
                }
                
                // 如果没有交易事件，直接返回
                if transactionEvents.isEmpty {
                    return Just(events.count).setFailureType(to: APIError.self).eraseToAnyPublisher()
                }
                
                // 刷新账户列表获取新的 accountMap
                guard let assetService = assetService else {
                    // 没有 assetService，使用原来的 accountMap
                    logInfo("⚠️ 无法刷新账户列表，使用原始 accountMap")
                    return self.saveTransactionEvents(transactionEvents, accountMap: accountMap, authService: authService)
                        .map { events.count }
                        .eraseToAnyPublisher()
                }
                
                return assetService.fetchAssets()
                    .flatMap { assets -> AnyPublisher<Int, APIError> in
                        // 构建新的账户映射
                        var newAccountMap = accountMap
                        for asset in assets {
                            newAccountMap[asset.name] = asset.id
                        }
                        logInfo("✅ 刷新账户映射，共 \(newAccountMap.count) 个账户")
                        
                        return self.saveTransactionEvents(transactionEvents, accountMap: newAccountMap, authService: authService)
                            .map { events.count }
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 保存交易事件（辅助方法）
    private func saveTransactionEvents(
        _ events: [ParsedFinancialEvent],
        accountMap: [String: String],
        authService: AuthService? = nil
    ) -> AnyPublisher<Void, APIError> {
        var publishers: [AnyPublisher<Void, APIError>] = []
        
        for event in events {
            if let data = event.transactionData {
                let pub = saveTransaction(data, accountMap: accountMap, authService: authService)
                    .map { _ in () }
                    .eraseToAnyPublisher()
                publishers.append(pub)
            }
        }
        
        if publishers.isEmpty {
            return Just(()).setFailureType(to: APIError.self).eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 保存交易记录
    private func saveTransaction(_ data: AIRecordParsed, accountMap: [String: String], authService: AuthService? = nil) -> AnyPublisher<Record, APIError> {
        // 检查是否涉及信用卡（有 cardIdentifier）
        if let cardIdentifier = data.cardIdentifier, !cardIdentifier.isEmpty {
            logInfo("✅ 信用卡消费: 卡号=\(cardIdentifier), 金额=\(data.amount), 类型=\(data.type)")
            
            // 调用信用卡消费记录接口（同时创建消费记录和更新余额）
            let transactionType = data.type == .expense ? "EXPENSE" : "PAYMENT"
            let request = CreateCreditCardTransactionRequest(
                cardIdentifier: cardIdentifier,
                amount: NSDecimalNumber(decimal: data.amount).doubleValue,
                type: transactionType,
                category: data.category,
                description: data.description,
                date: data.date
            )
            
            return CreditCardService.shared.createTransaction(request)
                .map { response -> Record in
                    // 返回一个 Record 表示成功
                    Record(
                        id: response.record?.id ?? UUID().uuidString,
                        amount: data.amount,
                        type: data.type,
                        category: data.category,
                        description: data.description,
                        date: data.date,
                        accountId: "",
                        accountName: data.accountName,
                        isConfirmed: true
                    )
                }
                .eraseToAnyPublisher()
        }
        
        // 普通账户交易 - 优先使用识别的账户，找不到则使用默认支出账户
        var accountId: String? = nil
        var usedDefaultAccount = false
        
        if !data.accountName.isEmpty {
            // 先尝试匹配识别的账户名
            accountId = accountMap[data.accountName]
        }
        
        // 如果没有匹配到，使用默认支出账户
        if accountId == nil {
            let auth = authService ?? AuthService.shared
            if let user = auth.currentUser,
               let defaultAccountId = user.defaultExpenseAccountId,
               user.defaultExpenseAccountType == "ACCOUNT" {
                accountId = defaultAccountId
                usedDefaultAccount = true
                logInfo("✅ 使用默认支出账户: \(defaultAccountId)")
            } else if !data.accountName.isEmpty {
                logInfo("⚠️ 未匹配到账户: \(data.accountName)，且无默认账户，将不关联账户保存")
            }
        }
        
        let accountDisplayName = usedDefaultAccount ? "默认账户" : (data.accountName.isEmpty ? "未指定" : data.accountName)
        logInfo("✅ 保存交易: 账户=\(accountDisplayName), 金额=\(data.amount), 类型=\(data.type)")
        
        let request = CreateRecordRequest(
            amount: data.amount,
            type: data.type,
            category: data.category,
            accountId: accountId,
            description: data.description,
            date: data.date
        )
        
        return networkManager.request(
            endpoint: "/records",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - 保存资产更新
    private func saveAssetUpdate(_ data: AssetUpdateParsed) -> AnyPublisher<Asset, APIError> {
        logInfo("✅ 保存资产更新: \(data.assetName), 金额=\(data.totalValue)")
        
        let assetType = mapAssetType(data.assetType)
        let request = AssetRequest(
            name: data.assetName,
            type: assetType,
            balance: data.totalValue,
            currency: data.currency
        )
        
        return networkManager.request(
            endpoint: "/assets",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - 保存预算
    private func saveBudget(_ data: BudgetParsed) -> AnyPublisher<Budget, APIError> {
        logInfo("✅ 保存预算: \(data.name), 目标金额=\(data.targetAmount)")
        
        // 获取目标月份，需要转换为 YYYY-MM 格式
        let targetMonth: String
        if let dateStr = data.targetDate, let date = parseDate(dateStr) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            targetMonth = formatter.string(from: date)
        } else {
            targetMonth = getCurrentMonth()
        }
        
        let request = CreateBudgetRequest(
            month: targetMonth,
            category: data.name.isEmpty ? nil : data.name,
            amount: NSDecimalNumber(decimal: data.targetAmount).doubleValue,
            isRecurring: data.isRecurring
        )
        
        return networkManager.request(
            endpoint: "/budgets",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - 保存信用卡更新
    private func saveCreditCardUpdate(_ data: CreditCardParsed) -> AnyPublisher<CreditCard, APIError> {
        logInfo("✅ 保存信用卡配置: 银行=\(data.institutionName ?? "未知"), 额度=\(data.creditLimit ?? 0)")
        
        // 调用 CreditCardService 的正确方法保存到信用卡模块
        return CreditCardService.shared.saveCreditCardFromParsed(data)
    }
    
    // MARK: - 辅助方法
    
    /// 根据资产类型和机构名称生成默认资产名称
    private func generateDefaultAssetName(type: String, institution: String?) -> String {
        let typeName: String
        switch type.uppercased() {
        case "BANK": typeName = "银行账户"
        case "INVESTMENT": typeName = "投资账户"
        case "CASH": typeName = "现金"
        case "CREDIT_CARD": typeName = "信用卡"
        case "DIGITAL_WALLET": typeName = "电子钱包"
        case "LOAN": typeName = "贷款"
        case "MORTGAGE": typeName = "房贷"
        case "SAVINGS": typeName = "储蓄账户"
        case "RETIREMENT": typeName = "养老金"
        case "CRYPTO": typeName = "加密货币"
        case "PROPERTY": typeName = "房产"
        case "VEHICLE": typeName = "车辆"
        case "OTHER_ASSET": typeName = "其他资产"
        case "OTHER_LIABILITY": typeName = "其他负债"
        default: typeName = "资产"
        }
        
        // 如果有机构名称，拼接机构名 + 类型
        if let inst = institution, !inst.isEmpty {
            return "\(inst)\(typeName)"
        }
        return typeName
    }
    
    private func mapAssetType(_ type: String) -> AssetType {
        // AI 返回的 asset_type 直接映射到 AssetType
        switch type.uppercased() {
        case "BANK": return .bank
        case "INVESTMENT": return .investment
        case "CASH": return .cash
        case "CREDIT_CARD": return .creditCard
        case "DIGITAL_WALLET": return .digitalWallet
        case "LOAN": return .loan
        case "MORTGAGE": return .mortgage
        case "SAVINGS": return .savings
        case "RETIREMENT": return .retirement
        case "CRYPTO": return .crypto
        case "PROPERTY": return .property
        case "VEHICLE": return .vehicle
        case "OTHER_ASSET": return .otherAsset
        case "OTHER_LIABILITY": return .otherLiability
        default: return .bank  // 默认为银行账户
        }
    }
    
    private func getCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    // MARK: - 批量创建记账（用户确认后）- 兼容旧接口
    func batchCreateRecords(_ parsedRecords: [AIRecordParsed], accountMap: [String: String]) -> AnyPublisher<[Record], APIError> {
        let publishers = parsedRecords.map { parsed -> AnyPublisher<Record, APIError> in
            guard let accountId = accountMap[parsed.accountName] else {
                logError("❌ 找不到账户: \(parsed.accountName), 可用账户: \(accountMap.keys.joined(separator: ", "))")
                return Fail(error: APIError.serverError("找不到账户: \(parsed.accountName)")).eraseToAnyPublisher()
            }
            
            logInfo("✅ 创建记录: 账户=\(parsed.accountName), 金额=\(parsed.amount), 类型=\(parsed.type)")
            
            let request = CreateRecordRequest(
                amount: parsed.amount,
                type: parsed.type,
                category: parsed.category,
                accountId: accountId,
                description: parsed.description,
                date: parsed.date
            )
            
            return networkManager.request(
                endpoint: "/records",
                method: "POST",
                body: request
            )
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    // MARK: - 辅助方法
    private func mapTransactionType(_ type: String) -> RecordType {
        switch type.uppercased() {
        case "EXPENSE": return .expense
        case "INCOME": return .income
        case "TRANSFER": return .transfer
        case "PAYMENT": return .payment
        default: return .expense
        }
    }
    
    private func parseDate(_ dateStr: String?) -> Date? {
        guard let dateStr = dateStr else { return nil }
        
        // 先尝试简单日期格式 (YYYY-MM-DD)
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleDateFormatter.date(from: dateStr) {
            return date
        }
        
        // 再尝试 ISO8601 完整格式
        let isoFormatter = ISO8601DateFormatter()
        return isoFormatter.date(from: dateStr)
    }
    
    // MARK: - 手动创建记账
    func createRecord(
        amount: Decimal,
        type: RecordType,
        category: String,
        accountId: String,
        description: String?,
        date: Date = Date()
    ) -> AnyPublisher<Record, APIError> {
        let request = CreateRecordRequest(
            amount: amount,
            type: type,
            category: category,
            accountId: accountId,
            description: description,
            date: date
        )
        
        return networkManager.request(
            endpoint: "/records",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - 更新记录
    func updateRecord(
        id: String,
        amount: Decimal?,
        type: RecordType?,
        category: String?,
        description: String?
    ) -> AnyPublisher<Record, APIError> {
        let request = UpdateRecordRequest(
            amount: amount,
            type: type,
            category: category,
            description: description
        )
        
        return networkManager.request(
            endpoint: "/records/\(id)",
            method: "PATCH",
            body: request
        )
    }
    
    // MARK: - 删除记录
    func deleteRecord(id: String) -> AnyPublisher<Void, APIError> {
        return networkManager.request(
            endpoint: "/records/\(id)",
            method: "DELETE"
        )
        .map { (_: EmptyResponse) in () }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 获取统计数据
    func fetchStatistics(period: String = "month") {
        networkManager.request(endpoint: "/records/statistics?period=\(period)", method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        logError("获取统计数据失败", error: error)
                    }
                },
                receiveValue: { [weak self] (stats: RecordStatistics) in
                    self?.statistics = stats
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 辅助模型
struct RecordFilters {
    var type: RecordType?
    var category: String?
    var accountId: String?
}

struct CreateRecordRequest: Codable {
    let amount: Decimal
    let type: RecordType
    let category: String
    let accountId: String?
    let description: String?
    let date: Date
}

struct UpdateRecordRequest: Codable {
    let amount: Decimal?
    let type: RecordType?
    let category: String?
    let description: String?
}

struct RecordStatistics: Codable {
    let period: String
    let totalIncome: Decimal
    let totalExpense: Decimal
    let balance: Decimal
    let categoryStats: [String: Decimal]
    let recordCount: Int
    
    enum CodingKeys: String, CodingKey {
        case period
        case totalIncome = "total_income"
        case totalExpense = "total_expense"
        case balance
        case categoryStats = "category_stats"
        case recordCount = "record_count"
    }
}

struct EmptyResponse: Codable {}

// MARK: - Financial API Models
struct ParseFinancialRequest: Codable {
    let text: String
}

struct FinancialEventsResponse: Codable {
    let events: [FinancialEvent]
}

struct FinancialEvent: Codable {
    let event_type: String
    let data: FinancialEventData?
}

// 统一的事件数据结构，支持所有事件类型
struct FinancialEventData: Codable {
    // 通用字段
    let amount: Double?
    let currency: String?
    let date: String?
    let name: String?
    let note: String?
    
    // TRANSACTION 字段
    let transaction_type: String?
    let category: String?
    let source_account: String?
    let target_account: String?
    let is_recurring: Bool?
    let payment_schedule: String?
    
    // ASSET_UPDATE 字段
    let asset_type: String?
    let institution_name: String?
    let quantity: Double?
    let interest_rate_apy: Double?
    let maturity_date: String?
    let is_initial_record: Bool?
    let cost_basis: Double?
    let cost_basis_currency: String?
    let projected_value: Double?
    let location: String?
    let repayment_amount: Double?
    let repayment_schedule: String?
    
    // CREDIT_CARD_UPDATE 字段
    let credit_limit: Double?
    let repayment_due_date: String?
    let outstanding_balance: Double?  // 待还金额
    
    // 通用信用卡标识字段（TRANSACTION/ASSET_UPDATE/CREDIT_CARD_UPDATE 共用）
    let card_identifier: String?
    
    // BUDGET 字段
    let budget_action: String?
    let priority: String?
    
    // is_recurring 用于 BUDGET 和 TRANSACTION（复用同一个字段）
    
    // 贷款专用字段 (LOAN / MORTGAGE)
    let loan_term_months: Int?      // 贷款期限(月)
    let interest_rate: Double?      // 年利率 (%)
    let monthly_payment: Double?    // 月供金额
    let repayment_day: Int?         // 还款日 (1-28)
    
    // 自动还款配置
    let auto_repayment: Bool?       // 是否启用自动还款
    let repayment_type: String?     // 还款类型: "FULL" 或 "MIN"（信用卡用）
}

// MARK: - 统一解析结果类型
enum FinancialEventType: String, Codable {
    case transaction = "TRANSACTION"
    case assetUpdate = "ASSET_UPDATE"
    case creditCardUpdate = "CREDIT_CARD_UPDATE"
    case budget = "BUDGET"
    case nullStatement = "NULL_STATEMENT"
}

// 统一的解析结果，支持多种事件类型
struct ParsedFinancialEvent: Identifiable {
    let id = UUID()
    let eventType: FinancialEventType
    
    // 交易数据
    var transactionData: AIRecordParsed?
    
    // 资产更新数据
    var assetUpdateData: AssetUpdateParsed?
    
    // 信用卡更新数据
    var creditCardData: CreditCardParsed?
    
    // 预算数据
    var budgetData: BudgetParsed?
}

// 资产更新解析结果
struct AssetUpdateParsed {
    let assetType: String           // BANK, INVESTMENT, CASH, CREDIT_CARD, DIGITAL_WALLET, LOAN, MORTGAGE, SAVINGS, RETIREMENT, CRYPTO, PROPERTY, VEHICLE, OTHER_ASSET, OTHER_LIABILITY
    let assetName: String
    let totalValue: Decimal
    let currency: String
    let date: Date
    let institutionName: String?
    
    let quantity: Double?
    let interestRateAPY: Double?
    let maturityDate: String?
    let isInitialRecord: Bool
    let costBasis: Double?
    let costBasisCurrency: String?
    let projectedValue: Double?
    let location: String?
    
    // 还款计划（负债类）
    let repaymentAmount: Double?
    let repaymentSchedule: String?
    
    // 信用卡标识（仅当 asset_type = CREDIT_CARD 时使用）
    var cardIdentifier: String?
    
    // 贷款专用字段 (LOAN / MORTGAGE)
    var loanTermMonths: Int?        // 贷款期限(月)
    var interestRate: Double?       // 年利率 (%)
    var monthlyPayment: Double?     // 月供金额
    var repaymentDay: Int?          // 还款日 (1-28)
    
    // 自动还款配置
    var autoRepayment: Bool?        // 是否启用自动还款
    var sourceAccount: String?      // 扣款来源账户名称
}

// 预算解析结果
struct BudgetParsed {
    let action: String      // CREATE_BUDGET, UPDATE_BUDGET
    let name: String
    let targetAmount: Decimal
    let currency: String?
    let targetDate: String?
    let priority: String?
    var isRecurring: Bool   // 是否每月循环
}

// 信用卡解析结果
struct CreditCardParsed {
    let name: String                // 卡片名称
    let outstandingBalance: Decimal // 待还金额
    let currency: String
    let date: Date
    let institutionName: String?    // 发卡银行
    let creditLimit: Double?        // 授信额度
    let repaymentDueDate: String?   // 还款日（如 "04"）
    var cardIdentifier: String?     // 卡片唯一标识（如尾号"1234"）
    
    // 自动还款配置
    var autoRepayment: Bool?        // 是否启用自动还款
    var repaymentType: String?      // 还款类型: "FULL" 或 "MIN"
    var sourceAccount: String?      // 扣款来源账户名称
}
