//
//  LocalOCRService.swift
//  PandaCoin
//
//  本地 OCR 服务 - 使用 Vision 框架进行票据文字识别
//

import Foundation
import Vision
import UIKit
import Combine

// MARK: - 票据类型
enum ReceiptType: String, CaseIterable {
    case shopping = "购物小票"
    case takeout = "外卖订单"
    case payment = "支付截图"
    case invoice = "发票"
    case bankBill = "银行账单"
    case taxi = "打车订单"
    case utility = "水电煤"
    case unknown = "其他票据"
    
    var icon: String {
        switch self {
        case .shopping: return "cart.fill"
        case .takeout: return "takeoutbag.and.cup.and.straw.fill"
        case .payment: return "creditcard.fill"
        case .invoice: return "doc.text.fill"
        case .bankBill: return "building.columns.fill"
        case .taxi: return "car.fill"
        case .utility: return "bolt.fill"
        case .unknown: return "doc.fill"
        }
    }
    
    var suggestedCategory: String {
        switch self {
        case .shopping: return "购物"
        case .takeout: return "餐饮"
        case .payment: return "其他"
        case .invoice: return "其他"
        case .bankBill: return "其他"
        case .taxi: return "交通"
        case .utility: return "居家"
        case .unknown: return "其他"
        }
    }
}

// MARK: - OCR 结果
struct OCRResult {
    let rawText: String              // 原始识别文字
    let isValidReceipt: Bool         // 是否有效票据
    let receiptType: ReceiptType     // 票据类型
    let extractedInfo: ExtractedInfo // 提取的关键信息
    let confidence: Double           // 识别置信度
    
    struct ExtractedInfo {
        var amount: Decimal?         // 金额
        var merchant: String?        // 商家名称
        var date: Date?              // 日期
        var paymentMethod: String?   // 支付方式
    }
}

// MARK: - OCR 错误
enum OCRError: Error, LocalizedError {
    case imageConversionFailed
    case recognitionFailed
    case noTextFound
    case notAReceipt
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "图片转换失败"
        case .recognitionFailed:
            return "文字识别失败"
        case .noTextFound:
            return "未识别到文字"
        case .notAReceipt:
            return "这不像是一张票据"
        }
    }
}

// MARK: - 本地 OCR 服务
class LocalOCRService: ObservableObject {
    static let shared = LocalOCRService()
    
    @Published var isProcessing = false
    @Published var progress: Double = 0
    
    private init() {}
    
    // MARK: - 票据识别关键词
    private struct Keywords {
        // 有效票据指示词
        static let validIndicators: Set<String> = [
            // 金额相关
            "¥", "￥", "元", "合计", "总计", "实付", "应付", "金额", "总额",
            "实收", "找零", "优惠", "折扣", "原价",
            
            // 交易相关
            "支付", "付款", "收款", "转账", "消费", "交易", "订单",
            "充值", "提现", "退款",
            
            // 票据类型
            "小票", "收据", "发票", "账单", "清单",
            
            // 平台相关
            "微信", "支付宝", "美团", "饿了么", "滴滴", "淘宝", "京东",
            "拼多多", "抖音", "高德", "百度", "花呗", "借呗",
            
            // 商家类型
            "超市", "商场", "便利店", "餐厅", "酒店", "加油站"
        ]
        
        // 票据类型检测关键词
        static let typeIndicators: [ReceiptType: Set<String>] = [
            .shopping: ["超市", "商场", "便利店", "购物", "小票", "收银", "商品", "数量", "单价"],
            .takeout: ["外卖", "配送", "骑手", "美团", "饿了么", "送达", "打包费", "配送费"],
            .payment: ["转账", "收款", "付款成功", "支付成功", "交易成功", "微信支付", "支付宝"],
            .invoice: ["发票", "税额", "税率", "价税合计", "开票", "纳税人"],
            .bankBill: ["信用卡", "账单", "还款", "最低还款", "账单日", "还款日", "消费明细"],
            .taxi: ["滴滴", "高德打车", "曹操", "首汽", "行程", "上车", "下车", "里程", "时长"],
            .utility: ["电费", "水费", "燃气", "物业", "缴费", "电力", "自来水", "天然气"]
        ]
    }
    
