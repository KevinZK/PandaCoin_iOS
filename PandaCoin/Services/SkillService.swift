//
//  SkillService.swift
//  PandaCoin
//
//  AI Skills 服务 - 处理智能助手功能
//

import Foundation
import Combine

// MARK: - 技能类型
enum SkillType: String, Codable, CaseIterable {
    case accounting = "accounting"          // 记账解析
    case billAnalysis = "bill-analysis"     // 账单分析
    case budgetAdvisor = "budget-advisor"   // 预算顾问
    case investment = "investment"          // 投资分析
    case loanAdvisor = "loan-advisor"       // 贷款顾问

    var displayName: String {
        switch self {
        case .accounting: return "记账"
        case .billAnalysis: return "账单分析"
        case .budgetAdvisor: return "预算顾问"
        case .investment: return "投资分析"
        case .loanAdvisor: return "贷款顾问"
        }
    }

    var icon: String {
        switch self {
        case .accounting: return "pencil.and.list.clipboard"
        case .billAnalysis: return "chart.pie"
        case .budgetAdvisor: return "target"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .loanAdvisor: return "creditcard"
        }
    }
}

// MARK: - 技能信息
struct SkillInfo: Codable, Identifiable {
    let name: String
    let description: String

    var id: String { name }

    var skillType: SkillType? {
        SkillType(rawValue: name)
    }
}

// MARK: - 技能路由结果
struct SkillRouteResult: Codable {
    let skillName: String
    let confidence: Double
    let reasoning: String
}

// MARK: - 技能执行结果
struct SkillExecuteResult: Codable {
    let success: Bool
    let skillUsed: String
    let response: SkillResponse?
    let confidence: Double
    let rawAiResponse: String?
    let error: String?
}

// MARK: - 技能响应（通用）
struct SkillResponse: Codable {
    // 通用字段
    let summary: String?
    let suggestions: [String]?
    let insights: [String]?

    // 记账相关
    let success: Bool?
    let needsConfirmation: Bool?
    let missingFields: [String]?
    let message: String?

    // 分析相关
    let analysisType: String?
    let overallStatus: String?

    // 数据字段（使用 AnyCodable 或保留原始 JSON）
    let data: [String: AnyCodableValue]?
    let risks: [[String: AnyCodableValue]]?

    enum CodingKeys: String, CodingKey {
        case summary, suggestions, insights
        case success, needsConfirmation, missingFields, message
        case analysisType, overallStatus
        case data, risks
    }
}

// MARK: - AnyCodable 值类型
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }

        if let int = try? container.decode(Int.self) {
            self = .int(int)
            return
        }

        if let double = try? container.decode(Double.self) {
            self = .double(double)
            return
        }

        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }

        if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
            return
        }

        if let dict = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dict)
            return
        }

        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    // 便捷访问器
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        if case .int(let value) = self { return Double(value) }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}

// MARK: - 技能服务
class SkillService: ObservableObject {
    static let shared = SkillService()

    @Published var availableSkills: [SkillInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSkills()
    }

    // MARK: - 加载可用技能
    func loadSkills() {
        isLoading = true

        NetworkManager.shared.request(
            endpoint: "/skills",
            method: "GET"
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    print("❌ [SkillService] 加载技能失败: \(error)")
                }
            },
            receiveValue: { [weak self] (skills: [SkillInfo]) in
                self?.availableSkills = skills
                print("✅ [SkillService] 已加载 \(skills.count) 个技能")
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 执行技能
    func executeSkill(
        message: String,
        skillName: String? = nil,
        completion: @escaping (Result<SkillExecuteResult, APIError>) -> Void
    ) {
        isLoading = true

        struct ExecuteRequest: Encodable {
            let message: String
            let skillName: String?
        }

        let request = ExecuteRequest(message: message, skillName: skillName)

        NetworkManager.shared.request(
            endpoint: "/skills/execute",
            method: "POST",
            body: request
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            },
            receiveValue: { (result: SkillExecuteResult) in
                completion(.success(result))
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 执行技能 (async/await)
    @MainActor
    func executeSkill(message: String, skillName: String? = nil) async throws -> SkillExecuteResult {
        isLoading = true
        defer { isLoading = false }

        return try await withCheckedThrowingContinuation { continuation in
            executeSkill(message: message, skillName: skillName) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - 路由消息（获取推荐技能）
    func routeMessage(
        _ message: String,
        completion: @escaping (Result<SkillRouteResult, APIError>) -> Void
    ) {
        struct RouteRequest: Encodable {
            let message: String
        }

        NetworkManager.shared.request(
            endpoint: "/skills/route",
            method: "POST",
            body: RouteRequest(message: message)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { result in
                if case .failure(let error) = result {
                    completion(.failure(error))
                }
            },
            receiveValue: { (result: SkillRouteResult) in
                completion(.success(result))
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 快捷方法：记账
    func parseAccounting(text: String) async throws -> SkillExecuteResult {
        try await executeSkill(message: text, skillName: "accounting")
    }

    // MARK: - 快捷方法：账单分析
    func analyzeBills(query: String) async throws -> SkillExecuteResult {
        try await executeSkill(message: query, skillName: "bill-analysis")
    }

    // MARK: - 快捷方法：预算建议
    func getBudgetAdvice(query: String) async throws -> SkillExecuteResult {
        try await executeSkill(message: query, skillName: "budget-advisor")
    }

    // MARK: - 快捷方法：投资分析
    func analyzeInvestment(query: String) async throws -> SkillExecuteResult {
        try await executeSkill(message: query, skillName: "investment")
    }

    // MARK: - 快捷方法：贷款建议
    func getLoanAdvice(query: String) async throws -> SkillExecuteResult {
        try await executeSkill(message: query, skillName: "loan-advisor")
    }
}
