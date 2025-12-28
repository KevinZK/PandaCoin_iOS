//
//  LocalOCRService.swift
//  PandaCoin
//
//  本地 OCR 服务 - 使用 Vision 框架进行票据文字识别
//  支持多语言票据识别
//

import Foundation
import Vision
import UIKit
import Combine

// MARK: - 票据类型
enum ReceiptType: String, CaseIterable {
    case shopping = "SHOPPING"
    case takeout = "TAKEOUT"
    case payment = "PAYMENT"
    case invoice = "INVOICE"
    case bankBill = "BANK_BILL"
    case taxi = "TAXI"
    case utility = "UTILITY"
    case unknown = "UNKNOWN"

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .shopping: return NSLocalizedString("receipt_type_shopping", comment: "Shopping receipt")
        case .takeout: return NSLocalizedString("receipt_type_takeout", comment: "Takeout order")
        case .payment: return NSLocalizedString("receipt_type_payment", comment: "Payment screenshot")
        case .invoice: return NSLocalizedString("receipt_type_invoice", comment: "Invoice")
        case .bankBill: return NSLocalizedString("receipt_type_bank_bill", comment: "Bank statement")
        case .taxi: return NSLocalizedString("receipt_type_taxi", comment: "Taxi order")
        case .utility: return NSLocalizedString("receipt_type_utility", comment: "Utility bill")
        case .unknown: return NSLocalizedString("receipt_type_unknown", comment: "Other receipt")
        }
    }

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

    /// 建议的分类（使用枚举标识符）
    var suggestedCategory: String {
        switch self {
        case .shopping: return "SHOPPING"
        case .takeout: return "FOOD"
        case .payment: return "OTHER"
        case .invoice: return "OTHER"
        case .bankBill: return "OTHER"
        case .taxi: return "TRANSPORT"
        case .utility: return "HOUSING"
        case .unknown: return "OTHER"
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
            return NSLocalizedString("error_image_conversion", comment: "Image conversion failed")
        case .recognitionFailed:
            return NSLocalizedString("error_recognition_failed", comment: "Text recognition failed")
        case .noTextFound:
            return NSLocalizedString("error_no_text", comment: "No text found")
        case .notAReceipt:
            return NSLocalizedString("error_not_receipt", comment: "Not a receipt")
        }
    }
}

// MARK: - 本地 OCR 服务
class LocalOCRService: ObservableObject {
    static let shared = LocalOCRService()

    @Published var isProcessing = false
    @Published var progress: Double = 0

    private init() {}

    // MARK: - 多语言票据识别关键词
    private struct Keywords {
        // 有效票据指示词（多语言）
        static let validIndicators: Set<String> = [
            // 中文
            "¥", "￥", "元", "合计", "总计", "实付", "应付", "金额", "总额",
            "实收", "找零", "优惠", "折扣", "原价",
            "支付", "付款", "收款", "转账", "消费", "交易", "订单",
            "充值", "提现", "退款",
            "小票", "收据", "发票", "账单", "清单",
            "微信", "支付宝", "美团", "饿了么", "滴滴", "淘宝", "京东",
            "拼多多", "抖音", "高德", "百度", "花呗", "借呗",
            "超市", "商场", "便利店", "餐厅", "酒店", "加油站",

            // 英文
            "$", "total", "subtotal", "amount", "price", "paid", "payment",
            "receipt", "invoice", "bill", "order", "transaction",
            "visa", "mastercard", "paypal", "apple pay", "google pay",
            "walmart", "amazon", "starbucks", "mcdonald", "uber",

            // 日文
            "円", "合計", "税込", "税抜", "お会計", "お支払い", "レシート",
            "領収書", "請求書", "カード", "現金", "クレジット",

            // 韩文
            "원", "합계", "총액", "결제", "영수증", "카드",

            // 德文
            "€", "gesamt", "summe", "betrag", "zahlung", "quittung", "rechnung",

            // 法文
            "total", "montant", "paiement", "reçu", "facture",

            // 西班牙文
            "total", "importe", "pago", "recibo", "factura"
        ]

