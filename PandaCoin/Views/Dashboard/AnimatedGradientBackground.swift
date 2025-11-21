//
//  AnimatedGradientBackground.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI

/// 流动的渐变背景动画
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // 基础渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.95, blue: 0.93),  // 米白色
                    Color(red: 0.98, green: 0.98, blue: 0.96),  // 浅米色
                    Color(red: 0.92, green: 0.94, blue: 0.92),  // 淡绿灰
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 8)
                    .repeatForever(autoreverses: true)
                ) {
                    animateGradient.toggle()
                }
            }
            
            // 水墨效果层
            InkBrushEffect()
        }
    }
}

/// 水墨笔刷效果
struct InkBrushEffect: View {
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 多层水墨效果
                ForEach(0..<3) { index in
                    WaveShape(offset: offsetY + CGFloat(index) * 50, amplitude: 40 + CGFloat(index) * 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.05 + Double(index) * 0.02),
                                    Color.gray.opacity(0.08 + Double(index) * 0.03),
                                    Color.black.opacity(0.03 + Double(index) * 0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blur(radius: 20 + CGFloat(index) * 10)
                        .offset(y: geometry.size.height * 0.3 + CGFloat(index) * 60)
                }
                
                // 绿色点缀
                ForEach(0..<5) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.3),
                                    Color.green.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .position(
                            x: CGFloat.random(in: 40...(geometry.size.width - 40)),
                            y: CGFloat(index) * geometry.size.height / 5 + offsetY / 2
                        )
                }
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 10)
                    .repeatForever(autoreverses: true)
                ) {
                    offsetY = 100
                    opacity = 0.5
                }
            }
        }
    }
}

/// 波浪形状
struct WaveShape: Shape {
    var offset: CGFloat
    var amplitude: CGFloat
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX + offset / 100) * .pi * 2)
            let y = midHeight + sine * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    AnimatedGradientBackground()
}
