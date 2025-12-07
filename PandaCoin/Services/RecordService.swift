//
//  RecordService.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import Combine

class RecordService: ObservableObject {
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
                    let transactionData = AIRecordParsed(
                        type: self.mapTransactionType(data.transaction_type ?? ""),
                        amount: Decimal(data.amount ?? 0),
                        category: data.category ?? "OTHER",
                        accountName: data.source_account ?? "",
                        description: data.note ?? "",
                        date: self.parseDate(data.date) ?? Date(),
                        confidence: 0.95
                    )
                    return ParsedFinancialEvent(
                        eventType: .transaction,
                        transactionData: transactionData,
                        assetUpdateData: nil,
                        budgetData: nil
                    )
                    
                case .assetUpdate:
                    // AI 返回的 ASSET_UPDATE 使用与 TRANSACTION 相同的字段结构
                    let assetData = AssetUpdateParsed(
                        assetType: data.category ?? "OTHER_ASSET",      // 使用 category
                        assetName: data.source_account ?? "",           // 使用 source_account
                        totalValue: Decimal(data.amount ?? 0),          // 使用 amount
                        currency: data.currency ?? "CNY",
                        date: self.parseDate(data.date) ?? Date(),
                        institutionName: data.target_account           // 使用 target_account 作为机构名
                    )
                    return ParsedFinancialEvent(
                        eventType: .assetUpdate,
                        transactionData: nil,
                        assetUpdateData: assetData,
                        budgetData: nil
                    )
                    
                case .budget:
                    let budgetData = BudgetParsed(
                        action: data.budget_action ?? "CREATE_SAVINGS",
                        name: data.budget_name ?? "",
                        targetAmount: Decimal(data.target_amount ?? 0),
                        targetDate: data.target_date,
                        priority: data.priority
                    )
                    return ParsedFinancialEvent(
                        eventType: .budget,
                        transactionData: nil,
                        assetUpdateData: nil,
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
    func saveFinancialEvents(
        _ events: [ParsedFinancialEvent],
        accountMap: [String: String]
    ) -> AnyPublisher<Int, APIError> {
        var successCount = 0
        var publishers: [AnyPublisher<Void, APIError>] = []
        
        for event in events {
            switch event.eventType {
            case .transaction:
                if let data = event.transactionData {
                    let pub = saveTransaction(data, accountMap: accountMap)
                        .map { _ in successCount += 1 }
                        .eraseToAnyPublisher()
                    publishers.append(pub)
                }
            case .assetUpdate:
                if let data = event.assetUpdateData {
                    let pub = saveAssetUpdate(data)
                        .map { _ in successCount += 1 }
                        .eraseToAnyPublisher()
                    publishers.append(pub)
                }
            case .budget:
                if let data = event.budgetData {
                    let pub = saveBudget(data)
                        .map { _ in successCount += 1 }
                        .eraseToAnyPublisher()
                    publishers.append(pub)
                }
            case .nullStatement:
                break
            }
        }
        
        guard !publishers.isEmpty else {
            return Just(0)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in events.count }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 保存交易记录
    private func saveTransaction(_ data: AIRecordParsed, accountMap: [String: String]) -> AnyPublisher<Record, APIError> {
        guard let accountId = accountMap[data.accountName] else {
            logError("❌ 找不到账户: \(data.accountName)")
            return Fail(error: APIError.serverError("找不到账户: \(data.accountName)")).eraseToAnyPublisher()
        }
        
        logInfo("✅ 保存交易: 账户=\(data.accountName), 金额=\(data.amount), 类型=\(data.type)")
        
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
        
        // 获取目标月份，默认当前月
        let targetMonth = data.targetDate ?? getCurrentMonth()
        
        let request = CreateBudgetRequest(
            month: targetMonth,
            category: data.name.isEmpty ? nil : data.name,
            amount: NSDecimalNumber(decimal: data.targetAmount).doubleValue
        )
        
        return networkManager.request(
            endpoint: "/budgets",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - 辅助方法
    private func mapAssetType(_ type: String) -> AssetType {
        // AI 返回的是 category 类型，需要映射到 AssetType
        switch type.uppercased() {
        case "BANK_BALANCE", "BANK", "SAVINGS": return .bank
        case "STOCK", "INVESTMENT": return .investment
        case "CRYPTO": return .crypto
        case "PHYSICAL_ASSET", "PROPERTY": return .property
        case "LIABILITY", "LOAN": return .loan
        case "CREDIT_CARD": return .creditCard
        case "CASH": return .cash
        case "DIGITAL_WALLET": return .digitalWallet
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
    let accountId: String
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
    // TRANSACTION 字段
    let transaction_type: String?
    let amount: Double?
    let category: String?
    let source_account: String?
    let target_account: String?
    let note: String?
    let date: String?
    let currency: String?
    
    // ASSET_UPDATE 字段
    let asset_type: String?
    let asset_name: String?
    let total_value: Double?
    let institution_name: String?
    
    // BUDGET 字段
    let budget_action: String?
    let budget_name: String?
    let target_amount: Double?
    let target_date: String?
    let priority: String?
}

// MARK: - 统一解析结果类型
enum FinancialEventType: String, Codable {
    case transaction = "TRANSACTION"
    case assetUpdate = "ASSET_UPDATE"
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
    
    // 预算数据
    var budgetData: BudgetParsed?
}

// 资产更新解析结果
struct AssetUpdateParsed {
    let assetType: String
    let assetName: String
    let totalValue: Decimal
    let currency: String
    let date: Date
    let institutionName: String?
}

// 预算解析结果
struct BudgetParsed {
    let action: String      // CREATE_SAVINGS, CREATE_DEBT_REPAYMENT, UPDATE_TARGET
    let name: String
    let targetAmount: Decimal
    let targetDate: String? // YYYY-MM 格式
    let priority: String?
}
