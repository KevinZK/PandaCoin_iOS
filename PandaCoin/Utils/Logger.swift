//
//  Logger.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import OSLog

// MARK: - 日志级别
enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case network = "🌐 NETWORK"
    case ai = "🤖 AI"
}

// MARK: - 日志管理器
class Logger {
    static let shared = Logger()
    
    private let osLog: OSLog
    private let dateFormatter: DateFormatter
    
    private init() {
        osLog = OSLog(subsystem: "com.pandacoin.app", category: "PandaCoin")
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    // MARK: - 基础日志方法
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += "\n错误详情: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, file: file, function: function, line: line)
    }
    
    // MARK: - 网络请求日志
    
    func logNetworkRequest(
        method: String,
        url: String,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) {
        var message = "📤 网络请求\n"
        message += "方法: \(method)\n"
        message += "URL: \(url)"
        
        if let headers = headers, !headers.isEmpty {
            message += "\n请求头: \(headers)"
        }
        
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            message += "\n请求体: \(bodyString)"
        }
        
        log(message, level: .network)
    }
    
    func logNetworkResponse(
        url: String,
        statusCode: Int,
        data: Data?,
        duration: TimeInterval
    ) {
        var message = "📥 网络响应\n"
        message += "URL: \(url)\n"
        message += "状态码: \(statusCode)\n"
        message += "耗时: \(String(format: "%.3f", duration))秒"
        
        if let data = data {
            message += "\n数据大小: \(data.count) bytes"
            
            // 尝试解析JSON并美化输出
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                message += "\n响应数据:\n\(prettyString)"
            } else if let dataString = String(data: data, encoding: .utf8) {
                message += "\n响应数据: \(dataString)"
            }
        }
        
        let level: LogLevel = statusCode >= 400 ? .error : .network
        log(message, level: level)
    }
    
    func logNetworkError(
        url: String,
        error: Error,
        duration: TimeInterval
    ) {
        var message = "❌ 网络错误\n"
        message += "URL: \(url)\n"
        message += "耗时: \(String(format: "%.3f", duration))秒\n"
        message += "错误: \(error.localizedDescription)"
        
        log(message, level: .error)
    }
    
    // MARK: - AI日志
    
    func logAIRequest(text: String) {
        let message = "🤖 AI解析请求\n输入文本: \(text)"
        log(message, level: .ai)
    }
    
    func logAIResponse(records: Int, confidence: Double?) {
        var message = "✅ AI解析完成\n记录数: \(records)"
        if let confidence = confidence {
            message += "\n置信度: \(String(format: "%.2f%%", confidence * 100))"
        }
        log(message, level: .ai)
    }
    
    func logAIError(error: Error) {
        let message = "❌ AI解析失败\n错误: \(error.localizedDescription)"
        log(message, level: .error)
    }
    
    // MARK: - 语音识别日志
    
    func logSpeechRecognition(status: String, text: String? = nil) {
        var message = "🎤 语音识别: \(status)"
        if let text = text {
            message += "\n识别文本: \(text)"
        }
        log(message, level: .info)
    }
    
    // MARK: - 数据操作日志
    
    func logDataOperation(operation: String, entity: String, details: String? = nil) {
        var message = "💾 数据操作\n操作: \(operation)\n实体: \(entity)"
        if let details = details {
            message += "\n详情: \(details)"
        }
        log(message, level: .info)
    }
    
    // MARK: - 核心日志方法
    
    private func log(
        _ message: String,
        level: LogLevel,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        
        let logMessage = """
        [\(timestamp)] \(level.rawValue)
        📍 \(fileName):\(line) - \(function)
        📝 \(message)
        ---
        """
        
        #if DEBUG
        print(logMessage)
        #endif
        
        // 同时写入系统日志
        os_log("%{public}@", log: osLog, type: getOSLogType(level), logMessage)
    }
    
    private func getOSLogType(_ level: LogLevel) -> OSLogType {
        switch level {
        case .debug:
            return .debug
        case .info, .network, .ai:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        }
    }
}

// MARK: - 便捷全局函数
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, file: file, function: function, line: line)
}

func logError(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, error: error, file: file, function: function, line: line)
}
