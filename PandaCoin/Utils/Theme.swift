//
//  Theme.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI

// MARK: - 颜色主题配置
struct Theme {
    // MARK: - 主色调 (固定色)
    static let bambooGreen = Color(hex: "#2ECC71")
    static let pandaBlack = Color(hex: "#2C3E50")
    static let offWhite = Color(hex: "#F5F7FA")
    static let coralRed = Color(hex: "#FF6B6B")
    static let warning = Color(hex: "#F39C12")  // 警告/还款橙色
    
    // MARK: - 语义化颜色 (支持深色模式)
    static let income = bambooGreen
    static let expense = coralRed
    
    /// 主背景色 - 适配深色模式
    static var background: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1) // #1C1C1E
                : UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1) // #F5F7FA
        })
    }
    
    /// 卡片背景色 - 适配深色模式
    static var cardBackground: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1) // #2C2C2E
                : UIColor.white
        })
    }
    
    /// 主文本色 - 适配深色模式
    static var text: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.white
                : UIColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1) // #2C3E50
        })
    }
    
    /// 次要文本色 - 适配深色模式
    static var textSecondary: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1) // #8E8E93
                : UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1) // #8E8E93
        })
    }
    
    /// 分割线/边框色 - 适配深色模式
    static var separator: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.23, green: 0.23, blue: 0.26, alpha: 1) // #3A3A3C
                : UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1) // #E5E5EA
        })
    }
    
    // MARK: - CFO 设计令牌
    static let cfoShadow = Color.black.opacity(0.08)
    static let cardGradient = LinearGradient(
        colors: [bambooGreen, Color(hex: "#27AE60")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 银行卡品牌渐变映射
    static func cardGradient(for institution: String) -> LinearGradient {
        if institution.contains("招商") {
            return LinearGradient(colors: [Color(hex: "#E74C3C"), Color(hex: "#C0392B")], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if institution.contains("工") || institution.contains("建设") || institution.contains("中") {
            return LinearGradient(colors: [Color(hex: "#2980B9"), Color(hex: "#2C3E50")], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if institution.contains("支付宝") || institution.contains("Digital") {
            return LinearGradient(colors: [Color(hex: "#00A0E9"), Color(hex: "#007BB1")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [Color(hex: "#444444"), Color(hex: "#222222")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    // MARK: - 渐变色
    static let incomeGradient = LinearGradient(
        colors: [bambooGreen, bambooGreen.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let expenseGradient = LinearGradient(
        colors: [coralRed, coralRed.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 字体配置
struct AppFont {
    // 数字专用字体(等宽)
    static func monoNumber(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    
    // 标题字体
    static func title(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    
    // 正文字体
    static func body(size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Color扩展 (支持十六进制)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 圆角配置
struct CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
    static let extraLarge: CGFloat = 28
}

// MARK: - 间距配置
struct Spacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
}
