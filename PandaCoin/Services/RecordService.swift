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
            // 转换 FinancialEvent 为 AIRecordParsed
            response.events.compactMap { event -> AIRecordParsed? in
                guard event.event_type == "TRANSACTION",
                      let data = event.data else { return nil }
                
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
    
    // MARK: - 批量创建记账（用户确认后）
    func batchCreateRecords(_ parsedRecords: [AIRecordParsed], accountMap: [String: String]) -> AnyPublisher<[Record], APIError> {
        let publishers = parsedRecords.map { parsed -> AnyPublisher<Record, APIError> in
            guard let accountId = accountMap[parsed.accountName] else {
                return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
            }
            
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
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateStr)
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

struct FinancialEventData: Codable {
    let transaction_type: String?
    let amount: Double?
    let category: String?
    let source_account: String?
    let note: String?
    let date: String?
}