        // 票据类型检测关键词（多语言）
        static let typeIndicators: [ReceiptType: Set<String>] = [
            .shopping: [
                // 中文
                "超市", "商场", "便利店", "购物", "小票", "收银", "商品", "数量", "单价",
                // 英文
                "supermarket", "mall", "store", "shopping", "receipt", "item", "quantity", "price",
                "walmart", "target", "costco", "grocery",
                // 日文
                "スーパー", "コンビニ", "お買い物", "商品",
                // 韩文
                "마트", "쇼핑"
            ],
            .takeout: [
                // 中文
                "外卖", "配送", "骑手", "美团", "饿了么", "送达", "打包费", "配送费",
                // 英文
                "delivery", "takeout", "takeaway", "uber eats", "doordash", "grubhub", "deliveroo",
                // 日文
                "デリバリー", "出前", "配達",
                // 韩文
                "배달", "배민"
            ],
            .payment: [
                // 中文
                "转账", "收款", "付款成功", "支付成功", "交易成功", "微信支付", "支付宝",
                // 英文
                "transfer", "payment successful", "transaction complete", "apple pay", "google pay",
                // 日文
                "送金", "支払い完了",
                // 韩文
                "이체", "결제 완료"
            ],
            .invoice: [
                // 中文
                "发票", "税额", "税率", "价税合计", "开票", "纳税人",
                // 英文
                "invoice", "tax", "vat", "tax rate", "taxpayer",
                // 日文
                "請求書", "税",
                // 德文
                "rechnung", "mwst", "steuer"
            ],
            .bankBill: [
                // 中文
                "信用卡", "账单", "还款", "最低还款", "账单日", "还款日", "消费明细",
                // 英文
                "credit card", "statement", "minimum payment", "due date", "balance",
                // 日文
                "クレジットカード", "明細"
            ],
            .taxi: [
                // 中文
                "滴滴", "高德打车", "曹操", "首汽", "行程", "上车", "下车", "里程", "时长",
                // 英文
                "uber", "lyft", "taxi", "ride", "trip", "pickup", "dropoff", "miles", "fare",
                // 日文
                "タクシー", "乗車"
            ],
            .utility: [
                // 中文
                "电费", "水费", "燃气", "物业", "缴费", "电力", "自来水", "天然气",
                // 英文
                "electricity", "water", "gas", "utility", "bill", "electric", "power",
                // 日文
                "電気", "水道", "ガス",
                // 德文
                "strom", "wasser"
            ]
        ]

        // 支付方式关键词（多语言）
        static let paymentMethods: [(keywords: [String], method: String)] = [
            // 中文
            (["微信支付", "微信"], "WeChat Pay"),
            (["支付宝"], "Alipay"),
            (["花呗"], "Huabei"),
            (["云闪付"], "UnionPay"),

            // 英文
            (["apple pay"], "Apple Pay"),
            (["google pay"], "Google Pay"),
            (["paypal"], "PayPal"),
            (["visa"], "Visa"),
            (["mastercard", "master card"], "Mastercard"),
            (["amex", "american express"], "American Express"),

            // 通用
            (["现金", "cash", "現金", "현금", "bargeld", "espèces", "efectivo"], "Cash"),
            (["信用卡", "credit card", "クレジット", "신용카드", "kreditkarte", "carte de crédit", "tarjeta de crédito"], "Credit Card"),
            (["借记卡", "debit card", "デビット"], "Debit Card"),
            (["银行卡", "bank card"], "Bank Card")
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

            // 配置识别参数 - 支持多语言
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR", "de-DE", "fr-FR", "es-ES"]
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

        // 检查是否包含金额模式（多语言支持）
        let amountPatterns = [
            // 中文格式
            #"[¥￥]\s*\d+\.?\d*"#,
            #"\d+\.?\d*\s*元"#,
            #"(?:合计|总计|实付|应付|应收|实收)[：:]*\s*\d+\.?\d*"#,
            // 日文格式
            #"\d+\s*円"#,
            #"(?:合計|お会計)[：:]*\s*\d+"#,
            // 韩文格式
            #"\d+\s*원"#,
            #"(?:합계|총액)[：:]*\s*\d+"#,
            // 英文/欧洲格式
            #"\$\s*\d+\.?\d*"#,
            #"€\s*\d+[,.]?\d*"#,
            #"(?:total|subtotal|amount)[:\s]*\$?\s*\d+\.?\d*"#,
            // 通用两位小数格式
            #"\d+\.\d{2}"#
        ]

        let hasAmount = amountPatterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }

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

        // 提取金额
        info.amount = extractAmount(from: text)

        // 提取商家名称
        info.merchant = extractMerchant(from: text)

        // 提取日期
        info.date = extractDate(from: text)