    // MARK: - 主要识别方法
    func recognizeText(from image: UIImage) -> AnyPublisher<OCRResult, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(OCRError.recognitionFailed))
                return
            }
            
            DispatchQueue.main.async {
                self.isProcessing = true
                self.progress = 0.1
            }
            
            // 转换图片为 CGImage
            guard let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                promise(.failure(OCRError.imageConversionFailed))
                return
            }
            
            // 创建文字识别请求
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.progress = 0.7
                }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                    promise(.failure(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                    promise(.failure(OCRError.recognitionFailed))
                    return
                }
                
                // 提取识别的文字
                var recognizedText = ""
                var totalConfidence: Double = 0
                
                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        recognizedText += topCandidate.string + "\n"
                        totalConfidence += Double(topCandidate.confidence)
                    }
                }
                
                let averageConfidence = observations.isEmpty ? 0 : totalConfidence / Double(observations.count)
                
                DispatchQueue.main.async {
                    self.progress = 0.9
                }
                
                // 验证和解析票据
                let result = self.parseReceipt(text: recognizedText, confidence: averageConfidence)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.progress = 1.0
                }
                
                promise(.success(result))
            }
            
            // 配置识别参数
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true
            
            DispatchQueue.main.async {
                self.progress = 0.3
            }
            
            // 执行识别
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 解析票据
    private func parseReceipt(text: String, confidence: Double) -> OCRResult {
        let lowercasedText = text.lowercased()
        
        // 检查是否为有效票据
        let isValid = isValidReceipt(text: lowercasedText)
        
        // 检测票据类型
        let receiptType = detectReceiptType(text: lowercasedText)
        
        // 提取关键信息
        let extractedInfo = extractInfo(from: text)
        
        return OCRResult(
            rawText: text,
            isValidReceipt: isValid,
            receiptType: receiptType,
            extractedInfo: extractedInfo,
            confidence: confidence
        )
    }
    
    // MARK: - 验证是否为有效票据
    private func isValidReceipt(text: String) -> Bool {
        // 检查是否包含有效关键词
        let hasValidKeyword = Keywords.validIndicators.contains { text.contains($0.lowercased()) }
        
        // 检查是否包含金额模式
        let amountPattern = #"[¥￥]\s*\d+\.?\d*|(\d+\.?\d*)\s*元"#
        let hasAmount = text.range(of: amountPattern, options: .regularExpression) != nil
        
        return hasValidKeyword && hasAmount
    }
    
    // MARK: - 检测票据类型
    private func detectReceiptType(text: String) -> ReceiptType {
        var maxScore = 0
        var detectedType: ReceiptType = .unknown
        
        for (type, keywords) in Keywords.typeIndicators {
            let score = keywords.filter { text.contains($0.lowercased()) }.count
            if score > maxScore {
                maxScore = score
                detectedType = type
            }
        }
        
        return detectedType
    }
    
    // MARK: - 提取关键信息
    private func extractInfo(from text: String) -> OCRResult.ExtractedInfo {
        var info = OCRResult.ExtractedInfo()
        
        // 提取金额（优先匹配"合计"、"实付"、"总计"后面的金额）
        info.amount = extractAmount(from: text)
        
        // 提取商家名称
        info.merchant = extractMerchant(from: text)
        
        // 提取日期
        info.date = extractDate(from: text)
        
        // 提取支付方式
        info.paymentMethod = extractPaymentMethod(from: text)
        
        return info
    }
    
    // MARK: - 提取金额
    private func extractAmount(from text: String) -> Decimal? {
        // 优先匹配关键词后的金额
        let priorityPatterns = [
            #"(?:合计|总计|实付|应付|总额|实收)[：:]*\s*[¥￥]?\s*(\d+\.?\d*)"#,
            #"[¥￥]\s*(\d+\.?\d*)"#,
            #"(\d+\.?\d*)\s*元"#
        ]
        
        for pattern in priorityPatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let match = String(text[range])
                // 提取数字部分
                let numberPattern = #"\d+\.?\d*"#
                if let numberRange = match.range(of: numberPattern, options: .regularExpression) {
                    let numberString = String(match[numberRange])
                    if let amount = Decimal(string: numberString), amount > 0 {
                        return amount
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 提取商家名称
    private func extractMerchant(from text: String) -> String? {
        // 常见商家名称模式
        let patterns = [
            #"(?:商户|商家|店名|门店)[：:]*\s*(.+)"#,
            #"^(.+(?:超市|商场|便利店|餐厅|酒店|店))"#
        ]
        
        let lines = text.components(separatedBy: .newlines)
        
        for pattern in patterns {
            for line in lines {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let match = String(line[range])
                    // 清理提取的商家名
                    let cleaned = match
                        .replacingOccurrences(of: "商户", with: "")
                        .replacingOccurrences(of: "商家", with: "")
                        .replacingOccurrences(of: "店名", with: "")
                        .replacingOccurrences(of: "门店", with: "")
                        .replacingOccurrences(of: "：", with: "")
                        .replacingOccurrences(of: ":", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    
                    if !cleaned.isEmpty && cleaned.count <= 20 {
                        return cleaned
                    }
                }
            }
        }
        
        // 如果没有匹配到模式，尝试取第一行非空内容作为商家名
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.count >= 2 && trimmed.count <= 20 {
                // 排除一些明显不是商家名的内容
                let excludePatterns = ["¥", "￥", "元", "日期", "时间", "订单", "编号"]
                let isExcluded = excludePatterns.contains { trimmed.contains($0) }
                if !isExcluded {
                    return trimmed
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 提取日期
    private func extractDate(from text: String) -> Date? {
        let datePatterns = [
            #"\d{4}[-/年]\d{1,2}[-/月]\d{1,2}[日]?"#,
            #"\d{1,2}[-/月]\d{1,2}[日]?\s+\d{1,2}:\d{2}"#
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        
        for pattern in datePatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                var dateString = String(text[range])
                    .replacingOccurrences(of: "年", with: "-")
                    .replacingOccurrences(of: "月", with: "-")
                    .replacingOccurrences(of: "日", with: "")
                    .replacingOccurrences(of: "/", with: "-")
                
                // 尝试多种日期格式
                let formats = ["yyyy-M-d", "yyyy-MM-dd", "M-d HH:mm", "MM-dd HH:mm"]
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 提取支付方式
    private func extractPaymentMethod(from text: String) -> String? {
        let paymentMethods = [
            "微信支付": "微信",
            "支付宝": "支付宝",
            "现金": "现金",
            "银行卡": "银行卡",
            "信用卡": "信用卡",
            "花呗": "花呗",
            "云闪付": "云闪付"
        ]
        
        let lowercasedText = text.lowercased()
        
        for (keyword, method) in paymentMethods {
            if lowercasedText.contains(keyword.lowercased()) {
                return method
            }
        }
        
        return nil
    }
}

