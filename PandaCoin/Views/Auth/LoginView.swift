//
//  LoginView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Combine

struct LoginView: View {
    @StateObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRegister = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.extraLarge) {
                        // Logo区域
                        VStack(spacing: Spacing.medium) {
                            Text("🐼")
                                .font(.system(size: 80))
                            
                            Text("熊猫记账")
                                .font(AppFont.title(size: 32))
                                .foregroundColor(Theme.text)
                            
                            Text("动口不动手,让AI做你的私人财务官")
                                .font(AppFont.body(size: 14))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Spacing.extraLarge * 2)
                        
                        // 表单区域
                        VStack(spacing: Spacing.large) {
                            // 邮箱输入
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("邮箱")
                                    .font(AppFont.body(size: 14, weight: .medium))
                                    .foregroundColor(Theme.text)
                                
                                TextField("请输入邮箱", text: $email)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }
                            
                            // 密码输入
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("密码")
                                    .font(AppFont.body(size: 14, weight: .medium))
                                    .foregroundColor(Theme.text)
                                
                                SecureField("请输入密码", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.password)
                            }
                            
                            // 错误提示
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .font(AppFont.body(size: 12))
                                    .foregroundColor(Theme.expense)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // 登录按钮
                            Button(action: handleLogin) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("登录")
                                        .font(AppFont.body(size: 18, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.bambooGreen)
                            .foregroundColor(.white)
                            .cornerRadius(CornerRadius.medium)
                            .disabled(isLoading || !isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.5)
                            
                            // Debug模式：一键登录按钮
                            #if DEBUG
                            Button(action: debugAutoLogin) {
                                HStack(spacing: Spacing.small) {
                                    Image(systemName: "hammer.fill")
                                        .font(.system(size: 14))
                                    Text("[DEBUG] 一键登录")
                                        .font(AppFont.body(size: 16, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(CornerRadius.medium)
                            }
                            .disabled(isLoading)
                            #endif
                            
                            // 注册链接
                            Button(action: { showRegister = true }) {
                                HStack(spacing: Spacing.tiny) {
                                    Text("还没有账户?")
                                        .foregroundColor(Theme.textSecondary)
                                    Text("立即注册")
                                        .foregroundColor(Theme.bambooGreen)
                                        .fontWeight(.medium)
                                }
                                .font(AppFont.body(size: 14))
                            }
                        }
                        .padding(.horizontal, Spacing.large)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
    }
    
    // MARK: - Actions
    
    #if DEBUG
    /// Debug模式专用：一键登录测试账号
    private func debugAutoLogin() {
        logInfo("🔨 [DEBUG] 使用测试账号自动登录")
        
        // 使用配置中的测试账号
        email = DebugConfig.TestAccount.email
        password = DebugConfig.TestAccount.password
        
        // 延迟一下让UI更新，然后自动登录
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.handleLogin()
        }
    }
    #endif
    
    private func handleLogin() {
        errorMessage = nil
        isLoading = true
        
        var cancellable: AnyCancellable?
        cancellable = authService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [self] completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                    cancellable?.cancel()
                },
                receiveValue: { _ in
                    // 登录成功,AuthService会自动更新状态
                }
            )
    }
}

// MARK: - 自定义文本框样式
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Spacing.medium)
            .background(Color.white)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    LoginView()
}
