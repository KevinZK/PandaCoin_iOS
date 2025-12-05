//
//  NetworkManager.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import Combine

// MARK: - API错误
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "服务器响应异常"
        case .unauthorized:
            return "未授权,请重新登录"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .decodingError(let error):
            return "数据解析失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - 网络管理器
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private var baseURL: String {
        AppConfig.apiBaseURL
    }
    private var cancellables = Set<AnyCancellable>()
    
    // JWT Token存储
    @Published var accessToken: String? {
        didSet {
            if let token = accessToken {
                UserDefaults.standard.set(token, forKey: "accessToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "accessToken")
            }
        }
    }
    
    private init() {
        // 从UserDefaults加载token
        self.accessToken = UserDefaults.standard.string(forKey: "accessToken")
    }
    
    // MARK: - 通用请求方法
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) -> AnyPublisher<T, APIError> {
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            logError("无效的URL: \(baseURL)\(endpoint)")
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        let startTime = Date() // 记录开始时间
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var headers: [String: String] = ["Content-Type": "application/json"]
        
        // 添加认证头
        if requiresAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            headers["Authorization"] = "Bearer \(token.prefix(10))..." // 只记录token前缀
        }
        
        // 设置请求体
        var bodyData: Data?
        if let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                bodyData = try encoder.encode(body)
                request.httpBody = bodyData
            } catch {
                logError("请求体编码失败", error: error)
                return Fail(error: APIError.networkError(error)).eraseToAnyPublisher()
            }
        }
        
        // 记录请求
        Logger.shared.logNetworkRequest(
            method: method,
            url: url.absoluteString,
            headers: headers,
            body: bodyData
        )
        
        // 发送请求
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Data in
                let duration = Date().timeIntervalSince(startTime)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logError("无效的响应类型")
                    throw APIError.invalidResponse
                }
                
                // 记录响应
                Logger.shared.logNetworkResponse(
                    url: url.absoluteString,
                    statusCode: httpResponse.statusCode,
                    data: data,
                    duration: duration
                )
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    logWarning("未授权访问: \(url.absoluteString)")
                    throw APIError.unauthorized
                case 400...499, 500...599:
                    // 尝试解析错误消息（新格式）
                    if let apiError = try? JSONDecoder().decode(APIResponse<String?>.self, from: data) {
                        logError("服务器错误 [\(httpResponse.statusCode)]: \(apiError.message)")
                        throw APIError.serverError(apiError.message)
                    }
                    logError("服务器错误 [\(httpResponse.statusCode)]")
                    throw APIError.invalidResponse
                default:
                    throw APIError.invalidResponse
                }
            }
            .tryMap { data -> T in
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // 先解析为APIResponse包装
                let wrapper = try decoder.decode(APIResponseWrapper<T>.self, from: data)
                
                // 检查响应码
                guard wrapper.code == 0 else {
                    logError("服务器返回错误: \(wrapper.message)")
                    throw APIError.serverError(wrapper.message)
                }
                
                // 提取data字段
                guard let data = wrapper.data else {
                    logError("响应数据为空")
                    throw APIError.invalidResponse
                }
                
                return data
            }
            .mapError { error in
                let duration = Date().timeIntervalSince(startTime)
                
                if let apiError = error as? APIError {
                    return apiError
                } else if let decodingError = error as? DecodingError {
                    // 详细记录解码错误
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        logError("JSON解析失败: \(url.absoluteString)\n缺少键: \(key.stringValue)\n路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        logError("JSON解析失败: \(url.absoluteString)\n类型不匹配: 期望\(type)\n路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))\n描述: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        logError("JSON解析失败: \(url.absoluteString)\n值缺失: \(type)\n路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        logError("JSON解析失败: \(url.absoluteString)\n数据损坏\n路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))\n描述: \(context.debugDescription)")
                    @unknown default:
                        logError("JSON解析失败: \(url.absoluteString)", error: error)
                    }
                    return APIError.decodingError(error)
                } else {
                    Logger.shared.logNetworkError(
                        url: url.absoluteString,
                        error: error,
                        duration: duration
                    )
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 登出
    func logout() {
        accessToken = nil
    }
}

// MARK: - 错误响应模型
struct ErrorResponse: Codable {
    let message: String
    let statusCode: Int?
    
    enum CodingKeys: String, CodingKey {
        case message
        case statusCode = "status_code"
    }
}

// MARK: - 通用响应包装
struct APIResponseWrapper<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: Int64
    let path: String?
}

// MARK: - API响应包装（兼容）
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: Int64
    let path: String?
}