        // 提取支付方式
        info.paymentMethod = extractPaymentMethod(from: text)

        return info
    }

    // MARK: - 提取金额（多语言）
    private func extractAmount(from text: String) -> Decimal? {
        // 优先匹配关键词后的金额（多语言）
        let priorityPatterns = [
            // 中文
            #"(?:合计|总计|实付|应付|总额|实收)[：:]*\s*[¥￥]?\s*(\d+\.?\d*)"#,
            // 日文
            #"(?:合計|お会計|税込)[：:]*\s*(\d+)"#,
            // 英文
            #"(?:total|subtotal|amount|paid)[:\s]*\$?\s*(\d+\.?\d*)"#,
            // 货币符号
            #"[¥￥\$€]\s*(\d+[,.]?\d*)"#,
            // 货币后缀
            #"(\d+\.?\d*)\s*(?:元|円|원)"#
        ]

        for pattern in priorityPatterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let match = String(text[range])
                // 提取数字部分
                let numberPattern = #"\d+[,.]?\d*"#
                if let numberRange = match.range(of: numberPattern, options: .regularExpression) {
                    var numberString = String(match[numberRange])
                    // 处理欧洲格式（逗号作为小数点）
                    numberString = numberString.replacingOccurrences(of: ",", with: ".")
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
        // 常见商家名称模式（多语言）
        let patterns = [
            // 中文
            #"(?:商户|商家|店名|门店)[：:]*\s*(.+)"#,
            #"^(.+(?:超市|商场|便利店|餐厅|酒店|店))"#,
            // 日文
            #"(?:店舗|お店)[：:]*\s*(.+)"#,
            // 英文
            #"(?:merchant|store|shop)[:\s]*(.+)"#
        ]

        let lines = text.components(separatedBy: .newlines)

        for pattern in patterns {
            for line in lines {
                if let range = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    var cleaned = String(line[range])
                    // 清理提取的商家名
                    let removeWords = ["商户", "商家", "店名", "门店", "店舗", "お店", "merchant", "store", "shop", "：", ":"]
                    for word in removeWords {
                        cleaned = cleaned.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
                    }
                    cleaned = cleaned.trimmingCharacters(in: .whitespaces)

                    if !cleaned.isEmpty && cleaned.count <= 30 {
                        return cleaned
                    }
                }
            }
        }

        // 如果没有匹配到模式，尝试取第一行非空内容作为商家名
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.count >= 2 && trimmed.count <= 30 {
                // 排除一些明显不是商家名的内容
                let excludePatterns = ["¥", "￥", "$", "€", "元", "円", "원", "日期", "时间", "订单", "编号", "date", "time", "order"]
                let isExcluded = excludePatterns.contains { trimmed.lowercased().contains($0.lowercased()) }
                if !isExcluded {
                    return trimmed
                }
            }
        }

        return nil
    }

    // MARK: - 提取日期（多语言）
    private func extractDate(from text: String) -> Date? {
        let datePatterns = [
            // ISO格式
            #"\d{4}[-/]\d{1,2}[-/]\d{1,2}"#,
            // 中文格式
            #"\d{4}年\d{1,2}月\d{1,2}日?"#,
            // 日文格式
            #"\d{4}年\d{1,2}月\d{1,2}日"#,
            // 欧洲格式 (dd/mm/yyyy)
            #"\d{1,2}[./]\d{1,2}[./]\d{4}"#,
            // 美国格式 (mm/dd/yyyy)
            #"\d{1,2}/\d{1,2}/\d{4}"#
        ]

        let dateFormatter = DateFormatter()

        for pattern in datePatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                var dateString = String(text[range])
                    .replacingOccurrences(of: "年", with: "-")
                    .replacingOccurrences(of: "月", with: "-")
                    .replacingOccurrences(of: "日", with: "")
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ".", with: "-")

                // 尝试多种日期格式
                let formats = ["yyyy-M-d", "yyyy-MM-dd", "d-M-yyyy", "dd-MM-yyyy", "M-d-yyyy", "MM-dd-yyyy"]
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

    // MARK: - 提取支付方式（多语言）
    private func extractPaymentMethod(from text: String) -> String? {
        let lowercasedText = text.lowercased()

        for (keywords, method) in Keywords.paymentMethods {
            for keyword in keywords {
                if lowercasedText.contains(keyword.lowercased()) {
                    return method
                }
            }
        }

        return nil
    }
}
